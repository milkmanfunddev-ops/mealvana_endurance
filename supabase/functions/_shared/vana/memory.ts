/** user_memories — what Vana knows. Settings are memories with kind='setting' + key. All through the caller's client (RLS). */
import type { Memory } from './contracts.ts';
import type { VanaCtx } from './env.ts';
import { embedText, vec } from './embeddings.ts';

// deno-lint-ignore no-explicit-any
const toMemory = (r: any): Memory => ({ id: r.id, kind: r.kind, key: r.key ?? null, fact: r.fact, value: r.value ?? null, confidence: Number(r.confidence ?? 0.8), lastConfirmedAt: r.last_confirmed_at });

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
export async function setSetting(v: VanaCtx, key: 'batch_cooking' | 'show_macros', value: boolean, source = 'settings'): Promise<Memory> {
  const fact = key === 'batch_cooking' ? (value ? 'Cooks in batches (cook once, eat across the week)' : 'Cooks most nights — no batch cooking') : (value ? 'Wants macro numbers shown by default' : 'Keeps macro numbers behind a tap');
  return rememberFact(v, { kind: 'setting', key, value, fact, confidence: 1, source });
}
