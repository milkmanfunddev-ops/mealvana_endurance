/**
 * Pure mapping from a RevenueCat subscription webhook event to the
 * `public.user_entitlements` row — a two-field cache of RevenueCat (mp-285):
 * `active_until` and `period_type`, plus `event_at` (the RC event time) so an
 * event older than the row is ignored. Nothing else from the payload is kept.
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

/**
 * Subscription lifecycle events that (re)compute the row. `TEST` (the
 * dashboard's "send test event") is deliberately absent: a ping carries no
 * expiry and must never write the cache.
 */
export const SUBSCRIPTION_EVENT_TYPES: ReadonlySet<string> = new Set([
  'INITIAL_PURCHASE',
  'RENEWAL',
  'CANCELLATION',
  'UNCANCELLATION',
  'EXPIRATION',
  'BILLING_ISSUE',
  'PRODUCT_CHANGE',
  'SUBSCRIPTION_PAUSED',
  'SUBSCRIPTION_EXTENDED',
]);

/** Handled separately: it carries user lists, not a product. */
export const TRANSFER_EVENT_TYPE = 'TRANSFER';

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
 * Build the row for [event].
 *
 * `active_until` is RevenueCat's `expiration_at_ms`: a CANCELLATION (auto-renew
 * off) keeps access to the end of the period and a BILLING_ISSUE keeps it while
 * RevenueCat keeps the expiry in the grace period — RevenueCat's own semantics.
 * An EXPIRATION closes the row at the event time when the payload's expiry is
 * later (clock skew). A payload without an expiry yields null: never
 * open-ended access by accident.
 *
 * `period_type` falls back to [previous] when the payload is silent.
 */
export function entitlementRowFor(
  event: RcEvent,
  nowMs: number,
  previous?: Partial<EntitlementRow> | null,
): EntitlementRow {
  const type = String(event.type ?? '');
  const eventAt = msToIso(event.event_timestamp_ms) ?? new Date(nowMs).toISOString();
  const expiry = msToIso(event.expiration_at_ms);

  let activeUntil = expiry;
  if (type === 'EXPIRATION' && (expiry === null || Date.parse(expiry) > Date.parse(eventAt))) {
    activeUntil = eventAt;
  }

  return {
    active_until: activeUntil,
    period_type: str(event.period_type) ?? previous?.period_type ?? null,
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
