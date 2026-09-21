/**
 * Pure mapping from a RevenueCat `pro` webhook event, plus RevenueCat's own
 * answer for the customer's current `pro` expiry, to the
 * `public.user_entitlements` row — a two-field cache of RevenueCat (mp-285):
 * `active_until` and `period_type`, plus `event_at` (the RC event time) so an
 * event older than the row is ignored. Nothing else from the payload is kept.
 * `active_until` is RevenueCat's answer, never the payload's expiry (mp-454):
 * RevenueCat already takes the later of a grant and a subscription.
 *
 * Kept free of Deno/Supabase imports so index.test.ts exercises the SAME code
 * the handler runs.
 */

/** The RevenueCat entitlement identifier the app is gated on. */
export const PRO_ENTITLEMENT = 'pro';

/**
 * Every store SKU attached to the `pro` entitlement, across all four store
 * apps (RC project proj77b3c48f, verified 2026-09-01). Play dev + prod share
 * ids; the RC Test Store reuses the iOS dev ids. Used as a fallback when an
 * event arrives without `entitlement_ids` (older payloads).
 */
export const PRO_PRODUCT_IDS: ReadonlySet<string> = new Set([
  // The "Mealvana Pro" group (mp-452): dev ids `me_pro_*`, prod the same
  // ending `_prod`.
  'me_pro_monthly',
  'me_pro_annual',
  'me_pro_monthly_founding',
  'me_pro_annual_founding',
  'me_pro_monthly_prod',
  'me_pro_annual_prod',
  'me_pro_monthly_founding_prod',
  'me_pro_annual_founding_prod',
  // The original SKUs: out of every offering (mp-452), still live for the
  // people subscribed to them.
  // iOS dev (6756683509) — also the RC Test Store products
  'mealvana_pro_monthly',
  'mealvana_pro_annual',
  // iOS prod (6751113738) — Apple product ids are team-unique
  'mealvana_pro_monthly_prod',
  'mealvana_pro_annual_prod',
  // Google Play dev + prod — `subscription:basePlan`
  'mealvana_pro_monthly:monthly',
  'mealvana_pro_annual:annual',
]);

/** The dashboard's "send test event": it must never write the cache (mp-317 §3). */
export const TEST_EVENT_TYPE = 'TEST';

/** Handled separately: it carries user lists, not a product. */
export const TRANSFER_EVENT_TYPE = 'TRANSFER';

/** Two expiries this close are the same end (RevenueCat rounds to the second). */
const SAME_END_TOLERANCE_MS = 60_000;

export type RcEvent = Record<string, unknown>;

/** The row minus `user_id`: the two gate fields and the event time. */
export interface EntitlementRow {
  /** End of the period RevenueCat last reported; null = no access. */
  active_until: string | null;
  /** NORMAL | TRIAL | INTRO | PROMOTIONAL, as RevenueCat names it. */
  period_type: string | null;
  /** RevenueCat `event_timestamp_ms` as ISO — the ordering key for stale events. */
  event_at: string;
}

/**
 * Whether [event] concerns the Pro entitlement: `entitlement_ids` names it,
 * or the product is one of the Pro SKUs. A credit-pack purchase (no
 * entitlement, consumable SKU) returns false and falls through to the grant
 * path.
 */
export function isProEvent(event: RcEvent): boolean {
  const ids = event.entitlement_ids;
  if (Array.isArray(ids) && ids.some((id) => String(id) === PRO_ENTITLEMENT)) {
    return true;
  }
  const productId = String(event.product_id ?? '');
  if (PRO_PRODUCT_IDS.has(productId)) return true;
  // Play events sometimes carry the bare subscription id; the base plan is in
  // `product_id`'s `:basePlan` suffix only on newer payloads.
  return PRO_PRODUCT_IDS.has(`${productId}:monthly`) ||
    PRO_PRODUCT_IDS.has(`${productId}:annual`);
}

/**
 * Whether [event] (re)computes a user's row: every event for `pro`, bought or
 * granted, whatever its type (mp-454 §1) — a promotional grant arrives as a
 * NON_RENEWING_PURCHASE. Only a TEST ping and a TRANSFER (its own path) are out.
 */
export function takesProPath(event: RcEvent): boolean {
  const type = String(event.type ?? '');
  if (type === TEST_EVENT_TYPE || type === TRANSFER_EVENT_TYPE) return false;
  return isProEvent(event);
}

export function msToIso(value: unknown): string | null {
  const ms = typeof value === 'number' ? value : Number(value);
  if (!Number.isFinite(ms) || ms <= 0) return null;
  return new Date(ms).toISOString();
}

function str(value: unknown): string | null {
  if (value === undefined || value === null) return null;
  const s = String(value);
  return s.length === 0 ? null : s;
}

/**
 * Build the row for [event] from [currentExpiry], RevenueCat's answer for the
 * customer's current `pro` expiry at the time of the call (mp-454 §2).
 *
 * `active_until` is that answer: a CANCELLATION keeps access to the period
 * end, a live grant outlasts a lapsed trial, a trial started during a grant
 * keeps the grant's end — all RevenueCat's own arithmetic. When RevenueCat
 * reports no `pro`, the row closes at the event time (mp-317 §4: an
 * EXPIRATION closes the row at the event time), never null-as-open and never
 * the payload's expiry.
 *
 * `period_type` is the payload's only when RevenueCat's end is the payload's
 * own expiry, i.e. this event's purchase is what grants access; otherwise the
 * stored one stays (a trial started under a grant leaves PROMOTIONAL). Either
 * falls back to the other when silent.
 */
export function entitlementRowFor(
  event: RcEvent,
  nowMs: number,
  currentExpiry: string | null,
  previous?: Partial<EntitlementRow> | null,
): EntitlementRow {
  const eventAt = msToIso(event.event_timestamp_ms) ?? new Date(nowMs).toISOString();
  const payloadExpiry = msToIso(event.expiration_at_ms);
  const payloadPeriod = str(event.period_type);
  const storedPeriod = previous?.period_type ?? null;

  const payloadIsTheEnd = currentExpiry === null || (payloadExpiry !== null &&
    Math.abs(Date.parse(payloadExpiry) - Date.parse(currentExpiry)) <= SAME_END_TOLERANCE_MS);

  return {
    active_until: currentExpiry ?? eventAt,
    period_type: payloadIsTheEnd ? (payloadPeriod ?? storedPeriod) : (storedPeriod ?? payloadPeriod),
    event_at: eventAt,
  };
}

/**
 * True when [event] is older than the row already stored, i.e. a delayed or
 * re-delivered event that must not clobber newer state. Both timestamps are
 * the RevenueCat `event_timestamp_ms` (stored in `event_at`).
 */
export function isStaleEvent(event: RcEvent, storedEventAt: string | null | undefined): boolean {
  if (!storedEventAt) return false;
  const eventAt = msToIso(event.event_timestamp_ms);
  if (!eventAt) return false;
  return Date.parse(eventAt) < Date.parse(storedEventAt);
}

/** The user ids a TRANSFER event moves purchases away from / to. */
export function transferParties(event: RcEvent): { from: string[]; to: string[] } {
  const list = (v: unknown): string[] =>
    Array.isArray(v) ? v.map((x) => String(x)).filter((x) => x.length > 0) : [];
  return { from: list(event.transferred_from), to: list(event.transferred_to) };
}
