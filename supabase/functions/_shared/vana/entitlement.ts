/**
 * The one server gate (mp-266, mp-279, mp-285): a caller passes when their
 * `public.user_entitlements` row — the small cache of RevenueCat that only
 * the revenuecat-webhook writes — has `active_until` in the future, or, while
 * the row says the subscription renews, less than [RENEWAL_GRACE_MS] in the
 * past (mp-457: a paying account keeps Pro between a period end and a late
 * RENEWAL webhook; testing-wave 06-002).
 *
 * There is no flag, no trial clock and no tester bypass on this path: nothing
 * app-side can grant an entitlement. Testers get a RevenueCat promotional
 * grant, which arrives through the webhook like any other event.
 *
 * One exception, ruled 2026-09-26 (testing-wave 122-004, superseding
 * mp-416's server check for admins): a team admin, `public.users.is_admin`
 * set by hand in the database (mp-144 clause 3), gets every feature. The flag
 * is read only when the cache says no, and only a literal `true` counts.
 */
import type { Db } from './env.ts';
import { jsonResponse } from '../responses.ts';

export type ProCheck = { ok: true } | { ok: false; reason: 'pro_required' };

/**
 * How long past `active_until` a renewing subscription keeps Pro on the server
 * while its RENEWAL webhook is on the way. Test Store renewals landed 2.5 and
 * 4 minutes after the period end (06-002); RevenueCat's first two webhook
 * retries come 5 and 10 minutes after a failed delivery. A cancelled
 * subscription, a grant or a closed row gets no grace.
 *
 * KEEP IN STEP with `public.entitlement_renewal_grace()`
 * (supabase/migrations/20260925110000_allowance_survives_renewal_grace.sql),
 * which keeps the monthly allowance alive for the same grace: the two must
 * move together, or the gate opens onto an empty wallet.
 */
export const RENEWAL_GRACE_MS = 15 * 60_000;

/** The row as the webhook writes it (period_type is carried for callers, not read here). */
export interface EntitlementCacheRow {
  active_until: string | null;
  period_type?: string | null;
  /** RevenueCat's last word that the store subscription renews at `active_until`. */
  will_renew?: boolean | null;
}

/**
 * Pure rule: access runs while `active_until` is later than now, and for
 * [RENEWAL_GRACE_MS] longer when the row says the subscription renews.
 */
export function isEntitled(row: EntitlementCacheRow | null | undefined, nowMs: number): boolean {
  const until = row?.active_until ? Date.parse(row.active_until) : NaN;
  if (!Number.isFinite(until)) return false;
  const end = row?.will_renew === true ? until + RENEWAL_GRACE_MS : until;
  return end > nowMs;
}

export async function requirePro(admin: Db, userId: string, nowMs: number = Date.now()): Promise<ProCheck> {
  try {
    const { data, error } = await admin
      .from('user_entitlements')
      .select('active_until, period_type, will_renew')
      .eq('user_id', userId)
      .maybeSingle();
    if (error) console.warn('[vana] user_entitlements read failed (treating as not entitled):', error.message);
    else if (isEntitled(data as EntitlementCacheRow | null, nowMs)) return { ok: true };
  } catch (e) {
    console.warn('[vana] user_entitlements read threw (treating as not entitled):', (e as Error).message);
  }
  if (await isAdmin(admin, userId)) return { ok: true };
  return { ok: false, reason: 'pro_required' };
}

/**
 * `public.users.is_admin`, read with the service role (the column is not in
 * the app's cached profile). Any failure, a missing row, `null` or a
 * non-boolean value answers false: the gate fails closed, as the cache read
 * does.
 */
async function isAdmin(admin: Db, userId: string): Promise<boolean> {
  try {
    const { data, error } = await admin.from('users').select('is_admin').eq('id', userId).maybeSingle();
    if (error) {
      console.warn('[vana] users.is_admin read failed (treating as not admin):', error.message);
      return false;
    }
    return (data as { is_admin?: unknown } | null)?.is_admin === true;
  } catch (e) {
    console.warn('[vana] users.is_admin read threw (treating as not admin):', (e as Error).message);
    return false;
  }
}

/**
 * The check every AI function makes at the top of its handler (mp-429 clause 11): null when the caller
 * is entitled, otherwise the refusal to return as is, 403 `{error:'pro_required'}`, the same answer
 * vana-chat gives. Bought credits do not open it; only the RevenueCat cache does.
 */
export async function refuseUnlessPro(admin: Db, userId: string, nowMs: number = Date.now()): Promise<Response | null> {
  const pro = await requirePro(admin, userId, nowMs);
  return pro.ok ? null : jsonResponse({ error: pro.reason }, 403);
}
