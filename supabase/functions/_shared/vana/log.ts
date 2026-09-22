/** Call log → public.vana_calls. One row per model call: who made it, which function and model, the tokens, and — since
 *  ai-cost ticket 05 (mp-420 clause 6, mp-464 clause 7) — what it cost us and what kind of turn it was:
 *
 *    cache_read_tokens / cache_write_tokens   the prompt cache, both directions (a write bills more than an uncached read)
 *    first_step_input_tokens /                the FIRST model step only. Only the first step can read the shared prefix
 *    first_step_cache_read_tokens             from cache; later steps read what this same call just wrote, so a whole-turn
 *                                             ratio flatters the cache. The hit rate mp-420 is measured against is this one.
 *    steps                                    model steps in the turn — a runaway tool loop is many billed calls
 *    gateway_cost_usd                         the gateway's OWN charge for the call, not our arithmetic
 *    debited                                  whether the turn drew the athlete's budget
 *    input_mode                               'tap' | 'typed' — what the athlete did (null for openers and background jobs)
 *    subscriber_period_type /                 the `user_entitlements` cache as it stood at the call. Raw, so the plan label
 *    subscriber_active_until                  stays in SQL (`vana_plan_label`) and can be re-cut without a backfill.
 *
 *  Service role: users can only SELECT their own rows. Never throws. Raw rows are swept after 90 days and the weekly
 *  rollup kept (`ai_log_retention_sweep`); the figures are read from `public.vana_weekly_cost`.
 */
import type { Db } from './env.ts';
import { cacheReadTokens, cacheWriteTokens } from './stream.ts';
import { gatewayCostUsd } from '../ai/usage.ts';

/** Everything about a finished call that is not its tokens, its function or its model. */
export interface CallCostFields {
  cacheReadTokens?: number | null;
  cacheWriteTokens?: number | null;
  steps?: number | null;
  gatewayCostUsd?: number | null;
  firstStepInputTokens?: number | null;
  firstStepCacheReadTokens?: number | null;
  debited?: boolean | null;
  inputMode?: InputMode | null;
  subscriberPeriodType?: string | null;
  subscriberActiveUntil?: string | null;
}

/** What the athlete did to send the message (mp-464 clause 7). A chip Vana named, "Adjust" and "Different protein" are
 *  taps that still cost a turn; the saving the fixed-label chips make is only visible against them. */
export type InputMode = 'tap' | 'typed';
export const INPUT_MODES: readonly InputMode[] = ['tap', 'typed'];
/** Narrow unchecked client input to an input mode; anything else is null rather than a rejected request. */
export const asInputMode = (raw: unknown): InputMode | null => (raw === 'tap' || raw === 'typed' ? raw : null);

/** The column patch for [c]. Keys the caller did not mention are left out, so `completeCall` never blanks a column it
 *  was not asked about. `null` is written through — it is the honest answer when a provider reported nothing. */
export function costColumns(c: CallCostFields): Record<string, unknown> {
  const patch: Record<string, unknown> = {};
  const put = (col: string, v: unknown) => { if (v !== undefined) patch[col] = v; };
  put('cache_read_tokens', c.cacheReadTokens);
  put('cache_write_tokens', c.cacheWriteTokens);
  put('steps', c.steps);
  put('gateway_cost_usd', c.gatewayCostUsd);
  put('first_step_input_tokens', c.firstStepInputTokens);
  put('first_step_cache_read_tokens', c.firstStepCacheReadTokens);
  put('debited', c.debited);
  put('input_mode', c.inputMode);
  put('subscriber_period_type', c.subscriberPeriodType);
  put('subscriber_active_until', c.subscriberActiveUntil);
  return patch;
}

/**
 * Read a finished turn's cost out of what the SDK handed back.
 *
 * `totalUsage` is the turn; `steps[0]` is the one step whose prompt could have been served from the cache. The gateway
 * reports its charge per step in that step's `providerMetadata`, so the turn's charge is the steps' charges added up —
 * the last step's metadata alone would undercount every tool loop. A turn where no step reported a charge gets null,
 * never 0: "the gateway said nothing" and "the call was free" must not read the same.
 */
// deno-lint-ignore no-explicit-any
export function callMetrics(steps: readonly any[] | undefined, totalUsage: any): CallCostFields {
  const all = steps ?? [];
  const charges = all.map((s) => gatewayCostUsd(s?.providerMetadata)).filter((c): c is number => c != null);
  const first = all[0];
  return {
    cacheReadTokens: cacheReadTokens(totalUsage),
    cacheWriteTokens: cacheWriteTokens(totalUsage),
    steps: all.length,
    gatewayCostUsd: charges.length ? charges.reduce((a, b) => a + b, 0) : null,
    firstStepInputTokens: first ? first.usage?.inputTokens ?? null : null,
    firstStepCacheReadTokens: first ? cacheReadTokens(first.usage) : null,
  };
}

export async function logCall(admin: Db, row: { userId: string; conversationId?: string | null; functionName: string; model: string; inputTokens?: number; outputTokens?: number } & CallCostFields) {
  try {
    const { error } = await admin.from('vana_calls').insert({
      user_id: row.userId,
      conversation_id: row.conversationId ?? null,
      function_name: row.functionName,
      model: row.model,
      input_tokens: row.inputTokens ?? null,
      output_tokens: row.outputTokens ?? null,
      cache_read_tokens: row.cacheReadTokens ?? null,
      ...costColumns({ ...row, cacheReadTokens: row.cacheReadTokens ?? null }),
    });
    if (error) console.error('[vana] vana_calls insert failed:', error.message);
  } catch (e) { console.error('[vana] vana_calls insert threw:', (e as Error).message); }
}
