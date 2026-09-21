/**
 * The one RevenueCat REST client (mp-454 §2, §4; mp-455; mp-458). Server-side
 * only: it holds the project's v2 secret API key.
 *
 *   currentProExpiry  the customer's current `pro` expiry, as RevenueCat
 *                     computes it (the later of a grant and a subscription)
 *   grantPro          a promotional `pro` grant for N days from now
 *   setAttributes     subscriber attributes (founding_member, coach_code, …)
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
  async function call<T>(method: 'GET' | 'POST', url: string, body?: unknown): Promise<T | null> {
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
  };
}
