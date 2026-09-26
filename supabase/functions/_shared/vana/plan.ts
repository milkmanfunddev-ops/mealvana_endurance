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
import { invalidateContext } from './context-cache.ts';
import { getMeal } from './meals.ts';
import { getSetting, getCoverageScope, getPantryItems, getPlanPeriod, getMealTypes } from './memory.ts';
import { buildShoppingList } from './grocery.ts';
import { ensureSavedMealIngredients, backfillPlanIngredients } from './saved-ingredients.ts';
import { resolveMealIcon } from './meal-icon.ts';
import { coverageOf, defaultSession, hasNutritionNumbers, servingsToCover } from './plan-math.ts';
import { syncPlanList, markListConfirmed, markListConfirmedIfUnset, toggleByName, dropArchivedDraftLists } from './shopping.ts';

export interface PlanScope { planId?: string | null; conversationId?: string | null }

// deno-lint-ignore no-explicit-any
const toPlanMeal = (r: any): PlanMeal => ({ id: r.id, planId: r.plan_id, source: r.source, libraryMealId: r.library_meal_id ?? null, savedMealId: r.saved_meal_id ?? null, name: r.name, mealType: r.meal_type, session: (r.session ?? null) as Session, servings: r.servings, servingsLeft: r.servings_left, kcal: r.kcal ?? null, carbsG: r.carbs_g == null ? null : Number(r.carbs_g), proteinG: r.protein_g == null ? null : Number(r.protein_g), fatG: r.fat_g == null ? null : Number(r.fat_g), swapsApplied: r.swaps_applied ?? [], comments: r.comments ?? [], position: r.position ?? 0, icon: resolveMealIcon(r.icon, { name: r.name }) });

export { coverageOf, defaultSession, servingsToCover };

// ---------------------------------------------------------------- resolution
/** The week a plan made today belongs to: the latest start day (the week_start setting, mp-269) on or before `iso`. */
export async function currentWeekStart(v: VanaCtx, iso = today()): Promise<string> { return weekStartFor(iso, (await getPlanPeriod(v)).weekStart); }
/** The week's active plan: confirmed if there is one, else the most recently edited draft. Omit `weekStart` for the current week. */
export async function getPlan(v: VanaCtx, week?: string): Promise<MealPlan | null> {
  const weekStart = week ?? await currentWeekStart(v);
  const { data } = await v.db.from('meal_plans').select('*').eq('user_id', v.userId).eq('week_start', weekStart).eq('is_deleted', false).neq('status', 'archived')
    .order('status', { ascending: true }) // 'confirmed' sorts before 'draft'
    .order('updated_at', { ascending: false }).limit(1).maybeSingle();
  return data ? hydrate(v, data) : null;
}
export async function getOrCreatePlan(v: VanaCtx, week?: string): Promise<MealPlan> {
  const weekStart = week ?? await currentWeekStart(v);
  const cur = await getPlan(v, weekStart);
  return cur ?? insertDraft(v, weekStart, null);
}
/** The draft owned by a conversation — created on first use so the plan bar starts empty. */
export async function getConversationPlan(v: VanaCtx, conversationId: string, create = true): Promise<MealPlan | null> {
  const { data } = await v.db.from('meal_plans').select('*').eq('user_id', v.userId).eq('conversation_id', conversationId).eq('is_deleted', false).order('created_at', { ascending: false }).limit(1).maybeSingle();
  if (data) return hydrate(v, data);
  return create ? insertDraft(v, await currentWeekStart(v), conversationId) : null;
}
export async function resolvePlan(v: VanaCtx, scope?: PlanScope | null, create = true): Promise<MealPlan | null> {
  if (scope?.planId) return getPlanById(v, scope.planId);
  if (scope?.conversationId) return getConversationPlan(v, scope.conversationId, create);
  return create ? getOrCreatePlan(v) : getPlan(v);
}
async function insertDraft(v: VanaCtx, weekStart: string, conversationId: string | null, name: string | null = null): Promise<MealPlan> {
  const batchCooking = (await getSetting<boolean>(v, 'batch_cooking')) ?? true;
  const { data, error } = await v.db.from('meal_plans').insert({ user_id: v.userId, week_start: weekStart, batch_cooking: batchCooking, conversation_id: conversationId, ...(name ? { name } : {}) }).select('*').single();
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
  const [{ data: rows }, coverageScope, period, mealTypes] = await Promise.all([v.db.from('plan_meals').select('*').eq('plan_id', plan.id).order('position').order('created_at'), getCoverageScope(v), getPlanPeriod(v), getMealTypes(v)]);
  const meals = (rows ?? []).map(toPlanMeal);
  return { id: plan.id, name: plan.name ?? null, weekStart: plan.week_start, status: plan.status, batchCooking: plan.batch_cooking, conversationId: plan.conversation_id ?? null, brief: plan.brief ?? null, days: (plan.days ?? {}) as Record<string, DayPlan>, rules: (plan.rules ?? []) as PlanRule[], meals, shopping: (plan.shopping ?? []) as ShoppingItem[], coverage: coverageOf(meals, coverageScope, period.periodDays, { batchCooking: !!plan.batch_cooking, mealTypes }), dayNotes: (plan.day_notes ?? {}) as Record<string, string>, dayNotesStale: plan.day_notes_stale !== false };
}

// ---------------------------------------------------------------- edits
/** The servings a meal goes in with when nobody named a number: enough of a batch to cover the period, one when the athlete
 *  cooks the night of (mp-231 clause 3). The model never passes servings for a normal pick — this is what scales them. */
export async function defaultServings(v: VanaCtx, batchCooking: boolean): Promise<number> {
  return servingsToCover((await getPlanPeriod(v)).periodDays, batchCooking);
}
/** A meal already in the plan is left alone — the same rule `draftFromLastTime` follows. Every Add surface (the picker
 *  carousel, Browse, the detail's Add to plan, the model's updateBatch) can reach a meal that is already there, and none
 *  of them is the athlete asking for more servings; that is the stepper (`setServings`). Testing-wave 18-001 / 18-003
 *  saw a second Add double a row from 4 to 8 with nothing on screen saying so. */
export async function addMeal(v: VanaCtx, ref: MealRef, servings?: number | null, session?: Session, scope?: PlanScope | null): Promise<MealPlan> {
  mustHaveNumbers(ref);
  const plan = (await resolvePlan(v, scope, true))!;
  mustTakeNewMeals(plan);
  const existing = plan.meals.find((m) => (ref.source === 'library' ? m.libraryMealId === ref.id : m.savedMealId === ref.id));
  if (existing) return (await getPlanById(v, plan.id))!;
  const want = servings ?? await defaultServings(v, plan.batchCooking);
  const s = session === undefined ? defaultSession(plan.batchCooking, ref, plan.meals) : session;
  const { error } = await v.db.from('plan_meals').insert({ plan_id: plan.id, user_id: v.userId, source: ref.source, library_meal_id: ref.source === 'library' ? ref.id : null, saved_meal_id: ref.source === 'saved' ? ref.id : null, name: ref.name, meal_type: ref.mealType, session: s, servings: want, servings_left: want, kcal: ref.kcal, carbs_g: ref.carbsG, protein_g: ref.proteinG, fat_g: ref.fatG, position: plan.meals.length, icon: ref.icon ?? null });
  if (error) throw new Error(error.message);
  // A dish-level saved meal (made from a log) gets its ingredients once before the list is built (saved-ingredients.ts).
  if (ref.source === 'saved') await ensureSavedMealIngredients(v, ref.id);
  return refreshShopping(v, plan.id);
}
/** The line a pick on an archived plan gets back, the tool's error Vana relays: the plan bar there offers
 *  "Use this plan instead" (plan_bar.dart), which copies it into this week as a new draft that takes meals. */
export const ARCHIVED_PLAN_PICK_REFUSAL =
  'plan is read-only: a different plan was confirmed for this week, so no meals can be added here. Tap "Use this plan instead" on the plan bar to copy it into a new draft you can add to.';
export class ArchivedPlanError extends Error { constructor() { super(ARCHIVED_PLAN_PICK_REFUSAL); this.name = 'ArchivedPlanError'; } }
/** A conversation's lookup (`getConversationPlan`) still finds its draft after another confirm archived it: the plan bar
 *  reads it back read-only. A pick must not land there (mp-683, under mp-675), and an earlier plan takes no new meals
 *  either (mp-675: servings and removals only). Every add ends at addMeal, so the refusal lives here, whichever surface
 *  asked: the picker's pick_meals, the model's updateBatch, a drafted week. Nothing is written and no new draft is
 *  made in the conversation's place, so the archived draft and its bar stay as they were. */
export function mustTakeNewMeals(plan: Pick<MealPlan, 'status'>): void {
  if (plan.status === 'archived') throw new ArchivedPlanError();
}
/** A plan never takes a meal whose numbers are missing (mp-678): every add and every swap ends at addMeal / swapMeal, so
 *  the rule holds here whichever surface asked. Browse's add and the model's updateBatch get this error back; plan build and
 *  the picker never reach it because they pass such a meal by (tools.ts), and same-as-last-time skips it. `set_day_slot`
 *  (actions.ts) calls it too before it puts a library or saved meal on a day (ticket 74). */
export function mustHaveNumbers(ref: MealRef): void {
  if (!hasNutritionNumbers(ref)) throw new Error(`no nutrition numbers: "${ref.name}" has no kcal or macros yet, so it can't go in a plan`);
}
export async function addMealById(v: VanaCtx, source: 'library' | 'saved', id: string, servings?: number | null, session?: Session, scope?: PlanScope | null) {
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
  await invalidateContext(v);
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
  await invalidateContext(v);
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
  await invalidateContext(v);
  return (await getPlanById(v, plan.id))!;
}
export async function setBrief(v: VanaCtx, brief: string, scope?: PlanScope | null) { const p = (await resolvePlan(v, scope, true))!; await v.db.from('meal_plans').update({ brief }).eq('id', p.id); }
/** Confirm: the shopping list is built here (TS grocery aggregation), then ONE SQL transaction — `confirm_meal_plan` —
 *  stores it, flips status → confirmed and archives every other non-archived plan for the same athlete-week. The
 *  client gets its remote ack from that single call. */
export async function confirmPlan(v: VanaCtx, scope?: PlanScope | null): Promise<MealPlan> {
  const target = (await resolvePlan(v, scope, true))!;
  // The plan is still a draft here, and a draft builds no list (110-012): `confirm` is what makes this build one.
  const plan = await refreshShopping(v, target.id, { confirm: true });
  const { data, error } = await v.db.rpc('confirm_meal_plan', { p_plan_id: plan.id, p_shopping: plan.shopping });
  if (error) throw new Error(`confirm_meal_plan: ${error.message}`);
  if (!data) throw new Error('confirm_meal_plan returned nothing');
  await markListConfirmed(v, plan.id); // the plan's list (shopping.ts) sorts to the top of the Shopping tab from now
  await dropDraftListsAfterArchive(v, plan.weekStart); // the drafts the confirm archived take their lists with them
  return hydrate(v, Array.isArray(data) ? data[0] : data);
}
/** Rebuild the plan's lines from its meals. Since 2026-09-16 the lines live in `shopping_lists` / `shopping_items`
 *  (shopping.ts): the plan-built rows are replaced, hand-added and hand-edited rows survive, and the merged list is
 *  mirrored into `meal_plans.shopping` for Kroger and every older reader. `checked` / `have` carry over by name.
 *  A draft gets only the mirror, no list, unless `confirm` says this is the confirm's build (110-012). */
export async function refreshShopping(v: VanaCtx, planId?: string | null, opts: { confirm?: boolean } = {}): Promise<MealPlan> {
  const plan = (planId ? await getPlanById(v, planId) : await getPlan(v))!;
  const prev = new Map(plan.shopping.map((i) => [i.name.toLowerCase(), i]));
  await backfillPlanIngredients(v, plan.meals); // dish-level saved meals already planned get their ingredients once (saved-ingredients.ts)
  const items = await buildShoppingList(v, plan, await getPantryItems(v));
  const fresh = items.map((i) => { const p = prev.get(i.name.toLowerCase()); return p ? { ...i, checked: p.checked, have: i.have || p.have } : i; });
  const merged = await syncPlanList(v, plan, fresh, opts);
  await v.db.from('meal_plans').update({ shopping: merged, day_notes_stale: true, updated_at: new Date().toISOString() }).eq('id', plan.id);
  await invalidateContext(v); // every meal edit ends here: the PLAN line changed
  return { ...plan, shopping: merged, dayNotesStale: true };
}
/** Rebuild shopping list (the Plan tab's ⋮, ticket 96, Lee 09-25): the plan's list from its meals by the same path
 *  confirm and every edit take (mp-244), so it updates the plan's one list in place, or makes it again after the athlete
 *  deleted it, and refills the `meal_plans.shopping` mirror. A confirmed plan's remade list is confirmed with it. On a
 *  draft it refills the mirror and makes no list (110-012); the Plan tab offers it on a confirmed plan only. */
export async function rebuildShoppingList(v: VanaCtx, scope?: PlanScope | null): Promise<MealPlan> {
  const target = await resolvePlan(v, scope, false);
  if (!target) throw new Error('no plan to build a shopping list from');
  const rebuilt = await refreshShopping(v, target.id);
  if (rebuilt.status === 'confirmed') await markListConfirmedIfUnset(v, rebuilt.id);
  return rebuilt;
}
export async function toggleShopping(v: VanaCtx, name: string, field: 'checked' | 'have', value: boolean): Promise<ShoppingItem[]> {
  const plan = (await getPlan(v))!;
  const shopping = plan.shopping.map((i) => (i.name.toLowerCase() === name.toLowerCase() ? { ...i, [field]: value } : i));
  await v.db.from('meal_plans').update({ shopping }).eq('id', plan.id);
  await toggleByName(v, plan.id, name, field, value); // the list row too, so the tab and the mirror agree
  return shopping;
}
/** "Ate it": the `plan_log_from_plan` SQL function decrements servings_left and writes the meal_logs row (source='plan',
 *  plan_meal_id set, per-serving macros) in one transaction. */
export async function logFromPlan(v: VanaCtx, planMealId: string, mealType?: string, logDate = today()): Promise<{ name: string; servingsLeft: number; logId: string }> {
  const { data: logId, error } = await v.db.rpc('plan_log_from_plan', { p_plan_meal_id: planMealId, p_meal_type: mealType ?? null, p_log_date: logDate });
  if (error) throw new Error(`plan_log_from_plan: ${error.message}`);
  const { data: m } = await v.db.from('plan_meals').select('name, servings_left').eq('id', planMealId).eq('user_id', v.userId).maybeSingle();
  if (!m) throw new Error('plan meal not found');
  await invalidateContext(v); // LOGGED TODAY and the servings left both moved
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
  mustHaveNumbers(ref);
  const eaten = cur.servings - cur.servings_left;
  await v.db.from('plan_meals').update({ source: ref.source, library_meal_id: ref.source === 'library' ? ref.id : null, saved_meal_id: ref.source === 'saved' ? ref.id : null, name: ref.name, meal_type: ref.mealType, kcal: ref.kcal, carbs_g: ref.carbsG, protein_g: ref.proteinG, fat_g: ref.fatG, icon: ref.icon ?? null, servings_left: Math.max(0, cur.servings - eaten), swaps_applied: [], comments: [...((cur.comments ?? []) as unknown[]), { role: 'vana', text: `Swapped ${cur.name} → ${ref.name}`, at: new Date().toISOString() }], updated_at: new Date().toISOString() }).eq('id', planMealId);
  if (ref.source === 'saved') await ensureSavedMealIngredients(v, ref.id); // same hook as addMeal
  return refreshShopping(v, cur.plan_id);
}

// ---------------------------------------------------------------- history / new plan
export async function getPlanById(v: VanaCtx, id: string): Promise<MealPlan | null> {
  const { data } = await v.db.from('meal_plans').select('*').eq('id', id).eq('user_id', v.userId).eq('is_deleted', false).maybeSingle();
  return data ? hydrate(v, data) : null;
}
/** `list_plans`: the athlete's plans with meals in them, newest week first, for the Previous plans sheet. One query: each
 *  plan's meal count is embedded through the `plan_meals.plan_id` foreign key (17-003 saw one count query per plan take
 *  8 s). Empty plans are dropped before the bound, not after, so a run of empty drafts can never push real plans off the
 *  end (17-001: a 20-row read over every plan showed 17 and never the oldest week). The caller drops the plan on its tab.
 *  Plans are a list of what was confirmed (mp-675, mp-677): a plan is listed when it is confirmed or was once
 *  (`confirmed_at`, stamped by `confirm_meal_plan`), so one a later plan replaced stays; a draft never confirmed is left
 *  out, archived or not (17-002: the leftover draft fc9687ff showed as an earlier plan). */
export async function listPlans(v: VanaCtx, limit = 200): Promise<(Pick<MealPlan, 'id' | 'weekStart' | 'status' | 'batchCooking'> & { name: string | null; mealCount: number })[]> {
  const { data, error } = await v.db.from('meal_plans').select('id, week_start, status, batch_cooking, name, confirmed_at, created_at, updated_at, plan_meals(count)')
    .eq('user_id', v.userId).eq('is_deleted', false).order('week_start', { ascending: false }).order('updated_at', { ascending: false });
  if (error) throw new Error(`list_plans: ${error.message}`);
  // Newest week first; within a week the confirmed plan leads and the rest follow newest first, ties on updated_at
  // (the same microsecond, seen three times on one account) told apart by created_at (testing-wave 97, 17-004).
  const later = (a: string, b: string) => (a > b ? -1 : a < b ? 1 : 0);
  return (data ?? [])
    .filter((p) => p.status === 'confirmed' || p.confirmed_at != null)
    .sort((a, b) => later(a.week_start, b.week_start) || (a.status === 'confirmed' ? 0 : 1) - (b.status === 'confirmed' ? 0 : 1) || later(a.updated_at, b.updated_at) || later(a.created_at, b.created_at))
    .map((p) => ({ id: p.id, name: p.name ?? null, weekStart: p.week_start, status: p.status, batchCooking: !!p.batch_cooking, mealCount: (p.plan_meals as { count: number }[] | null)?.[0]?.count ?? 0 }))
    .filter((p) => p.mealCount > 0)
    .slice(0, limit);
}
/** `rename_plan`: the athlete's own name for a plan (mp-675), shown in Previous plans in place of the week. Whitespace is
 *  collapsed; an empty name clears it, and the plan goes back to showing its week. */
export const PLAN_NAME_MAX = 60;
export async function renamePlan(v: VanaCtx, id: string, name: string): Promise<MealPlan> {
  const cur = await getPlanById(v, id);
  if (!cur) throw new Error('plan not found');
  const clean = name.replace(/\s+/g, ' ').trim().slice(0, PLAN_NAME_MAX);
  const { error } = await v.db.from('meal_plans').update({ name: clean || null, updated_at: new Date().toISOString() }).eq('id', id).eq('user_id', v.userId);
  if (error) throw new Error(error.message);
  return (await getPlanById(v, id))!;
}
/** `use_plan_again` (mp-675): an earlier plan copied into this week as a new draft, its name and meals with it. The earlier
 *  plan is left as it was, and this week's plan is untouched until the copy is confirmed, which replaces it the way any
 *  new plan's confirm does (`confirm_meal_plan`; mp-674). The copy has no conversation: it is the Plan tab's. Meals go in
 *  through `addMealById`, fresh from the library or the saved meal, so every guard on adding a meal holds for a copy
 *  too; one that can no longer be added is left out rather than copied blind.
 *  The copy takes the place of any earlier conversation-less draft for the week (73-001): that draft is archived first,
 *  so the week never holds a live draft the athlete cannot reach. A conversation's own draft (mp-241) and the
 *  confirmed plan are left alone. */
export async function usePlanAgain(v: VanaCtx, id: string): Promise<MealPlan> {
  const source = await getPlanById(v, id);
  if (!source) throw new Error('plan not found');
  const weekStart = await currentWeekStart(v);
  const { error } = await v.db.from('meal_plans').update({ status: 'archived', updated_at: new Date().toISOString() })
    .eq('user_id', v.userId).eq('week_start', weekStart).eq('status', 'draft').is('conversation_id', null).eq('is_deleted', false);
  if (error) throw new Error(`use_plan_again: ${error.message}`);
  await dropDraftListsAfterArchive(v, weekStart);
  const target = await insertDraft(v, weekStart, null, source.name ?? null);
  await copyMeals(v, source, target, 'use again');
  return refreshShopping(v, target.id);
}
/** A draft archived here takes its list with it (ticket 101; shopping.ts `dropArchivedDraftLists`). The archive has
 *  already landed, so a failed clean-up is logged, not thrown: the next archive in the week, or the migration's
 *  predicate, clears the leftover. */
async function dropDraftListsAfterArchive(v: VanaCtx, weekStart: string): Promise<void> {
  try { await dropArchivedDraftLists(v, weekStart); } catch (e) { console.warn('[plan] draft list clean-up failed', weekStart, (e as Error).message); }
}
/** `new_plan`: archive the plan the scope resolves to (a conversation's draft, an explicit plan, or the week's active
 *  plan) and start a fresh, empty draft in its place — same conversation ownership as the one archived. */
export async function newPlan(v: VanaCtx, scope?: PlanScope | null): Promise<MealPlan> {
  const cur = await resolvePlan(v, scope, false);
  if (cur) {
    await v.db.from('meal_plans').update({ status: 'archived', updated_at: new Date().toISOString() }).eq('id', cur.id);
    await dropDraftListsAfterArchive(v, cur.weekStart); // a draft's list goes with it; a once-confirmed plan keeps its list
  }
  const conversationId = scope?.conversationId ?? cur?.conversationId ?? null;
  const fresh = await insertDraft(v, cur?.weekStart ?? await currentWeekStart(v), conversationId);
  await invalidateContext(v);
  return fresh;
}

/** "Same as last time" (mp-231 clause 5): the athlete's last confirmed plan, copied into the one they are building. Fully
 *  deterministic — the model selects nothing and only presents the result (clause 6). The previous plan's meals come across in
 *  their own order with the servings they had — it is the same as last time — except when the athlete now cooks the night of,
 *  where every meal is one night. Sessions are re-derived by the current mode. A meal already in the draft is left alone rather
 *  than doubled. Throws when the athlete has no confirmed plan to copy.
 *  Note: `meal_plans` records no period of its own, so a plan built over a different period comes across at its own servings
 *  rather than rescaled — the athlete adjusts with the stepper. */
export async function draftFromLastTime(v: VanaCtx, scope?: PlanScope | null): Promise<MealPlan> {
  const target = (await resolvePlan(v, scope, true))!;
  const { data } = await v.db.from('meal_plans').select('*').eq('user_id', v.userId).eq('status', 'confirmed').eq('is_deleted', false)
    .lte('week_start', target.weekStart).neq('id', target.id).order('week_start', { ascending: false }).order('updated_at', { ascending: false }).limit(1).maybeSingle();
  if (!data) throw new Error('no confirmed plan to copy');
  await copyMeals(v, await hydrate(v, data), target, 'same-as-last-time');
  return refreshShopping(v, target.id);
}
/** An earlier plan's meals added to [target] in their own order at the servings they had (one night each when the
 *  athlete now cooks the night of); sessions re-derived by the current mode; a meal already there is left alone. */
async function copyMeals(v: VanaCtx, previous: MealPlan, target: MealPlan, why: string): Promise<void> {
  const have = new Set(target.meals.map((m) => `${m.source}:${m.libraryMealId ?? m.savedMealId}`));
  for (const m of previous.meals) {
    const id = m.libraryMealId ?? m.savedMealId;
    if (!id || have.has(`${m.source}:${id}`)) continue;
    have.add(`${m.source}:${id}`);
    const servings = target.batchCooking ? Math.max(1, Math.min(12, m.servings)) : 1;
    try { await addMealById(v, m.source, id, servings, undefined, { planId: target.id }); } catch (e) { console.warn(`[plan] ${why} skipped`, id, (e as Error).message); }
  }
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
