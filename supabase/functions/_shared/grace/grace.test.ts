/**
 * The grace month (mp-455 §1-2, mp-429 §5): who gets it, and a run that
 * grants it once. The world is faked at the wire: a GoTrue admin users list
 * (the accounts) and RevenueCat's v2 REST API (the grants), both answering in
 * their own shapes and keeping state, so a second run sees what the first
 * one wrote the way the real services would show it. The fake lives in
 * tests/grace/support/revenuecat_world.ts, shared with the grace-claim tests.
 *
 * Run with:
 *   deno test --allow-all supabase/functions/_shared/grace/grace.test.ts
 */
import { assert, assertEquals } from 'https://deno.land/std@0.224.0/assert/mod.ts';
import { describe, it } from 'https://deno.land/std@0.224.0/testing/bdd.ts';
import { SERVICE_KEY, SUPABASE_URL, World } from '../../tests/grace/support/revenuecat_world.ts';
import {
  applyGrace,
  type AuthUser,
  FOUNDING_MEMBER_ATTRIBUTE,
  GRACE_DAYS,
  listAuthUsers,
  runGrace,
  selectGraceAccounts,
} from './grace.ts';

const DAY = 24 * 60 * 60 * 1000;
const FLIP = new Date('2026-10-01T07:00:00Z');
const RUN_AT = Date.parse('2026-10-01T15:00:00Z');

// ---------------------------------------------------------------------------
// Accounts, as GoTrue's admin API lists them
// ---------------------------------------------------------------------------

function authUser(id: string, createdAt: string, extra: Partial<AuthUser> = {}): AuthUser {
  return {
    id,
    aud: 'authenticated',
    role: 'authenticated',
    email: `${id}@test.com`,
    created_at: createdAt,
    updated_at: createdAt,
    is_anonymous: false,
    app_metadata: { provider: 'email', providers: ['email'] },
    user_metadata: {},
    identities: [],
    ...extra,
  } as AuthUser;
}

const OLD = authUser('u-old', '2026-01-07T10:00:00.000000Z');
const OLDER = authUser('u-older', '2025-12-18T23:13:25.559437Z');
const PAID = authUser('u-paid', '2026-03-02T09:00:00Z');
const COMPED = authUser('u-comped', '2026-02-04T09:00:00Z');
const NEVER_SEEN = authUser('u-never-seen', '2026-05-27T09:00:00Z');
const ANON = authUser('u-anon', '2026-02-01T09:00:00Z', { is_anonymous: true, email: '' });
const AFTER = authUser('u-after', '2026-10-01T08:00:00Z');
const AT_FLIP = authUser('u-at-flip', FLIP.toISOString());
const DELETED = authUser('u-deleted', '2026-01-09T09:00:00Z', { deleted_at: '2026-04-01T00:00:00Z' });

const ALL = [AFTER, OLD, ANON, PAID, COMPED, AT_FLIP, NEVER_SEEN, DELETED, OLDER];


function world() {
  const w = new World(RUN_AT);
  w.users = ALL;
  w.customer(OLD.id)
    .customer(OLDER.id)
    .customer(PAID.id, { subs: [{ store: 'app_store', ends_at: RUN_AT + 20 * DAY }] })
    .customer(COMPED.id, { subs: [{ store: 'promotional', ends_at: RUN_AT + 365 * DAY }] })
    .customer(ANON.id)
    .customer(AFTER.id);
  return w;
}

const noSleep = () => Promise.resolve();
const quiet = () => {};

async function run(w: World, opts: { write: boolean; onlyIds?: string[] }) {
  const users = await listAuthUsers({ url: SUPABASE_URL, serviceRoleKey: SERVICE_KEY, fetch: w.fetch, perPage: 2 });
  return runGrace({ users, rc: w.rc(), flipAt: FLIP, write: opts.write, onlyIds: opts.onlyIds, log: quiet, sleep: noSleep, now: () => w.now });
}

// ---------------------------------------------------------------------------

describe('selectGraceAccounts', () => {
  it('registered accounts created strictly before the flip, oldest first', () => {
    assertEquals(selectGraceAccounts(ALL, FLIP).map((u) => u.id), [OLDER.id, OLD.id, COMPED.id, PAID.id, NEVER_SEEN.id]);
  });

  it('an account without is_anonymous (older GoTrue rows) counts as registered', () => {
    const legacy = { ...OLD, is_anonymous: undefined } as unknown as AuthUser;
    assertEquals(selectGraceAccounts([legacy], FLIP).length, 1);
  });

  it('an unparseable created_at is never selected', () => {
    assertEquals(selectGraceAccounts([{ ...OLD, created_at: 'soon' }], FLIP).length, 0);
  });
});

describe('listAuthUsers', () => {
  it('pages through the admin list until a short page', async () => {
    const w = world();
    const users = await listAuthUsers({ url: SUPABASE_URL, serviceRoleKey: SERVICE_KEY, fetch: w.fetch, perPage: 2 });
    assertEquals(users.map((u) => u.id), ALL.map((u) => u.id));
  });

  it('a refused key throws instead of listing nobody', async () => {
    const w = world();
    let threw = false;
    try {
      await listAuthUsers({ url: SUPABASE_URL, serviceRoleKey: 'wrong', fetch: w.fetch });
    } catch {
      threw = true;
    }
    assert(threw);
  });
});

describe('runGrace: the dry run', () => {
  it('lists every selected account and the count, and writes nothing', async () => {
    const w = world();
    const summary = await run(w, { write: false });
    assertEquals(summary.selected, 5);
    assertEquals(summary.outcomes.map((o) => [o.userId, o.status]), [
      [OLDER.id, 'would_grant'],
      [OLD.id, 'would_grant'],
      [COMPED.id, 'would_mark'],
      [PAID.id, 'would_grant'],
      [NEVER_SEEN.id, 'would_grant'],
    ]);
    assertEquals(summary.counts.would_grant, 4);
    assertEquals(w.writes, []);
  });
});

describe('runGrace: the write run', () => {
  it(`grants ${GRACE_DAYS} days of pro and sets founding_member; the second run grants nobody`, async () => {
    const w = world();
    const first = await run(w, { write: true });
    assertEquals(first.counts.granted, 4);
    assertEquals(first.counts.marked, 1);
    for (const id of [OLDER.id, OLD.id, PAID.id, NEVER_SEEN.id]) {
      assertEquals(w.promoEnd(id), RUN_AT + GRACE_DAYS * DAY, id);
      assertEquals(w.customers.get(id)!.attributes[FOUNDING_MEMBER_ATTRIBUTE], 'true', id);
    }
    // A customer RevenueCat had never seen is created before the grant.
    assert(w.writes.indexOf(`create ${NEVER_SEEN.id}`) < w.writes.indexOf(`grant ${NEVER_SEEN.id}`));
    // Nobody outside the selection was touched.
    for (const id of [ANON.id, AFTER.id, AT_FLIP.id, DELETED.id]) assert(!w.writes.some((x) => x.includes(id)), id);

    w.writes = [];
    w.now = RUN_AT + 3 * 60 * 60 * 1000; // run again three hours later
    const second = await run(w, { write: true });
    assertEquals(second.counts.granted, 0);
    assertEquals(second.counts.already, 5);
    assertEquals(w.writes, []);
  });

  it('a live grant (a comp) is not shortened or re-granted; the account still becomes a founding member', async () => {
    const w = world();
    await run(w, { write: true });
    assertEquals(w.writes.filter((x) => x.includes(COMPED.id)), [`attributes ${COMPED.id}`]);
    assertEquals(w.promoEnd(COMPED.id), RUN_AT + 365 * DAY);
  });

  it('a grant that ends before the grace month would is not enough: that account is granted', async () => {
    const w = world();
    w.customer(OLD.id, { subs: [{ store: 'promotional', ends_at: RUN_AT + 5 * DAY }] });
    const summary = await run(w, { write: true, onlyIds: [OLD.id] });
    assertEquals(summary.outcomes[0].status, 'granted');
    assertEquals(w.promoEnd(OLD.id), RUN_AT + GRACE_DAYS * DAY);
  });

  it('an expired old grant does not count as holding one', async () => {
    const w = world();
    w.customer(OLD.id, { subs: [{ store: 'promotional', ends_at: RUN_AT - DAY }] });
    const summary = await run(w, { write: true, onlyIds: [OLD.id] });
    assertEquals(summary.outcomes[0].status, 'granted');
  });

  it('a grant that landed without its attribute is finished by the next run, not granted twice', async () => {
    const w = world();
    w.failures.set(`/customers/${OLD.id}/attributes`, [500, 500, 500, 500, 500]);
    const first = await run(w, { write: true, onlyIds: [OLD.id] });
    assertEquals(first.outcomes[0].status, 'failed');
    assertEquals(w.promoEnd(OLD.id), RUN_AT + GRACE_DAYS * DAY);
    w.writes = [];
    const second = await run(w, { write: true, onlyIds: [OLD.id] });
    assertEquals(second.outcomes[0].status, 'marked');
    assertEquals(w.writes, [`attributes ${OLD.id}`]);
  });

  it('one failing account does not stop the run', async () => {
    const w = world();
    w.failures.set(`/customers/${OLDER.id}/actions/grant_entitlement`, [500, 500, 500, 500, 500]);
    const summary = await run(w, { write: true });
    assertEquals(summary.counts.failed, 1);
    assertEquals(summary.counts.granted, 3);
    assert(summary.outcomes.find((o) => o.userId === OLDER.id)!.error!.includes('500'));
  });

  it('a rate limit is waited out and retried', async () => {
    const w = world();
    w.failures.set(`/customers/${OLD.id}/actions/grant_entitlement`, [429, 429]);
    const summary = await run(w, { write: true, onlyIds: [OLD.id] });
    assertEquals(summary.outcomes[0].status, 'granted');
    assertEquals(w.writes.filter((x) => x === `grant ${OLD.id}`).length, 1);
  });
});

describe('runGrace: the user filter', () => {
  it('touches only the named accounts, and says when a named account is not selected', async () => {
    const w = world();
    const summary = await run(w, { write: true, onlyIds: [OLD.id, ANON.id, 'u-nobody'] });
    assertEquals(summary.outcomes.map((o) => o.userId), [OLD.id]);
    assertEquals(summary.notSelected, [ANON.id, 'u-nobody']);
    assertEquals(w.writes, [`grant ${OLD.id}`, `attributes ${OLD.id}`]);
  });
});

describe('runGrace: the clock', () => {
  it('refuses to write before the flip (a grant made early would end before the grace month does)', async () => {
    const w = world();
    let threw = false;
    try {
      await runGrace({ users: ALL, rc: w.rc(), flipAt: FLIP, write: true, log: quiet, sleep: noSleep, now: () => FLIP.getTime() - 1 });
    } catch {
      threw = true;
    }
    assert(threw);
    assertEquals(w.writes, []);
  });

  it('a dry run before the flip is fine', async () => {
    const w = world();
    const summary = await runGrace({ users: ALL, rc: w.rc(), flipAt: FLIP, write: false, log: quiet, sleep: noSleep, now: () => FLIP.getTime() - DAY });
    assertEquals(summary.selected, 5);
  });
});

describe('applyGrace (the one-account path the claim function reuses)', () => {
  it('grants once and then reports already', async () => {
    const w = world();
    const rc = w.rc();
    assertEquals((await applyGrace(rc, OLD.id, { flipAt: FLIP, write: true, sleep: noSleep })).status, 'granted');
    assertEquals((await applyGrace(rc, OLD.id, { flipAt: FLIP, write: true, sleep: noSleep })).status, 'already');
  });
});
