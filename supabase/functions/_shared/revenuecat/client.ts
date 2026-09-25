/**
 * The one RevenueCat REST client (mp-454 §2, §4; mp-455; mp-458). Server-side
 * only: it holds the project's v2 secret API key.
 *
 *   currentProExpiry  the customer's current `pro` expiry, as RevenueCat
 *                     computes it (the later of a grant and a subscription)
 *   grantPro          a promotional `pro` grant for N days from now
 *   setAttributes     subscriber attributes (founding_member, coach_code, …)
 *   getAttributes     the customer's attributes, or null for an unknown customer
 *   promotionalProEnd the end of the customer's live promotional `pro` grant
 *   createCustomer    make a customer RevenueCat has never seen (a grant needs one)
 *   deleteCustomer    delete a customer and its data (account deletion; 02-005)
 *
 * The v2 API names entitlements by an opaque id; the app knows `pro` by its
 * lookup key, so the client resolves the id once per instance.
 *
 * Pure of Deno globals: `fetch` and the clock are injected so the handler
 * tests and this module's tests run the same code the functions run.
 */

export const PRO_LOOKUP_KEY = 'pro';
export const REVENUECAT_API_BASE = 'https://api.revenuecat.com/v2';

/** What an active `pro` without an expiry (a lifetime entitlement) reads as. */
export const NO_EXPIRY_ISO = '9999-12-31T00:00:00.000Z';

const DAY_MS = 24 * 60 * 60 * 1000;

export class RevenueCatError extends Error {
  constructor(message: string, readonly status: number | null = null) {
    super(message);
    this.name = 'RevenueCatError';
  }
}

export interface RevenueCatClient {
  /** ISO end of the customer's active `pro`, or null when they have none. */
  currentProExpiry(appUserId: string): Promise<string | null>;
  /** Grant `pro` from now for [days] days. */
  grantPro(appUserId: string, days: number): Promise<void>;
  /** Set subscriber attributes; an empty map makes no call. */
  setAttributes(appUserId: string, attributes: Record<string, string>): Promise<void>;
  /** The customer's attributes as name → value, or null when RevenueCat has never seen them. */
  getAttributes(appUserId: string): Promise<Record<string, string> | null>;
  /**
   * ISO end of the latest live promotional (granted) `pro`, or null when the
   * customer holds none. Bought subscriptions do not count.
   */
  promotionalProEnd(appUserId: string): Promise<string | null>;
  /** Create a customer by id (RevenueCat refuses a grant to an unknown one). */
  createCustomer(appUserId: string): Promise<void>;
  /** Delete a customer; one RevenueCat has never seen (404) is already gone. */
  deleteCustomer(appUserId: string): Promise<void>;
}

export interface RevenueCatConfig {
  secretKey: string;
  projectId: string;
  fetch?: typeof globalThis.fetch;
  now?: () => number;
  baseUrl?: string;
}

interface ListBody<T> {
  items?: T[];
}
interface EntitlementItem {
  id?: string;
  lookup_key?: string;
}
interface AttributeItem {
  name?: string;
  value?: string | null;
}
interface SubscriptionItem {
  store?: string;
  gives_access?: boolean;
  ends_at?: number | null;
  entitlements?: ListBody<EntitlementItem>;
}
interface ActiveEntitlementItem {
  entitlement_id?: string;
  expires_at?: number | null;
}

export function makeRevenueCatClient(config: RevenueCatConfig): RevenueCatClient {
  if (!config.secretKey) throw new RevenueCatError('RevenueCat secret key not set');
  if (!config.projectId) throw new RevenueCatError('RevenueCat project id not set');
  const doFetch = config.fetch ?? globalThis.fetch;
  const now = config.now ?? Date.now;
  const base = `${config.baseUrl ?? REVENUECAT_API_BASE}/projects/${encodeURIComponent(config.projectId)}`;
  let proEntitlementId: Promise<string> | null = null;

  const customerPath = (appUserId: string) => `${base}/customers/${encodeURIComponent(appUserId)}`;

  /** A JSON call; a 404 comes back as null, any other non-2xx throws. */
  async function call<T>(method: 'GET' | 'POST' | 'DELETE', url: string, body?: unknown): Promise<T | null> {
    const res = await doFetch(url, {
      method,
      headers: {
        Authorization: `Bearer ${config.secretKey}`,
        'Content-Type': 'application/json',
        Accept: 'application/json',
      },
      body: body === undefined ? undefined : JSON.stringify(body),
    });
    const text = await res.text();
    if (res.status === 404) return null;
    if (!res.ok) {
      throw new RevenueCatError(`RevenueCat ${method} ${new URL(url).pathname} → ${res.status}: ${text.slice(0, 200)}`, res.status);
    }
    return (text ? JSON.parse(text) : {}) as T;
  }

  function proId(): Promise<string> {
    proEntitlementId ??= (async () => {
      const list = await call<ListBody<EntitlementItem>>('GET', `${base}/entitlements?limit=100`);
      const pro = list?.items?.find((e) => e.lookup_key === PRO_LOOKUP_KEY);
      if (!pro?.id) throw new RevenueCatError(`no '${PRO_LOOKUP_KEY}' entitlement in project ${config.projectId}`);
      return pro.id;
    })().catch((e) => {
      proEntitlementId = null; // a failed lookup is retried on the next call
      throw e;
    });
    return proEntitlementId;
  }

  return {
    async currentProExpiry(appUserId) {
      const id = await proId();
      const active = await call<ListBody<ActiveEntitlementItem>>(
        'GET',
        `${customerPath(appUserId)}/active_entitlements?limit=100`,
      );
      const pro = active?.items?.find((e) => e.entitlement_id === id);
      if (!pro) return null;
      if (pro.expires_at === null || pro.expires_at === undefined) return NO_EXPIRY_ISO;
      return new Date(pro.expires_at).toISOString();
    },

    async grantPro(appUserId, days) {
      if (!Number.isFinite(days) || days <= 0) throw new RevenueCatError(`grant days must be positive, got ${days}`);
      const id = await proId();
      const res = await call('POST', `${customerPath(appUserId)}/actions/grant_entitlement`, {
        entitlement_id: id,
        expires_at: now() + Math.round(days * DAY_MS),
      });
      if (res === null) throw new RevenueCatError(`RevenueCat has no customer ${appUserId}`, 404);
    },

    async setAttributes(appUserId, attributes) {
      const pairs = Object.entries(attributes).map(([name, value]) => ({ name, value }));
      if (pairs.length === 0) return;
      const res = await call('POST', `${customerPath(appUserId)}/attributes`, { attributes: pairs });
      if (res === null) throw new RevenueCatError(`RevenueCat has no customer ${appUserId}`, 404);
    },

    async getAttributes(appUserId) {
      const customer = await call<{ attributes?: ListBody<AttributeItem> }>(
        'GET',
        `${customerPath(appUserId)}?expand=attributes`,
      );
      if (customer === null) return null;
      const out: Record<string, string> = {};
      for (const a of customer.attributes?.items ?? []) {
        if (a.name && typeof a.value === 'string') out[a.name] = a.value;
      }
      return out;
    },

    async promotionalProEnd(appUserId) {
      const id = await proId();
      const subs = await call<ListBody<SubscriptionItem>>('GET', `${customerPath(appUserId)}/subscriptions?limit=100`);
      let latest: number | null | undefined;
      for (const s of subs?.items ?? []) {
        if (s.store !== 'promotional' || s.gives_access !== true) continue;
        if (!s.entitlements?.items?.some((e) => e.id === id)) continue;
        const end = s.ends_at ?? null;
        if (end === null) return NO_EXPIRY_ISO;
        if (latest === undefined || latest === null || end > latest) latest = end;
      }
      return latest === undefined || latest === null ? null : new Date(latest).toISOString();
    },

    async createCustomer(appUserId) {
      await call('POST', `${base}/customers`, { id: appUserId });
    },

    async deleteCustomer(appUserId) {
      await call('DELETE', customerPath(appUserId));
    },
  };
}
