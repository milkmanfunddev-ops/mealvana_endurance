/**
 * The RevenueCat REST client's account-deletion call against a fake fetch
 * that answers the way RevenueCat's v2 API does. The deleteCustomer cases
 * are mealplanning f5cef058's (ticket 95); develop has no entitlement calls.
 *
 * Run with:
 *   deno test --allow-all supabase/functions/_shared/revenuecat/client.test.ts
 */
import { assertEquals, assertRejects } from 'https://deno.land/std@0.224.0/assert/mod.ts';
import { describe, it } from 'https://deno.land/std@0.224.0/testing/bdd.ts';
import { makeRevenueCatClient, RevenueCatError } from './client.ts';

const PROJECT = 'proj77b3c48f';
const KEY = 'sk_test_fake';
const USER = 'c18d3737-0000-4000-8000-000000000001';
const T0 = Date.parse('2026-09-15T12:00:00Z');

interface Call {
  method: string;
  url: string;
  auth: string | null;
}

function fakeFetch(routes: Record<string, { status?: number; body: unknown }>) {
  const calls: Call[] = [];
  // deno-lint-ignore require-await
  const fetch = async (input: string | URL | Request, init?: RequestInit): Promise<Response> => {
    const url = String(input);
    const method = init?.method ?? 'GET';
    const headers = new Headers(init?.headers);
    calls.push({ method, url, auth: headers.get('Authorization') });
    const path = new URL(url).pathname;
    const route = routes[`${method} ${path}`];
    if (!route) return new Response(JSON.stringify({ type: 'resource_missing', message: 'not found' }), { status: 404 });
    return new Response(JSON.stringify(route.body), { status: route.status ?? 200 });
  };
  return { fetch: fetch as typeof globalThis.fetch, calls };
}

describe('makeRevenueCatClient', () => {
  it('refuses to build without a secret key', () => {
    let threw = false;
    try {
      makeRevenueCatClient({ secretKey: '', projectId: PROJECT });
    } catch (e) {
      threw = e instanceof RevenueCatError;
    }
    assertEquals(threw, true);
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
    assertEquals(calls[0].url.startsWith('https://api.revenuecat.com/v2/'), true);
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
