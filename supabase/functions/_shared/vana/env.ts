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

// Model ids are spelled the way the gateway catalogue spells them (https://ai-gateway.vercel.sh/v1/models,
// read 2026-09-21): `anthropic/claude-haiku-4.5`, a dot, not a dash. The dashed form these defaults carried
// until now is not an id in the catalogue; whatever the gateway resolved it to, it was not spelled by us,
// and the billed model and price were a guess (mp-467, criterion 5).
export const CHAT_MODEL: string = Deno.env.get('VANA_CHAT_MODEL') ?? 'anthropic/claude-haiku-4.5';
export const TOOL_MODEL: string = Deno.env.get('VANA_TOOL_MODEL') ?? 'anthropic/claude-haiku-4.5';
export const EMBED_MODEL: string = Deno.env.get('VANA_EMBED_MODEL') ?? 'openai/text-embedding-3-small';

/**
 * The three background jobs' model, apart from the chat model (mp-465 clause 3, ai-cost ticket 14).
 *
 * These three write nothing the athlete reads — the memory extraction when a conversation goes idle
 * (`extract.ts`), the rolling summary of an open conversation (`extract.ts`) and the ingredient list
 * for a saved meal (`saved-ingredients.ts`) — so their model is chosen on price against "does it
 * return the same structured answer". They must not follow `VANA_CHAT_MODEL` (Vana's conversation,
 * clause 1) or `VANA_TOOL_MODEL` (still the day notes, clause 5, and the pantry photo).
 *
 * Read at CALL time, not at import time, so a changed function secret takes effect on the next
 * invocation without the module graph being re-imported. Absent, the three stay where they were.
 */
export const BACKGROUND_MODEL_ENV = 'VANA_BACKGROUND_MODEL';
export const backgroundModel = (): string => Deno.env.get(BACKGROUND_MODEL_ENV) ?? 'anthropic/claude-haiku-4.5';

export const SUPABASE_URL = Deno.env.get('SUPABASE_URL') ?? '';
export const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '';

/** The live daily-macros engine (the app calls the same one — see daily_macro_service.dart). */
export const MACROS_FN = 'calculate-daily-macros-v6';

export const today = () => new Date().toISOString().slice(0, 10);
export const addDays = (iso: string, n: number) => new Date(new Date(iso + 'T00:00:00Z').getTime() + n * 86400_000).toISOString().slice(0, 10);
export type DayKey = 'sun' | 'mon' | 'tue' | 'wed' | 'thu' | 'fri' | 'sat';
/** getUTCDay order: index 0 is Sunday. The `week_start` setting stores one of these. */
export const DAY_KEYS: readonly DayKey[] = ['sun', 'mon', 'tue', 'wed', 'thu', 'fri', 'sat'];
/** The plan week containing `iso`: the latest `startDay` on or before it (mp-269; the `week_start` setting, Sunday by
 *  default, matching the design's "Aug 23 – 29"). The Dart port is `weekStartFor` in domain/week_start.dart — keep in lockstep. */
export function weekStartFor(iso = today(), startDay: DayKey = 'sun') { const d = new Date(iso + 'T00:00:00Z'); const back = (d.getUTCDay() - DAY_KEYS.indexOf(startDay) + 7) % 7; return addDays(iso, -back); }
export const dayKey = (iso: string) => DAY_KEYS[new Date(iso + 'T00:00:00Z').getUTCDay()];
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
