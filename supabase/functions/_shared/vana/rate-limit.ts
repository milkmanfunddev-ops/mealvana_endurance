/** Per-user rate limit, counted from public.vana_calls (the call log is the bucket store). Fails open on DB errors.
 *  Buckets match by prefix: `vana.chat` covers `vana.chat.meal_planning` and `vana.chat.general`, `vana.opener` both opener kinds.
 *  Reads through the service-role client so the count is authoritative regardless of RLS. */
import type { Db } from './env.ts';

const WINDOWS = {
  'vana.chat': { seconds: 10, max: 4 },      // 4 turns / 10s
  'vana.opener': { seconds: 60, max: 3 },    // new conversations
  'vana.brief': { seconds: 60, max: 2 },
  'vana.daynotes': { seconds: 60, max: 4 },  // one call writes all seven days
  'vana.embed': { seconds: 60, max: 30 },
} as const;
export type RateLimitedFn = keyof typeof WINDOWS;

export async function checkRateLimit(admin: Db, userId: string, fn: RateLimitedFn): Promise<{ allowed: boolean; retryAfterSeconds?: number }> {
  const w = WINDOWS[fn];
  try {
    const since = new Date(Date.now() - w.seconds * 1000).toISOString();
    const { count, error } = await admin.from('vana_calls').select('*', { count: 'exact', head: true }).eq('user_id', userId).like('function_name', `${fn}%`).gte('created_at', since);
    if (error || count == null) return { allowed: true };
    return count >= w.max ? { allowed: false, retryAfterSeconds: w.seconds } : { allowed: true };
  } catch { return { allowed: true }; }
}
/** Thrown by model paths that have no HTTP response of their own (opener, brief, embeddings); the functions map it to 429. */
export class RateLimitedError extends Error {
  constructor(public fn: RateLimitedFn, public retryAfterSeconds: number) { super(`rate_limited: ${fn}`); this.name = 'RateLimitedError'; }
}
export async function assertRateLimit(admin: Db, userId: string, fn: RateLimitedFn): Promise<void> {
  const r = await checkRateLimit(admin, userId, fn);
  if (!r.allowed) throw new RateLimitedError(fn, r.retryAfterSeconds ?? WINDOWS[fn].seconds);
}
