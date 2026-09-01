/**
 * Vana — per-request wiring + model selection for the Deno edge functions.
 *
 * Port of the prototype's `server/vana/env.ts`. The one structural change: the prototype used a
 * service-role client with an explicit `user_id` filter in every query; here every user-owned read
 * and write goes through the CALLER'S JWT client (`db`) so Postgres RLS does the filtering. The
 * service-role client (`admin`) is reserved for the few things the user's role cannot do:
 * `vana_calls` writes (users may only read their own rows), `daily_macro_targets` fills on the
 * user's behalf, and `refresh_meal_library_pairs()`.
 *
 * Models are plain "provider/model" strings — the AI SDK routes them through the Vercel AI Gateway
 * when AI_GATEWAY_API_KEY is set (same convention as `_shared/ai/model.ts`).
 */
import type { SupabaseClient } from 'https://esm.sh/@supabase/supabase-js@2.39.3';

// deno-lint-ignore no-explicit-any
export type Db = SupabaseClient<any, 'public', any>;

/** Everything a Vana module needs to act for one athlete in one request. */
export interface VanaCtx {
  /** The caller's JWT-scoped client — RLS applies. */
  db: Db;
  /** Service-role client — call logs, rate-limit counts, macro fills only. */
  admin: Db;
  /** auth.users id of the caller (also what search_meals / recall_memories take as p_user_id). */
  userId: string;
  /** The caller's raw JWT — forwarded to `vana-day-notes` for background regeneration. */
  token: string;
}

export const CHAT_MODEL: string = Deno.env.get('VANA_CHAT_MODEL') ?? 'anthropic/claude-haiku-4-5';
export const TOOL_MODEL: string = Deno.env.get('VANA_TOOL_MODEL') ?? 'anthropic/claude-haiku-4-5';
export const EMBED_MODEL: string = Deno.env.get('VANA_EMBED_MODEL') ?? 'openai/text-embedding-3-small';

export const SUPABASE_URL = Deno.env.get('SUPABASE_URL') ?? '';
export const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '';

/** The live daily-macros engine (the app calls the same one — see daily_macro_service.dart). */
export const MACROS_FN = 'calculate-daily-macros-v6';

export const today = () => new Date().toISOString().slice(0, 10);
export const addDays = (iso: string, n: number) => new Date(new Date(iso + 'T00:00:00Z').getTime() + n * 86400_000).toISOString().slice(0, 10);
/** Sunday-start week (cook day Sunday), matching the design's "Aug 23 – 29". */
export function weekStartFor(iso = today()) { const d = new Date(iso + 'T00:00:00Z'); return addDays(iso, -d.getUTCDay()); }
export const dayKey = (iso: string) => ['sun', 'mon', 'tue', 'wed', 'thu', 'fri', 'sat'][new Date(iso + 'T00:00:00Z').getUTCDay()] as 'sun' | 'mon' | 'tue' | 'wed' | 'thu' | 'fri' | 'sat';
export const dayName = (iso: string) => new Date(iso + 'T00:00:00Z').toLocaleDateString('en-US', { weekday: 'long', timeZone: 'UTC' });
/** YYYY-MM-DD in the athlete's timezone (falls back to UTC on a bad IANA name). */
export function localDate(tz: string | null | undefined): string {
  if (!tz) return today();
  try { return new Intl.DateTimeFormat('en-CA', { timeZone: tz }).format(new Date()); } catch { return today(); }
}

/** Fire-and-forget under the edge runtime (falls back to a detached promise locally / in tests). */
export function waitUntil(p: Promise<unknown>): void {
  // deno-lint-ignore no-explicit-any
  const rt = (globalThis as any).EdgeRuntime;
  if (rt?.waitUntil) rt.waitUntil(p); else void p.catch((e) => console.error('[vana] background task failed:', e));
}
