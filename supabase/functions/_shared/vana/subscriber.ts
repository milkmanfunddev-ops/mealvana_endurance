/**
 * The subscriber's plan and trial state, as the call log records it (ai-cost ticket 05).
 *
 * `user_entitlements` is the two-field cache of RevenueCat (mp-285): `active_until` and `period_type`, and nothing else —
 * the store product id was deliberately dropped. So the log stores those two RAW and lets SQL name the plan
 * (`public.vana_plan_label`): an annual subscriber's access runs a year out, a monthly one's a month, and TRIAL / INTRO /
 * PROMOTIONAL name themselves. Storing the raw pair instead of a label means the label can be re-cut in the view when
 * the products change, with no backfill and no second source of truth.
 *
 * Read on the background task that finishes the call, never on the athlete's critical path, and never throws: a call
 * whose plan could not be read is logged with nulls rather than not logged.
 */
import type { Db } from './env.ts';

export interface SubscriberState {
  /** RevenueCat's period type: NORMAL | TRIAL | INTRO | PROMOTIONAL. Null when the athlete has no entitlement row. */
  periodType: string | null;
  /** End of the period RevenueCat last reported, ISO. Null = no access (or no row). */
  activeUntil: string | null;
}

export const UNKNOWN_SUBSCRIBER: SubscriberState = { periodType: null, activeUntil: null };

export async function subscriberState(admin: Db, userId: string): Promise<SubscriberState> {
  try {
    const { data, error } = await admin.from('user_entitlements').select('period_type, active_until').eq('user_id', userId).maybeSingle();
    if (error) { console.warn('[vana] user_entitlements read for the call log failed:', error.message); return UNKNOWN_SUBSCRIBER; }
    const row = data as { period_type?: string | null; active_until?: string | null } | null;
    return { periodType: row?.period_type ?? null, activeUntil: row?.active_until ?? null };
  } catch (e) {
    console.warn('[vana] user_entitlements read for the call log threw:', (e as Error).message);
    return UNKNOWN_SUBSCRIBER;
  }
}
