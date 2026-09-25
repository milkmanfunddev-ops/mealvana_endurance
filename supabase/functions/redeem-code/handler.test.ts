/**
 * Seam tests for the redeem-code edge function (mp-458, mp-461; paywall ticket 07).
 *
 * The handler is built by `makeRedeemHandler()` with the caller lookup, the
 * database and the RevenueCat REST client injected, so these tests run the
 * code the deployed function runs. The database is the shared in-memory
 * PostgREST fake with rows shaped as the tables hold them (`codes`,
 * `code_redemptions`, `coaches`, `coach_athlete_relationships`, `users`), and
 * `code_claim` is faked to do what the migration's SQL function does. The
 * RevenueCat client is a fake that records grants and attributes.
 *
 * What it must do:
 *   - a coach entering their own code is marked coach and gets 30 days of `pro`;
 *   - an athlete entering a coach or influencer code gets the attribute set;
 *     a coach code also opens a pending pairing with the coach, an influencer
 *     code never pairs;
 *   - an account RevenueCat has never seen is created there first;
 *   - a giveaway code grants 365 days, once, and stays spent after the
 *     account that redeemed it is deleted;
 *   - a wrong, not-yet-valid, expired or used code gets a plain reason, and
 *     nothing is written or granted;
 *   - only a signed-in (not anonymous) caller gets in.
 *
 * Run with:
 *   deno test --allow-read --allow-write --allow-env --allow-sys --node-modules-dir=none \
 *     supabase/functions/redeem-code/handler.test.ts
 */
import { assert, assertEquals } from 'https://deno.land/std@0.224.0/assert/mod.ts';
import { describe, it } from 'https://deno.land/std@0.224.0/testing/bdd.ts';
import { type Caller, makeRedeemHandler, REFUSALS } from './handler.ts';
import { fakeDb, type FakeDb, type Row } from '../tests/vana/support/fake_db.ts';
import { RevenueCatError, type RevenueCatClient } from '../_shared/revenuecat/client.ts';
import type { Db } from '../_shared/vana/env.ts';

const COACH = 'c0ac0000-0000-4000-8000-000000000001';
const ATHLETE = 'a0000000-0000-4000-8000-000000000002';
const INFLUENCER = '1f000000-0000-4000-8000-000000000003';
const WINNER = '91f70000-0000-4000-8000-000000000004';
const SECOND_WINNER = '91f70000-0000-4000-8000-000000000005';

const NOW = Date.parse('2026-10-05T12:00:00Z');
const DAY = 24 * 60 * 60 * 1000;
const iso = (ms: number) => new Date(ms).toISOString();

// ---------------------------------------------------------------------------
// Rows, as the tables hold them
// ---------------------------------------------------------------------------

const code = (over: Row): Row => ({
  id: crypto.randomUUID(),
  code: 'KYLE30',
  type: 'coach',
  owner_user_id: COACH,
  valid_from: iso(NOW - 10 * DAY),
  valid_until: null,
  perk_days: 30,
  max_redemptions: null,
  note: null,
  created_at: iso(NOW - 10 * DAY),
  updated_at: iso(NOW - 10 * DAY),
  ...over,
});

const users = (): Row[] => [
  { id: COACH, first_name: 'Kyle', last_name: 'Coach', email: 'kyle@example.com', is_anonymous: false },
  { id: ATHLETE, first_name: 'Ava', last_name: 'Athlete', email: 'ava@example.com', is_anonymous: false },
  { id: INFLUENCER, first_name: 'Ivy', last_name: 'Influencer', email: 'ivy@example.com', is_anonymous: false },
  { id: WINNER, first_name: null, last_name: null, email: 'win@example.com', is_anonymous: false },
  { id: SECOND_WINNER, first_name: null, last_name: null, email: 'win2@example.com', is_anonymous: false },
];

/**
 * What the migration's `code_claim` does, in one transaction: the code row is
 * locked, a caller who already redeemed it is told so, a code at its
 * redemption limit (a giveaway's is 1 unless the row says otherwise) is used,
 * and otherwise one `code_redemptions` row is written.
 */
function claimRpc(db: FakeDb) {
  // deno-lint-ignore no-explicit-any
  return (args: any) => {
    const c = db.rows('codes').find((r) => r.id === args.p_code_id);
    if (!c) return 'not_found';
    const mine = db.rows('code_redemptions').filter((r) => r.code_id === c.id);
    if (mine.some((r) => r.user_id === args.p_user_id)) return 'already_redeemed';
    const limit = c.type === 'giveaway' ? (c.max_redemptions ?? 1) : c.max_redemptions;
    if (limit != null && mine.length >= limit) return 'used';
    db.rows('code_redemptions').push({
      id: crypto.randomUUID(),
      code_id: c.id,
      user_id: args.p_user_id,
      redeemed_at: iso(NOW),
    });
    return 'claimed';
  };
}

/**
 * What deleting an auth account does to `code_redemptions`, read from the
 * newest migration that declares the `user_id` foreign key: `cascade` drops the
 * account's rows, `set null` keeps them with no user. The fake follows the SQL,
 * so a migration that changes the rule changes what these tests see.
 */
function redemptionUserOnDelete(): 'cascade' | 'set null' {
  const dir = new URL('../../migrations/', import.meta.url);
  const files = [...Deno.readDirSync(dir)]
    .filter((e) => e.isFile && e.name.endsWith('.sql'))
    .map((e) => e.name)
    .sort()
    .reverse();
  const rule = /user_id\s+uuid[^,;]*?references\s+auth\.users\s*\(\s*id\s*\)\s+on\s+delete\s+(cascade|set\s+null)|code_redemptions_user_id_fkey\s+foreign\s+key\s*\(\s*user_id\s*\)\s+references\s+auth\.users\s*\(\s*id\s*\)\s+on\s+delete\s+(cascade|set\s+null)/i;
  for (const name of files) {
    const sql = Deno.readTextFileSync(new URL(name, dir));
    if (!/code_redemptions/i.test(sql)) continue;
    const m = sql.match(rule);
    if (m) return (m[1] ?? m[2]).toLowerCase().replace(/\s+/, ' ') as 'cascade' | 'set null';
  }
  throw new Error('no migration declares the code_redemptions.user_id foreign key');
}

/** Delete an account the way `delete-user` does, with the migrations' FK rule applied. */
function deleteAccount(db: FakeDb, userId: string): void {
  const rows = db.rows('code_redemptions');
  if (redemptionUserOnDelete() === 'cascade') {
    for (let i = rows.length - 1; i >= 0; i--) if (rows[i].user_id === userId) rows.splice(i, 1);
  } else {
    for (const r of rows) if (r.user_id === userId) r.user_id = null;
  }
}

function world(codes: Row[], extra: Record<string, Row[]> = {}): FakeDb {
  // deno-lint-ignore no-explicit-any
  const rpc = { code_claim: (args: any) => claimRpc(db)(args) };
  const db: FakeDb = fakeDb(
    { codes, users: users(), code_redemptions: [], coaches: [], coach_athlete_relationships: [], ...extra },
    { rpc },
  );
  return db;
}

// ---------------------------------------------------------------------------
// A fake RevenueCat REST client
// ---------------------------------------------------------------------------

interface FakeRc extends RevenueCatClient {
  grants: { user: string; days: number }[];
  attributes: { user: string; attributes: Record<string, string> }[];
  failGrant?: RevenueCatError;
  failAttributes?: RevenueCatError;
  /** Customers RevenueCat has never seen: a write for one answers 404 until it is created. */
  unknown: Set<string>;
  created: string[];
}

function fakeRc(): FakeRc {
  const rc: FakeRc = {
    grants: [],
    attributes: [],
    unknown: new Set(),
    created: [],
    // deno-lint-ignore require-await
    async currentProExpiry() {
      return null;
    },
    // deno-lint-ignore require-await
    async grantPro(user, days) {
      if (rc.failGrant) throw rc.failGrant;
      if (rc.unknown.has(user)) throw new RevenueCatError(`RevenueCat has no customer ${user}`, 404);
      rc.grants.push({ user, days });
    },
    // deno-lint-ignore require-await
    async setAttributes(user, attributes) {
      if (rc.failAttributes) throw rc.failAttributes;
      if (rc.unknown.has(user)) throw new RevenueCatError(`RevenueCat has no customer ${user}`, 404);
      rc.attributes.push({ user, attributes });
    },
    // deno-lint-ignore require-await
    async getAttributes() {
      throw new Error('redeem-code never reads attributes');
    },
    // deno-lint-ignore require-await
    async promotionalProEnd() {
      throw new Error('redeem-code never reads grants');
    },
    // deno-lint-ignore require-await
    async createCustomer(user) {
      rc.unknown.delete(user);
      rc.created.push(user);
    },
  };
  return rc;
}

// ---------------------------------------------------------------------------
// Driving the handler
// ---------------------------------------------------------------------------

const signedIn = (userId: string): Caller => ({ userId, email: users().find((u) => u.id === userId)?.email ?? null, anonymous: false });

async function redeem(
  db: FakeDb,
  rc: FakeRc,
  caller: Caller | null,
  body: unknown,
): Promise<{ status: number; body: Record<string, unknown> }> {
  const handler = makeRedeemHandler({
    caller: () => Promise.resolve(caller),
    db: () => db as unknown as Db,
    revenueCat: () => rc,
    now: () => NOW,
  });
  const res = await handler(
    new Request('https://stub.supabase.test/functions/v1/redeem-code', {
      method: 'POST',
      headers: { Authorization: 'Bearer user-jwt', 'Content-Type': 'application/json' },
      body: typeof body === 'string' ? body : JSON.stringify(body),
    }),
  );
  return { status: res.status, body: await res.json() };
}

const refusedWith = (res: { status: number; body: Record<string, unknown> }, reason: keyof typeof REFUSALS) => {
  assertEquals(res.status, 200);
  assertEquals(res.body.ok, false);
  assertEquals(res.body.reason, reason);
  assertEquals(res.body.message, REFUSALS[reason]);
};

/** Nothing reached the database's write side except, at most, reads. */
const nothingWritten = (db: FakeDb, rc: FakeRc) => {
  assertEquals(db.writes.length, 0);
  assertEquals(db.rows('code_redemptions').length, 0);
  assertEquals(rc.grants.length, 0);
  assertEquals(rc.attributes.length, 0);
};

// ---------------------------------------------------------------------------

describe('a coach entering their own code', () => {
  it('is marked coach and gets 30 days of pro', async () => {
    const db = world([code({})]);
    const rc = fakeRc();
    const res = await redeem(db, rc, signedIn(COACH), { code: 'KYLE30' });

    assertEquals(res.status, 200);
    assertEquals(res.body.ok, true);
    assertEquals(res.body.kind, 'coach');
    assertEquals(res.body.pro_days, 30);
    assertEquals(rc.grants, [{ user: COACH, days: 30 }]);

    const coaches = db.rows('coaches');
    assertEquals(coaches.length, 1);
    assertEquals(coaches[0].user_id, COACH);
    assertEquals(coaches[0].application_status, 'approved');
    assertEquals(coaches[0].first_name, 'Kyle');
    assertEquals(coaches[0].email, 'kyle@example.com');
    assert(coaches[0].approved_at);
    assertEquals(db.rows('code_redemptions').map((r) => r.user_id), [COACH]);
  });

  it('with an existing pending application approves it rather than adding a second row', async () => {
    const db = world([code({})], {
      coaches: [{
        id: 'c0ac-row',
        user_id: COACH,
        first_name: 'Kyle',
        last_name: 'Coach',
        email: 'kyle@example.com',
        application_status: 'pending',
        approved_at: null,
      }],
    });
    const rc = fakeRc();
    const res = await redeem(db, rc, signedIn(COACH), { code: 'KYLE30' });
    assertEquals(res.body.ok, true);
    assertEquals(db.rows('coaches').length, 1);
    assertEquals(db.rows('coaches')[0].application_status, 'approved');
    assertEquals(db.writesTo('coaches', 'insert').length, 0);
  });

  it('is matched however the code is typed (case and spaces)', async () => {
    const db = world([code({})]);
    const rc = fakeRc();
    const res = await redeem(db, rc, signedIn(COACH), { code: '  kyle 30 ' });
    assertEquals(res.body.ok, true);
    assertEquals(rc.grants, [{ user: COACH, days: 30 }]);
  });

  it('a coach RevenueCat has never seen (a web sign-up) is created there, then granted', async () => {
    const db = world([code({})]);
    const rc = fakeRc();
    rc.unknown.add(COACH);
    const res = await redeem(db, rc, signedIn(COACH), { code: 'KYLE30' });
    assertEquals(res.body.ok, true);
    assertEquals(rc.created, [COACH]);
    assertEquals(rc.grants, [{ user: COACH, days: 30 }]);
  });

  it('a second time is refused: the 30 days are granted once', async () => {
    const db = world([code({})]);
    const rc = fakeRc();
    await redeem(db, rc, signedIn(COACH), { code: 'KYLE30' });
    const again = await redeem(db, rc, signedIn(COACH), { code: 'KYLE30' });
    refusedWith(again, 'already_redeemed');
    assertEquals(rc.grants.length, 1);
  });

  it('a grant RevenueCat refuses answers 502 and frees the claim so the coach can try again', async () => {
    const db = world([code({})]);
    const rc = fakeRc();
    rc.failGrant = new RevenueCatError('RevenueCat POST → 503', 503);
    const res = await redeem(db, rc, signedIn(COACH), { code: 'KYLE30' });
    assertEquals(res.status, 502);
    assertEquals(res.body.error, 'store_unavailable');
    assertEquals(db.rows('code_redemptions').length, 0);

    rc.failGrant = undefined;
    const retry = await redeem(db, rc, signedIn(COACH), { code: 'KYLE30' });
    assertEquals(retry.body.ok, true);
    assertEquals(rc.grants, [{ user: COACH, days: 30 }]);
  });
});

describe('an athlete entering a coach code', () => {
  it('gets coach_code set and a pending pairing with the coach, and no pro', async () => {
    const db = world([code({})]);
    const rc = fakeRc();
    const res = await redeem(db, rc, signedIn(ATHLETE), { code: 'KYLE30' });

    assertEquals(res.status, 200);
    assertEquals(res.body.ok, true);
    assertEquals(res.body.kind, 'paired');
    assertEquals(res.body.coach_user_id, COACH);
    assertEquals(rc.attributes, [{ user: ATHLETE, attributes: { coach_code: 'KYLE30' } }]);
    assertEquals(rc.grants.length, 0);
    assertEquals(db.rows('coaches').length, 0);

    // The existing pairing path's row: athlete-requested, pending, until the coach accepts.
    const pairs = db.rows('coach_athlete_relationships');
    assertEquals(pairs.length, 1);
    assertEquals(pairs[0].coach_user_id, COACH);
    assertEquals(pairs[0].athlete_user_id, ATHLETE);
    assertEquals(pairs[0].status, 'pending');
    assertEquals(pairs[0].requested_by, 'athlete');
    assert(pairs[0].requested_at);
  });

  it('already paired with that coach leaves the pairing as it is', async () => {
    const db = world([code({})], {
      coach_athlete_relationships: [{
        id: 'rel-1',
        coach_user_id: COACH,
        athlete_user_id: ATHLETE,
        status: 'active',
        requested_by: 'coach',
        accepted_at: iso(NOW - DAY),
      }],
    });
    const rc = fakeRc();
    const res = await redeem(db, rc, signedIn(ATHLETE), { code: 'KYLE30' });
    assertEquals(res.body.ok, true);
    assertEquals(db.rows('coach_athlete_relationships').length, 1);
    assertEquals(db.rows('coach_athlete_relationships')[0].status, 'active');
    assertEquals(db.writesTo('coach_athlete_relationships').length, 0);
    assertEquals(rc.attributes, [{ user: ATHLETE, attributes: { coach_code: 'KYLE30' } }]);
  });

  it('after an archived pairing asks again: the row goes back to pending', async () => {
    const db = world([code({})], {
      coach_athlete_relationships: [{
        id: 'rel-1',
        coach_user_id: COACH,
        athlete_user_id: ATHLETE,
        status: 'archived',
        requested_by: 'coach',
        archived_at: iso(NOW - DAY),
      }],
    });
    const rc = fakeRc();
    const res = await redeem(db, rc, signedIn(ATHLETE), { code: 'KYLE30' });
    assertEquals(res.body.ok, true);
    const pairs = db.rows('coach_athlete_relationships');
    assertEquals(pairs.length, 1);
    assertEquals(pairs[0].status, 'pending');
    assertEquals(pairs[0].requested_by, 'athlete');
    assertEquals(pairs[0].archived_at, null);
  });

  it('an attribute RevenueCat refuses answers 502 and frees the claim', async () => {
    const db = world([code({})]);
    const rc = fakeRc();
    rc.failAttributes = new RevenueCatError('RevenueCat has no customer', 404);
    const res = await redeem(db, rc, signedIn(ATHLETE), { code: 'KYLE30' });
    assertEquals(res.status, 502);
    assertEquals(db.rows('code_redemptions').length, 0);
  });
});

describe('an athlete entering an influencer code', () => {
  it('gets influencer_code set and no pairing: an influencer is not a coach', async () => {
    const db = world([code({ code: 'IVYRUNS', type: 'influencer', owner_user_id: INFLUENCER, perk_days: 0 })]);
    const rc = fakeRc();
    const res = await redeem(db, rc, signedIn(ATHLETE), { code: 'ivyruns' });

    assertEquals(res.body.ok, true);
    assertEquals(res.body.kind, 'attributed');
    assertEquals(rc.attributes, [{ user: ATHLETE, attributes: { influencer_code: 'IVYRUNS' } }]);
    assertEquals(rc.grants.length, 0);
    assertEquals(db.rows('coach_athlete_relationships').length, 0);
  });

  it('an athlete RevenueCat has never seen is created there, then attributed', async () => {
    const db = world([code({ code: 'PODCAST', type: 'influencer', owner_user_id: null, perk_days: 0 })]);
    const rc = fakeRc();
    rc.unknown.add(ATHLETE);
    const res = await redeem(db, rc, signedIn(ATHLETE), { code: 'PODCAST' });
    assertEquals(res.body.ok, true);
    assertEquals(rc.created, [ATHLETE]);
    assertEquals(rc.attributes, [{ user: ATHLETE, attributes: { influencer_code: 'PODCAST' } }]);
  });

  it('with no owner sets the attribute and pairs with no one', async () => {
    const db = world([code({ code: 'PODCAST', type: 'influencer', owner_user_id: null, perk_days: 0 })]);
    const rc = fakeRc();
    const res = await redeem(db, rc, signedIn(ATHLETE), { code: 'PODCAST' });
    assertEquals(res.body.ok, true);
    assertEquals(res.body.kind, 'attributed');
    assertEquals(rc.attributes, [{ user: ATHLETE, attributes: { influencer_code: 'PODCAST' } }]);
    assertEquals(db.rows('coach_athlete_relationships').length, 0);
  });

  it('entered by its own owner is refused', async () => {
    const db = world([code({ code: 'IVYRUNS', type: 'influencer', owner_user_id: INFLUENCER, perk_days: 0 })]);
    const rc = fakeRc();
    refusedWith(await redeem(db, rc, signedIn(INFLUENCER), { code: 'IVYRUNS' }), 'own_code');
    nothingWritten(db, rc);
  });
});

describe('a giveaway code', () => {
  it('grants 365 days of pro', async () => {
    const db = world([code({ code: 'WIN2026', type: 'giveaway', owner_user_id: null, perk_days: 365 })]);
    const rc = fakeRc();
    const res = await redeem(db, rc, signedIn(WINNER), { code: 'WIN2026' });
    assertEquals(res.status, 200);
    assertEquals(res.body.ok, true);
    assertEquals(res.body.kind, 'giveaway');
    assertEquals(res.body.pro_days, 365);
    assertEquals(rc.grants, [{ user: WINNER, days: 365 }]);
    assertEquals(rc.attributes.length, 0);
    assertEquals(db.rows('coach_athlete_relationships').length, 0);
  });

  it('works once: the next person is told it has been used', async () => {
    const db = world([code({ code: 'WIN2026', type: 'giveaway', owner_user_id: null, perk_days: 365 })]);
    const rc = fakeRc();
    await redeem(db, rc, signedIn(WINNER), { code: 'WIN2026' });
    refusedWith(await redeem(db, rc, signedIn(SECOND_WINNER), { code: 'WIN2026' }), 'used');
    assertEquals(rc.grants, [{ user: WINNER, days: 365 }]);
  });

  it('entered twice by the winner is refused the second time', async () => {
    const db = world([code({ code: 'WIN2026', type: 'giveaway', owner_user_id: null, perk_days: 365 })]);
    const rc = fakeRc();
    await redeem(db, rc, signedIn(WINNER), { code: 'WIN2026' });
    refusedWith(await redeem(db, rc, signedIn(WINNER), { code: 'WIN2026' }), 'already_redeemed');
    assertEquals(rc.grants.length, 1);
  });

  it('a failed grant frees the code for the winner to try again', async () => {
    const db = world([code({ code: 'WIN2026', type: 'giveaway', owner_user_id: null, perk_days: 365 })]);
    const rc = fakeRc();
    rc.failGrant = new RevenueCatError('down', 500);
    assertEquals((await redeem(db, rc, signedIn(WINNER), { code: 'WIN2026' })).status, 502);
    rc.failGrant = undefined;
    assertEquals((await redeem(db, rc, signedIn(WINNER), { code: 'WIN2026' })).body.ok, true);
    assertEquals(rc.grants, [{ user: WINNER, days: 365 }]);
  });

  // Finding 11-012, ticket 39: deleting an account used to take its redemption
  // rows with it (on delete cascade), so a spent giveaway came back.
  it('at its limit refuses a new account even after the redeeming account was deleted', async () => {
    const db = world([code({ code: 'WIN2026', type: 'giveaway', owner_user_id: null, perk_days: 365 })]);
    const rc = fakeRc();
    assertEquals((await redeem(db, rc, signedIn(WINNER), { code: 'WIN2026' })).body.ok, true);

    deleteAccount(db, WINNER);

    assertEquals(db.rows('code_redemptions').length, 1, 'the redemption outlives the account');
    refusedWith(await redeem(db, rc, signedIn(SECOND_WINNER), { code: 'WIN2026' }), 'used');
    assertEquals(rc.grants, [{ user: WINNER, days: 365 }]);
  });

  it('with room for more still counts a deleted account toward its limit', async () => {
    const db = world([
      code({ code: 'WIN2026', type: 'giveaway', owner_user_id: null, perk_days: 365, max_redemptions: 2 }),
    ]);
    const rc = fakeRc();
    await redeem(db, rc, signedIn(WINNER), { code: 'WIN2026' });
    deleteAccount(db, WINNER);
    assertEquals((await redeem(db, rc, signedIn(SECOND_WINNER), { code: 'WIN2026' })).body.ok, true);
    refusedWith(await redeem(db, rc, signedIn(ATHLETE), { code: 'WIN2026' }), 'used');
  });
});

describe('refusals', () => {
  it('a code we do not have', async () => {
    const db = world([code({})]);
    const rc = fakeRc();
    refusedWith(await redeem(db, rc, signedIn(ATHLETE), { code: 'NOPE99' }), 'not_found');
    nothingWritten(db, rc);
  });

  it('an expired code', async () => {
    const db = world([code({ valid_until: iso(NOW - DAY) })]);
    const rc = fakeRc();
    refusedWith(await redeem(db, rc, signedIn(COACH), { code: 'KYLE30' }), 'expired');
    nothingWritten(db, rc);
  });

  it('a code whose window ends exactly now has expired', async () => {
    const db = world([code({ valid_until: iso(NOW) })]);
    const rc = fakeRc();
    refusedWith(await redeem(db, rc, signedIn(ATHLETE), { code: 'KYLE30' }), 'expired');
  });

  it('a code whose window has not opened', async () => {
    const db = world([code({ valid_from: iso(NOW + DAY) })]);
    const rc = fakeRc();
    refusedWith(await redeem(db, rc, signedIn(ATHLETE), { code: 'KYLE30' }), 'not_yet_valid');
    nothingWritten(db, rc);
  });

  it('a coach or influencer code at its redemption limit is used', async () => {
    const c = code({ max_redemptions: 1 });
    const db = world([c], {
      code_redemptions: [{ id: 'r1', code_id: c.id, user_id: INFLUENCER, redeemed_at: iso(NOW - DAY) }],
    });
    const rc = fakeRc();
    refusedWith(await redeem(db, rc, signedIn(ATHLETE), { code: 'KYLE30' }), 'used');
    assertEquals(db.rows('coach_athlete_relationships').length, 0);
    assertEquals(rc.attributes.length, 0);
  });

  it('an athlete entering the same coach code twice is told they already used it', async () => {
    const db = world([code({})]);
    const rc = fakeRc();
    await redeem(db, rc, signedIn(ATHLETE), { code: 'KYLE30' });
    refusedWith(await redeem(db, rc, signedIn(ATHLETE), { code: 'KYLE30' }), 'already_redeemed');
    assertEquals(rc.attributes.length, 1);
  });

  it('every reason has a plain sentence', () => {
    for (const [reason, message] of Object.entries(REFUSALS)) {
      assert(message.length > 10 && message.endsWith('.'), `${reason}: ${message}`);
    }
  });
});

describe('who may call', () => {
  it('no signed-in caller → 401, nothing read', async () => {
    const db = world([code({})]);
    const rc = fakeRc();
    const res = await redeem(db, rc, null, { code: 'KYLE30' });
    assertEquals(res.status, 401);
    assertEquals(res.body.error, 'unauthenticated');
    assertEquals(db.reads.length, 0);
  });

  it('an anonymous session → 403 sign_in_required, nothing read', async () => {
    const db = world([code({})]);
    const rc = fakeRc();
    const res = await redeem(db, rc, { userId: ATHLETE, email: null, anonymous: true }, { code: 'KYLE30' });
    assertEquals(res.status, 403);
    assertEquals(res.body.error, 'sign_in_required');
    assertEquals(db.reads.length, 0);
  });

  it('a body without a code → 400', async () => {
    const db = world([code({})]);
    const rc = fakeRc();
    assertEquals((await redeem(db, rc, signedIn(ATHLETE), {})).status, 400);
    assertEquals((await redeem(db, rc, signedIn(ATHLETE), { code: '   ' })).status, 400);
    assertEquals((await redeem(db, rc, signedIn(ATHLETE), 'not json')).status, 400);
    assertEquals((await redeem(db, rc, signedIn(ATHLETE), { code: 'X'.repeat(80) })).status, 400);
  });
});
