/**
 * RevenueCat's REST API, server side only: it holds the project's v2 secret
 * API key.
 *
 *   deleteCustomer    delete a customer and its data (account deletion; 02-005)
 *
 * develop carries only the account-deletion call. mealplanning's client of the
 * same name adds the `pro` entitlement calls (grants, attributes, expiry) for
 * its paywall; those stay there. Backported from mealplanning f5cef058
 * (testing-wave ticket 95) by testing-wave develop-2026-10 ticket 29.
 *
 * Pure of Deno globals: `fetch` is injected so the handler tests and this
 * module's tests run the same code the function runs.
 */

export const REVENUECAT_API_BASE = 'https://api.revenuecat.com/v2';

export class RevenueCatError extends Error {
  constructor(message: string, readonly status: number | null = null) {
    super(message);
    this.name = 'RevenueCatError';
  }
}

export interface RevenueCatClient {
  /** Delete a customer; one RevenueCat has never seen (404) is already gone. */
  deleteCustomer(appUserId: string): Promise<void>;
}

export interface RevenueCatConfig {
  secretKey: string;
  projectId: string;
  fetch?: typeof globalThis.fetch;
  baseUrl?: string;
}

export function makeRevenueCatClient(config: RevenueCatConfig): RevenueCatClient {
  if (!config.secretKey) throw new RevenueCatError('RevenueCat secret key not set');
  if (!config.projectId) throw new RevenueCatError('RevenueCat project id not set');
  const doFetch = config.fetch ?? globalThis.fetch;
  const base = `${config.baseUrl ?? REVENUECAT_API_BASE}/projects/${encodeURIComponent(config.projectId)}`;

  const customerPath = (appUserId: string) => `${base}/customers/${encodeURIComponent(appUserId)}`;

  /** A JSON call; a 404 comes back as null, any other non-2xx throws. */
  async function call<T>(method: 'DELETE', url: string): Promise<T | null> {
    const res = await doFetch(url, {
      method,
      headers: {
        Authorization: `Bearer ${config.secretKey}`,
        'Content-Type': 'application/json',
        Accept: 'application/json',
      },
    });
    const text = await res.text();
    if (res.status === 404) return null;
    if (!res.ok) {
      throw new RevenueCatError(`RevenueCat ${method} ${new URL(url).pathname} → ${res.status}: ${text.slice(0, 200)}`, res.status);
    }
    return (text ? JSON.parse(text) : {}) as T;
  }

  return {
    async deleteCustomer(appUserId) {
      await call('DELETE', customerPath(appUserId));
    },
  };
}
