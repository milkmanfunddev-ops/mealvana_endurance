/** Per-user rate limit, counted from public.vana_calls (the call log is the bucket store). Fails open on DB errors.
 *  Buckets match by prefix: `vana.chat` covers `vana.chat.meal_planning` and `vana.chat.general`, `vana.opener` both opener kinds.
 *  Reads through the service-role client so the count is authoritative regardless of RLS.
 *
 *  A call is counted when it STARTS (mp-430 clause 9). `reserveCall` writes the row first and then asks the database who
 *  was early enough, so five requests fired at once against a limit of four let four through; `checkRateLimit`, which
 *  counted rows that only appeared when the turn finished, let all five run. Prefer `reserveCall` on every path that is
 *  about to spend money; `checkRateLimit` remains for the background paths that only want to skip work (day notes,
 *  extraction, the rolling summary), where a second count is cheaper than a row to withdraw.
 *
 *  The per-minute windows here are the only short ceiling. There is no daily cap and no cap on turns or openers — the
 *  monthly budget is the other ceiling, and it lives with the wallet, not here (mp-430 clause 9).
 *
 *  This module is the ONLY limiter: the photo, description and pantry paths call it on the server, and nothing counts on
 *  the phone, where a client could simply not count (Lee, 2026-09-21, `.scratch/ai-cost/spec.md`). */
import type { Db } from './env.ts';

const WINDOWS = {
  'vana.chat': { seconds: 10, max: 4 },      // 4 turns / 10s
  'vana.opener': { seconds: 60, max: 3 },    // new conversations
  'vana.brief': { seconds: 60, max: 2 },
  'vana.daynotes': { seconds: 60, max: 4 },  // one call writes all seven days
  'vana.embed': { seconds: 60, max: 30 },
  'vana.extract': { seconds: 60, max: 3 },   // extraction at idle: one per conversation the client signals idle (a repeat signal never reaches the model)
  'vana.summary': { seconds: 60, max: 3 },   // the rolling history summary: one per twenty messages of a conversation, plus a catch-up
  'vana.ingredients': { seconds: 60, max: 10 }, // ingredients for a dish-level saved meal joining a plan: once per meal ever, so a burst is "same as last time" copying many
  'vana.pantry_photo': { seconds: 60, max: 3 }, // a fridge photo is a vision call: a retake or two, not a burst
  'vana.describe_meal': { seconds: 60, max: 6 }, // logging a few meals in one sitting is normal; sixty a minute is not
  'vana.meal_photo': { seconds: 60, max: 6 },   // the photo the athlete logs a meal from (analyze-meal-photo)
} as const;
export type RateLimitedFn = keyof typeof WINDOWS;
/** The windows, readable by a test and by anything reporting what the limits are. */
export const RATE_LIMIT_WINDOWS: Record<RateLimitedFn, { seconds: number; max: number }> = WINDOWS;

const windowStart = (seconds: number) => new Date(Date.now() - seconds * 1000).toISOString();

export async function checkRateLimit(admin: Db, userId: string, fn: RateLimitedFn): Promise<{ allowed: boolean; retryAfterSeconds?: number }> {
  const w = WINDOWS[fn];
  try {
    const { count, error } = await admin.from('vana_calls').select('*', { count: 'exact', head: true }).eq('user_id', userId).like('function_name', `${fn}%`).gte('created_at', windowStart(w.seconds));
    if (error || count == null) return { allowed: true };
    return count >= w.max ? { allowed: false, retryAfterSeconds: w.seconds } : { allowed: true };
  } catch { return { allowed: true }; }
}

/** What a reservation leaves behind: the id of the call row to finish with `completeCall`, or null when the log could
 *  not be written (the limiter failed open and the caller should fall back to `logCall`). */
export type Reservation = { allowed: true; callId: string | null } | { allowed: false; retryAfterSeconds: number };

/**
 * Take a place in the bucket, before the model runs.
 *
 * Insert the call row, then read the first `max` rows of the window in the database's own order
 * (created_at, then id, so rows written in the same millisecond still have one order every caller agrees on). The call
 * is allowed exactly when its own row is among them; the loser's row is deleted again, so a refusal neither runs a
 * model nor holds a slot for the rest of the window.
 *
 * Race-free without a lock: whoever reads, reads the same rows, and at most `max` rows can be the first `max`.
 */
export async function reserveCall(admin: Db, userId: string, fn: RateLimitedFn, row: { functionName?: string; conversationId?: string | null; model: string }): Promise<Reservation> {
  const w = WINDOWS[fn];
  try {
    const { data: mine, error } = await admin.from('vana_calls')
      .insert({ user_id: userId, conversation_id: row.conversationId ?? null, function_name: row.functionName ?? fn, model: row.model })
      .select('id, created_at').single();
    if (error || !mine?.id) { console.error('[vana] reserveCall insert failed, failing open:', error?.message); return { allowed: true, callId: null }; }
    const { data: first, error: readError } = await admin.from('vana_calls')
      .select('id').eq('user_id', userId).like('function_name', `${fn}%`).gte('created_at', windowStart(w.seconds))
      .order('created_at', { ascending: true }).order('id', { ascending: true }).limit(w.max);
    if (readError || !Array.isArray(first)) return { allowed: true, callId: mine.id as string };
    if (first.some((r: { id: string }) => r.id === mine.id)) return { allowed: true, callId: mine.id as string };
    await admin.from('vana_calls').delete().eq('id', mine.id);
    return { allowed: false, retryAfterSeconds: w.seconds };
  } catch (e) { console.error('[vana] reserveCall threw, failing open:', (e as Error).message); return { allowed: true, callId: null }; }
}

/** Finish a reservation: the tokens the call actually spent, on the row that held its place. Never throws. */
export async function completeCall(admin: Db, callId: string | null, tokens: { inputTokens?: number; outputTokens?: number; cacheReadTokens?: number; functionName?: string; conversationId?: string | null }): Promise<void> {
  if (!callId) return;
  try {
    const patch: Record<string, unknown> = { input_tokens: tokens.inputTokens ?? null, output_tokens: tokens.outputTokens ?? null, cache_read_tokens: tokens.cacheReadTokens ?? null };
    // The reservation is made before the conversation is resolved, so its name and id are settled here.
    if (tokens.functionName) patch.function_name = tokens.functionName;
    if (tokens.conversationId) patch.conversation_id = tokens.conversationId;
    const { error } = await admin.from('vana_calls').update(patch).eq('id', callId);
    if (error) console.error('[vana] completeCall failed:', error.message);
  } catch (e) { console.error('[vana] completeCall threw:', (e as Error).message); }
}

/** Thrown by model paths that have no HTTP response of their own (opener, brief, embeddings); the functions map it to 429. */
export class RateLimitedError extends Error {
  constructor(public fn: RateLimitedFn, public retryAfterSeconds: number) { super(`rate_limited: ${fn}`); this.name = 'RateLimitedError'; }
}
export async function assertRateLimit(admin: Db, userId: string, fn: RateLimitedFn): Promise<void> {
  const r = await checkRateLimit(admin, userId, fn);
  if (!r.allowed) throw new RateLimitedError(fn, r.retryAfterSeconds ?? WINDOWS[fn].seconds);
}
/** `reserveCall` for a path whose only way to refuse is to throw (a Vana action). Returns the reservation id. */
export async function reserveCallOrThrow(admin: Db, userId: string, fn: RateLimitedFn, row: { functionName?: string; conversationId?: string | null; model: string }): Promise<string | null> {
  const r = await reserveCall(admin, userId, fn, row);
  if (!r.allowed) throw new RateLimitedError(fn, r.retryAfterSeconds);
  return r.callId;
}
