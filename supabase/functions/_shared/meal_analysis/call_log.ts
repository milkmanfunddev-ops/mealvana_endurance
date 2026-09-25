/**
 * How a meal-logging AI call (describe-meal, analyze-meal-photo) lands in the Vana call log: as ONE row.
 *
 * The rate-limit reservation made before the model runs IS the call's row, so the tokens, the gateway's charge, the
 * step, the budget draw and the subscriber's plan state are written onto it. A second insert (the old `jade_calls`
 * write, a view over `vana_calls`) doubled every call and its tokens in `vana_weekly_cost` (Finding 24-001).
 *
 * When the reservation failed open (`callId` null: the limiter could not write its row) there is nothing to finish,
 * so the call is logged as a fresh row instead, the way a chat turn falls back. Either way: one call, one row.
 * Never throws; run it on the background task.
 */
import type { Db } from '../vana/env.ts';
import { callMetrics, logCall } from '../vana/log.ts';
import { completeCall, type RateLimitedFn } from '../vana/rate-limit.ts';
import { subscriberState } from '../vana/subscriber.ts';

export async function finishMealCall(admin: Db, call: {
  userId: string;
  callId: string | null;
  /** The limiter bucket the reservation was taken in; also the row's function name. */
  bucket: RateLimitedFn;
  model: string;
  // deno-lint-ignore no-explicit-any
  usage: any;
  // deno-lint-ignore no-explicit-any
  providerMetadata: any;
}): Promise<void> {
  const sub = await subscriberState(admin, call.userId);
  const fields = {
    inputTokens: call.usage?.inputTokens ?? 0,
    outputTokens: call.usage?.outputTokens ?? 0,
    ...callMetrics([{ usage: call.usage, providerMetadata: call.providerMetadata }], call.usage),
    debited: true,
    subscriberPeriodType: sub.periodType,
    subscriberActiveUntil: sub.activeUntil,
  };
  if (call.callId) await completeCall(admin, call.callId, fields);
  else await logCall(admin, { userId: call.userId, functionName: call.bucket, model: call.model, ...fields });
}
