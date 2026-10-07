/**
 * ensure-credits Edge Function
 *
 * Provisions the caller's token wallet and grants the monthly free allotment,
 * then returns the current balance.
 *
 * POST /functions/v1/ensure-credits
 * Auth: Supabase user JWT (Authorization: Bearer ...)
 *
 * Response (200): { balance: number, free_monthly: number, enforced: boolean }
 * Errors: 401 missing/invalid JWT · 500 unexpected
 *
 * WHY THIS EXISTS
 * The wallet was provisioned lazily by the AI edge functions, on the first
 * `describe-meal` / `analyze-meal-photo` call. Until then no `token_wallets`
 * row existed, so the client read a balance of 0 and a brand-new user was shown
 * "You're out of tokens" and a purchase prompt while their free grant sat
 * unissued — then the number jumped to (grant - 1) the moment they ran an
 * analysis anyway. The grant RPCs are SECURITY DEFINER and take the user id as
 * a *parameter*, so they are granted to `service_role` only and the client
 * cannot call them directly (doing so would let any user credit any other
 * user's wallet). This function is the authenticated, user-scoped door to that
 * same logic: it derives the user from the JWT and never trusts a body.
 *
 * Idempotent: `ensure_free_credits` grants at most once per calendar month
 * (guarded by `token_wallets.free_period`), so callers may invoke this on every
 * app start.
 *
 * The handler (and the D9 wallet-unit warning) is in handler.ts.
 *
 * Deploy:
 *   supabase functions deploy ensure-credits --project-ref <ref>
 */

import { serve } from 'https://deno.land/std@0.224.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.39.3';
import { initSentry, withSentry } from '../_shared/sentry.ts';
import { CREDITS_ENFORCED, FREE_MONTHLY_CREDITS } from '../_shared/ai/credits.ts';
import { makeEnsureCreditsHandler } from './handler.ts';

const SUPABASE_URL = Deno.env.get('SUPABASE_URL') ?? '';
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '';

initSentry();

serve(withSentry('ensure-credits', makeEnsureCreditsHandler({
  admin: () => createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY),
  freeMonthly: FREE_MONTHLY_CREDITS,
  enforced: CREDITS_ENFORCED,
})));
