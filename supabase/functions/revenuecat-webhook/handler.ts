/**
 * The revenuecat-webhook request handler, built with its dependencies
 * injected so the seam tests (index.test.ts) run this exact code against a
 * fake database. index.ts wires it to Deno.env and the service-role client.
 *
 * Two paths:
 *   1. Every `pro` event, bought or granted (mp-454) → `public.user_entitlements`,
 *      the two-field cache of RevenueCat (mp-285): `active_until` + `period_type`,
 *      written only here, ordered by `event_at`. `active_until` is RevenueCat's
 *      answer for the customer's current `pro` expiry, asked over REST on each
 *      event (_shared/revenuecat), so a grant and a subscription never shorten
 *      each other. A TRANSFER moves the row. The same
 *      delivery then moves the monthly Allowance (mp-281): INITIAL_PURCHASE
 *      and RENEWAL grant it into the wallet (`grant_allowance`, idempotent on
 *      the event id), EXPIRATION forfeits what is left (`forfeit_allowance`),
 *      CANCELLATION leaves the wallet alone — access and the allowance run
 *      to the period end. Annual plans get the grant monthly through
 *      `ensure_allowance` on the AI functions' side (_shared/ai/credits.ts).
 *   2. Credit-pack purchases → `grant_credits` RPC (unchanged).
 */
import type { SupabaseClient } from 'https://esm.sh/@supabase/supabase-js@2.39.3';
import {
  type EntitlementRow,
  entitlementRowFor,
  isStaleEvent,
  msToIso,
  type RcEvent,
  takesProPath,
  TRANSFER_EVENT_TYPE,
  transferParties,
} from './entitlements.ts';
import type { RevenueCatClient } from '../_shared/revenuecat/client.ts';
import {
  ALLOWANCE_FORFEIT_EVENT_TYPES,
  ALLOWANCE_GRANT_EVENT_TYPES,
  monthlyAllowance,
} from '../_shared/ai/allowance.ts';

// deno-lint-ignore no-explicit-any
export type WebhookDb = SupabaseClient<any, 'public', any>;

export interface WebhookDeps {
  env: (key: string) => string | undefined;
  /** A service-role client — the only writer of user_entitlements. */
  db: () => WebhookDb;
  /** RevenueCat's REST API; throws when the secret key is not configured. */
  revenueCat: () => RevenueCatClient;
  now?: () => number;
}

const TABLE = 'user_entitlements';
const ROW_COLUMNS = 'user_id, active_until, period_type, event_at';

/** RC store product id → credits granted. Override via RC_PRODUCT_CREDITS JSON. */
export const DEFAULT_PRODUCT_CREDITS: Record<string, number> = {
  mealvana_credits_50: 50,
  mealvana_credits_250: 250,
  // Prod App Store `_prod` variants of the packs above — same Apple
  // product-id-uniqueness constraint as the test pack below.
  mealvana_credits_50_prod: 50,
  mealvana_credits_250_prod: 250,
  // $0.99 pipeline-test pack, shown only to dev builds / tester devices.
  // The prod App Store carries a `_prod` variant because Apple rejects a
  // product id already claimed by any app in the team (the dev app owns it).
  mealvana_credits_test_1: 1,
  mealvana_credits_test_1_prod: 1,
};

/** Event types that represent a one-time credit-pack purchase. */
export const GRANTING_EVENT_TYPES = new Set(['NON_RENEWING_PURCHASE', 'INITIAL_PURCHASE', 'RENEWAL']);

function productCredits(env: WebhookDeps['env']): Record<string, number> {
  const raw = env('RC_PRODUCT_CREDITS');
  if (!raw) return DEFAULT_PRODUCT_CREDITS;
  try {
    const parsed = JSON.parse(raw);
    if (parsed && typeof parsed === 'object') return parsed as Record<string, number>;
  } catch (e) {
    console.error('[rc-webhook] bad RC_PRODUCT_CREDITS JSON, using defaults:', e);
  }
  return DEFAULT_PRODUCT_CREDITS;
}

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { 'Content-Type': 'application/json' },
  });
}

type StoredRow = EntitlementRow & { user_id: string };

/** What the allowance step did, echoed in the response for the RC event log. */
type AllowanceOutcome =
  | { ok: true; body: Record<string, unknown> }
  | { ok: false; status: number; body: Record<string, unknown> };

/**
 * Move the Allowance for a subscription event that has just written the row
 * (mp-281 §2, §3). Grants are keyed on the RevenueCat event id, so a
 * redelivery grants once; a failure other than that is a 500 so RevenueCat
 * retries the delivery (the row upsert is idempotent for the retry).
 */
async function applyAllowance(
  deps: WebhookDeps,
  client: WebhookDb,
  type: string,
  eventId: string,
  appUserId: string,
  row: EntitlementRow,
  /** RevenueCat reported a live `pro` for this event. */
  active: boolean,
): Promise<AllowanceOutcome> {
  if (ALLOWANCE_GRANT_EVENT_TYPES.has(type)) {
    if (!active) {
      console.log(`[rc-webhook] ${type} ${eventId}: RevenueCat reports no live pro, no allowance window to open`);
      return { ok: true, body: { skipped: 'not_active' } };
    }
    const amount = monthlyAllowance(deps.env);
    const { data, error } = await client.rpc('grant_allowance', {
      p_user_id: appUserId,
      p_amount: amount,
      p_active_until: row.active_until,
      p_ref: eventId,
    });
    if (error) {
      if (error.code === '23505') {
        console.log(`[rc-webhook] allowance for event ${eventId} already granted (idempotent)`);
        return { ok: true, body: { idempotent: true } };
      }
      console.error('[rc-webhook] grant_allowance error:', error.message);
      return { ok: false, status: 500, body: { error: 'allowance grant failed' } };
    }
    console.log(`[rc-webhook] ${type}: allowance ${amount} → ${appUserId} (${JSON.stringify(data)})`);
    return { ok: true, body: (data ?? { granted: true }) as Record<string, unknown> };
  }
  if (ALLOWANCE_FORFEIT_EVENT_TYPES.has(type)) {
    // A lapsed trial under a live grant: access goes on, so does the allowance.
    if (active) return { ok: true, body: { untouched: 'still_active' } };
    const { data, error } = await client.rpc('forfeit_allowance', { p_user_id: appUserId, p_ref: eventId });
    if (error) {
      console.error('[rc-webhook] forfeit_allowance error:', error.message);
      return { ok: false, status: 500, body: { error: 'allowance forfeit failed' } };
    }
    console.log(`[rc-webhook] ${type}: allowance forfeited for ${appUserId} (${JSON.stringify(data)})`);
    return { ok: true, body: (data ?? { forfeited: 0 }) as Record<string, unknown> };
  }
  return { ok: true, body: { untouched: true } };
}

/**
 * Upsert the row for [appUserId] from a `pro` event, with `active_until` taken
 * from RevenueCat's REST answer. Reads the existing
 * row first so a delayed re-delivery older than what is stored is dropped
 * instead of rolling the state back, and so a payload silent on period_type
 * keeps the stored one.
 */
async function handleProSubscription(
  deps: WebhookDeps,
  event: RcEvent,
  type: string,
  eventId: string,
  appUserId: string,
): Promise<Response> {
  if (!appUserId || !eventId) {
    console.error(`[rc-webhook] missing app_user_id or event id (user=${appUserId} id=${eventId})`);
    return json({ error: 'Missing app_user_id or event id' }, 400);
  }

  const client = deps.db();
  try {
    const { data: existing, error: readError } = await client
      .from(TABLE)
      .select(ROW_COLUMNS)
      .eq('user_id', appUserId)
      .maybeSingle();
    if (readError) {
      console.error('[rc-webhook] user_entitlements read error:', readError.message);
      return json({ error: 'entitlement read failed' }, 500);
    }

    const stored = existing as StoredRow | null;
    if (isStaleEvent(event, stored?.event_at)) {
      console.log(`[rc-webhook] event ${eventId} (${type}) older than stored row, ignoring`);
      return json({ ok: true, ignored: 'stale_event' });
    }

    let currentExpiry: string | null;
    try {
      currentExpiry = await deps.revenueCat().currentProExpiry(appUserId);
    } catch (e) {
      // Unconfigured key or RevenueCat down: 500 so RevenueCat redelivers.
      console.error(`[rc-webhook] RevenueCat pro expiry for ${appUserId} failed:`, (e as Error).message);
      return json({ error: 'revenuecat lookup failed' }, 500);
    }

    const row = entitlementRowFor(event, (deps.now ?? Date.now)(), currentExpiry, stored);
    // user_id is the primary key — not a partial unique index — so naming it
    // in onConflict is safe (no 42P10).
    const { error } = await client
      .from(TABLE)
      .upsert({ user_id: appUserId, ...row }, { onConflict: 'user_id' });
    if (error) {
      // FK violation == the app_user_id has no users row in THIS project —
      // same dev/prod split as the credit path. Ack so RC doesn't retry.
      if (error.code === '23503') {
        console.log(`[rc-webhook] user ${appUserId} not in this project, ignoring event ${eventId}`);
        return json({ ok: true, ignored: 'user_not_in_project' });
      }
      console.error('[rc-webhook] user_entitlements upsert error:', error.message);
      return json({ error: 'entitlement upsert failed' }, 500);
    }
    console.log(
      `[rc-webhook] ${type}: active_until=${row.active_until} period=${row.period_type} for ${appUserId}`,
    );
    const active = currentExpiry !== null && Date.parse(currentExpiry) > (deps.now ?? Date.now)();
    const allowance = await applyAllowance(deps, client, type, eventId, appUserId, row, active);
    if (!allowance.ok) return json(allowance.body, allowance.status);
    return json({
      ok: true,
      active_until: row.active_until,
      period_type: row.period_type,
      allowance: allowance.body,
    });
  } catch (e) {
    console.error('[rc-webhook] exception:', e);
    return json({ error: 'internal error' }, 500);
  }
}

/**
 * TRANSFER: RevenueCat moved every purchase from `transferred_from` users to
 * `transferred_to` users (a restore on a device signed into another account).
 * The new owners get the source row's two fields; the old owners' rows close
 * at the transfer time (kept, not deleted, so a late event for them is stale).
 */
async function handleTransfer(deps: WebhookDeps, event: RcEvent, eventId: string): Promise<Response> {
  const { from, to } = transferParties(event);
  if (from.length === 0 && to.length === 0) {
    console.log(`[rc-webhook] TRANSFER ${eventId} without parties, ignoring`);
    return json({ ok: true, ignored: 'transfer_no_parties' });
  }

  const client = deps.db();
  const transferAt = msToIso(event.event_timestamp_ms) ?? new Date((deps.now ?? Date.now)()).toISOString();
  try {
    let source: StoredRow | undefined;
    if (from.length > 0) {
      const { data: sourceRows, error: readError } = await client
        .from(TABLE)
        .select(ROW_COLUMNS)
        .in('user_id', from);
      if (readError) {
        console.error('[rc-webhook] transfer read error:', readError.message);
        return json({ error: 'entitlement read failed' }, 500);
      }
      const rows = (sourceRows ?? []) as StoredRow[];
      // The row with the furthest access is the one being carried over.
      source = rows.reduce<StoredRow | undefined>((best, r) => {
        if (!best) return r;
        return (Date.parse(r.active_until ?? '') || 0) > (Date.parse(best.active_until ?? '') || 0) ? r : best;
      }, undefined);
    }

    if (source && to.length > 0) {
      const { error } = await client
        .from(TABLE)
        .upsert(
          to.map((userId) => ({
            user_id: userId,
            active_until: source!.active_until,
            period_type: source!.period_type,
            event_at: transferAt,
          })),
          { onConflict: 'user_id' },
        );
      // A recipient outside this project is expected (dev/prod split).
      if (error && error.code !== '23503') {
        console.error('[rc-webhook] transfer upsert error:', error.message);
        return json({ error: 'entitlement upsert failed' }, 500);
      }
    }
    if (source && from.length > 0) {
      const { error } = await client
        .from(TABLE)
        .update({ active_until: transferAt, event_at: transferAt })
        .in('user_id', from);
      if (error) {
        console.error('[rc-webhook] transfer close error:', error.message);
        return json({ error: 'entitlement update failed' }, 500);
      }
    }
    console.log(`[rc-webhook] TRANSFER ${eventId}: ${from.join(',')} → ${to.join(',')} (moved=${!!source})`);
    return json({ ok: true, transferred: !!source, from, to });
  } catch (e) {
    console.error('[rc-webhook] exception:', e);
    return json({ error: 'internal error' }, 500);
  }
}

export function makeWebhookHandler(deps: WebhookDeps): (req: Request) => Promise<Response> {
  return async (req: Request) => {
    if (req.method !== 'POST') return json({ error: 'Method not allowed' }, 405);

    // ── Verify shared secret ────────────────────────────────────────────────
    const webhookSecret = deps.env('REVENUECAT_WEBHOOK_SECRET') ?? '';
    if (!webhookSecret) {
      console.error('[rc-webhook] REVENUECAT_WEBHOOK_SECRET not set');
      return json({ error: 'Webhook not configured' }, 500);
    }
    const auth = req.headers.get('Authorization') ?? '';
    if (auth !== webhookSecret) {
      console.error('[rc-webhook] Authorization mismatch');
      return json({ error: 'Unauthorized' }, 401);
    }

    // ── Parse body ──────────────────────────────────────────────────────────
    let payload: { event?: RcEvent };
    try {
      payload = await req.json();
    } catch {
      return json({ error: 'Invalid JSON' }, 400);
    }
    const event = payload.event ?? {};
    const type = String(event.type ?? '');
    const eventId = String(event.id ?? '');
    const appUserId = String(event.app_user_id ?? '');
    const productId = String(event.product_id ?? '');

    // ── Pro subscription → user_entitlements ────────────────────────────────
    if (type === TRANSFER_EVENT_TYPE) {
      return await handleTransfer(deps, event, eventId);
    }
    if (takesProPath(event)) {
      return await handleProSubscription(deps, event, type, eventId, appUserId);
    }

    // Acknowledge non-granting events (cancellations, billing issues, test pings)
    // so RC doesn't retry — we just don't grant.
    if (!GRANTING_EVENT_TYPES.has(type)) {
      console.log(`[rc-webhook] ignoring event type=${type} id=${eventId}`);
      return json({ ok: true, ignored: type });
    }

    const credits = productCredits(deps.env)[productId];
    if (!credits || credits <= 0) {
      console.log(`[rc-webhook] no credit mapping for product=${productId} (type=${type})`);
      return json({ ok: true, ignored: 'unmapped_product', product_id: productId });
    }

    if (!appUserId || !eventId) {
      console.error(`[rc-webhook] missing app_user_id or event id (user=${appUserId} id=${eventId})`);
      return json({ error: 'Missing app_user_id or event id' }, 400);
    }

    // ── Grant credits (idempotent on event id) ──────────────────────────────
    const client = deps.db();
    try {
      const { data, error } = await client.rpc('grant_credits', {
        p_user_id: appUserId,
        p_amount: credits,
        p_reason: 'grant_purchase',
        p_ref: eventId,
      });
      if (error) {
        // Unique-violation on the per-event ledger index == already processed.
        if (error.code === '23505') {
          console.log(`[rc-webhook] event ${eventId} already processed (idempotent)`);
          return json({ ok: true, idempotent: true });
        }
        // FK violation == the app_user_id has no auth.users row in THIS project.
        // Dev and prod share one RevenueCat project, and TestFlight purchases are
        // always sandbox, so both Supabase projects can receive events for users
        // that only exist in the other one. Acknowledge so RC doesn't retry.
        if (error.code === '23503') {
          console.log(`[rc-webhook] user ${appUserId} not in this project, ignoring event ${eventId}`);
          return json({ ok: true, ignored: 'user_not_in_project' });
        }
        console.error('[rc-webhook] grant_credits error:', error.message);
        return json({ error: 'grant failed' }, 500);
      }
      console.log(`[rc-webhook] granted ${credits} credits to ${appUserId} (product=${productId}, balance=${data})`);
      return json({ ok: true, granted: credits, balance: data });
    } catch (e) {
      console.error('[rc-webhook] exception:', e);
      return json({ error: 'internal error' }, 500);
    }
  };
}
