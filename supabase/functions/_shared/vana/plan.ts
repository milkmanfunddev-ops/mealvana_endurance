/** meal_plans + plan_meals — the batch. Coverage and sessions are computed here, never by the model.
 *
 *  Plan resolution (2026-08-31): one CONFIRMED plan per athlete-week (partial unique index `meal_plans_confirmed_week`);
 *  any number of DRAFTS, each owned by the Vana conversation building it (`meal_plans.conversation_id`).
 *  - `getPlan(v)` → the week's ACTIVE plan for athlete-facing surfaces (Plan tab, shopping, context): confirmed first, else the newest draft.
 *  - `resolvePlan(v, scope)` → the plan a write should land on: an explicit planId, else the conversation's own draft
 *    (created on first use), else the week's active plan. Edits keyed by planMealId derive the plan from the row.
 *
 *  Remote-ack writes (`confirmPlan`, `logFromPlan`) go through the SQL functions in
 *  supabase/migrations/20260902090000_meal_planning_rpcs.sql so one transaction does the whole thing and the Dart repos
 *  can replay the same RPCs offline-first. Every other edit is a plain RLS-scoped row update. */
import type { MealPlan, PlanMeal, PlanRule, ShoppingItem, MealRef, Session, DayPlan, DaySlot, DaySlotRef } from './contracts.ts';
import type { VanaCtx } from './env.ts';
import { weekStartFor, today } from './env.ts';
import { getMeal } from './meals.ts';
import { getSetting, getCoverageScope, getPantryItems } from './memory.ts';
import { buildShoppingList } from './grocery.ts';
import { resolveMealIcon } from './meal-icon.ts';
import { coverageOf, defaultSession } from './plan-math.ts';

export interface PlanScope { planId?: string | null; conversationId?: string | null }

// deno-lint-ignore no-explicit-any
const toPlanMeal = (r: any): PlanMeal => ({ id: r.id, planId: r.plan_id, source: r.source, libraryMealId: r.library_meal_id ?? null, savedMealId: r.saved_meal_id ?? null, name: r.name, mealType: r.meal_type, session: (r.session ?? null) as Session, servings: r.servings, servingsLeft: r.servings_left, kcal: r.kcal ?? null, carbsG: r.carbs_g == null ? null : Number(r.carbs_g), proteinG: r.protein_g == null ? null : Number(r.protein_g), fatG: r.fat_g == null ? null : Number(r.fat_g), swapsApplied: r.swaps_applied ?? [], comments: r.comments ?? [], position: r.position ?? 0, icon: resolveMealIcon(r.icon, { name: r.name }) });

export { coverageOf, defaultSession };

// ---------------------------------------------------------------- resolution
/** The week's active plan: confirmed if there is one, else the most recently edited draft. */
export async function getPlan(v: VanaCtx, weekStart = weekStartFor(today())): Promise<MealPlan | null> {
  const { data } = await v.db.from('meal_plans').select('*').eq('user_id', v.userId).eq('week_start', weekStart).eq('is_deleted', false).neq('status', 'archived')
    .order('status', { ascending: true }) // 'confirmed' sorts before 'draft'
    .order('updated_at', { ascending: false }).limit(1).maybeSingle();
  return data ? hydrate(v, data) : null;
}
export async function getOrCreatePlan(v: VanaCtx, weekStart = weekStartFor(today())): Promise<MealPlan> {
  const cur = await getPlan(v, weekStart);
  return cur ?? insertDraft(v, weekStart, null);
}
/** The draft owned by a conversation — created on first use so the plan bar starts empty. */
export async function getConversationPlan(v: VanaCtx, conversationId: string, create = true): Promise<MealPlan | null> {
  const { data } = await v.db.from('meal_plans').select('*').eq('user_id', v.userId).eq('conversation_id', conversationId).eq('is_deleted', false).order('created_at', { ascending: false }).limit(1).maybeSingle();
  if (data) return hydrate(v, data);
  return create ? insertDraft(v, weekStartFor(today()), conversationId) : null;
}
export async function resolvePlan(v: VanaCtx, scope?: PlanScope | null, create = true): Promise<MealPlan | null> {
  if (scope?.planId) return getPlanById(v, scope.planId);
  if (scope?.conversationId) return getConversationPlan(v, scope.conversationId, create);
  return create ? getOrCreatePlan(v) : getPlan(v);
}
async function insertDraft(v: VanaCtx, weekStart: string, conversationId: string | null): Promise<MealPlan> {
  const batchCooking = (await getSetting<boolean>(v, 'batch_cooking')) ?? true;
  const { data, error } = await v.db.from('meal_plans').insert({ user_id: v.userId, week_start: weekStart, batch_cooking: batchCooking, conversation_id: conversationId }).select('*').single();
  if (error) throw new Error(error.message);
  return hydrate(v, data);
}
/** plan_meals row → its plan id (edits keyed by planMealId never need a scope). */
async function planIdOfMeal(v: VanaCtx, planMealId: string): Promise<string> {
  const { data } = await v.db.from('plan_meals').select('plan_id').eq('id', planMealId).eq('user_id', v.userId).maybeSingle();
  if (!data) throw new Error('plan meal not found');
  return data.plan_id as string;
}
// deno-lint-ignore no-explicit-any
async function hydrate(v: VanaCtx, plan: any): Promise<MealPlan> {
  const [{ data: rows }, coverageScope] = await Promise.all([v.db.from('plan_meals').select('*').eq('plan_id', plan.id).order('position').order('created_at'), getCoverageScope(v)]);
  const meals = (rows ?? []).map(toPlanMeal);
  return { id: plan.id, weekStart: plan.week_start, status: plan.status, batchCooking: plan.batch_cooking, conversationId: plan.conversation_id ?? null, brief: plan.brief ?? null, days: (plan.days ?? {}) as Record<string, DayPlan>, rules: (plan.rules ?? []) as PlanRule[], meals, shopping: (plan.shopping ?? []) as ShoppingItem[], coverage: coverageOf(meals, coverageScope), dayNotes: (plan.day_notes ?? {}) as Record<string, string>, dayNotesStale: plan.day_notes_stale !== false };
}

// ---------------------------------------------------------------- edits
export async function addMeal(v: VanaCtx, ref: MealRef, servings: number, session?: Session, scope?: PlanScope | null): Promise<MealPlan> {
  const plan = (await resolvePlan(v, scope, true))!;
  const existing = plan.meals.find((m) => (ref.source === 'library' ? m.libraryMealId === ref.id : m.savedMealId === ref.id));
  if (existing) {
    await v.db.from('plan_meals').update({ servings: existing.servings + servings, servings_left: existing.servingsLeft + servings, updated_at: new Date().toISOString() }).eq('id', existing.id);
  } else {
    const s = session === undefined ? defaultSession(plan.batchCooking, ref, plan.meals) : session;
    const { error } = await v.db.from('plan_meals').insert({ plan_id: plan.id, user_id: v.userId, source: ref.source, library_meal_id: ref.source === 'library' ? ref.id : null, saved_meal_id: ref.source === 'saved' ? ref.id : null, name: ref.name, meal_type: ref.mealType, session: s, servings, servings_left: servings, kcal: ref.kcal, carbs_g: ref.carbsG, protein_g: ref.proteinG, fat_g: ref.fatG, position: plan.meals.length, icon: ref.icon ?? null });
    if (error) throw new Error(error.message);
  }
  return refreshShopping(v, plan.id);
}
export async function addMealById(v: VanaCtx, source: 'library' | 'saved', id: string, servings: number, session?: Session, scope?: PlanScope | null) {
  const ref = await getMeal(v, source, id); if (!ref) throw new Error(`meal not found: ${source}/${id}`);
  return addMeal(v, ref, servings, session, scope);
}
export async function setServings(v: VanaCtx, planMealId: string, servings: number): Promise<MealPlan> {
  const planId = await planIdOfMeal(v, planMealId);
  if (servings <= 0) await v.db.from('plan_meals').delete().eq('id', planMealId).eq('user_id', v.userId);
  else { const { data: cur } = await v.db.from('plan_meals').select('servings, servings_left').eq('id', planMealId).eq('user_id', v.userId).maybeSingle(); const eaten = cur ? cur.servings - cur.servings_left : 0; await v.db.from('plan_meals').update({ servings, servings_left: Math.max(0, servings - eaten), updated_at: new Date().toISOString() }).eq('id', planMealId).eq('user_id', v.userId); }
  return refreshShopping(v, planId);
}
export async function setSession(v: VanaCtx, planMealId: string, session: Session): Promise<MealPlan> {
  const planId = await planIdOfMeal(v, planMealId);
  await v.db.from('plan_meals').update({ session }).eq('id', planMealId).eq('user_id', v.userId);
  return (await getPlanById(v, planId))!;
}
export async function applySwap(v: VanaCtx, planMealId: string, swap: { from: string; to: string; effect?: string }): Promise<MealPlan> {
  const { data: cur } = await v.db.from('plan_meals').select('plan_id, swaps_applied, name').eq('id', planMealId).eq('user_id', v.userId).maybeSingle();
  if (!cur) throw new Error('plan meal not found');
  const swaps = [...((cur.swaps_applied ?? []) as unknown[]), swap];
  await v.db.from('plan_meals').update({ swaps_applied: swaps, updated_at: new Date().toISOString() }).eq('id', planMealId);
  return refreshShopping(v, cur.plan_id);
}
export async function addComment(v: VanaCtx, planMealId: string, role: 'user' | 'vana', text: string): Promise<MealPlan> {
  const { data: cur } = await v.db.from('plan_meals').select('plan_id, comments').eq('id', planMealId).eq('user_id', v.userId).maybeSingle();
  if (!cur) throw new Error('plan meal not found');
  await v.db.from('plan_meals').update({ comments: [...((cur.comments ?? []) as unknown[]), { role, text, at: new Date().toISOString() }] }).eq('id', planMealId);
  return (await getPlanById(v, cur.plan_id))!;
}
export async function setRule(v: VanaCtx, rule: PlanRule, scope?: PlanScope | null): Promise<MealPlan> {
  const plan = (await resolvePlan(v, scope, true))!;
  const rules = plan.rules.filter((r) => !(r.day === rule.day && r.rule === rule.rule)).concat(rule);
  await v.db.from('meal_plans').update({ rules, updated_at: new Date().toISOString() }).eq('id', plan.id);
  return (await getPlanById(v, plan.id))!;
}
export async function setBatchCooking(v: VanaCtx, on: boolean, scope?: PlanScope | null): Promise<MealPlan> {
  const plan = (await resolvePlan(v, scope, true))!;
  await v.db.from('meal_plans').update({ batch_cooking: on, updated_at: new Date().toISOString() }).eq('id', plan.id);
  // re-derive sessions
  let sunday = 0;
  for (const m of plan.meals) {
    const ref = { batch: m.source === 'library' ? (await getMeal(v, 'library', m.libraryMealId!))?.batch ?? true : true };
    let s: Session = null;
    if (on) { if (!ref.batch) s = 'fresh-fri'; else { s = sunday >= 2 ? 'topup-wed' : 'cook-sun'; sunday++; } }
    await v.db.from('plan_meals').update({ session: s }).eq('id', m.id);
  }
  return (await getPlanById(v, plan.id))!;
}
export async function setBrief(v: VanaCtx, brief: string, scope?: PlanScope | null) { const p = (await resolvePlan(v, scope, true))!; await v.db.from('meal_plans').update({ brief }).eq('id', p.id); }
/** Confirm: the shopping list is built here (TS grocery aggregation), then ONE SQL transaction — `confirm_meal_plan` —
 *  stores it, flips status → confirmed and archives every other non-archived plan for the same athlete-week. The
 *  client gets its remote ack from that single call. */
export async function confirmPlan(v: VanaCtx, scope?: PlanScope | null): Promise<MealPlan> {
  const target = (await resolvePlan(v, scope, true))!;
  const plan = await refreshShopping(v, target.id);
  const { data, error } = await v.db.rpc('confirm_meal_plan', { p_plan_id: plan.id, p_shopping: plan.shopping });
  if (error) throw new Error(`confirm_meal_plan: ${error.message}`);
  if (!data) throw new Error('confirm_meal_plan returned nothing');
  return hydrate(v, Array.isArray(data) ? data[0] : data);
}
export async function refreshShopping(v: VanaCtx, planId?: string | null): Promise<MealPlan> {
  const plan = (planId ? await getPlanById(v, planId) : await getPlan(v))!;
  const prev = new Map(plan.shopping.map((i) => [i.name.toLowerCase(), i]));
  const items = await buildShoppingList(v, plan, await getPantryItems(v));
  const merged = items.map((i) => { const p = prev.get(i.name.toLowerCase()); return p ? { ...i, checked: p.checked, have: i.have || p.have } : i; });
  await v.db.from('meal_plans').update({ shopping: merged, day_notes_stale: true, updated_at: new Date().toISOString() }).eq('id', plan.id);
  return { ...plan, shopping: merged, dayNotesStale: true };
}
export async function toggleShopping(v: VanaCtx, name: string, field: 'checked' | 'have', value: boolean): Promise<ShoppingItem[]> {
  const plan = (await getPlan(v))!;
  const shopping = plan.shopping.map((i) => (i.name.toLowerCase() === name.toLowerCase() ? { ...i, [field]: value } : i));
  await v.db.from('meal_plans').update({ shopping }).eq('id', plan.id);
  return shopping;
}
/** "Ate it": the `plan_log_from_plan` SQL function decrements servings_left and writes the meal_logs row (source='plan',
 *  plan_meal_id set, per-serving macros) in one transaction. */
export async function logFromPlan(v: VanaCtx, planMealId: string, mealType?: string, logDate = today()): Promise<{ name: string; servingsLeft: number; logId: string }> {
  const { data: logId, error } = await v.db.rpc('plan_log_from_plan', { p_plan_meal_id: planMealId, p_meal_type: mealType ?? null, p_log_date: logDate });
  if (error) throw new Error(`plan_log_from_plan: ${error.message}`);
  const { data: m } = await v.db.from('plan_meals').select('name, servings_left').eq('id', planMealId).eq('user_id', v.userId).maybeSingle();
  if (!m) throw new Error('plan meal not found');
  return { name: m.name, servingsLeft: m.servings_left, logId: String(logId) };
}

/** Find a plan meal by its source ref (library id or saved id). */
export async function findPlanMeal(v: VanaCtx, source: 'library' | 'saved', id: string, scope?: PlanScope | null): Promise<PlanMeal | null> {
  const p = await resolvePlan(v, scope, false); if (!p) return null;
  return p.meals.find((m) => (source === 'library' ? m.libraryMealId === id : m.savedMealId === id)) ?? null;
}
/** Untick in the picker: remove the meal that this ref added. */
export async function removeMealByRef(v: VanaCtx, source: 'library' | 'saved', id: string, scope?: PlanScope | null): Promise<MealPlan> {
  const m = await findPlanMeal(v, source, id, scope);
  return m ? setServings(v, m.id, 0) : (await resolvePlan(v, scope, true))!;
}
/** Swap in place: same servings, session and position; new meal's name/macros/source. */
export async function swapMeal(v: VanaCtx, planMealId: string, source: 'library' | 'saved', id: string): Promise<MealPlan> {
  const { data: cur } = await v.db.from('plan_meals').select('*').eq('id', planMealId).eq('user_id', v.userId).maybeSingle();
  if (!cur) throw new Error('plan meal not found');
  const ref = await getMeal(v, source, id); if (!ref) throw new Error(`meal not found: ${source}/${id}`);
  const eaten = cur.servings - cur.servings_left;
  await v.db.from('plan_meals').update({ source: ref.source, library_meal_id: ref.source === 'library' ? ref.id : null, saved_meal_id: ref.source === 'saved' ? ref.id : null, name: ref.name, meal_type: ref.mealType, kcal: ref.kcal, carbs_g: ref.carbsG, protein_g: ref.proteinG, fat_g: ref.fatG, icon: ref.icon ?? null, servings_left: Math.max(0, cur.servings - eaten), swaps_applied: [], comments: [...((cur.comments ?? []) as unknown[]), { role: 'vana', text: `Swapped ${cur.name} → ${ref.name}`, at: new Date().toISOString() }], updated_at: new Date().toISOString() }).eq('id', planMealId);
  return refreshShopping(v, cur.plan_id);
}

// ---------------------------------------------------------------- history / new plan
export async function getPlanById(v: VanaCtx, id: string): Promise<MealPlan | null> {
  const { data } = await v.db.from('meal_plans').select('*').eq('id', id).eq('user_id', v.userId).eq('is_deleted', false).maybeSingle();
  return data ? hydrate(v, data) : null;
}
export async function listPlans(v: VanaCtx, limit = 20): Promise<(Pick<MealPlan, 'id' | 'weekStart' | 'status' | 'batchCooking'> & { mealCount: number })[]> {
  const { data } = await v.db.from('meal_plans').select('id, week_start, status, batch_cooking, updated_at').eq('user_id', v.userId).eq('is_deleted', false).order('week_start', { ascending: false }).order('updated_at', { ascending: false }).limit(limit);
  const out = [] as (Pick<MealPlan, 'id' | 'weekStart' | 'status' | 'batchCooking'> & { mealCount: number })[];
  for (const p of data ?? []) { const { count } = await v.db.from('plan_meals').select('*', { count: 'exact', head: true }).eq('plan_id', p.id); out.push({ id: p.id, weekStart: p.week_start, status: p.status, batchCooking: !!p.batch_cooking, mealCount: count ?? 0 }); }
  return out;
}
/** `new_plan`: archive the plan the scope resolves to (a conversation's draft, an explicit plan, or the week's active
 *  plan) and start a fresh, empty draft in its place — same conversation ownership as the one archived. */
export async function newPlan(v: VanaCtx, scope?: PlanScope | null): Promise<MealPlan> {
  const cur = await resolvePlan(v, scope, false);
  if (cur) await v.db.from('meal_plans').update({ status: 'archived', updated_at: new Date().toISOString() }).eq('id', cur.id);
  const conversationId = scope?.conversationId ?? cur?.conversationId ?? null;
  return insertDraft(v, cur?.weekStart ?? weekStartFor(today()), conversationId);
}

// ---------------------------------------------------------------- day planner (meal_plans.days jsonb)
const SLOTS: DaySlot[] = ['breakfast', 'lunch', 'dinner', 'snack'];
export async function getDay(v: VanaCtx, date: string): Promise<DayPlan> { const p = await getPlan(v); return (p?.days?.[date] ?? {}) as DayPlan; }
export async function setDaySlot(v: VanaCtx, date: string, slot: DaySlot, ref: DaySlotRef | null): Promise<DayPlan> {
  const p = await getOrCreatePlan(v);
  const days = { ...(p.days ?? {}) }; const day = { ...(days[date] ?? {}) }; if (ref) day[slot] = ref; else delete day[slot]; days[date] = day;
  await v.db.from('meal_plans').update({ days, updated_at: new Date().toISOString() }).eq('id', p.id);
  return day;
}
/** Fill the empty slots of a day: plan meals by meal type first (fewest servings used first), else a library pick by context. */
export async function planDay(v: VanaCtx, date: string, pickLibrary: (mealType: DaySlot) => Promise<MealRef | null>): Promise<{ slots: DayPlan; filled: DaySlot[] }> {
  const p = await getOrCreatePlan(v);
  const day = { ...((p.days ?? {})[date] ?? {}) } as DayPlan; const filled: DaySlot[] = [];
  const usedPlan = new Set(Object.values(day).map((r) => r?.id));
  for (const slot of SLOTS) {
    if (day[slot]) continue;
    const cands = p.meals.filter((m) => m.mealType === slot && m.servingsLeft > 0 && !usedPlan.has(m.id)).sort((a, b) => b.servingsLeft - a.servingsLeft);
    if (cands[0]) { day[slot] = { source: 'plan', id: cands[0].id, name: cands[0].name, kcal: cands[0].kcal, carbsG: cands[0].carbsG }; usedPlan.add(cands[0].id); filled.push(slot); continue; }
    const lib = await pickLibrary(slot); if (lib) { day[slot] = { source: lib.source === 'saved' ? 'saved' : 'library', id: lib.id, name: lib.name, kcal: lib.kcal, carbsG: lib.carbsG }; filled.push(slot); }
  }
  const days = { ...(p.days ?? {}), [date]: day };
  await v.db.from('meal_plans').update({ days, updated_at: new Date().toISOString() }).eq('id', p.id);
  return { slots: day, filled };
}

// ---------------------------------------------------------------- additive 2026-09-03 (plan Phases 6, 8)
/** The draft's meals as a replayable list — stored on every assistant turn (vana_messages.metadata.plan_snapshot) so
 *  an edit-rewind can put the draft back to its state at that message (plan Phase 6.1). */
export type MealSnapshot = { source: 'library' | 'saved'; id: string; servings: number; session: Session }[];
export async function snapshotPlan(v: VanaCtx, scope?: PlanScope | null): Promise<MealSnapshot> {
  const p = await resolvePlan(v, scope, false);
  return (p?.meals ?? []).map((m) => ({ source: m.source, id: (m.source === 'library' ? m.libraryMealId : m.savedMealId) ?? '', servings: m.servings, session: m.session })).filter((m) => m.id);
}
/** Replace the draft's meals with a snapshot (empty snapshot = empty draft). Sessions are kept as snapshotted. */
export async function restorePlan(v: VanaCtx, scope: PlanScope | null | undefined, snap: MealSnapshot): Promise<MealPlan> {
  const p = (await resolvePlan(v, scope, true))!;
  await v.db.from('plan_meals').delete().eq('plan_id', p.id).eq('user_id', v.userId);
  for (const m of snap) { try { await addMealById(v, m.source, m.id, m.servings, m.session, { planId: p.id }); } catch (e) { console.warn('[plan] restore skipped', m.id, (e as Error).message); } }
  return refreshShopping(v, p.id);
}
/** Ingredient-level swap (plan Phase 6.3): a saved variant of the meal with `from` replaced by `to`, swapped into the plan
 *  in place and recorded on the plan meal, so the shopping list recomputes from the new components. The original library
 *  row / saved meal is never mutated. */
export async function swapIngredient(v: VanaCtx, planMealId: string, from: string, to: string): Promise<MealPlan> {
  const { data: cur } = await v.db.from('plan_meals').select('*').eq('id', planMealId).eq('user_id', v.userId).maybeSingle();
  if (!cur) throw new Error('plan meal not found');
  const norm = (s: string) => s.toLowerCase().replace(/[^a-z0-9 ]/g, ' ').replace(/\s+/g, ' ').trim();
  let items: { name: string; portion: string; role: string | null }[] = []; let base: Record<string, unknown> = {}; let libraryMealId: string | null = null;
  if (cur.source === 'library' && cur.library_meal_id) {
    const { data: lib } = await v.db.from('meal_library').select('*').eq('id', cur.library_meal_id).maybeSingle(); if (!lib) throw new Error('library meal not found');
    items = ((lib.ingredients_json ?? []) as { name: string; qty?: string; role?: string }[]).map((i) => ({ name: i.name, portion: i.qty ?? '', role: i.role ?? null }));
    base = { calories: lib.kcal, carbs_g: lib.carbs_g, protein_g: lib.protein_g, fat_g: lib.fat_g, meal_types: [lib.meal_type], batch: lib.batch, icon: lib.icon ?? null }; libraryMealId = lib.id;
  } else if (cur.saved_meal_id) {
    const { data: s } = await v.db.from('saved_meals').select('*').eq('id', cur.saved_meal_id).maybeSingle(); if (!s) throw new Error('saved meal not found');
    items = ((s.items ?? []) as { name?: string; food_name?: string; portion?: string; role?: string | null }[]).map((i) => ({ name: i.name ?? i.food_name ?? '', portion: i.portion ?? '', role: i.role ?? null }));
    base = { calories: s.calories, carbs_g: s.carbs_g, protein_g: s.protein_g, fat_g: s.fat_g, meal_types: s.meal_types ?? [cur.meal_type], batch: s.batch ?? false, icon: s.icon ?? null }; libraryMealId = s.library_meal_id ?? null;
  } else throw new Error('plan meal has no source');
  const hit = items.some((i) => norm(i.name).includes(norm(from)));
  if (!hit) throw new Error(`ingredient not in this meal: ${from}`);
  const swapped = items.map((i) => (norm(i.name).includes(norm(from)) ? { ...i, name: to } : i));
  const name = `${String(cur.name).replace(/\s*\([^)]*\)\s*$/, '')} (${to})`;
  const { data: variant, error } = await v.db.from('saved_meals').insert({ user_id: v.userId, name, items: swapped, ...base, library_meal_id: libraryMealId, notes: `Swapped ${from} for ${to}`, last_used_at: new Date().toISOString() }).select('id').single();
  if (error) throw new Error(error.message);
  await swapMeal(v, planMealId, 'saved', variant.id as string);
  return applySwap(v, planMealId, { from, to });
}
