/** Meal search + library access. ONE call to search_meals(): hard filters first, vector rank, saved + library together.
 *  Everything runs on the caller's client: meal_library is readable by `authenticated`, the rest is the athlete's own rows. */
import type { MealRef, MealType, MealContext, MealDetail, MealIngredient } from './contracts.ts';
import type { VanaCtx } from './env.ts';
import { embedText, vec } from './embeddings.ts';
import { resolveMealIcon } from './meal-icon.ts';

/** ≤40-char attribution label: the first named person/source before ' — ', ';', ' (' or a URL. Cards and the model only ever see this. */
export function attributionShort(full: string | null | undefined): string {
  if (!full) return '';
  let s = String(full).split(/\s+—\s+|;|\s+\(|https?:\/\//)[0].trim();
  s = s.replace(/^(reported|commonly reported|the|a)\s+/i, '').replace(/'s\s+(stated|reported|fixed|regular|race-day|daily|actual|pre-race|post-stage)\s.*$/i, '').replace(/\s+(stated|reported)\s.*$/i, '');
  if (s.length > 40) s = s.slice(0, 38).replace(/\s+\S*$/, '') + '…';
  return s;
}

// deno-lint-ignore no-explicit-any
export function rowToMealRef(r: any): MealRef {
  return {
    source: r.source, id: String(r.id), name: r.name, mealType: r.meal_type as MealType,
    contexts: (r.contexts ?? []) as MealContext[], batch: !!r.batch, prepMinutes: r.prep_minutes ?? null,
    kcal: r.kcal ?? null, carbsG: r.carbs_g == null ? null : Number(r.carbs_g), proteinG: r.protein_g == null ? null : Number(r.protein_g), fatG: r.fat_g == null ? null : Number(r.fat_g),
    allergens: r.allergens ?? [], dietsOk: r.diets_ok ?? [], swaps: r.swaps ?? null,
    why: r.why ?? '', attribution: r.attribution ?? r.source_text ?? '', attributionShort: r.attribution_short ?? attributionShort(r.attribution ?? r.source_text ?? ''), ingredients: r.ingredients ?? '',
    libraryMealId: r.library_meal_id ?? (r.source === 'library' ? String(r.id) : null), score: Number(r.score ?? 0),
    kind: r.kind === 'assembly' ? 'assembly' : r.kind === 'recipe' ? 'recipe' : undefined,
    pattern: r.pattern ?? null, frequency: r.frequency ?? null,
    icon: resolveMealIcon(r.icon, { name: r.name, ingredients: r.ingredients ?? null, pattern: r.pattern ?? null }),
    myVote: (r.my_vote ?? 0) as -1 | 0 | 1,
  };
}

export interface SearchOpts { query?: string; mealType?: MealType; contexts?: MealContext[]; batch?: boolean; includeSaved?: boolean; limit?: number; embed?: boolean; excludeAllergens?: string[]; requireDiet?: string; excludeIds?: string[]; kind?: 'assembly' | 'recipe' | null }
export async function searchMeals(v: VanaCtx, o: SearchOpts): Promise<MealRef[]> {
  let embedding: string | null = null;
  if (o.query && o.embed !== false) { try { embedding = vec(await embedText(v, o.query)); } catch { embedding = null; } }
  const ex = new Set((o.excludeIds ?? []).map(String));
  const limit = (o.limit ?? 12) + ex.size;
  const { data, error } = await v.db.rpc('search_meals', {
    p_user_id: v.userId, p_query: o.query ?? null, p_embedding: embedding, p_meal_type: o.mealType ?? null,
    p_contexts: o.contexts?.length ? o.contexts : null, p_batch: o.batch ?? null, p_include_saved: o.includeSaved ?? true, p_limit: limit,
    p_exclude_allergens: o.excludeAllergens?.length ? o.excludeAllergens : null, p_require_diet: o.requireDiet ?? null,
    p_kind: o.kind ?? null,
  });
  if (error) throw new Error(`search_meals: ${error.message}`);
  return (data ?? []).map(rowToMealRef).filter((m: MealRef) => !ex.has(m.id)).slice(0, o.limit ?? 12);
}

/** Fetch one meal by ref, shaped as a MealRef (no scoring). */
export async function getMeal(v: VanaCtx, source: 'library' | 'saved', id: string): Promise<MealRef | null> {
  if (source === 'library') {
    const { data } = await v.db.from('meal_library').select('*').eq('id', id).maybeSingle();
    if (!data) return null;
    return rowToMealRef({ ...data, source: 'library', attribution: data.source, score: 1, library_meal_id: data.id });
  }
  const { data } = await v.db.from('saved_meals').select('*, meal_library:library_meal_id(swaps, why)').eq('id', id).eq('user_id', v.userId).maybeSingle();
  if (!data) return null;
  const items = (data.items ?? []) as { name?: string; food_name?: string }[];
  return rowToMealRef({ source: 'saved', id: data.id, name: data.name, meal_type: data.meal_types?.[0] ?? 'dinner', contexts: [], batch: data.batch ?? false, prep_minutes: null,
    kcal: data.calories, carbs_g: data.carbs_g, protein_g: data.protein_g, fat_g: data.fat_g, allergens: [], diets_ok: [], swaps: data.meal_library?.swaps ?? null,
    why: data.meal_library?.why ?? 'one of your saved meals', attribution: 'your saved meal', ingredients: items.map((i) => i.name ?? i.food_name ?? '').filter(Boolean).join(', '), library_meal_id: data.library_meal_id, score: 1, icon: data.icon });
}

/** Library ingredient rows for the grocery builder. */
export async function libraryIngredients(v: VanaCtx, id: string): Promise<{ name: string; qty: string }[]> {
  const { data } = await v.db.from('meal_library').select('ingredients_json').eq('id', id).maybeSingle();
  return (data?.ingredients_json ?? []) as { name: string; qty: string }[];
}

/** "Save to mine": copy a library meal into saved_meals (name, items from ingredients_json, macros, link, meal type, icon).
 *  Idempotent per (user, library_meal_id) — a second save returns the existing row. Embedding is best-effort. */
export async function saveLibraryMeal(v: VanaCtx, libraryMealId: string): Promise<MealRef> {
  const { data: existing } = await v.db.from('saved_meals').select('id').eq('user_id', v.userId).eq('library_meal_id', libraryMealId).eq('is_deleted', false).limit(1).maybeSingle();
  if (existing) return (await getMeal(v, 'saved', existing.id))!;
  const { data: lib } = await v.db.from('meal_library').select('*').eq('id', libraryMealId).maybeSingle();
  if (!lib) throw new Error(`library meal not found: ${libraryMealId}`);
  const items = ((lib.ingredients_json ?? []) as { name: string; qty?: string; role?: string }[]).map((i) => ({ name: i.name, portion: i.qty ?? '', role: i.role ?? null }));
  let embedding: string | null = null;
  try { embedding = vec(await embedText(v, `${lib.meal_type}: ${lib.name}. Ingredients: ${lib.ingredients}`)); } catch { embedding = null; }
  const { data, error } = await v.db.from('saved_meals').insert({ user_id: v.userId, name: lib.name, items, calories: lib.kcal, carbs_g: lib.carbs_g, protein_g: lib.protein_g, fat_g: lib.fat_g, library_meal_id: lib.id, meal_types: [lib.meal_type], batch: lib.batch, icon: lib.icon ?? null, last_used_at: new Date().toISOString(), ...(embedding ? { embedding } : {}) }).select('id').single();
  if (error) throw new Error(error.message);
  return (await getMeal(v, 'saved', data.id))!;
}

// ---------------------------------------------------------------- detail / recents / notes / feedback
const isUuid = (id: string) => /^[0-9a-f-]{36}$/i.test(id);
// deno-lint-ignore no-explicit-any
const directionsOf = (r: any): MealDetail['directions'] => ({ origin: (r?.directions_origin ?? null) as MealDetail['directions']['origin'], sourceUrl: r?.directions_source_url ?? null, sourceName: r?.directions_source_name ?? null, verbatim: !!r?.directions_verbatim });
// deno-lint-ignore no-explicit-any
const imageOf = (r: any): MealDetail['image'] => (r?.image_url ? { url: r.image_url, license: r.image_license ?? null, creator: r.image_creator ?? null, credit: r.image_credit ?? null, sourceUrl: r.image_source_url ?? null } : null);
const splitSwaps = (s: unknown) => String(s ?? '').split(';').map((x) => x.trim()).filter(Boolean);
/** The user's thumb on a meal (0 = none). */
export async function myVote(v: VanaCtx, target: { libraryMealId?: string | null; savedMealId?: string | null }): Promise<-1 | 0 | 1> {
  let q = v.db.from('meal_feedback').select('vote').eq('user_id', v.userId);
  q = target.libraryMealId ? q.eq('library_meal_id', target.libraryMealId) : q.eq('saved_meal_id', target.savedMealId!);
  const { data } = await q.maybeSingle();
  return ((data?.vote as number | undefined) ?? 0) as -1 | 0 | 1;
}
/** get_meal: a library id ('D-048') or a saved_meals uuid → MealDetail. A saved meal linked to a recipe inherits that recipe's
 *  method/media; an unlinked one is assembly-style (no method). Null when not found / not the caller's. */
export async function getMealDetail(v: VanaCtx, id: string): Promise<MealDetail | null> {
  if (!isUuid(id)) {
    const { data: r } = await v.db.from('meal_library').select('*').eq('id', id).maybeSingle();
    if (!r) return null;
    return { meal: rowToMealRef({ ...r, source: 'library', attribution: r.source, score: 1, library_meal_id: r.id }), ingredients: (r.ingredients_json ?? []) as MealIngredient[], methodSteps: (r.method_steps ?? []) as string[], directions: directionsOf(r), image: imageOf(r), sourceUrl: r.source_url ?? null, source: r.source ?? '', swaps: splitSwaps(r.swaps), prep: r.prep ?? null, servings: r.servings ?? 1, notes: null, vote: await myVote(v, { libraryMealId: r.id }) };
  }
  const { data: s } = await v.db.from('saved_meals').select('*').eq('id', id).eq('user_id', v.userId).eq('is_deleted', false).maybeSingle();
  if (!s) return null;
  const { data: r } = s.library_meal_id ? await v.db.from('meal_library').select('*').eq('id', s.library_meal_id).maybeSingle() : { data: null };
  const items = (s.items ?? []) as { name?: string; food_name?: string; quantity?: string; serving?: string; portion?: string; role?: string | null }[];
  return {
    meal: rowToMealRef({ source: 'saved', id: s.id, name: s.name, meal_type: s.meal_types?.[0] ?? r?.meal_type ?? 'dinner', contexts: r?.contexts ?? [], batch: s.batch ?? r?.batch ?? false, prep_minutes: r?.prep_minutes ?? null, kcal: s.calories, carbs_g: s.carbs_g, protein_g: s.protein_g, fat_g: s.fat_g, allergens: r?.allergens ?? [], diets_ok: r?.diets_ok ?? [], swaps: r?.swaps ?? null, why: r?.why ?? 'one of your saved meals', attribution: 'your saved meal', ingredients: items.map((i) => i.name ?? i.food_name ?? '').filter(Boolean).join(', '), library_meal_id: s.library_meal_id, score: 1, kind: r?.kind, pattern: r?.pattern, icon: s.icon }),
    ingredients: items.map((i) => ({ name: i.name ?? i.food_name ?? '', qty: i.quantity ?? i.serving ?? i.portion ?? '', role: i.role ?? null })),
    methodSteps: (r?.method_steps ?? []) as string[], directions: directionsOf(r), image: imageOf(r), sourceUrl: r?.source_url ?? null, source: '',
    swaps: splitSwaps(r?.swaps), prep: r?.prep ?? null, servings: r?.servings ?? 1, notes: (s.notes ?? null) as string | null, vote: await myVote(v, { savedMealId: s.id }),
  };
}
/** recent_meals: meals logged OR planned, most recent first. search_meals ranks by score only, so this walks meal_logs + plan_meals,
 *  merges by recency, then resolves the rows in bulk. */
export async function recentMeals(v: VanaCtx, limit = 20): Promise<(MealRef & { lastUsedAt: string })[]> {
  const d = v.db;
  const [{ data: logs }, { data: planned }] = await Promise.all([
    d.from('meal_logs').select('name, saved_meal_id, plan_meal_id, eaten_at, log_date, created_at').eq('user_id', v.userId).eq('is_deleted', false).order('created_at', { ascending: false }).limit(200),
    d.from('plan_meals').select('library_meal_id, saved_meal_id, name, created_at').eq('user_id', v.userId).order('created_at', { ascending: false }).limit(200),
  ]);
  const recent = new Map<string, string>();   // saved:<uuid> | lib:<id> → most recent touch
  const touch = (key: string, at: string | null | undefined) => { const prev = recent.get(key); if (!prev || !at || at > prev) recent.set(key, at ?? prev ?? ''); };
  const savedIds = new Set<string>(); const libIds = new Set<string>(); const namesOnly: { name: string; at: string }[] = [];
  for (const l of logs ?? []) { const at = (l.eaten_at ?? l.created_at ?? l.log_date) as string | null; if (l.saved_meal_id) { savedIds.add(l.saved_meal_id); touch(`saved:${l.saved_meal_id}`, at); } else namesOnly.push({ name: String(l.name).trim(), at: at ?? '' }); }
  for (const p of planned ?? []) { const at = (p.created_at ?? '') as string; if (p.saved_meal_id) { savedIds.add(p.saved_meal_id); touch(`saved:${p.saved_meal_id}`, at); } else if (p.library_meal_id) { libIds.add(p.library_meal_id); touch(`lib:${p.library_meal_id}`, at); } else namesOnly.push({ name: String(p.name).trim(), at }); }
  const out: (MealRef & { lastUsedAt: string })[] = [];
  const [{ data: savedRows }, { data: libRows }] = await Promise.all([
    // deno-lint-ignore no-explicit-any
    savedIds.size ? d.from('saved_meals').select('*').in('id', [...savedIds]).eq('user_id', v.userId).eq('is_deleted', false) : Promise.resolve({ data: [] as any[] }),
    // deno-lint-ignore no-explicit-any
    libIds.size ? d.from('meal_library').select('*').in('id', [...libIds]).eq('is_active', true) : Promise.resolve({ data: [] as any[] }),
  ]);
  for (const s of savedRows ?? []) out.push({ ...rowToMealRef({ source: 'saved', id: s.id, name: s.name, meal_type: s.meal_types?.[0] ?? 'dinner', kcal: s.calories, carbs_g: s.carbs_g, protein_g: s.protein_g, fat_g: s.fat_g, library_meal_id: s.library_meal_id, icon: s.icon, batch: s.batch, ingredients: ((s.items ?? []) as { name?: string }[]).map((i) => i.name).filter(Boolean).join(', '), why: 'one of your meals', attribution: 'your saved meal', score: 1 }), lastUsedAt: recent.get(`saved:${s.id}`) ?? '' });
  for (const r of libRows ?? []) out.push({ ...rowToMealRef({ ...r, source: 'library', attribution: r.source, score: 1, library_meal_id: r.id }), lastUsedAt: recent.get(`lib:${r.id}`) ?? '' });
  // log/plan rows with no link: an exact-ish library name match, else dropped silently
  for (const n of namesOnly.slice(0, 30)) {
    if (!n.name || out.some((m) => m.name.toLowerCase() === n.name.toLowerCase())) continue;
    const { data: r } = await d.from('meal_library').select('*').ilike('name', n.name).eq('is_active', true).limit(1);
    if (r?.[0]) out.push({ ...rowToMealRef({ ...r[0], source: 'library', attribution: r[0].source, score: 1, library_meal_id: r[0].id }), lastUsedAt: n.at });
  }
  return out.sort((a, b) => (b.lastUsedAt ?? '').localeCompare(a.lastUsedAt ?? '')).slice(0, limit);
}
/** set_saved_meal_notes: the athlete's own directions on a saved meal (≤2000 chars). */
export async function setSavedMealNotes(v: VanaCtx, savedMealId: string, notes: string): Promise<{ ok: boolean; notes: string; error?: string }> {
  const clean = notes.slice(0, 2000);
  const { error } = await v.db.from('saved_meals').update({ notes: clean, updated_at: new Date().toISOString() }).eq('id', savedMealId).eq('user_id', v.userId);
  return error ? { ok: false, notes: clean, error: error.message } : { ok: true, notes: clean };
}
export interface FeedbackTarget { libraryMealId?: string | null; savedMealId?: string | null }
/** set_meal_feedback: thumbs up / down; the same vote again clears it; vote 0 clears outright. Returns the resulting vote.
 *  Always the set_meal_feedback() RPC (security invoker, auth.uid()) — the meal_feedback uniques are PARTIAL indexes, so a
 *  PostgREST upsert on them would fail with 42P10. */
export async function setMealFeedback(v: VanaCtx, target: FeedbackTarget, vote: -1 | 0 | 1, reason?: string | null): Promise<-1 | 0 | 1> {
  const lib = target.libraryMealId ?? null; const saved = target.savedMealId ?? null;
  if ((lib ? 1 : 0) + (saved ? 1 : 0) !== 1) throw new Error('pass exactly one of libraryMealId / savedMealId');
  const { data, error } = await v.db.rpc('set_meal_feedback', { p_library_meal_id: lib, p_saved_meal_id: saved, p_vote: vote, p_reason: reason ?? null });
  if (error) throw new Error(error.message);
  return ((data as number | null) ?? 0) as -1 | 0 | 1;
}
