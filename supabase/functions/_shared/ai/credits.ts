/**
 * The monthly budget, metered in real cost, for the AI edge functions
 * (mp-430, mp-436; ai-cost ticket 09).
 *
 * Every account has the same monthly budget of model cost, held in the
 * `token_wallets` row in whole micro-dollars beside any bought budget (the
 * SQL: 20260916130000_monthly_allowance.sql, 20260922120000_ai_budget_micro_dollars.sql).
 * Every debiting call — a message to Vana, an opener, the described meal,
 * the meal photo, the pantry photo — goes through this module:
 *
 *   1. `reserveBudget` BEFORE the model: one RPC, `ai_budget_reserve`, that
 *      rolls the allowance, checks the balance against the call's kind's
 *      ESTIMATE and debits it, under the wallet's row lock. A burst of
 *      requests is counted one after the other (mp-430 clause 9). The
 *      refusal is a 402 the client's one handler turns into the top-up sheet
 *      (mp-282); the body is a share, a refill date and bought extra, never
 *      a dollar figure (mp-436 clause 3).
 *   2. `hold.settle(cost)` AFTER the model: `ai_budget_settle` with the real
 *      cost (usage.ts: the gateway's charge, else tokens priced from the one
 *      table). A call that started inside the budget finishes even if it
 *      ends over; the wallet floors at zero and the next call is refused.
 *   3. `hold.refund()` when the call failed: settles at zero, the estimate
 *      comes back. A reservation nobody settled is released by the database
 *      after two hours.
 *
 * Fail-CLOSED on the reservation: a database error refuses the call as OURS
 * (503 `ai_unavailable`, the "Vana is unavailable right now" line), never as
 * the athlete's wallet. The old credit path failed open; a budget that can be
 * bypassed by an outage is not a ceiling.
 *
 * Enforcement stays behind the AI_CREDITS_ENFORCED secret (on for dev, off
 * on prod until the paywall): off, nothing is reserved and every call runs.
 *
 * Tunables: AI_MONTHLY_BUDGET, AI_TRIAL_BUDGET (allowance.ts) and
 * AI_ESTIMATE_<KIND> (micro-dollars; e.g. AI_ESTIMATE_VANA_CHAT).
 */

import type { SupabaseClient } from 'https://esm.sh/@supabase/supabase-js@2.39.3';
import { budgetStatus, monthlyBudget, trialBudget, type BudgetStatus, type WalletBudgetRow } from './allowance.ts';
import { realCostMicro, type RealCostInput } from './usage.ts';
import { AI_UNAVAILABLE } from './gateway_error.ts';

export const CREDITS_ENFORCED = Deno.env.get('AI_CREDITS_ENFORCED') === 'true';

const env = (key: string) => Deno.env.get(key);

/** The monthly budget for this project, in micro-dollars. */
export const MONTHLY_BUDGET = monthlyBudget(env);
/** The trial week's budget for this project, in micro-dollars. */
export const TRIAL_BUDGET = trialBudget(env);

/** The kinds of call that draw the budget. Openers are one of them (mp-430 clause 1). */
export type BudgetKind = 'vana-chat' | 'vana-opener' | 'jade-chat' | 'describe-meal' | 'analyze-meal-photo' | 'vana-pantry-photo';

/**
 * What a call of each kind is expected to cost, in micro-dollars: the
 * reservation taken when it starts. Set from the per-call cost log on dev
 * (ai_usage / vana_calls, 2026-09-15 and the 09-20 audit): a planning turn on
 * Haiku 4.5 with the cache warm is about a cent, an opener a little less, a
 * described meal on Sonnet 4.6 under a cent, a photo a little over. An
 * estimate is only what is held until the real cost is known; it decides
 * nothing but whether an almost-empty wallet may start one more call.
 */
const DEFAULT_ESTIMATES: Record<BudgetKind, number> = {
  'vana-chat': 15_000,
  'vana-opener': 10_000,
  'jade-chat': 15_000,
  'describe-meal': 8_000,
  'analyze-meal-photo': 13_000,
  'vana-pantry-photo': 13_000,
};

export function budgetEstimate(kind: BudgetKind): number {
  const raw = env(`AI_ESTIMATE_${kind.toUpperCase().replace(/-/g, '_')}`);
  const fallback = DEFAULT_ESTIMATES[kind];
  if (raw == null || raw.trim() === '') return fallback;
  const n = Number(raw);
  return Number.isFinite(n) && n > 0 ? Math.trunc(n) : fallback;
}

/** A reservation held for one call: settle it to the real cost, or give it back. Each does something once. */
export interface BudgetHold {
  /** The `token_reservations` id; null when enforcement is off. */
  reservationId: string | null;
  kind: BudgetKind;
  /** Micro-dollars reserved. */
  estimate: number;
  /** The reservation becomes the real cost. Unpriceable input settles at the estimate. Never throws. */
  settle(cost: RealCostInput): Promise<void>;
  /** The call failed: the whole reservation comes back. Never throws. */
  refund(): Promise<void>;
}

export type BudgetReservation =
  | { allowed: true; hold: BudgetHold; status: BudgetStatus }
  | { allowed: false; status: 402 | 503; body: Record<string, unknown> };

/** The `ai_budget_reserve` RPC's row. */
interface ReserveRow extends WalletBudgetRow {
  allowed?: boolean;
  reservation_id?: string;
}

// deno-lint-ignore no-explicit-any
type Client = SupabaseClient<any, any, any>;

function makeHold(client: Client, kind: BudgetKind, estimate: number, reservationId: string | null): BudgetHold {
  let done = false;
  const settleTo = async (real: number, what: string) => {
    if (done) return;
    done = true;
    if (!reservationId) return;
    try {
      const { error } = await client.rpc('ai_budget_settle', { p_id: reservationId, p_real_cost: real });
      if (error) console.error(`[budget] ${what} ${kind} ${reservationId} failed:`, error.message);
    } catch (e) {
      console.error(`[budget] ${what} ${kind} ${reservationId} threw:`, (e as Error).message);
    }
  };
  return {
    reservationId, kind, estimate,
    settle: (cost) => settleTo(realCostMicro(cost) ?? estimate, 'settle'),
    refund: () => settleTo(0, 'refund'),
  };
}

/**
 * Take this call's place in the budget before the model runs. The database
 * decides in one statement; this only shapes the answer.
 */
export async function reserveBudget(client: Client, userId: string, kind: BudgetKind, ref: string = kind): Promise<BudgetReservation> {
  const estimate = budgetEstimate(kind);
  if (!CREDITS_ENFORCED) {
    return { allowed: true, hold: makeHold(client, kind, estimate, null), status: { share_used: null, refill_at: null, bought_extra_share: 0 } };
  }
  try {
    const { data, error } = await client.rpc('ai_budget_reserve', {
      p_user_id: userId, p_kind: kind, p_estimate: estimate, p_monthly: MONTHLY_BUDGET, p_trial: TRIAL_BUDGET, p_ref: ref,
    });
    if (error) {
      console.error(`[budget] ai_budget_reserve error for ${kind} (refusing):`, error.message);
      return { allowed: false, status: 503, body: budgetUnavailableBody() };
    }
    const row = (data ?? {}) as ReserveRow;
    const status = budgetStatus(row, MONTHLY_BUDGET);
    if (row.allowed !== true || typeof row.reservation_id !== 'string') {
      return { allowed: false, status: 402, body: insufficientCreditsBody(status) };
    }
    return { allowed: true, hold: makeHold(client, kind, estimate, row.reservation_id), status };
  } catch (e) {
    console.error(`[budget] reserveBudget threw for ${kind} (refusing):`, e);
    return { allowed: false, status: 503, body: budgetUnavailableBody() };
  }
}

/**
 * Structured 402 body the client's one handler turns into the top-up sheet
 * (mp-282). What the sheet shows and nothing more: the share of the month
 * used, when it refills, any bought extra (mp-436 clause 3). The error code
 * is the one the client already keys on. `allowance_expires_at` repeats
 * `refill_at` under the name today's sheet reads for its renewal line.
 */
export function insufficientCreditsBody(status: BudgetStatus) {
  return {
    error: 'insufficient_credits',
    message: "You have used this month's Vana. Top up to continue.",
    share_used: status.share_used,
    refill_at: status.refill_at,
    allowance_expires_at: status.refill_at,
    bought_extra_share: status.bought_extra_share,
  };
}

/** The database could not answer for the wallet: the fault is ours (mp-437's posture), not the athlete's budget. */
export function budgetUnavailableBody() {
  return { success: false as const, error: AI_UNAVAILABLE, reason: 'budget_unavailable' };
}

/**
 * Thrown by paths that have no HTTP response of their own (a Vana action);
 * the function maps it to the reservation's status and body.
 */
export class BudgetRefusedError extends Error {
  constructor(public status: 402 | 503, public body: Record<string, unknown>) {
    super(`budget_refused: ${String(body.error)}`);
    this.name = 'BudgetRefusedError';
  }
}

/** `reserveBudget` for a path whose only way to refuse is to throw. */
export async function reserveBudgetOrThrow(client: Client, userId: string, kind: BudgetKind, ref?: string): Promise<BudgetHold> {
  const r = await reserveBudget(client, userId, kind, ref);
  if (!r.allowed) throw new BudgetRefusedError(r.status, r.body);
  return r.hold;
}
