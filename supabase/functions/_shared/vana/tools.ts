/** Vana tools — AI SDK v6. UI-rendering tools return a VanaPart (with `kind`); data tools return plain data.
 *  All 24 tools of the prototype, same two tool sets per conversation kind. */
import { tool } from 'npm:ai@6';
import { z } from 'npm:zod@3';
import type { VanaPart, MealRef, MealContext, MealType, PlanRule, ConversationKind, AthleteContext } from './contracts.ts';
import { today, addDays, dayKey, dayName } from './env.ts';
import type { VanaCtx } from './env.ts';
import { searchMeals, getMeal, rowToMealRef } from './meals.ts';
import { embedTexts, vec } from './embeddings.ts';
import * as plan from './plan.ts';
import type { PlanScope } from './plan.ts';
import { refreshDayNotesSoon } from './daynotes.ts';
import { rememberFact, recallMemories, forgetMemory, setSetting as setSettingRow, getSetting } from './memory.ts';
import { weatherLine } from './weather.ts';

const MealTypeZ = z.enum(['breakfast', 'lunch', 'dinner', 'snack']);
const ContextZ = z.enum(['everyday', 'pre-session', 'recovery', 'rest-day', 'race-week', 'carb-load', 'travel']);
const AllergenZ = z.enum(['dairy','eggs','fish','gluten','peanuts','sesame','shellfish','soy','tree_nuts']);
const DietZ = z.enum(['omnivore','vegetarian','pescatarian','vegan','mediterranean','paleo','keto','low_carb']);
const DayZ = z.enum(['mon', 'tue', 'wed', 'thu', 'fri', 'sat', 'sun']);
const SlotZ = z.enum(['breakfast', 'lunch', 'dinner', 'snack']);

/** Day planner: fill the four slots for a date from plan meals, else the library by the day's context. */
export async function planDayPart(v: VanaCtx, ctx: AthleteContext, date: string): Promise<Extract<VanaPart, { kind: 'day' }>> {
  const dg = await dayGuidance(v, ctx, date);
  const contexts = (dg.label === 'Rest day' || dg.label === 'Low-load day') ? ['rest-day'] : dg.label === 'Race eve' ? ['race-week', 'carb-load'] : dg.label === 'Carb-load day' ? ['carb-load'] : ['everyday', 'recovery'];
  const used = new Set<string>(); const r = await plan.planDay(v, date, async (slot) => { const found = await searchMeals(v, { mealType: slot, contexts: contexts as MealContext[], limit: 6, embed: false }); const pick = found.find((m) => !used.has(m.name.toLowerCase()) && (m.source === 'library' || m.mealType === slot)) ?? found.find((m) => !used.has(m.name.toLowerCase())) ?? null; if (pick) used.add(pick.name.toLowerCase()); return pick; });
  return { kind: 'day', date, label: dg.label, slots: r.slots, filled: r.filled };
}

/** What the model sees for a meal: compact, never the full source string. */
export const compactMeal = (m: MealRef) => ({ id: m.id, source: m.source, name: m.name, mealType: m.mealType, kind: m.kind, pattern: m.pattern, why: m.why, by: m.attributionShort, batch: m.batch, prepMinutes: m.prepMinutes, contexts: m.contexts, kcal: m.kcal, carbsG: m.carbsG, proteinG: m.proteinG });

/** Context tags for this week, derived from race distance and load (deterministic). */
export function weekContexts(ctx: AthleteContext): MealContext[] {
  if (ctx.race && ctx.race.daysOut >= 0 && ctx.race.daysOut <= 7) return ['carb-load', 'race-week'];
  if (/rest|recovery|easy/i.test(ctx.week.character)) return ['rest-day', 'everyday'];
  if (/high/i.test(ctx.week.character)) return ['recovery', 'pre-session'];
  return ['everyday', 'recovery'];
}

/** Staples: meal_logs (30d) grouped by name + saved_meals, matched to the library by embedding. */
export async function diagnoseStaples(v: VanaCtx): Promise<Extract<VanaPart, { kind: 'staples' }>> {
  const d = v.db; const since = addDays(today(), -30);
  const [{ data: logs }, { data: saved }] = await Promise.all([
    d.from('meal_logs').select('name, items, calories, carbs_g, protein_g, fat_g, slot, saved_meal_id').eq('user_id', v.userId).eq('is_deleted', false).gte('log_date', since).limit(300),
    d.from('saved_meals').select('id, name, items, calories, carbs_g, protein_g, fat_g, library_meal_id, meal_types, batch, embedding').eq('user_id', v.userId).eq('is_deleted', false).limit(50),
  ]);
  // deno-lint-ignore no-explicit-any
  const counts = new Map<string, { n: number; row: any }>();
  for (const l of logs ?? []) { const k = l.name.toLowerCase().trim(); const c = counts.get(k); counts.set(k, { n: (c?.n ?? 0) + 1, row: l }); }
  const top = [...counts.values()].sort((a, b) => b.n - a.n).slice(0, 5);
  // match to the library (embed names not already matched)
  const texts = top.map((t) => `${t.row.name}. ${((t.row.items ?? []) as { name?: string }[]).map((i) => i.name ?? '').join(', ')}`);
  let vecs: number[][] = []; try { vecs = await embedTexts(v, texts); } catch { vecs = []; }
  const meals: Extract<VanaPart, { kind: 'staples' }>['meals'] = [];
  for (let i = 0; i < top.length; i++) {
    const t = top[i]; let ref: MealRef | null = null;
    if (t.row.saved_meal_id) ref = await getMeal(v, 'saved', t.row.saved_meal_id);
    if (!ref && vecs[i]) { const { data: hits } = await d.rpc('match_library', { p_embedding: vec(vecs[i]), p_meal_type: t.row.slot ?? null, p_limit: 1 }); const h = hits?.[0]; if (h && h.score >= 0.82) ref = await getMeal(v, 'library', h.id); }
    if (!ref) ref = rowToMealRef({ source: 'saved', id: `log:${t.row.name}`, name: t.row.name, meal_type: t.row.slot ?? 'dinner', contexts: [], batch: false, kcal: t.row.calories, carbs_g: t.row.carbs_g, protein_g: t.row.protein_g, fat_g: t.row.fat_g, why: 'from your log', attribution: 'your log', ingredients: ((t.row.items ?? []) as { name?: string }[]).map((x) => x.name ?? '').filter(Boolean).join(', '), score: 1 });
    meals.push({ ...ref, timesLogged: t.n, ticked: true });
  }
  for (const s of saved ?? []) {
    if (meals.some((m) => m.id === s.id || m.name.toLowerCase() === s.name.toLowerCase())) continue;
    const ref = await getMeal(v, 'saved', s.id); if (ref) meals.push({ ...ref, timesLogged: 0, ticked: true });
    if (meals.length >= 6) break;
  }
  return { kind: 'staples', meals };
}

/** Day guidance — deterministic from budget + workouts + library contexts. */
export async function dayGuidance(v: VanaCtx, ctx: AthleteContext, dateIso = today()): Promise<Extract<VanaPart, { kind: 'day_guidance' }>> {
  const workouts = ctx.week.workouts.filter((w) => w.date === dateIso);
  const minutes = workouts.reduce((s, w) => s + (w.minutes ?? 0), 0);
  const raceIn = ctx.race ? Math.round((new Date(ctx.race.date + 'T00:00:00Z').getTime() - new Date(dateIso + 'T00:00:00Z').getTime()) / 86400_000) : null;
  let label: string; let contexts: MealContext[]; let note: string;
  const { data: mt } = await v.db.from('daily_macro_targets').select('carb_g, prot_g').eq('user_id', v.userId).eq('target_date', dateIso).maybeSingle();
  const minCarbsG = Math.round(Number(mt?.carb_g ?? ctx.budget.today?.carbsG ?? 0));
  if (raceIn != null && raceIn === 0) { label = 'Race day'; contexts = ['race-week', 'pre-session']; note = 'Race-morning breakfast from your pre-race formula; eat familiar food only.'; }
  else if (raceIn != null && raceIn === 1) { label = 'Race eve'; contexts = ['race-week', 'carb-load']; note = `Low-fiber, low-fat, high-carb: at least ${minCarbsG}g carbs. Nothing new tonight.`; }
  else if (raceIn != null && raceIn <= 3) { label = 'Carb-load day'; contexts = ['carb-load', 'race-week']; note = `At least ${minCarbsG}g carbs today; keep fat and fiber modest.`; }
  else if (!workouts.length || minutes < 45) { label = workouts.length ? 'Low-load day' : 'Rest day'; contexts = ['rest-day']; note = `At least ${minCarbsG}g carbs, protein at every meal. No need to top up around training.`; }
  else if (minutes >= 120) { label = 'Big session day'; contexts = ['recovery', 'pre-session']; note = `At least ${minCarbsG}g carbs; a real recovery meal within two hours of finishing.`; }
  else { label = 'Training day'; contexts = ['everyday', 'recovery']; note = `At least ${minCarbsG}g carbs, protein at every meal.`; }
  // One dinner + one snack; the snack search excludes the dinner so a saved meal never fills both slots.
  const dinner = await searchMeals(v, { mealType: 'dinner', contexts, limit: 1, embed: false });
  const snack = await searchMeals(v, { mealType: 'snack', contexts, limit: 1, embed: false, excludeIds: dinner.map((m) => m.id) });
  const suggestions = [...dinner, ...snack];
  return { kind: 'day_guidance', date: dateIso, label, workout: workouts.map((w) => `${w.title}${w.minutes ? ` · ${w.minutes} min` : ''}`).join(', ') || null, minCarbsG, note, suggestions };
}

/** `scope` = the conversation's own draft plan (every plan write in a chat lands there); `shownIds` = meals already shown in this
 *  conversation's pickers, so "other options" never repeats. */
export interface ToolOpts { scope?: PlanScope | null; shownIds?: string[] }
export function makeVanaTools(v: VanaCtx, ctx: AthleteContext, kind: ConversationKind = 'meal_planning', opts: ToolOpts = {}) {
  const all = makeAllTools(v, ctx, opts);
  // Day-grid tools (planDay/setDaySlot) are UI-only (the day planner on Food → Plan);
  // a conversation builds the week's COLLECTION, never a day-by-day grid.
  if (kind === 'general') { const { askChoice, searchMeals: sm, dayGuidance: dg, getWeather, getWorkouts, getLoggedMeals, getMacroTargets, recallFacts, rememberFact, forgetFact, getSetting, getBatch, logFromPlan, getProfile, recallConversations } = all; return { askChoice, searchMeals: sm, dayGuidance: dg, getWeather, getWorkouts, getLoggedMeals, getMacroTargets, recallFacts, rememberFact, forgetFact, getSetting, getBatch, logFromPlan, getProfile, recallConversations }; }
  const { planDay: _pd, setDaySlot: _sds, ...collection } = all;
  return collection;
}
function makeAllTools(v: VanaCtx, ctx: AthleteContext, opts: ToolOpts = {}) {
  const scope = opts.scope ?? null;
  const shown = new Set(opts.shownIds ?? []);
  return {
    swapMeal: tool({ description: 'Replace one plan meal in place (keeps servings/session) with a meal from a tool result.', inputSchema: z.object({ planMealId: z.string(), source: z.enum(['library', 'saved']), mealId: z.string() }), execute: async (i): Promise<VanaPart> => ({ kind: 'batch', plan: await plan.swapMeal(v, i.planMealId, i.source, i.mealId) }) }),
    askChoice: tool({ description: 'Ask ONE question with 2–3 short tappable options. Use this at the end of almost every turn.', inputSchema: z.object({ question: z.string().optional(), options: z.array(z.string()).min(2).max(3) }), execute: async ({ question, options }): Promise<VanaPart> => await Promise.resolve({ kind: 'choices', question, options }) }),
    diagnoseStaples: tool({ description: 'What the athlete already eats most weeks (logs + saved meals), as a tappable staples widget. Nothing is added to the plan — the athlete ticks what they want. Use when they ask what they usually eat or want to start from their own meals.', inputSchema: z.object({}), execute: async () => { const st = await diagnoseStaples(v); const p = await plan.resolvePlan(v, scope, false); const inPlan = new Set((p?.meals ?? []).map((m) => m.libraryMealId ?? m.savedMealId ?? '')); const meals = st.meals.map((m) => ({ ...m, ticked: inPlan.has(m.id) })); meals.forEach((m) => shown.add(m.id)); const target = ctx.budget.today; return { kind: 'staples' as const, meals, planCarbsPerDay: p?.coverage.perDay.carbsG ?? 0, targetCarbsPerDay: target?.carbsG ?? null, covered: p?.coverage.covered ?? 0, of: p?.coverage.lunchDinnerSlots ?? 14 }; } }),
    searchMeals: tool({ description: 'Search the meal library AND the athlete\'s saved meals with hard allergy/diet filters. Use for lookups; use suggestMeals to show a picker.', inputSchema: z.object({ query: z.string().optional(), mealType: MealTypeZ.optional(), contexts: z.array(ContextZ).optional(), batch: z.boolean().optional(), kind: z.enum(['assembly', 'recipe']).optional().describe('assembly = no-recipe component combos; omit for both'), limit: z.number().int().min(1).max(12).optional(), excludeAllergens: z.array(AllergenZ).optional().describe('Query-time exclusions the athlete asked for (e.g. without nuts), on top of their stored allergies'), requireDiet: DietZ.optional().describe('Query-time diet the athlete asked for (e.g. vegan tonight)') }), execute: async (i) => (await searchMeals(v, { ...i, kind: i.kind ?? null, limit: Math.min(i.limit ?? 6, 6) })).map(compactMeal) }),
    suggestMeals: tool({ description: 'Render a meal picker (3 options) for ONE meal type, filtered by this week\'s context, from the library and saved meals. Never repeats a meal already in the plan or already shown in this conversation, so call it again for \'other options\'. Mixes no-recipe assemblies and recipes by default. Optional maxPrepMinutes for \'quick\' / \'under 20 min\'.', inputSchema: z.object({ title: z.string().default('Tap any — they go straight into your plan'), query: z.string().optional(), mealType: MealTypeZ.default('dinner'), contexts: z.array(ContextZ).optional(), batch: z.boolean().optional(), kind: z.enum(['assembly', 'recipe']).optional().describe('assembly = no-recipe component combos; omit for a mix'), maxPrepMinutes: z.number().int().min(0).max(120).optional(), defaultServings: z.number().int().min(1).max(8).default(4), excludeAllergens: z.array(AllergenZ).optional(), requireDiet: DietZ.optional() }), execute: async (i): Promise<VanaPart> => { const cur = await plan.resolvePlan(v, scope, false); const excludeIds = [...(cur?.meals ?? []).map((m) => m.libraryMealId ?? m.savedMealId ?? '').filter(Boolean), ...shown]; const want = 3; const found = await searchMeals(v, { query: i.query, mealType: i.mealType as MealType, contexts: (i.contexts as MealContext[] | undefined) ?? weekContexts(ctx), batch: i.batch, limit: i.maxPrepMinutes != null ? 12 : want, excludeAllergens: i.excludeAllergens, requireDiet: i.requireDiet, excludeIds, kind: i.kind ?? null }); const meals = (i.maxPrepMinutes != null ? found.filter((m) => m.prepMinutes != null && m.prepMinutes <= i.maxPrepMinutes!) : found).slice(0, want); meals.forEach((m) => shown.add(m.id)); return { kind: 'meal_picker', title: i.title, mealType: i.mealType as MealType, meals, multi: true, defaultServings: i.defaultServings }; } }),
    checkCombination: tool({ description: 'Anti-hallucination check for an ad-hoc component combination the athlete asked for (NOT from a tool result). Pass the plain components ([\'chicken breast\',\'white rice\',\'broccoli\']). If any pair has 0 support, it is not something athletes eat — say so and offer searchMeals instead. Never propose an unsupported combination.', inputSchema: z.object({ components: z.array(z.string()).min(2).max(6) }), execute: async (i) => { const { data, error } = await v.db.rpc('library_pair_support', { p_components: i.components }); if (error) return { supported: false, pairs: [], error: error.message }; const pairs = ((data ?? []) as { comp_a: string; comp_b: string; n_meals: number }[]).map((p) => ({ components: `${p.comp_a} + ${p.comp_b}`, count: p.n_meals })); return { supported: pairs.length > 0 && pairs.every((p) => p.count > 0), pairs }; } }),
    getBatch: tool({ description: 'Show the plan being built (meals × servings, sessions, rules, coverage).', inputSchema: z.object({}), execute: async (): Promise<VanaPart> => ({ kind: 'batch', plan: (await plan.resolvePlan(v, scope, true))! }) }),
    updateBatch: tool({ description: 'Add a meal (by source+id from a tool result) with servings, change servings of a plan meal, or remove it. Returns the batch.', inputSchema: z.object({ action: z.enum(['add', 'set_servings', 'remove']), source: z.enum(['library', 'saved']).optional(), mealId: z.string().optional(), planMealId: z.string().optional(), servings: z.number().int().min(0).max(12).optional() }), execute: async (i): Promise<VanaPart> => { let p; if (i.action === 'add') p = await plan.addMealById(v, i.source!, i.mealId!, i.servings ?? 4, undefined, scope); else if (i.action === 'set_servings') p = await plan.setServings(v, i.planMealId!, i.servings ?? 1); else p = await plan.setServings(v, i.planMealId!, 0); return { kind: 'batch', plan: p }; } }),
    proposeRule: tool({ description: 'Propose one day-specific rule (e.g. Friday race-eve plate). Optionally attach the library meal that satisfies it. The user accepts via askChoice afterwards.', inputSchema: z.object({ day: DayZ, rule: z.string(), mealId: z.string().optional(), accepted: z.boolean().default(false) }), execute: async (i): Promise<VanaPart> => { const rule: PlanRule = { day: i.day, rule: i.rule, mealId: i.mealId, accepted: i.accepted }; await plan.setRule(v, rule, scope); const meal = i.mealId ? await getMeal(v, 'library', i.mealId) : null; return { kind: 'rule', rule, meal: meal ?? undefined }; } }),
    confirmPlan: tool({ description: 'Confirm the plan being built (it becomes this week\'s plan) and build the shopping list. Only when the athlete explicitly asks to confirm.', inputSchema: z.object({}), execute: async (): Promise<VanaPart> => { const p = await plan.confirmPlan(v, scope); refreshDayNotesSoon(v, today(), p.id); return { kind: 'shopping_list', items: p.shopping, itemCount: p.shopping.filter((x) => !x.have).length, skipped: p.shopping.filter((x) => x.have).map((x) => x.name) }; } }),
    shoppingList: tool({ description: 'Show the aisle-grouped shopping list for the plan being built.', inputSchema: z.object({}), execute: async (): Promise<VanaPart> => { const cur = (await plan.resolvePlan(v, scope, true))!; const p = await plan.refreshShopping(v, cur.id); return { kind: 'shopping_list', items: p.shopping, itemCount: p.shopping.filter((x) => !x.have).length, skipped: p.shopping.filter((x) => x.have).map((x) => x.name) }; } }),
    dayGuidance: tool({ description: 'Deterministic guidance for a day (rest / training / carb-load / race eve) with a library dinner + snack. Use for \'what should I eat today\'.', inputSchema: z.object({ date: z.string().optional() }), execute: async (i) => dayGuidance(v, ctx, i.date ?? today()) }),
    logFromPlan: tool({ description: 'The athlete ate one serving of a plan meal: decrement servings and write a log row.', inputSchema: z.object({ planMealId: z.string(), mealType: MealTypeZ.optional() }), execute: async (i): Promise<VanaPart> => { const r = await plan.logFromPlan(v, i.planMealId, i.mealType); return { kind: 'logged', planMealId: i.planMealId, name: r.name, servingsLeft: r.servingsLeft }; } }),
    rememberFact: tool({ description: 'Store something the athlete stated explicitly or does repeatedly (dislike, constraint, pattern). Never guesses.', inputSchema: z.object({ kind: z.enum(['preference', 'constraint', 'pattern', 'episode']), fact: z.string().max(200), confidence: z.number().min(0).max(1).default(0.8) }), execute: async (i): Promise<VanaPart> => ({ kind: 'memory_saved', memory: await rememberFact(v, i) }) }),
    recallFacts: tool({ description: 'Search what Vana knows about the athlete.', inputSchema: z.object({ query: z.string() }), execute: async (i) => recallMemories(v, i.query, 8) }),
    forgetFact: tool({ description: 'Delete a memory by id (the athlete asked).', inputSchema: z.object({ id: z.string() }), execute: async (i) => { await forgetMemory(v, i.id); return { ok: true }; } }),
    setSetting: tool({ description: 'Flip a setting: batch_cooking (also re-derives cooking sessions) or show_macros.', inputSchema: z.object({ key: z.enum(['batch_cooking', 'show_macros']), value: z.boolean() }), execute: async (i): Promise<VanaPart> => { const m = await setSettingRow(v, i.key, i.value, 'conversation'); if (i.key === 'batch_cooking') await plan.setBatchCooking(v, i.value, scope); return { kind: 'memory_saved', memory: m }; } }),
    getSetting: tool({ description: 'Read a setting (null if never set).', inputSchema: z.object({ key: z.enum(['batch_cooking', 'show_macros']) }), execute: async (i) => ({ key: i.key, value: await getSetting(v, i.key) }) }),
    planDay: tool({ description: 'Plan a day: fill Breakfast · Lunch · Dinner · Snack for a date from the batch first, then the library by that day\'s context. Returns the day widget.', inputSchema: z.object({ date: z.string().optional() }), execute: async (i): Promise<VanaPart> => planDayPart(v, ctx, i.date ?? today()) }),
    setDaySlot: tool({ description: 'Put a specific meal (source+id from a tool result) into one slot of a day, or clear it.', inputSchema: z.object({ date: z.string().optional(), slot: SlotZ, source: z.enum(['plan', 'library', 'saved']).optional(), mealId: z.string().optional(), name: z.string().optional(), clear: z.boolean().optional() }), execute: async (i): Promise<VanaPart> => { const date = i.date ?? today(); if (i.clear) await plan.setDaySlot(v, date, i.slot, null); else if (i.source && i.mealId) { let name = i.name ?? ''; let kcal: number | null = null; let carbsG: number | null = null; if (i.source === 'plan') { const p = await plan.getOrCreatePlan(v); const m = p.meals.find((x) => x.id === i.mealId); if (m) { name = m.name; kcal = m.kcal; carbsG = m.carbsG; } } else { const m = await getMeal(v, i.source, i.mealId); if (m) { name = m.name; kcal = m.kcal; carbsG = m.carbsG; } } await plan.setDaySlot(v, date, i.slot, { source: i.source, id: i.mealId, name, kcal, carbsG }); } const slots = await plan.getDay(v, date); const dg = await dayGuidance(v, ctx, date); return { kind: 'day', date, label: dg.label, slots, filled: [] }; } }),
    getWeather: tool({ description: 'Weather one-liner for a place and date (Open-Meteo).', inputSchema: z.object({ place: z.string(), date: z.string() }), execute: async (i) => ({ line: await weatherLine(i.place, i.date) }) }),
    // deno-lint-ignore no-explicit-any
    getProfile: tool({ description: 'The athlete\'s profile: diet, allergies, gut-training level, and the next race (name, date, days out, location).', inputSchema: z.object({}), execute: async () => { const d = v.db; const [{ data: u }, { data: ev }] = await Promise.all([d.from('users').select('first_name, dietary_preference, allergies, gut_training_level').eq('id', v.userId).maybeSingle(), d.from('events').select('event_name, event_date, location, event_type').eq('user_id', v.userId).gte('event_date', today()).order('event_date').limit(3)]); return { firstName: u?.first_name ?? null, diet: u?.dietary_preference ?? null, allergies: u?.allergies ?? [], gutTraining: u?.gut_training_level ?? null, upcomingRaces: (ev ?? []).map((e: any) => ({ name: e.event_name, date: e.event_date, daysOut: Math.round((new Date(e.event_date).getTime() - new Date(today()).getTime()) / 864e5), location: e.location, type: e.event_type })) }; } }),
    // deno-lint-ignore no-explicit-any
    recallConversations: tool({ description: 'Search what was said in the athlete\'s earlier conversations with Vana (both kinds). Returns matching messages with dates. Use when they refer to something \'we talked about\'.', inputSchema: z.object({ query: z.string(), limit: z.number().int().min(1).max(12).default(6) }), execute: async (i) => { const words = i.query.split(/\s+/).filter((w) => w.length > 2).slice(0, 4); if (!words.length) return []; let q = v.db.from('vana_messages').select('role, content, created_at, conversation_id').eq('user_id', v.userId).order('created_at', { ascending: false }).limit(i.limit); for (const w of words) q = q.ilike('content', `%${w}%`); const { data } = await q; return (data ?? []).map((m: any) => ({ when: String(m.created_at).slice(0, 10), role: m.role, text: String(m.content ?? '').slice(0, 300) })); } }),
    getWorkouts: tool({ description: 'Planned workouts for the next N days (already summarised in context; call for detail).', inputSchema: z.object({ days: z.number().int().min(1).max(21).default(7) }), execute: async (i) => { const { data } = await v.db.from('activities').select('scheduled_date_time, title, activity_type, duration_minutes, intensity_level, distance_miles').eq('user_id', v.userId).is('deleted_at', null).gte('scheduled_date_time', today()).lt('scheduled_date_time', addDays(today(), i.days + 1)).order('scheduled_date_time'); return data ?? []; } }),
    getLoggedMeals: tool({ description: 'Meals the athlete logged in the last N days.', inputSchema: z.object({ days: z.number().int().min(1).max(30).default(7) }), execute: async (i) => { const { data } = await v.db.from('meal_logs').select('log_date, slot, name, calories, carbs_g, protein_g, fat_g, source').eq('user_id', v.userId).eq('is_deleted', false).gte('log_date', addDays(today(), -i.days)).order('log_date', { ascending: false }).limit(60); return data ?? []; } }),
    getMacroTargets: tool({ description: 'Daily macro targets for a date range.', inputSchema: z.object({ from: z.string(), to: z.string() }), execute: async (i) => { const { data } = await v.db.from('daily_macro_targets').select('target_date, carb_g, prot_g, fat_g, tdee').eq('user_id', v.userId).gte('target_date', i.from).lte('target_date', i.to).order('target_date'); return data ?? []; } }),
  };
}
export const dayLabel = (iso: string) => `${dayName(iso)} (${dayKey(iso)})`;
