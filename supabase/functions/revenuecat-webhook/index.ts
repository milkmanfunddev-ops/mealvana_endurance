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
 */

import { serve } from 'https://deno.land/std@0.224.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.39.3';

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
