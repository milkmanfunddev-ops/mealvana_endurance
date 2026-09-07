/**
 * Pure mapping from a RevenueCat subscription webhook event to a
 * `public.user_entitlements` row (docs/implement_mealplanning/04-entitlement.md).
 *
 * Kept free of Deno/Supabase imports so index.test.ts exercises the SAME code
 * the handler runs instead of a hand-maintained mirror.
 */

/** The RevenueCat entitlement identifier that unlocks meal planning. */
export const PRO_ENTITLEMENT = 'pro';

/**
 * Every store SKU attached to the `pro` entitlement, across all four store
 * apps (RC project proj77b3c48f, verified 2026-09-01). Play dev + prod share
 * ids; the RC Test Store reuses the iOS dev ids. Used as a fallback when an
 * event arrives without `entitlement_ids` (older payloads / TRANSFER).
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

/** Subscription lifecycle events that (re)compute the entitlement row. */
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
  'TEST',
]);

/** Handled separately: it carries user lists, not a product. */
export const TRANSFER_EVENT_TYPE = 'TRANSFER';

export type RcEvent = Record<string, unknown>;

/** Shape of a `user_entitlements` upsert payload (minus user_id). */
export interface EntitlementRow {
  entitlement: string;
  active: boolean;
  product_id: string | null;
  store: string | null;
  period_type: string | null;
  expires_at: string | null;
  unsubscribe_detected_at: string | null;
  billing_issue_detected_at: string | null;
  source: 'revenuecat';
  updated_at: string;
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

function msToIso(value: unknown): string | null {
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
 * Build the row for [event]. `active` is "the subscription has not expired
 * as of [nowMs] and this is not the EXPIRATION event itself" — a CANCELLATION
 * (auto-renew off) therefore stays active until `expiration_at_ms`, matching
 * RevenueCat's own entitlement semantics. BILLING_ISSUE stays active while
 * RevenueCat keeps the expiry in the grace period.
 *
 * [previous] is the current row, so the cancellation / billing timestamps
 * survive events that do not speak to them (a RENEWAL after a BILLING_ISSUE
 * clears it; a PRODUCT_CHANGE after a CANCELLATION keeps it).
 */
export function entitlementRowFor(
  event: RcEvent,
  nowMs: number,
  previous?: Partial<EntitlementRow> | null,
): EntitlementRow {
  const type = String(event.type ?? '');
  const expiresAt = msToIso(event.expiration_at_ms);
  const expiresMs = expiresAt ? Date.parse(expiresAt) : null;
  const eventAt = msToIso(event.event_timestamp_ms) ?? new Date(nowMs).toISOString();

  const notExpired = expiresMs === null ? false : expiresMs > nowMs;
  const active = type !== 'EXPIRATION' && notExpired;

  let unsubscribeDetectedAt = previous?.unsubscribe_detected_at ?? null;
  let billingIssueDetectedAt = previous?.billing_issue_detected_at ?? null;
  switch (type) {
    case 'CANCELLATION':
      unsubscribeDetectedAt = eventAt;
      break;
    case 'BILLING_ISSUE':
      billingIssueDetectedAt = eventAt;
      break;
    case 'UNCANCELLATION':
      unsubscribeDetectedAt = null;
      billingIssueDetectedAt = null;
      break;
    case 'INITIAL_PURCHASE':
    case 'RENEWAL':
      billingIssueDetectedAt = null;
      break;
  }

  return {
    entitlement: PRO_ENTITLEMENT,
    active,
    product_id: str(event.product_id) ?? previous?.product_id ?? null,
    store: str(event.store) ?? previous?.store ?? null,
    period_type: str(event.period_type) ?? previous?.period_type ?? null,
    expires_at: expiresAt,
    unsubscribe_detected_at: unsubscribeDetectedAt,
    billing_issue_detected_at: billingIssueDetectedAt,
    source: 'revenuecat',
    updated_at: eventAt,
  };
}

/**
 * True when [event] is older than the row already stored, i.e. a delayed or
 * re-delivered event that must not clobber newer state. Both timestamps are
 * the RevenueCat `event_timestamp_ms` (stored in `updated_at`).
 */
export function isStaleEvent(event: RcEvent, storedUpdatedAt: string | null | undefined): boolean {
  if (!storedUpdatedAt) return false;
  const eventAt = msToIso(event.event_timestamp_ms);
  if (!eventAt) return false;
  return Date.parse(eventAt) < Date.parse(storedUpdatedAt);
}

/** The user ids a TRANSFER event moves purchases away from / to. */
export function transferParties(event: RcEvent): { from: string[]; to: string[] } {
  const list = (v: unknown): string[] =>
    Array.isArray(v) ? v.map((x) => String(x)).filter((x) => x.length > 0) : [];
  return { from: list(event.transferred_from), to: list(event.transferred_to) };
}
