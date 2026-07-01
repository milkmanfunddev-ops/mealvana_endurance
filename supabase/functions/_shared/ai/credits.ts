/**
 * AI credit enforcement for the AI edge functions.
 *
 * Users hold a balance of app-defined "AI credits" (see the token_wallets /
 * token_ledger schema + grant_credits/debit_credits/ensure_free_credits RPCs).
 * Each AI action costs a fixed number of credits. This module:
 *   1. lazily provisions a wallet + grants the monthly free allotment,
 *   2. checks the user can afford the action BEFORE the model call,
 *   3. debits the cost AFTER a successful call (failed calls aren't charged).
 *
 * Enforcement is OFF by default and gated by the AI_CREDITS_ENFORCED secret, so
 * deploying this is a no-op until you flip the flag per project:
 *   supabase secrets set AI_CREDITS_ENFORCED=true   (when the paywall is ready)
 *
 * Tunables (all env-overridable, sensible defaults):
 *   AI_FREE_MONTHLY_CREDITS   — free credits granted once per calendar month
 *   AI_COST_<FN>              — per-action cost override (e.g. AI_COST_JADE_CHAT)
 *
 * Fail-open: any wallet/db error returns allowed (never block AI on infra
 * hiccups). Flip to fail-closed later if abuse appears.
 */

import type { SupabaseClient } from 'https://esm.sh/@supabase/supabase-js@2.39.3';

export const CREDITS_ENFORCED = Deno.env.get('AI_CREDITS_ENFORCED') === 'true';

export const FREE_MONTHLY_CREDITS = intEnv('AI_FREE_MONTHLY_CREDITS', 50);

/** Per-action credit cost. User-facing credits, NOT raw LLM tokens — the real
 *  token cost is tracked separately in ai_usage. Tune freely. */
const DEFAULT_COSTS: Record<string, number> = {
  'ai-coach': 1,
  'describe-meal': 1,
  'analyze-meal-photo': 2,
  'jade-chat': 1,
};

export function creditCost(fn: string): number {
  const envKey = `AI_COST_${fn.toUpperCase().replace(/-/g, '_')}`;
  return intEnv(envKey, DEFAULT_COSTS[fn] ?? 1);
}

export interface CreditCheck {
  /** true if the call may proceed (always true when enforcement is off). */
  allowed: boolean;
  /** current balance, or -1 when unknown (enforcement off / fail-open). */
  balance: number;
  /** credit cost of this action. */
  cost: number;
}

/**
 * Ensure the wallet exists + monthly free credits are granted, then check
 * (WITHOUT debiting) whether the user can afford `fn`. Fail-open on error.
 */
export async function ensureAndCheckCredits(
  // deno-lint-ignore no-explicit-any
  client: SupabaseClient<any, any, any>,
  userId: string,
  fn: string,
): Promise<CreditCheck> {
  const cost = creditCost(fn);
  if (!CREDITS_ENFORCED) return { allowed: true, balance: -1, cost };
  try {
    const { data, error } = await client.rpc('ensure_free_credits', {
      p_user_id: userId,
      p_amount: FREE_MONTHLY_CREDITS,
    });
    if (error) {
      console.error('[credits] ensure_free_credits error (fail-open):', error.message);
      return { allowed: true, balance: -1, cost };
    }
    const balance = typeof data === 'number' ? data : 0;
    return { allowed: balance >= cost, balance, cost };
  } catch (e) {
    console.error('[credits] ensureAndCheckCredits exception (fail-open):', e);
    return { allowed: true, balance: -1, cost };
  }
}

/**
 * Debit `fn`'s cost after a successful AI call. Never throws. No-op when
 * enforcement is off. Atomic + balance-guarded server-side (debit_credits RPC).
 */
export async function debitForUsage(
  // deno-lint-ignore no-explicit-any
  client: SupabaseClient<any, any, any>,
  userId: string,
  fn: string,
): Promise<void> {
  if (!CREDITS_ENFORCED) return;
  const cost = creditCost(fn);
  try {
    const { data, error } = await client.rpc('debit_credits', {
      p_user_id: userId,
      p_amount: cost,
      p_reason: 'debit_usage',
      p_ref: fn,
    });
    if (error) {
      console.error('[credits] debit_credits error:', error.message);
      return;
    }
    // debit_credits returns { success, balance }. success:false (no error)
    // means the balance was drained between the pre-call check and this debit
    // (check-then-debit race). The action was already served, so we can't
    // reclaim it — but log it instead of silently swallowing the shortfall.
    const result = data as { success?: boolean; balance?: number } | null;
    if (result && result.success === false) {
      console.warn(
        `[credits] debit declined for ${fn} (user ${userId}): balance ` +
          `${result.balance ?? '?'} < cost ${cost} — served without charge`,
      );
    }
  } catch (e) {
    console.error('[credits] debit exception:', e);
  }
}

/** Structured 402 body the client uses to trigger the "buy credits" sheet. */
export function insufficientCreditsBody(check: CreditCheck) {
  return {
    error: 'insufficient_credits',
    message: 'You are out of AI credits. Purchase more to continue.',
    balance: check.balance,
    cost: check.cost,
  };
}

function intEnv(name: string, fallback: number): number {
  const raw = Deno.env.get(name);
  if (raw == null || raw.trim() === '') return fallback;
  const n = Number(raw);
  return Number.isFinite(n) ? Math.trunc(n) : fallback;
}
