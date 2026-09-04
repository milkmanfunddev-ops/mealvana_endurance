/** user_memories — what Vana knows. Settings are memories with kind='setting' + key. All through the caller's client (RLS). */
import type { Memory } from './contracts.ts';
import type { VanaCtx } from './env.ts';
import { embedText, vec } from './embeddings.ts';

// deno-lint-ignore no-explicit-any
const toMemory = (r: any): Memory => ({ id: r.id, kind: r.kind, key: r.key ?? null, fact: r.fact, value: r.value ?? null, confidence: Number(r.confidence ?? 0.8), lastConfirmedAt: r.last_confirmed_at, source: r.source ?? null });

export async function listMemories(v: VanaCtx, limit = 50): Promise<Memory[]> {
  const { data } = await v.db.from('user_memories').select('*').eq('user_id', v.userId).eq('is_deleted', false).order('last_confirmed_at', { ascending: false }).limit(limit);
  return (data ?? []).map(toMemory);
}
export async function recallMemories(v: VanaCtx, text: string, limit = 8): Promise<Memory[]> {
  try {
    const e = vec(await embedText(v, text));
    const { data } = await v.db.rpc('recall_memories', { p_user_id: v.userId, p_embedding: e, p_limit: limit });
    return (data ?? []).map(toMemory);
  } catch { return listMemories(v, limit); }
}
export async function rememberFact(v: VanaCtx, m: { kind: Memory['kind']; fact: string; key?: string | null; value?: unknown; confidence?: number; source?: string }): Promise<Memory> {
  let embedding: string | null = null; try { embedding = vec(await embedText(v, m.fact)); } catch { /* optional */ }
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
export async function forgetMemory(v: VanaCtx, id: string) {
  await v.db.from('user_memories').update({ is_deleted: true }).eq('id', id).eq('user_id', v.userId);
}
export async function getSetting<T = unknown>(v: VanaCtx, key: string): Promise<T | null> {
  const { data } = await v.db.from('user_memories').select('value').eq('user_id', v.userId).eq('kind', 'setting').eq('key', key).eq('is_deleted', false).maybeSingle();
  return (data?.value ?? null) as T | null;
}
export type SettingKey = 'batch_cooking' | 'show_macros' | 'coverage_scope' | 'weekly_budget_usd' | 'pantry_items';
export type SettingValue = boolean | CoverageScope | number | string[];
export type CoverageScope = 'dinners' | 'dinners_lunches' | 'all';
export const COVERAGE_SCOPES: readonly CoverageScope[] = ['dinners', 'dinners_lunches', 'all'];
/** What a setting means when the athlete never chose it. show_macros defaults ON (plan §2 Q-4: "runners want to see
 *  numbers", 2026-09-03); coverage_scope has no default — "never chosen" is what makes the persona ask once. */
export const SETTING_DEFAULTS: { batch_cooking: boolean; show_macros: boolean; coverage_scope: CoverageScope | null; weekly_budget_usd: number | null; pantry_items: string[] } = { batch_cooking: true, show_macros: true, coverage_scope: null, weekly_budget_usd: null, pantry_items: [] };
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
    : value === 'dinners' ? 'Plans dinners only' : value === 'dinners_lunches' ? 'Plans dinners and lunches' : 'Plans every meal of the week';
  return rememberFact(v, { kind: 'setting', key, value, fact, confidence: 1, source });
}
