/**
 * ensure-credits Edge Function
 *
 * Provisions the caller's token wallet and grants the monthly free allotment,
 * then returns the current balance.
 *
 * POST /functions/v1/ensure-credits
 * Auth: Supabase user JWT (Authorization: Bearer ...)
 *
 * Response (200): { share_used: number|null, refill_at: string|null, bought_extra_share: number,
 *                   allowance_expires_at: string|null, enforced: boolean }
 *   — the budget as the app may see it (mp-436 clause 3): the share of the month used, when it refills,
 *   any bought extra as a share of a month. Never a balance or a dollar figure. `allowance_expires_at`
 *   repeats `refill_at` under the name the shipped client reads.
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
 * app start. The free grant ends the day the paywall opens (mp-430 clause 10,
 * `freeMonthlyBudget`); from then on this only rolls the subscription's
 * monthly budget.
 *
 * Deploy:
 *   supabase functions deploy ensure-credits --project-ref <ref>
 */

import { serve } from 'https://deno.land/std@0.224.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.39.3';
import { handleCors } from '../_shared/cors.ts';
import { errorResponse, jsonResponse, serverError } from '../_shared/responses.ts';
import { CREDITS_ENFORCED, MONTHLY_BUDGET, TRIAL_BUDGET } from '../_shared/ai/credits.ts';
import { budgetStatus, freeMonthlyBudget } from '../_shared/ai/allowance.ts';

const SUPABASE_URL = Deno.env.get('SUPABASE_URL') ?? '';
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '';

serve(async (req) => {
  const cors = handleCors(req);
  if (cors) return cors;

  try {
    const token = req.headers.get('Authorization')?.replace(/^Bearer\s+/i, '');
    if (!token) return errorResponse('Missing authorization header', 401);

    const admin = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);
    const { data: { user }, error: authError } = await admin.auth.getUser(token);
    if (authError || !user) {
      console.error('[ensure-credits] auth error:', authError);
      return errorResponse('Invalid or expired token', 401);
    }

    // The old free grant, until the paywall opens; 0 from that day (the RPC grants nothing for 0).
    const { error } = await admin.rpc('ensure_free_credits', {
      p_user_id: user.id,
      p_amount: freeMonthlyBudget((k) => Deno.env.get(k)),
    });

    if (error) {
      console.error('[ensure-credits] ensure_free_credits error:', error.message);
      return serverError('Could not provision wallet');
    }

    // The subscription's monthly budget (mp-281, mp-430): forfeit an expired
    // window, grant the current one when the entitlement is active — so what
    // the app shows at launch is already rolled, not a call late.
    const { data: allowance, error: allowanceError } = await admin.rpc('ensure_allowance', {
      p_user_id: user.id,
      p_amount: MONTHLY_BUDGET,
      p_trial_amount: TRIAL_BUDGET,
    });
    if (allowanceError) {
      console.error('[ensure-credits] ensure_allowance error:', allowanceError.message);
    }
    const status = budgetStatus((allowance ?? {}) as Record<string, never>, MONTHLY_BUDGET);

    return jsonResponse({
      ...status,
      allowance_expires_at: status.refill_at,
      enforced: CREDITS_ENFORCED,
    });
  } catch (e) {
    console.error('[ensure-credits] unexpected error:', e);
    return serverError('Unexpected error');
  }
});
