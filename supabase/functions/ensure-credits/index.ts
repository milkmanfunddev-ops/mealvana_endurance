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
 * Deploy:
 *   supabase functions deploy ensure-credits --project-ref <ref>
 */

import { serve } from 'https://deno.land/std@0.224.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.39.3';
import { handleCors } from '../_shared/cors.ts';
import { errorResponse, jsonResponse, serverError } from '../_shared/responses.ts';
import { CREDITS_ENFORCED, FREE_MONTHLY_CREDITS } from '../_shared/ai/credits.ts';

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

    const { data, error } = await admin.rpc('ensure_free_credits', {
      p_user_id: user.id,
      p_amount: FREE_MONTHLY_CREDITS,
    });

    if (error) {
      console.error('[ensure-credits] ensure_free_credits error:', error.message);
      return serverError('Could not provision wallet');
    }

    return jsonResponse({
      balance: typeof data === 'number' ? data : 0,
      free_monthly: FREE_MONTHLY_CREDITS,
      enforced: CREDITS_ENFORCED,
    });
  } catch (e) {
    console.error('[ensure-credits] unexpected error:', e);
    return serverError('Unexpected error');
  }
});
