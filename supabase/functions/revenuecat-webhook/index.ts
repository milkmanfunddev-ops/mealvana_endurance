/**
 * revenuecat-webhook Edge Function
 *
 * Receives RevenueCat webhook events. Two paths (handler.ts):
 *   • Every `pro` event, bought or granted (a promotional grant arrives as a
 *     NON_RENEWING_PURCHASE), maintains `public.user_entitlements`, the
 *     two-field cache of RevenueCat the server gate reads (mp-285, mp-454):
 *     `active_until` + `period_type`, written only here, ordered by the RC
 *     event time so a delayed delivery cannot roll the row back; a TRANSFER
 *     moves the row to the new owner.
 *   • Credit-pack purchases grant AI credits to the purchasing user's wallet
 *     (token_wallets / grant_credits RPC), idempotent on the RC event id.
 *
 * Setup (RevenueCat dashboard → Integrations → Webhooks):
 *   • URL:  https://<project-ref>.supabase.co/functions/v1/revenuecat-webhook
 *   • Authorization header: set to the SAME value as the REVENUECAT_WEBHOOK_SECRET
 *     secret below (RC sends it verbatim in the Authorization header).
 *   • Event types: ALL subscription lifecycle events (cancellation, expiration,
 *     transfer, billing issue, …) — a cache that only hears purchases and
 *     renewals never closes a row.
 *   • Environment filter: the PROD webhook must receive BOTH sandbox and
 *     production events — TestFlight purchases are always sandbox, so a
 *     production-only filter silently routes every TestFlight purchase to the
 *     dev project and the prod wallet never increments (2026-08-11 incident).
 *     Cross-project deliveries are safe: an app_user_id that doesn't exist in
 *     this project's users FK-fails and is acked as a no-op.
 * Deploy with JWT verification OFF (RC is not a Supabase-authed caller):
 *   supabase functions deploy revenuecat-webhook --no-verify-jwt --project-ref <ref>
 * Secrets:
 *   REVENUECAT_WEBHOOK_SECRET  — shared secret matched against the Authorization header
 *   REVENUECAT_SECRET_KEY      — RevenueCat v2 secret API key (mp-454 §4). Every `pro`
 *                                event asks RevenueCat for the customer's current `pro`
 *                                expiry; without it those events answer 500 and
 *                                RevenueCat redelivers. Credit packs do not need it.
 *   REVENUECAT_PROJECT_ID      — optional, defaults to proj77b3c48f
 *   REVENUECAT_SANDBOX_ONLY    — "true" on DEV only. The dev integration takes every
 *                                environment so grants (PRODUCTION, PROMOTIONAL store)
 *                                reach it; this drops every other PRODUCTION event, so a
 *                                real store purchase is never handled on dev. Never on prod.
 *   RC_PRODUCT_BUDGET          — optional JSON map of store product id → micro-dollars added,
 *                                e.g. {"mealvana_credits_50":1000000,"mealvana_credits_250":5000000}
 *                                NOTE: when set, this REPLACES the defaults in _shared/ai/allowance.ts —
 *                                a stale secret is enough to make every new SKU grant nothing.
 *                                (RC_PRODUCT_CREDITS, the credit-era map, is read by nothing now.)
 *
 * IMPORTANT: the RevenueCat "App User ID" must be the Supabase auth user id
 * (set via Purchases.logIn(userId) in the app) so app_user_id maps to our user.
 */

import { serve } from 'https://deno.land/std@0.224.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.39.3';
import { makeWebhookHandler } from './handler.ts';
import { makeRevenueCatClient, type RevenueCatClient } from '../_shared/revenuecat/client.ts';

const SUPABASE_URL = Deno.env.get('SUPABASE_URL') ?? '';
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '';
/** One RevenueCat project serves dev and prod. */
const DEFAULT_REVENUECAT_PROJECT_ID = 'proj77b3c48f';

// Kept across requests so the `pro` entitlement id is looked up once per instance.
let revenueCat: RevenueCatClient | null = null;

serve(makeWebhookHandler({
  env: (key) => Deno.env.get(key),
  db: () => createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY),
  revenueCat: () =>
    revenueCat ??= makeRevenueCatClient({
      secretKey: Deno.env.get('REVENUECAT_SECRET_KEY') ?? '',
      projectId: Deno.env.get('REVENUECAT_PROJECT_ID') || DEFAULT_REVENUECAT_PROJECT_ID,
    }),
}));
