/**
 * RevenueCat's v2 REST API and GoTrue's admin users list, faked at the wire
 * for the grace month's tests (the flip-day run in _shared/grace and the
 * grace-claim handler). Both answer in their own shapes and keep state, so a
 * second call sees what the first one wrote the way the real services would
 * show it. Moved here from grace.test.ts (paywall ticket 06) so the claim
 * (ticket 09) is tested against the same RevenueCat.
 */
import { assertEquals } from 'https://deno.land/std@0.224.0/assert/mod.ts';
import { makeRevenueCatClient } from '../../../_shared/revenuecat/client.ts';
import type { AuthUser } from '../../../_shared/grace/grace.ts';

export const PROJECT = 'proj77b3c48f';
export const PRO_ID = 'entla441faaeb4';
export const SUPABASE_URL = 'https://vlmtsdzpnjnavdgytcmi.supabase.co';
export const SERVICE_KEY = 'service-role-fake';

export interface Sub {
  store: string;
  ends_at: number | null;
}
export interface Customer {
  attributes: Record<string, string>;
  subs: Sub[];
}

export class World {
  customers = new Map<string, Customer>();
  users: AuthUser[] = [];
  writes: string[] = [];
  /** Per path suffix: statuses to answer before behaving normally. */
  failures = new Map<string, number[]>();
  constructor(public now: number) {}

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
