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
  return { ok: false, reason: 'pro_required' };
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
