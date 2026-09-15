/** user_memories — what Vana knows. Settings are memories with kind='setting' + key. All through the caller's client (RLS). */
import type { Memory } from './contracts.ts';
import type { VanaCtx, DayKey } from './env.ts';
import { DAY_KEYS } from './env.ts';
import { embedText, vec } from './embeddings.ts';
import { invalidateContext } from './context-cache.ts';

/** Cosine similarity above which a new sentence is the same margin note as one already on file.
 *  text-embedding-3-small puts a genuine paraphrase around 0.85–0.92 and a restatement above 0.95,
 *  so this rejects restatements and lets a real second thought through. Tunable without a deploy. */
export const MEMORY_DUPLICATE_SIMILARITY = Number(Deno.env.get('VANA_MEMORY_DUPE_THRESHOLD') ?? 0.95);
/** The embedding call is the one thing in this module that leaves the process; injecting it is what
 *  lets a test drive the dedupe from fixture vectors. Production takes the default. */
export interface MemoryDeps { embed: (v: VanaCtx, text: string) => Promise<number[]> }
export const defaultMemoryDeps: MemoryDeps = { embed: embedText };

// deno-lint-ignore no-explicit-any
const toMemory = (r: any): Memory => ({ id: r.id, kind: r.kind, key: r.key ?? null, fact: r.fact, value: r.value ?? null, confidence: Number(r.confidence ?? 0.8), lastConfirmedAt: r.last_confirmed_at, source: r.source ?? null });

export async function listMemories(v: VanaCtx, limit = 50): Promise<Memory[]> {
  const { data } = await v.db.from('user_memories').select('*').eq('user_id', v.userId).eq('is_deleted', false).order('last_confirmed_at', { ascending: false }).limit(limit);
  return (data ?? []).map(toMemory);
}
/** The athlete's margin notes, newest first: every kind but the episode. An episode is a sentence per
 *  conversation, so an athlete who talks often would otherwise push every note out of a short list. */
export async function listNotes(v: VanaCtx, limit = 10): Promise<Memory[]> {
  const { data } = await v.db.from('user_memories').select('*').eq('user_id', v.userId).eq('is_deleted', false).neq('kind', 'episode').order('last_confirmed_at', { ascending: false }).limit(limit);
  return (data ?? []).map(toMemory);
}
/** The newest conversations' episode sentences, newest first, a sentence repeated across conversations
 *  shown once. */
export async function recentEpisodes(v: VanaCtx, limit = 3): Promise<Memory[]> {
  const { data } = await v.db.from('user_memories').select('*').eq('user_id', v.userId).eq('is_deleted', false).eq('kind', 'episode').order('last_confirmed_at', { ascending: false }).limit(limit * 4);
  const seen = new Set<string>();
  return (data ?? []).map(toMemory).filter((m) => !seen.has(m.fact) && seen.add(m.fact)).slice(0, limit);
}
export async function recallMemories(v: VanaCtx, text: string, limit = 8): Promise<Memory[]> {
  try {
    const e = vec(await embedText(v, text));
    const { data } = await v.db.rpc('recall_memories', { p_user_id: v.userId, p_embedding: e, p_limit: limit });
    return (data ?? []).map(toMemory);
  } catch { return listMemories(v, limit); }
}
/** The athlete's closest existing Memory to `embedding`, when it is close enough to be the same
 *  note. Uses recall_memories, which already scores cosine similarity server-side; a row with no
 *  embedding scores 0.3 there and can never be mistaken for a duplicate. */
// deno-lint-ignore no-explicit-any
async function nearIdentical(v: VanaCtx, embedding: number[]): Promise<any | null> {
  try {
    // Ask for more rows than we need: settings and episodes carry embeddings and compete on score,
    // so filtering AFTER a tight limit lets them crowd the real duplicate out of the window.
    const { data, error } = await v.db.rpc('recall_memories', { p_user_id: v.userId, p_embedding: vec(embedding), p_limit: 25 });
    if (error) return null;
    // deno-lint-ignore no-explicit-any
    const hit = ((data ?? []) as any[]).filter((r) => r.kind !== 'setting' && r.kind !== 'episode').find((r) => Number(r.score ?? 0) >= MEMORY_DUPLICATE_SIMILARITY);
    return hit ?? null;
  } catch { return null; }   // no embedding service, no dedupe — a duplicate is better than a lost note
}

/**
 * Writes one margin note, or refreshes the one already on file that says the same thing.
 *
 * Three kinds of write land here. A `setting` is keyed and has exactly one row per key. An
 * `episode` is keyed by conversation and has exactly one row per conversation. Everything else is
 * a sentence, and a sentence near-identical by embedding to one this athlete already has is not
 * written twice: the existing row's confirmed date is refreshed instead, so recency still moves.
 * Conflicting notes both stay — each carries its date in the prompt and the model weighs them.
 */
/** `quiet`: the write is the server's own bookkeeping (the extraction an idle signal runs), not a tool the
 *  athlete's turn called. It does not rebuild the context block:
 *  mp-276 refreshes the block on a tool write or a new day, nothing else, and a background write landing between two
 *  turns would otherwise churn the cached prefix mid-conversation. The next conversation, tool write or day sees it. */
export async function rememberFact(v: VanaCtx, m: { kind: Memory['kind']; fact: string; key?: string | null; value?: unknown; confidence?: number; source?: string }, deps: MemoryDeps = defaultMemoryDeps, opts: { quiet?: boolean } = {}): Promise<Memory> {
  const out = await writeFact(v, m, deps);
  if (!opts.quiet) await invalidateContext(v); // memories, settings and the pantry are all lines of the block
  return out;
}
async function writeFact(v: VanaCtx, m: { kind: Memory['kind']; fact: string; key?: string | null; value?: unknown; confidence?: number; source?: string }, deps: MemoryDeps): Promise<Memory> {
  let raw: number[] | null = null;
  try { raw = await deps.embed(v, m.fact); } catch { /* optional — a write without an embedding is still a write */ }
  const embedding: string | null = raw ? vec(raw) : null;
  // Keyed kinds own their uniqueness: one row per setting key, one episode per conversation.
  if (m.kind === 'episode' && m.key) {
    const { data: existing } = await newestEpisode(v, m.key);
    if (existing) {
      const { data } = await v.db.from('user_memories').update({ fact: m.fact, confidence: m.confidence ?? 0.8, source: m.source ?? 'conversation', last_confirmed_at: new Date().toISOString(), embedding }).eq('id', existing.id).select('*').single();
      return toMemory(data);
    }
  } else if (m.kind !== 'setting' && raw) {
    const dupe = await nearIdentical(v, raw);
    if (dupe) {
      const { data } = await v.db.from('user_memories').update({ last_confirmed_at: new Date().toISOString(), confidence: Math.max(Number(dupe.confidence ?? 0.8), m.confidence ?? 0.8) }).eq('id', dupe.id).eq('user_id', v.userId).select('*').single();
      return toMemory(data ?? dupe);
    }
  }
  if (m.kind === 'setting' && m.key) {
    // one row per setting key (partial unique index user_memories_setting_key — select-then-update, never upsert on it)
    const { data: existing } = await v.db.from('user_memories').select('id').eq('user_id', v.userId).eq('kind', 'setting').eq('key', m.key).eq('is_deleted', false).maybeSingle();
    if (existing) {
      const { data } = await v.db.from('user_memories').update({ fact: m.fact, value: m.value ?? null, confidence: m.confidence ?? 1, source: m.source ?? 'settings', last_confirmed_at: new Date().toISOString(), embedding }).eq('id', existing.id).select('*').single();
      return toMemory(data);
    }
  }
  const { data, error } = await v.db.from('user_memories').insert({ user_id: v.userId, kind: m.kind, key: m.key ?? null, fact: m.fact, value: m.value ?? null, confidence: m.confidence ?? 0.8, source: m.source ?? 'conversation', embedding }).select('*').single();
  if (error) throw new Error(error.message);
  return toMemory(data);
}
/** The episode sentence for one conversation, or null. Keyed by conversation id so re-extraction
 *  cannot pile them up. Written once, when the client signals the conversation idle (mp-288); a conversation still in
 *  progress has none — its long history is summarised onto its own row instead (mp-277 clause 1). */
export async function episodeFor(v: VanaCtx, conversationId: string): Promise<string | null> {
  if (!conversationId) return null;
  const { data } = await newestEpisode(v, conversationId);
  return data?.fact ? String(data.fact) : null;
}
/** No index keeps an episode unique (select-then-insert, unlike settings), so two writers racing can
 *  leave two rows. Read the newest rather than `maybeSingle` alone, which errors on two: a duplicate
 *  must cost a spare row, never the episode. */
function newestEpisode(v: VanaCtx, conversationId: string) {
  return v.db.from('user_memories').select('id, fact').eq('user_id', v.userId).eq('kind', 'episode').eq('key', conversationId).eq('is_deleted', false)
    .order('last_confirmed_at', { ascending: false }).limit(1).maybeSingle();
}
export async function forgetMemory(v: VanaCtx, id: string) {
  await v.db.from('user_memories').update({ is_deleted: true }).eq('id', id).eq('user_id', v.userId);
  await invalidateContext(v);
}
export async function getSetting<T = unknown>(v: VanaCtx, key: string): Promise<T | null> {
  const { data } = await v.db.from('user_memories').select('value').eq('user_id', v.userId).eq('kind', 'setting').eq('key', key).eq('is_deleted', false).maybeSingle();
  return (data?.value ?? null) as T | null;
}
export type SettingKey = 'batch_cooking' | 'show_macros' | 'coverage_scope' | 'weekly_budget_usd' | 'pantry_items' | 'week_start' | 'period_days';
export type SettingValue = boolean | CoverageScope | number | string[] | DayKey;
export type CoverageScope = 'dinners' | 'dinners_lunches' | 'all';
export const COVERAGE_SCOPES: readonly CoverageScope[] = ['dinners', 'dinners_lunches', 'all'];
/** What a setting means when the athlete never chose it. show_macros defaults ON (plan §2 Q-4: "runners want to see
 *  numbers", 2026-09-03); coverage_scope has no default — "never chosen" is what makes the persona ask once. */
export const SETTING_DEFAULTS: { batch_cooking: boolean; show_macros: boolean; coverage_scope: CoverageScope | null; weekly_budget_usd: number | null; pantry_items: string[]; week_start: DayKey; period_days: number } = { batch_cooking: true, show_macros: true, coverage_scope: null, weekly_budget_usd: null, pantry_items: [], week_start: 'sun', period_days: 7 };
/** The range the period_days setting accepts (mp-269). Under three days the three cooking sessions would share a day; two weeks is
 *  the longest a batch holds. The Dart settings stepper uses the same bounds (domain/week_start.dart PlanPeriod). */
export const PERIOD_DAYS_MIN = 3;
export const PERIOD_DAYS_MAX = 14;
export const isDayKey = (x: unknown): x is DayKey => typeof x === 'string' && (DAY_KEYS as readonly string[]).includes(x);
export const isPeriodDays = (x: unknown): x is number => typeof x === 'number' && Number.isInteger(x) && x >= PERIOD_DAYS_MIN && x <= PERIOD_DAYS_MAX;
export interface PlanPeriod { weekStart: DayKey; periodDays: number }
/** The athlete's plan period (mp-269): start day and length, each falling back to its default when never set or out of contract. */
export async function getPlanPeriod(v: VanaCtx): Promise<PlanPeriod> {
  const [start, days] = await Promise.all([getSetting(v, 'week_start'), getSetting(v, 'period_days')]);
  return { weekStart: isDayKey(start) ? start : SETTING_DEFAULTS.week_start, periodDays: isPeriodDays(days) ? days : SETTING_DEFAULTS.period_days };
}
const DAY_NAMES: Record<DayKey, string> = { sun: 'Sunday', mon: 'Monday', tue: 'Tuesday', wed: 'Wednesday', thu: 'Thursday', fri: 'Friday', sat: 'Saturday' };
export const isCoverageScope = (x: unknown): x is CoverageScope => typeof x === 'string' && (COVERAGE_SCOPES as readonly string[]).includes(x);
/** The coverage scope the athlete chose, or null when never chosen (an unknown stored value reads as never chosen). */
export async function getCoverageScope(v: VanaCtx): Promise<CoverageScope | null> { const s = await getSetting(v, 'coverage_scope'); return isCoverageScope(s) ? s : null; }
/** What the athlete said is in the house (set_pantry / "Use these"); feeds the shopping list's `have`. Empty when never set. */
export async function getPantryItems(v: VanaCtx): Promise<string[]> { const x = await getSetting(v, 'pantry_items'); return Array.isArray(x) ? x.map(String).filter(Boolean) : []; }
export async function setSetting(v: VanaCtx, key: SettingKey, value: SettingValue, source = 'settings'): Promise<Memory> {
  const fact = key === 'batch_cooking' ? (value ? 'Cooks in batches (cook once, eat across the week)' : 'Cooks most nights — no batch cooking')
    : key === 'show_macros' ? (value ? 'Wants macro numbers shown by default' : 'Keeps macro numbers behind a tap')
    : key === 'weekly_budget_usd' ? `Keeps the weekly grocery budget around $${Math.round(Number(value))}`
    : key === 'pantry_items' ? `Has on hand: ${(value as string[]).join(', ')}`
    : key === 'week_start' ? `Starts the plan week on ${DAY_NAMES[value as DayKey] ?? String(value)}`
    : key === 'period_days' ? `Plans ${Number(value)} days at a time`
    : value === 'dinners' ? 'Plans dinners only' : value === 'dinners_lunches' ? 'Plans dinners and lunches' : 'Plans every meal of the week';
  return rememberFact(v, { kind: 'setting', key, value, fact, confidence: 1, source });
}
