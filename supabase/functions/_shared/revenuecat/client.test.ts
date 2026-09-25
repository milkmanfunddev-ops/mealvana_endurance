/**
 * The RevenueCat REST client (mp-454 §2, §4) against a fake fetch that answers
 * the way RevenueCat's v2 API does: the entitlement list names `pro` by
 * `lookup_key` and carries its opaque id; a customer's active entitlements
 * name that opaque id and `expires_at` in ms.
 *
 * Run with:
 *   deno test --allow-all supabase/functions/_shared/revenuecat/client.test.ts
 */
import { assertEquals, assertRejects } from 'https://deno.land/std@0.224.0/assert/mod.ts';
import { describe, it } from 'https://deno.land/std@0.224.0/testing/bdd.ts';
import { makeRevenueCatClient, RevenueCatError } from './client.ts';

const PROJECT = 'proj77b3c48f';
const KEY = 'sk_test_fake';
const PRO_ID = 'entla441faaeb4';
const USER = 'c18d3737-0000-4000-8000-000000000001';
const T0 = Date.parse('2026-09-15T12:00:00Z');
const DAY = 24 * 60 * 60 * 1000;

interface Call {
  method: string;
  url: string;
  auth: string | null;
  body: unknown;
}

/** RevenueCat's entitlement list for the project, as the v2 API returns it. */
const ENTITLEMENTS = {
  object: 'list',
  items: [
    {
      object: 'entitlement',
      project_id: PROJECT,
      id: 'entl0000other',
      lookup_key: 'legacy',
      display_name: 'Legacy',
      created_at: 1_700_000_000_000,
      state: 'active',
    },
    {
      object: 'entitlement',
      project_id: PROJECT,
      id: PRO_ID,
      lookup_key: 'pro',
      display_name: 'Mealvana Endurance Pro',
      created_at: 1_763_486_244_738,
      state: 'active',
    },
  ],
  next_page: null,
  url: `/v2/projects/${PROJECT}/entitlements`,
};

function activeEntitlements(items: { entitlement_id: string; expires_at: number | null }[]) {
  return {
    object: 'list',
    items: items.map((i) => ({ object: 'customer.active_entitlement', ...i })),
    next_page: null,
    url: `/v2/projects/${PROJECT}/customers/${USER}/active_entitlements`,
  };
}

function fakeFetch(routes: Record<string, { status?: number; body: unknown }>) {
  const calls: Call[] = [];
  // deno-lint-ignore require-await
  const fetch = async (input: string | URL | Request, init?: RequestInit): Promise<Response> => {
    const url = String(input);
    const method = init?.method ?? 'GET';
    const headers = new Headers(init?.headers);
    calls.push({
      method,
      url,
      auth: headers.get('Authorization'),
      body: init?.body ? JSON.parse(String(init.body)) : null,
    });
    const path = new URL(url).pathname;
    const route = routes[`${method} ${path}`];
    if (!route) return new Response(JSON.stringify({ type: 'resource_missing', message: 'not found' }), { status: 404 });
    return new Response(JSON.stringify(route.body), { status: route.status ?? 200 });
  };
  return { fetch: fetch as typeof globalThis.fetch, calls };
}

const ENTITLEMENTS_ROUTE = `GET /v2/projects/${PROJECT}/entitlements`;
const ACTIVE_ROUTE = `GET /v2/projects/${PROJECT}/customers/${USER}/active_entitlements`;

describe('currentProExpiry', () => {
  it('returns the `pro` expiry as ISO, found through the lookup key', async () => {
    const { fetch, calls } = fakeFetch({
      [ENTITLEMENTS_ROUTE]: { body: ENTITLEMENTS },
      [ACTIVE_ROUTE]: {
        body: activeEntitlements([
          { entitlement_id: 'entl0000other', expires_at: T0 + 400 * DAY },
          { entitlement_id: PRO_ID, expires_at: T0 + 30 * DAY },
        ]),
      },
    });
    const rc = makeRevenueCatClient({ secretKey: KEY, projectId: PROJECT, fetch });
    assertEquals(await rc.currentProExpiry(USER), new Date(T0 + 30 * DAY).toISOString());
    assertEquals(calls.every((c) => c.auth === `Bearer ${KEY}`), true);
    assertEquals(calls[0].url.startsWith('https://api.revenuecat.com/v2/'), true);
  });

  it('no active `pro` → null', async () => {
    const { fetch } = fakeFetch({
      [ENTITLEMENTS_ROUTE]: { body: ENTITLEMENTS },
      [ACTIVE_ROUTE]: { body: activeEntitlements([{ entitlement_id: 'entl0000other', expires_at: T0 + DAY }]) },
    });
    const rc = makeRevenueCatClient({ secretKey: KEY, projectId: PROJECT, fetch });
    assertEquals(await rc.currentProExpiry(USER), null);
  });

  it('a customer RevenueCat has never seen (404) has no `pro`', async () => {
    const { fetch } = fakeFetch({ [ENTITLEMENTS_ROUTE]: { body: ENTITLEMENTS } });
    const rc = makeRevenueCatClient({ secretKey: KEY, projectId: PROJECT, fetch });
    assertEquals(await rc.currentProExpiry(USER), null);
  });

  it('a `pro` without an expiry (lifetime) reads as open to the far future', async () => {
    const { fetch } = fakeFetch({
      [ENTITLEMENTS_ROUTE]: { body: ENTITLEMENTS },
      [ACTIVE_ROUTE]: { body: activeEntitlements([{ entitlement_id: PRO_ID, expires_at: null }]) },
    });
    const rc = makeRevenueCatClient({ secretKey: KEY, projectId: PROJECT, fetch });
    assertEquals(await rc.currentProExpiry(USER), '9999-12-31T00:00:00.000Z');
  });

  it('looks the entitlement id up once per client', async () => {
    const { fetch, calls } = fakeFetch({
      [ENTITLEMENTS_ROUTE]: { body: ENTITLEMENTS },
      [ACTIVE_ROUTE]: { body: activeEntitlements([]) },
    });
    const rc = makeRevenueCatClient({ secretKey: KEY, projectId: PROJECT, fetch });
    await rc.currentProExpiry(USER);
    await rc.currentProExpiry(USER);
    assertEquals(calls.filter((c) => new URL(c.url).pathname.endsWith('/entitlements')).length, 1);
  });

  it('a server error throws RevenueCatError with the status (the caller retries)', async () => {
    const { fetch } = fakeFetch({
      [ENTITLEMENTS_ROUTE]: { body: ENTITLEMENTS },
      [ACTIVE_ROUTE]: { status: 503, body: { type: 'server_error', message: 'down' } },
    });
    const rc = makeRevenueCatClient({ secretKey: KEY, projectId: PROJECT, fetch });
    const err = await assertRejects(() => rc.currentProExpiry(USER), RevenueCatError);
    assertEquals(err.status, 503);
  });

  it('a project without a `pro` entitlement throws', async () => {
    const { fetch } = fakeFetch({ [ENTITLEMENTS_ROUTE]: { body: { ...ENTITLEMENTS, items: [ENTITLEMENTS.items[0]] } } });
    const rc = makeRevenueCatClient({ secretKey: KEY, projectId: PROJECT, fetch });
    await assertRejects(() => rc.currentProExpiry(USER), RevenueCatError);
  });

  it('escapes the customer id in the path', async () => {
    const { fetch, calls } = fakeFetch({ [ENTITLEMENTS_ROUTE]: { body: ENTITLEMENTS } });
    const rc = makeRevenueCatClient({ secretKey: KEY, projectId: PROJECT, fetch });
    await rc.currentProExpiry('$RCAnonymousID:abc/def');
    assertEquals(calls[1].url.includes('%24RCAnonymousID%3Aabc%2Fdef'), true);
  });
});

describe('grantPro', () => {
  it('grants `pro` until now + N days', async () => {
    const { fetch, calls } = fakeFetch({
      [ENTITLEMENTS_ROUTE]: { body: ENTITLEMENTS },
      [`POST /v2/projects/${PROJECT}/customers/${USER}/actions/grant_entitlement`]: {
        body: { object: 'customer', id: USER, project_id: PROJECT },
      },
    });
    const rc = makeRevenueCatClient({ secretKey: KEY, projectId: PROJECT, fetch, now: () => T0 });
    await rc.grantPro(USER, 30);
    const grant = calls.find((c) => c.method === 'POST')!;
    assertEquals(grant.body, { entitlement_id: PRO_ID, expires_at: T0 + 30 * DAY });
  });

  it('refuses a non-positive number of days without calling RevenueCat', async () => {
    const { fetch, calls } = fakeFetch({});
    const rc = makeRevenueCatClient({ secretKey: KEY, projectId: PROJECT, fetch });
    await assertRejects(() => rc.grantPro(USER, 0), RevenueCatError);
    assertEquals(calls.length, 0);
  });

  it('a refused grant throws with the status', async () => {
    const { fetch } = fakeFetch({
      [ENTITLEMENTS_ROUTE]: { body: ENTITLEMENTS },
      [`POST /v2/projects/${PROJECT}/customers/${USER}/actions/grant_entitlement`]: {
        status: 422,
        body: { type: 'invalid_request', message: 'bad' },
      },
    });
    const rc = makeRevenueCatClient({ secretKey: KEY, projectId: PROJECT, fetch });
    const err = await assertRejects(() => rc.grantPro(USER, 30), RevenueCatError);
    assertEquals(err.status, 422);
  });
});

describe('setAttributes', () => {
  it('posts the attributes as name/value pairs', async () => {
    const { fetch, calls } = fakeFetch({
      [`POST /v2/projects/${PROJECT}/customers/${USER}/attributes`]: {
        body: { object: 'list', items: [], next_page: null, url: '' },
      },
    });
    const rc = makeRevenueCatClient({ secretKey: KEY, projectId: PROJECT, fetch });
    await rc.setAttributes(USER, { founding_member: 'true', coach_code: 'KYLE30' });
    assertEquals(calls.length, 1);
    assertEquals(calls[0].body, {
      attributes: [
        { name: 'founding_member', value: 'true' },
        { name: 'coach_code', value: 'KYLE30' },
      ],
    });
  });

  it('no attributes → no call', async () => {
    const { fetch, calls } = fakeFetch({});
    const rc = makeRevenueCatClient({ secretKey: KEY, projectId: PROJECT, fetch });
    await rc.setAttributes(USER, {});
    assertEquals(calls.length, 0);
  });
});

describe('construction', () => {
  it('a missing secret key or project id throws', () => {
    let threw = 0;
    try {
      makeRevenueCatClient({ secretKey: '', projectId: PROJECT });
    } catch (e) {
      if (e instanceof RevenueCatError) threw++;
    }
    try {
      makeRevenueCatClient({ secretKey: KEY, projectId: '' });
    } catch (e) {
      if (e instanceof RevenueCatError) threw++;
    }
    assertEquals(threw, 2);
  });
});

/** A customer's subscription list as the v2 API returns it (shape read off the dev project, 2026-09-21). */
function subscriptions(items: { store: string; ends_at: number | null; gives_access?: boolean; entitlement?: string }[]) {
  return {
    object: 'list',
    items: items.map((s, i) => ({
      object: 'subscription',
      id: `sub${i}`,
      customer_id: USER,
      store: s.store,
      status: 'active',
      gives_access: s.gives_access ?? true,
      starts_at: T0 - DAY,
      current_period_ends_at: s.ends_at,
      ends_at: s.ends_at,
      auto_renewal_status: 'will_not_renew',
      product_id: null,
      environment: 'production',
      entitlements: {
        object: 'list',
        items: [{ object: 'entitlement', id: s.entitlement ?? PRO_ID, lookup_key: 'pro', state: 'active' }],
        next_page: null,
      },
    })),
    next_page: null,
    url: `/v2/projects/${PROJECT}/customers/${USER}/subscriptions`,
  };
}
const SUBS_ROUTE = `GET /v2/projects/${PROJECT}/customers/${USER}/subscriptions`;
const CUSTOMER_ROUTE = `GET /v2/projects/${PROJECT}/customers/${USER}`;

describe('promotionalProEnd', () => {
  it('the latest end among live promotional `pro` subscriptions; bought ones do not count', async () => {
    const { fetch } = fakeFetch({
      [ENTITLEMENTS_ROUTE]: { body: ENTITLEMENTS },
      [SUBS_ROUTE]: {
        body: subscriptions([
          { store: 'app_store', ends_at: T0 + 400 * DAY },
          { store: 'promotional', ends_at: T0 + 10 * DAY },
          { store: 'promotional', ends_at: T0 + 30 * DAY },
          { store: 'promotional', ends_at: T0 + 90 * DAY, gives_access: false },
          { store: 'promotional', ends_at: T0 + 90 * DAY, entitlement: 'entl0000other' },
        ]),
      },
    });
    const rc = makeRevenueCatClient({ secretKey: KEY, projectId: PROJECT, fetch });
    assertEquals(await rc.promotionalProEnd(USER), new Date(T0 + 30 * DAY).toISOString());
  });

  it('no promotional `pro` → null; an unknown customer (404) → null', async () => {
    const one = fakeFetch({
      [ENTITLEMENTS_ROUTE]: { body: ENTITLEMENTS },
      [SUBS_ROUTE]: { body: subscriptions([{ store: 'play_store', ends_at: T0 + DAY }]) },
    });
    assertEquals(await makeRevenueCatClient({ secretKey: KEY, projectId: PROJECT, fetch: one.fetch }).promotionalProEnd(USER), null);
    const two = fakeFetch({ [ENTITLEMENTS_ROUTE]: { body: ENTITLEMENTS } });
    assertEquals(await makeRevenueCatClient({ secretKey: KEY, projectId: PROJECT, fetch: two.fetch }).promotionalProEnd(USER), null);
  });

  it('a promotional grant without an end reads as open to the far future', async () => {
    const { fetch } = fakeFetch({
      [ENTITLEMENTS_ROUTE]: { body: ENTITLEMENTS },
      [SUBS_ROUTE]: { body: subscriptions([{ store: 'promotional', ends_at: null }]) },
    });
    const rc = makeRevenueCatClient({ secretKey: KEY, projectId: PROJECT, fetch });
    assertEquals(await rc.promotionalProEnd(USER), '9999-12-31T00:00:00.000Z');
  });
});

describe('getAttributes', () => {
  it('reads the customer with its attributes expanded, as a name → value map', async () => {
    const { fetch, calls } = fakeFetch({
      [CUSTOMER_ROUTE]: {
        body: {
          object: 'customer',
          id: USER,
          project_id: PROJECT,
          attributes: {
            object: 'list',
            items: [
              { object: 'customer.attribute', name: '$attConsentStatus', value: 'notDetermined', updated_at: T0 },
              { object: 'customer.attribute', name: 'founding_member', value: 'true', updated_at: T0 },
            ],
            next_page: null,
          },
        },
      },
    });
    const rc = makeRevenueCatClient({ secretKey: KEY, projectId: PROJECT, fetch });
    assertEquals(await rc.getAttributes(USER), { $attConsentStatus: 'notDetermined', founding_member: 'true' });
    assertEquals(new URL(calls[0].url).searchParams.get('expand'), 'attributes');
  });

  it('an unknown customer → null', async () => {
    const { fetch } = fakeFetch({});
    const rc = makeRevenueCatClient({ secretKey: KEY, projectId: PROJECT, fetch });
    assertEquals(await rc.getAttributes(USER), null);
  });
});

describe('createCustomer', () => {
  it('posts the id', async () => {
    const { fetch, calls } = fakeFetch({
      [`POST /v2/projects/${PROJECT}/customers`]: { status: 201, body: { object: 'customer', id: USER, project_id: PROJECT } },
    });
    const rc = makeRevenueCatClient({ secretKey: KEY, projectId: PROJECT, fetch });
    await rc.createCustomer(USER);
    assertEquals(calls[0].body, { id: USER });
  });
});

describe('deleteCustomer', () => {
  it('deletes the customer by id with the secret key (02-005, ticket 95)', async () => {
    const { fetch, calls } = fakeFetch({
      [`DELETE /v2/projects/${PROJECT}/customers/${USER}`]: { body: { object: 'customer', id: USER, deleted_at: T0 } },
    });
    const rc = makeRevenueCatClient({ secretKey: KEY, projectId: PROJECT, fetch });
    await rc.deleteCustomer(USER);
    assertEquals(calls.length, 1);
    assertEquals(calls[0].method, 'DELETE');
    assertEquals(calls[0].auth, `Bearer ${KEY}`);
  });

  it('a customer RevenueCat never saw (404) is already gone, not an error', async () => {
    const { fetch } = fakeFetch({});
    const rc = makeRevenueCatClient({ secretKey: KEY, projectId: PROJECT, fetch });
    await rc.deleteCustomer(USER);
  });

  it('any other failure throws with the status', async () => {
    const { fetch } = fakeFetch({
      [`DELETE /v2/projects/${PROJECT}/customers/${USER}`]: { status: 503, body: { message: 'down' } },
    });
    const rc = makeRevenueCatClient({ secretKey: KEY, projectId: PROJECT, fetch });
    const e = await assertRejects(() => rc.deleteCustomer(USER), RevenueCatError);
    assertEquals(e.status, 503);
  });
});
