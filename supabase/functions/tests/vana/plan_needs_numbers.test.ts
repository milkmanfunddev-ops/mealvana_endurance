/**
 * Ticket 61 (testing-wave 29-001; Lee's ruling on mp-678, 2026-09-25): a plan never picks a meal whose numbers are missing.
 *
 * "A meal added later without numbers stays browsable but is never put in a plan." A meal's numbers are its kcal, carbs,
 * protein and fat; any one of them null means the numbers are missing (`null` is not `0`: a meal with 0 g fat has its numbers).
 *
 * Every path that puts a meal into a plan is driven here the way the function runs it, over the fake database with
 * producer-shaped rows (`search_meals` answers as the database does; `meal_library` rows are what the table holds):
 *   1. Plan build: "Draft my week" (`draftWeekPlan`) and the picker it offers from (`mealPickerPart`) skip the blank meal
 *      and still fill the draft from the meals that have numbers.
 *   2. Browse's add (`pick_meals`, the action Browse and the detail page's Add to plan send) refuses the blank meal and
 *      writes nothing; the model's `updateBatch` add reaches the same `addMeal`.
 *   3. Swap (`swap_meal`) refuses to swap a plan meal for the blank meal and leaves the row as it was.
 *   4. Same as last time (`same_as_last_time`) copies the last plan's meals except one whose library row has no numbers.
 *
 * Run: deno test --allow-all supabase/functions/tests/vana/plan_needs_numbers.test.ts
 */
import { assert, assertEquals, assertRejects } from 'https://deno.land/std@0.177.1/testing/asserts.ts';
import { hasNutritionNumbers } from '../../_shared/vana/plan-math.ts';
import { runAction, extraAction } from '../../_shared/vana/actions.ts';
import { draftWeekPlan, mealPickerPart, planDayPart } from '../../_shared/vana/tools.ts';
import { buildAthleteContext } from '../../_shared/vana/context.ts';
import { addDays, today, weekStartFor } from '../../_shared/vana/env.ts';
import type { MealType } from '../../_shared/vana/contracts.ts';
import { testCtx, offlineDeps, TEST_USER_ID } from './support/vana_ctx.ts';
import type { Row, Tables } from './support/fake_db.ts';

const U = TEST_USER_ID;
const CONV = 'conv-needs-numbers';
const PLAN = 'aaaaaaaa-0000-4000-8000-000000000061';
const PREV = 'aaaaaaaa-0000-4000-8000-000000000060';
/** AD-103 as dev held it before the fill: an active plant-based bowl with every number null (29-001). */
const BLANK = 'AD-103';

const setting = (key: string, value: unknown): Row => ({ id: `mem-${key}`, user_id: U, kind: 'setting', key, value, fact: key, confidence: 1, source: 'settings', is_deleted: false, last_confirmed_at: '2026-09-20T09:00:00Z' });
/** A `meal_library` row as the table holds it. */
const libRow = (id: string, mealType: MealType, over: Row = {}): Row => ({ id, name: `Meal ${id}`, meal_type: mealType, contexts: ['everyday'], batch: true, prep_minutes: 20, kcal: 600, carbs_g: 70, protein_g: 35, fat_g: 15, allergens: [], diets_ok: [], swaps: null, why: 'fits the week', source: 'the library', ingredients: 'rice, beans', ingredients_json: [{ name: 'rice', qty: '1 cup' }], is_active: true, kind: 'assembly', ...over });
const blankRow = (): Row => libRow(BLANK, 'dinner', { name: 'Farro, chickpea & roasted cauliflower bowl with tahini', kcal: null, carbs_g: null, protein_g: null, fat_g: null });
/** A row as `search_meals` returns it: the library row, sourced and scored. The blank meal ranks first, so a guard
 *  that only looked past the top result would still be caught. */
const searchRow = (r: Row, score: number): Row => ({ ...r, source: 'library', attribution: r.source, library_meal_id: r.id, score });
const LIBRARY: Row[] = [blankRow(), ...['AD-014', 'AD-015', 'AD-016', 'AD-017', 'AD-018'].map((id) => libRow(id, 'dinner')), ...['AL-001', 'AL-002', 'AL-003', 'AL-004'].map((id) => libRow(id, 'lunch'))];

const planRow = (over: Row = {}): Row => ({ id: PLAN, user_id: U, week_start: weekStartFor(today()), status: 'draft', batch_cooking: true, conversation_id: CONV, brief: null, rules: [], shopping: [], day_notes: {}, day_notes_stale: false, days: {}, is_deleted: false, updated_at: '2026-09-25T09:00:00Z', created_at: '2026-09-25T09:00:00Z', ...over });
const planMeal = (id: string, libraryMealId: string, over: Row = {}): Row => ({ id, plan_id: PLAN, user_id: U, source: 'library', library_meal_id: libraryMealId, saved_meal_id: null, name: `Meal ${libraryMealId}`, meal_type: 'dinner', session: 'cook-sun', servings: 3, servings_left: 3, kcal: 600, carbs_g: 70, protein_g: 35, fat_g: 15, swaps_applied: [], comments: [], position: 0, icon: null, created_at: '2026-09-25T09:00:00Z', ...over });

function world(over: Partial<Tables> = {}) {
  const tables: Tables = {
    users: [{ id: U, first_name: 'Lee' }],
    user_memories: [setting('meal_types', ['dinner'])],
    meal_plans: [planRow()], plan_meals: [], meal_library: LIBRARY.map((r) => ({ ...r })),
    vana_conversations: [], vana_messages: [], saved_meals: [], shopping_lists: [], shopping_items: [], pantry_items: [],
    ...over,
  };
  return testCtx(tables, { rpc: { search_meals: (a: { p_meal_type: string | null; p_limit: number }) => LIBRARY.filter((r) => !a.p_meal_type || r.meal_type === a.p_meal_type).map((r, i) => searchRow(r, 1 - i / 100)).slice(0, a.p_limit) } });
}
const insertedIds = (v: ReturnType<typeof world>) => v.fake.writesTo('plan_meals', 'insert').flatMap((w) => w.rows.map((r) => r.library_meal_id));

// ---------------------------------------------------------------- the rule itself
Deno.test('a meal has its numbers only when kcal, carbs, protein and fat are all there; 0 is a number, null is not', () => {
  const m = { kcal: 600, carbsG: 70, proteinG: 35, fatG: 0 };
  assert(hasNutritionNumbers(m));
  assert(!hasNutritionNumbers({ ...m, kcal: null }));
  assert(!hasNutritionNumbers({ ...m, carbsG: null }));
  assert(!hasNutritionNumbers({ ...m, proteinG: null }));
  assert(!hasNutritionNumbers({ ...m, fatG: null }));
});

// ---------------------------------------------------------------- 1. plan build
Deno.test('plan build: "Draft my week" never drafts the blank meal and still fills the batch from meals with numbers', async () => {
  const v = world();
  const ctx = await buildAthleteContext(v, today(), offlineDeps());
  const p = await draftWeekPlan(v, ctx, { conversationId: CONV }, new Set(), 'dinners');
  const ids = insertedIds(v);
  assert(!ids.includes(BLANK), `the blank meal was drafted: ${ids.join(', ')}`);
  assertEquals(ids, ['AD-014', 'AD-015', 'AD-016']);   // three dinners at one sitting, none of them the blank one
  assert(p.meals.every((m) => m.kcal != null && m.carbsG != null && m.proteinG != null && m.fatG != null));
});

Deno.test('plan build: the picker never offers the blank meal, on its tiles or behind "Show more"', async () => {
  const v = world();
  const ctx = await buildAthleteContext(v, today(), offlineDeps());
  const part = await mealPickerPart(v, ctx, { conversationId: CONV }, new Set(), { mealType: 'dinner', count: 3 });
  const offered = [...part.meals, ...(part.more ?? [])].map((m) => m.id);
  assert(!offered.includes(BLANK), `the picker offered the blank meal: ${offered.join(', ')}`);
  assertEquals(part.meals.map((m) => m.id), ['AD-014', 'AD-015', 'AD-016']);
});

Deno.test('plan build: the day planner never fills a slot with the blank meal', async () => {
  const v = world({ user_memories: [] });
  const ctx = await buildAthleteContext(v, today(), offlineDeps());
  const day = await planDayPart(v, ctx, today());
  assertEquals(day.slots.dinner?.id, 'AD-014');
});

// ---------------------------------------------------------------- 2. Browse's add
Deno.test('Browse add: pick_meals refuses the blank meal and writes nothing to the plan', async () => {
  const v = world();
  await assertRejects(() => runAction(v, { type: 'pick_meals', payload: { meals: [{ source: 'library', id: BLANK }], conversationId: CONV } } as never), Error, 'no nutrition numbers');
  assertEquals(v.fake.writesTo('plan_meals', 'insert'), []);
});

Deno.test('Browse add: a meal with its numbers still goes in', async () => {
  const v = world();
  const r = await runAction(v, { type: 'pick_meals', payload: { meals: [{ source: 'library', id: 'AD-014' }], conversationId: CONV } } as never);
  assertEquals(insertedIds(v), ['AD-014']);
  assertEquals((r.parts[0] as { plan: { meals: unknown[] } }).plan.meals.length, 1);
});

Deno.test('Browse add: a saved meal copied from a blank library meal is refused too', async () => {
  const saved: Row = { id: 'bbbbbbbb-0000-4000-8000-000000000061', user_id: U, name: 'Farro bowl', items: [], calories: null, carbs_g: null, protein_g: null, fat_g: null, library_meal_id: BLANK, meal_types: ['dinner'], batch: true, icon: null, is_deleted: false };
  const v = world({ saved_meals: [saved] });
  await assertRejects(() => runAction(v, { type: 'pick_meals', payload: { meals: [{ source: 'saved', id: saved.id }], conversationId: CONV } } as never), Error, 'no nutrition numbers');
  assertEquals(v.fake.writesTo('plan_meals', 'insert'), []);
});

// ---------------------------------------------------------------- 3. swap
Deno.test('swap: a plan meal is never swapped for the blank meal, and the row stays as it was', async () => {
  const v = world({ plan_meals: [planMeal('pm-1', 'AD-014')] });
  await assertRejects(() => runAction(v, { type: 'swap_meal', payload: { planMealId: 'pm-1', source: 'library', id: BLANK } } as never), Error, 'no nutrition numbers');
  assertEquals(v.fake.writesTo('plan_meals', 'update'), []);
});

Deno.test('swap: a meal with its numbers still swaps in', async () => {
  const v = world({ plan_meals: [planMeal('pm-1', 'AD-014')] });
  await runAction(v, { type: 'swap_meal', payload: { planMealId: 'pm-1', source: 'library', id: 'AD-015' } } as never);
  assertEquals(v.fake.writesTo('plan_meals', 'update')[0].values.library_meal_id, 'AD-015');
});

// ---------------------------------------------------------------- 4. same as last time
Deno.test('same as last time: the last plan comes across without the meal whose numbers are missing', async () => {
  const ws = weekStartFor(today());
  const v = world({
    meal_plans: [planRow({ id: PREV, week_start: addDays(ws, -7), status: 'confirmed', conversation_id: null }), planRow()],
    // Last week's rows were written before the library meal lost (or before it had) its numbers: the plan row carries
    // what the library held then, the library row is what it holds now.
    plan_meals: [planMeal('prev-1', 'AD-014', { plan_id: PREV, position: 0 }), planMeal('prev-2', BLANK, { plan_id: PREV, position: 1, kcal: null, carbs_g: null, protein_g: null, fat_g: null }), planMeal('prev-3', 'AD-015', { plan_id: PREV, position: 2 })],
  });
  const r = await extraAction(v, 'same_as_last_time', { conversationId: CONV });
  assertEquals(insertedIds(v), ['AD-014', 'AD-015']);
  const meals = (r!.parts[0] as { plan: { meals: { libraryMealId: string }[] } }).plan.meals;
  assertEquals(meals.map((m) => m.libraryMealId), ['AD-014', 'AD-015']);
});

// ---------------------------------------------------------------- 5. a day slot by hand (ticket 74, 61-001)
// `set_day_slot` puts a library or saved meal on a day of the plan, so it follows the same rule: a blank meal is refused and
// the plan's days are left as they were.
const dayWrites = (v: ReturnType<typeof world>) => v.fake.writesTo('meal_plans', 'update').filter((w) => 'days' in w.values);

Deno.test('day slot: set_day_slot refuses the blank library meal and writes nothing', async () => {
  const v = world();
  await assertRejects(() => runAction(v, { type: 'set_day_slot', payload: { date: today(), slot: 'dinner', source: 'library', id: BLANK } } as never), Error, 'no nutrition numbers');
  assertEquals(dayWrites(v), []);
});

Deno.test('day slot: set_day_slot refuses a saved meal with no numbers and writes nothing', async () => {
  const saved: Row = { id: 'bbbbbbbb-0000-4000-8000-000000000074', user_id: U, name: 'Farro bowl', items: [], calories: null, carbs_g: null, protein_g: null, fat_g: null, library_meal_id: BLANK, meal_types: ['dinner'], batch: true, icon: null, is_deleted: false };
  const v = world({ saved_meals: [saved] });
  await assertRejects(() => runAction(v, { type: 'set_day_slot', payload: { date: today(), slot: 'dinner', source: 'saved', id: saved.id } } as never), Error, 'no nutrition numbers');
  assertEquals(dayWrites(v), []);
});

Deno.test('day slot: a library meal with its numbers still goes on the day', async () => {
  const v = world();
  const r = await runAction(v, { type: 'set_day_slot', payload: { date: today(), slot: 'dinner', source: 'library', id: 'AD-014' } } as never);
  assertEquals((r.parts[0] as { slots: { dinner?: { id: string } } }).slots.dinner?.id, 'AD-014');
  assertEquals(dayWrites(v).length, 1);
});
