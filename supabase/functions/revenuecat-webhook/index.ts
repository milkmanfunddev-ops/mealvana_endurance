/**
 * revenuecat-webhook Edge Function
 *
 * Receives RevenueCat webhook events and grants AI credits to the purchasing
 * user's wallet (token_wallets / grant_credits RPC). This is the "purchase →
 * grant" half of the AI-credits feature; the "use → debit" half lives in the AI
 * edge functions via _shared/ai/credits.ts.
 *
 * Setup (RevenueCat dashboard → Integrations → Webhooks):
 *   • URL:  https://<project-ref>.supabase.co/functions/v1/revenuecat-webhook
 *   • Authorization header: set to the SAME value as the REVENUECAT_WEBHOOK_SECRET
 *     secret below (RC sends it verbatim in the Authorization header).
 *   • Environment filter: the PROD webhook must receive BOTH sandbox and
 *     production events — TestFlight purchases are always sandbox, so a
 *     production-only filter silently routes every TestFlight purchase to the
 *     dev project and the prod wallet never increments (2026-08-11 incident).
 *     Cross-project deliveries are safe: an app_user_id that doesn't exist in
 *     this project's auth.users FK-fails in grant_credits and is acked as a
 *     no-op below.
 * Deploy with JWT verification OFF (RC is not a Supabase-authed caller):
 *   supabase functions deploy revenuecat-webhook --no-verify-jwt --project-ref <ref>
 * Secrets:
 *   REVENUECAT_WEBHOOK_SECRET  — shared secret matched against the Authorization header
 *   RC_PRODUCT_CREDITS         — optional JSON map of store product id → credit amount,
 *                                e.g. {"mealvana_credits_50":50,"mealvana_credits_250":250}
 *                                NOTE: when set, this REPLACES the defaults below — a stale
 *                                secret is enough to make every new SKU grant 0 credits.
 *
 * IMPORTANT: the RevenueCat "App User ID" must be the Supabase auth user id
 * (set via Purchases.logIn(userId) in the app) so app_user_id maps to our user.
 *
 * Idempotent: grant_credits writes one ledger row per RC event id
 * (token_ledger unique index on ref for grant_purchase); a re-delivered event is
 * a safe no-op.
 *
 * Pro subscription (2026-09-01, docs/implement_mealplanning/04-entitlement.md):
 * subscription lifecycle events for the `pro` entitlement upsert
 * `public.user_entitlements` — the server-side paywall the vana-* edge
 * functions read via has_entitlement(). That branch runs BEFORE the consumable
 * grant path, so an INITIAL_PURCHASE / RENEWAL of a Pro SKU never reaches
 * grant_credits. Idempotent + order-safe: an event older than the stored row's
 * `updated_at` (= RC event_timestamp_ms) is acked without writing. Unmapped
 * users (23503) are acked as no-ops exactly like the credit path.
 */

import { serve } from 'https://deno.land/std@0.224.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.39.3';
import {
  entitlementRowFor,
  isProEvent,
  isStaleEvent,
  PRO_ENTITLEMENT,
  SUBSCRIPTION_EVENT_TYPES,
  TRANSFER_EVENT_TYPE,
  transferParties,
} from './entitlements.ts';

const SUPABASE_URL = Deno.env.get('SUPABASE_URL') ?? '';
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '';
const WEBHOOK_SECRET = Deno.env.get('REVENUECAT_WEBHOOK_SECRET') ?? '';

/** RC store product id → credits granted. Override via RC_PRODUCT_CREDITS JSON. */
const DEFAULT_PRODUCT_CREDITS: Record<string, number> = {
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

function productCredits(): Record<string, number> {
  const raw = Deno.env.get('RC_PRODUCT_CREDITS');
  if (!raw) return DEFAULT_PRODUCT_CREDITS;
  try {
    const parsed = JSON.parse(raw);
    if (parsed && typeof parsed === 'object') return parsed as Record<string, number>;
  } catch (e) {
    console.error('[rc-webhook] bad RC_PRODUCT_CREDITS JSON, using defaults:', e);
  }
  return DEFAULT_PRODUCT_CREDITS;
}

/** Event types that represent a one-time credit-pack purchase. */
const GRANTING_EVENT_TYPES = new Set(['NON_RENEWING_PURCHASE', 'INITIAL_PURCHASE', 'RENEWAL']);

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { 'Content-Type': 'application/json' },
  });
}

/**
 * Upsert the `pro` row for [appUserId] from a subscription event.
 *
 * Reads the existing row first so (a) cancellation / billing timestamps carry
 * across events that do not mention them and (b) a delayed re-delivery older
 * than what is stored is dropped instead of rolling the state back.
 */
async function handleProSubscription(
  event: Record<string, unknown>,
  type: string,
  eventId: string,
  appUserId: string,
): Promise<Response> {
  if (!appUserId || !eventId) {
    console.error(`[rc-webhook] missing app_user_id or event id (user=${appUserId} id=${eventId})`);
    return json({ error: 'Missing app_user_id or event id' }, 400);
  }

  const client = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);
  try {
    const { data: existing, error: readError } = await client
      .from('user_entitlements')
      .select('*')
      .eq('user_id', appUserId)
      .eq('entitlement', PRO_ENTITLEMENT)
      .maybeSingle();
    if (readError) {
      console.error('[rc-webhook] user_entitlements read error:', readError.message);
      return json({ error: 'entitlement read failed' }, 500);
    }

    if (isStaleEvent(event, existing?.updated_at)) {
      console.log(`[rc-webhook] event ${eventId} (${type}) older than stored row, ignoring`);
      return json({ ok: true, ignored: 'stale_event' });
    }

    const row = entitlementRowFor(event, Date.now(), existing);
    // (user_id, entitlement) is the real primary key — not a partial unique
    // index — so naming it in onConflict is safe (no 42P10).
    const { error } = await client
      .from('user_entitlements')
      .upsert({ user_id: appUserId, ...row }, { onConflict: 'user_id,entitlement' });
    if (error) {
      // FK violation == the app_user_id has no users row in THIS project —
      // same dev/prod split as the credit path. Ack so RC doesn't retry.
      if (error.code === '23503') {
        console.log(
          `[rc-webhook] user ${appUserId} not in this project, ignoring event ${eventId}`,
        );
        return json({ ok: true, ignored: 'user_not_in_project' });
      }
      console.error('[rc-webhook] user_entitlements upsert error:', error.message);
      return json({ error: 'entitlement upsert failed' }, 500);
    }
    console.log(
      `[rc-webhook] ${type}: pro active=${row.active} until=${row.expires_at} for ${appUserId} (product=${row.product_id})`,
    );
    return json({
      ok: true,
      entitlement: PRO_ENTITLEMENT,
      active: row.active,
      expires_at: row.expires_at,
    });
  } catch (e) {
    console.error('[rc-webhook] exception:', e);
    return json({ error: 'internal error' }, 500);
  }
}

/**
 * TRANSFER: RevenueCat moved every purchase from `transferred_from` users to
 * `transferred_to` users (a restore on a device signed into another account).
 * Carry the `pro` row over and deactivate it on the old owners. The event
 * carries no product/expiry, so a missing source row means nothing to move.
 */
async function handleTransfer(
  event: Record<string, unknown>,
  eventId: string,
): Promise<Response> {
  const { from, to } = transferParties(event);
  if (from.length === 0 && to.length === 0) {
    console.log(`[rc-webhook] TRANSFER ${eventId} without parties, ignoring`);
    return json({ ok: true, ignored: 'transfer_no_parties' });
  }

  const client = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);
  try {
    let source: Record<string, unknown> | undefined;
    if (from.length > 0) {
      const { data: sourceRows, error: readError } = await client
        .from('user_entitlements')
        .select('*')
        .in('user_id', from)
        .eq('entitlement', PRO_ENTITLEMENT);
      if (readError) {
        console.error('[rc-webhook] transfer read error:', readError.message);
        return json({ error: 'entitlement read failed' }, 500);
      }
      const rows = (sourceRows ?? []) as Record<string, unknown>[];
      source = rows.find((r) => r.active === true) ?? rows[0];
    }
    const nowIso = new Date().toISOString();

    if (source && to.length > 0) {
      const { user_id: _ignored, ...fields } = source;
      const { error } = await client
        .from('user_entitlements')
        .upsert(
          to.map((userId) => ({ ...fields, user_id: userId, updated_at: nowIso })),
          { onConflict: 'user_id,entitlement' },
        );
      // A recipient outside this project is expected (dev/prod split).
      if (error && error.code !== '23503') {
        console.error('[rc-webhook] transfer upsert error:', error.message);
        return json({ error: 'entitlement upsert failed' }, 500);
      }
    }
    if (from.length > 0) {
      const { error } = await client
        .from('user_entitlements')
        .update({ active: false, updated_at: nowIso })
        .in('user_id', from)
        .eq('entitlement', PRO_ENTITLEMENT);
      if (error) {
        console.error('[rc-webhook] transfer deactivate error:', error.message);
        return json({ error: 'entitlement update failed' }, 500);
      }
    }
    console.log(
      `[rc-webhook] TRANSFER ${eventId}: pro ${from.join(',')} → ${to.join(',')} (moved=${!!source})`,
    );
    return json({ ok: true, transferred: !!source, from, to });
  } catch (e) {
    console.error('[rc-webhook] exception:', e);
    return json({ error: 'internal error' }, 500);
  }
}

serve(async (req: Request) => {
  if (req.method !== 'POST') return json({ error: 'Method not allowed' }, 405);

  // ── Verify shared secret ──────────────────────────────────────────────────
  if (!WEBHOOK_SECRET) {
    console.error('[rc-webhook] REVENUECAT_WEBHOOK_SECRET not set');
    return json({ error: 'Webhook not configured' }, 500);
  }
  const auth = req.headers.get('Authorization') ?? '';
  if (auth !== WEBHOOK_SECRET) {
    console.error('[rc-webhook] Authorization mismatch');
    return json({ error: 'Unauthorized' }, 401);
  }

  // ── Parse body ────────────────────────────────────────────────────────────
  let payload: { event?: Record<string, unknown> };
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

  // ── Pro subscription → user_entitlements ─────────────────────────────────
  if (type === TRANSFER_EVENT_TYPE) {
    return await handleTransfer(event, eventId);
  }
  if (SUBSCRIPTION_EVENT_TYPES.has(type) && isProEvent(event)) {
    return await handleProSubscription(event, type, eventId, appUserId);
  }

  // Acknowledge non-granting events (cancellations, billing issues, test pings)
  // so RC doesn't retry — we just don't grant.
  if (!GRANTING_EVENT_TYPES.has(type)) {
    console.log(`[rc-webhook] ignoring event type=${type} id=${eventId}`);
    return json({ ok: true, ignored: type });
  }

  const credits = productCredits()[productId];
  if (!credits || credits <= 0) {
    console.log(`[rc-webhook] no credit mapping for product=${productId} (type=${type})`);
    return json({ ok: true, ignored: 'unmapped_product', product_id: productId });
  }

  if (!appUserId || !eventId) {
    console.error(`[rc-webhook] missing app_user_id or event id (user=${appUserId} id=${eventId})`);
    return json({ error: 'Missing app_user_id or event id' }, 400);
  }

  // ── Grant credits (idempotent on event id) ────────────────────────────────
  const client = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);
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
        console.log(
          `[rc-webhook] user ${appUserId} not in this project, ignoring event ${eventId}`,
        );
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
});
