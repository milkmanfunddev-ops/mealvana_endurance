/**
 * The grace month (mp-455 §1-2, mp-429 §5): who gets it, and a run that
 * grants it once. The world is faked at the wire: a GoTrue admin users list
 * (the accounts) and RevenueCat's v2 REST API (the grants), both answering in
 * their own shapes and keeping state, so a second run sees what the first
 * one wrote the way the real services would show it.
 *
 * Run with:
 *   deno test --allow-all supabase/functions/_shared/grace/grace.test.ts
 */
import { assert, assertEquals } from 'https://deno.land/std@0.224.0/assert/mod.ts';
import { describe, it } from 'https://deno.land/std@0.224.0/testing/bdd.ts';
import { makeRevenueCatClient } from '../revenuecat/client.ts';
import {
  applyGrace,
  type AuthUser,
  FOUNDING_MEMBER_ATTRIBUTE,
  GRACE_DAYS,
  listAuthUsers,
  runGrace,
  selectGraceAccounts,
} from './grace.ts';

const PROJECT = 'proj77b3c48f';
const PRO_ID = 'entla441faaeb4';
const SUPABASE_URL = 'https://vlmtsdzpnjnavdgytcmi.supabase.co';
const SERVICE_KEY = 'service-role-fake';
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

// ---------------------------------------------------------------------------
// RevenueCat, as its v2 REST API answers
// ---------------------------------------------------------------------------

interface Sub {
  store: string;
  ends_at: number | null;
}
interface Customer {
  attributes: Record<string, string>;
  subs: Sub[];
}

class World {
  customers = new Map<string, Customer>();
  users: AuthUser[] = [];
  writes: string[] = [];
  /** Per path suffix: statuses to answer before behaving normally. */
  failures = new Map<string, number[]>();
  now = RUN_AT;

  customer(id: string, c: Partial<Customer> = {}) {
    this.customers.set(id, { attributes: { $attConsentStatus: 'notDetermined', ...c.attributes }, subs: c.subs ?? [] });
    return this;
  }

  // deno-lint-ignore require-await
  fetch = async (input: string | URL | Request, init?: RequestInit): Promise<Response> => {
    const url = new URL(String(input));
    const method = init?.method ?? 'GET';
    const body = init?.body ? JSON.parse(String(init.body)) : null;
    const headers = new Headers(init?.headers);
    const json = (status: number, b: unknown) => new Response(JSON.stringify(b), { status });
    const missing = () => json(404, { object: 'error', type: 'resource_missing', message: 'Customer not found' });

    if (url.origin === SUPABASE_URL) {
      if (headers.get('apikey') !== SERVICE_KEY || headers.get('Authorization') !== `Bearer ${SERVICE_KEY}`) {
        return json(401, { code: 401, error_code: 'no_authorization', msg: 'This endpoint requires a valid Bearer token' });
      }
      if (method === 'GET' && url.pathname === '/auth/v1/admin/users') {
        const page = Number(url.searchParams.get('page') ?? 1);
        const per = Number(url.searchParams.get('per_page') ?? 50);
        return json(200, { users: this.users.slice((page - 1) * per, page * per), aud: 'authenticated' });
      }
      return json(404, { code: 404, msg: 'not found' });
    }

    const prefix = `/v2/projects/${PROJECT}`;
    const path = url.pathname.slice(prefix.length);
    for (const [suffix, statuses] of this.failures) {
      if (path.endsWith(suffix) && statuses.length > 0) {
        const status = statuses.shift()!;
        return json(status, { object: 'error', type: status === 429 ? 'rate_limit_error' : 'server_error', message: 'x' });
      }
    }
    if (method === 'GET' && path === '/entitlements') {
      return json(200, {
        object: 'list',
        items: [{ object: 'entitlement', id: PRO_ID, lookup_key: 'pro', display_name: 'Mealvana Endurance Pro', state: 'active' }],
        next_page: null,
      });
    }
    if (method === 'POST' && path === '/customers') {
      this.writes.push(`create ${body.id}`);
      if (this.customers.has(body.id)) return json(409, { type: 'resource_already_exists', message: 'exists' });
      this.customer(body.id);
      return json(201, { object: 'customer', id: body.id, project_id: PROJECT });
    }
    const m = /^\/customers\/([^/]+)(\/.*)?$/.exec(path);
    if (!m) return json(404, { type: 'resource_missing' });
    const id = decodeURIComponent(m[1]);
    const rest = m[2] ?? '';
    const c = this.customers.get(id);
    if (!c) {
      if (method === 'POST') this.writes.push(`${rest} ${id} (missing)`);
      return missing();
    }
    if (method === 'GET' && rest === '') {
      return json(200, {
        object: 'customer',
        id,
        project_id: PROJECT,
        attributes: {
          object: 'list',
          items: Object.entries(c.attributes).map(([name, value]) => ({ object: 'customer.attribute', name, value, updated_at: 1 })),
          next_page: null,
        },
      });
    }
    if (method === 'GET' && rest === '/subscriptions') {
      return json(200, {
        object: 'list',
        items: c.subs.map((s, i) => ({
          object: 'subscription',
          id: `sub${i}`,
          customer_id: id,
          store: s.store,
          status: s.ends_at === null || s.ends_at > this.now ? 'active' : 'expired',
          gives_access: s.ends_at === null || s.ends_at > this.now,
          ends_at: s.ends_at,
          current_period_ends_at: s.ends_at,
          environment: 'production',
          entitlements: { object: 'list', items: [{ object: 'entitlement', id: PRO_ID, lookup_key: 'pro' }], next_page: null },
        })),
        next_page: null,
      });
    }
    if (method === 'POST' && rest === '/actions/grant_entitlement') {
      this.writes.push(`grant ${id}`);
      assertEquals(body.entitlement_id, PRO_ID);
      c.subs.push({ store: 'promotional', ends_at: body.expires_at });
      return json(201, { object: 'customer', id, project_id: PROJECT });
    }
    if (method === 'POST' && rest === '/attributes') {
      this.writes.push(`attributes ${id}`);
      for (const a of body.attributes) c.attributes[a.name] = a.value;
      return json(200, { object: 'list', items: [], next_page: null });
    }
    return json(404, { type: 'resource_missing' });
  };

  rc() {
    return makeRevenueCatClient({ secretKey: 'sk_fake', projectId: PROJECT, fetch: this.fetch, now: () => this.now });
  }

  promoEnd(id: string): number | undefined {
    return this.customers.get(id)?.subs.filter((s) => s.store === 'promotional').map((s) => s.ends_at ?? Infinity).sort().at(-1);
  }
}

function world() {
  const w = new World();
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
