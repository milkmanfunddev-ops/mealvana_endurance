/**
 * The one server gate (mp-266, mp-279, mp-285): a caller passes when their
 * `public.user_entitlements` row — the two-field cache of RevenueCat that only
 * the revenuecat-webhook writes — has `active_until` in the future.
 *
 * There is no flag, no trial clock and no tester bypass on this path: nothing
 * app-side can grant an entitlement. Testers get a RevenueCat promotional
 * grant, which arrives through the webhook like any other event.
 */
import type { Db } from './env.ts';

export type ProCheck = { ok: true } | { ok: false; reason: 'pro_required' };

/** The row as the webhook writes it (period_type is carried for callers, not read here). */
export interface EntitlementCacheRow {
  active_until: string | null;
  period_type?: string | null;
}

/** Pure rule: access runs while `active_until` is later than now. */
export function isEntitled(row: EntitlementCacheRow | null | undefined, nowMs: number): boolean {
  const until = row?.active_until ? Date.parse(row.active_until) : NaN;
  return Number.isFinite(until) && until > nowMs;
}

export async function requirePro(admin: Db, userId: string, nowMs: number = Date.now()): Promise<ProCheck> {
  try {
    const { data, error } = await admin
      .from('user_entitlements')
      .select('active_until, period_type')
      .eq('user_id', userId)
      .maybeSingle();
    if (error) console.warn('[vana] user_entitlements read failed (treating as not entitled):', error.message);
    else if (isEntitled(data as EntitlementCacheRow | null, nowMs)) return { ok: true };
  } catch (e) {
    console.warn('[vana] user_entitlements read threw (treating as not entitled):', (e as Error).message);
  }
  return { ok: false, reason: 'pro_required' };
}
