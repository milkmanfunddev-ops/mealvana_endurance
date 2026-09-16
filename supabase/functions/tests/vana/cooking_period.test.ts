/**
 * Ticket 30 (mp-231) at the server seam: a plan fills a cooking period, not fourteen slots.
 *
 * The coverage cases are the SHARED fixture the Dart seam test reads too
 * (test/features/meal_planning/fixtures/coverage_cases.json) — producer-shaped plan meals in, one expected coverage out — so
 * the server and the client are held to the same numbers rather than to each other's output.
 */
import { assertEquals, assertRejects } from 'https://deno.land/std@0.177.1/testing/asserts.ts';
import { BATCH_MEALS_PER_TYPE, coverageOf, servingsToCover, walkFor } from '../../_shared/vana/plan-math.ts';
import { getMealTypes } from '../../_shared/vana/memory.ts';
import { addMeal, draftFromLastTime, getPlanById } from '../../_shared/vana/plan.ts';
import { buildAthleteContext, contextBlock } from '../../_shared/vana/context.ts';
import { addDays, today, weekStartFor } from '../../_shared/vana/env.ts';
import { testCtx, offlineDeps, TEST_USER_ID } from './support/vana_ctx.ts';
import type { MealRef, MealType, PlanMeal } from '../../_shared/vana/contracts.ts';
import type { Tables } from './support/fake_db.ts';

const U = TEST_USER_ID;
const setting = (key: string, value: unknown) => ({ id: `s-${key}`, user_id: U, kind: 'setting', key, fact: key, value, source: 'settings', is_deleted: false });

interface CoverageCase {
  name: string;
  scope: string | null;
  periodDays: number;
  batchCooking: boolean;
  mealTypes: MealType[] | null;
  meals: PlanMeal[];
  expected: { lunchDinnerSlots: number; covered: number; periodDays: number; mealTypes: MealType[]; perDay: { kcal: number; carbsG: number; proteinG: number } };
}
const fixture = JSON.parse(await Deno.readTextFile(new URL('../../../../test/features/meal_planning/fixtures/coverage_cases.json', import.meta.url))) as { cases: CoverageCase[] };

// ---------------------------------------------------------------- coverage, against the shared fixture
for (const c of fixture.cases) {
  Deno.test(`coverage: ${c.name}`, () => {
    assertEquals(coverageOf(c.meals, c.scope, c.periodDays, { batchCooking: c.batchCooking, mealTypes: c.mealTypes }), c.expected);
  });
}

// ---------------------------------------------------------------- servings scale to cover the period (clause 3)
Deno.test('a batch is a few meals at one sitting, and its servings cover the days', () => {
  assertEquals(BATCH_MEALS_PER_TYPE, 3);
  assertEquals(servingsToCover(7), 3);       // a week over three meals
  assertEquals(servingsToCover(10), 4);      // ten days need four each
  assertEquals(servingsToCover(14), 5);
  assertEquals(servingsToCover(3), 1);
  assertEquals(servingsToCover(10, true, 2), 5);  // two meals at the sitting, five servings each
});

Deno.test('an athlete who does not batch cooks the night of: one serving, whatever the period', () => {
  assertEquals(servingsToCover(7, false), 1);
  assertEquals(servingsToCover(14, false), 1);
});

// ---------------------------------------------------------------- the walk (clause 1)
Deno.test('the walk is the types they plan, in their order, and nothing else', () => {
  assertEquals(walkFor(['breakfast', 'dinner']), ['breakfast', 'dinner']);
  assertEquals(walkFor(['snack', 'snack', 'dinner']), ['snack', 'dinner']);        // no repeats
  assertEquals(walkFor(['brunch', 'dinner']), ['dinner']);                          // an unknown type is dropped
  // Never chosen: the coverage scope stands in, which is what coverage counted before the walk existed.
  assertEquals(walkFor(null), ['dinner', 'lunch']);
  assertEquals(walkFor([], 'dinners'), ['dinner']);
  assertEquals(walkFor(null, 'all'), ['dinner', 'lunch']);
});

Deno.test('settings seam: the chosen walk reaches the context block, and the default says it was never chosen', async () => {
  const chosen = testCtx({ users: [{ id: U, first_name: 'Lee' }], user_memories: [setting('meal_types', ['breakfast', 'dinner'])] });
  assertEquals(await getMealTypes(chosen), ['breakfast', 'dinner']);
  const block = contextBlock(await buildAthleteContext(chosen, '2026-09-16', offlineDeps()));
  assertEquals(block.split('\n').find((l) => l.startsWith('WALK')), 'WALK breakfast → dinner');

  const never = testCtx({ users: [{ id: U, first_name: 'Lee' }] });
  assertEquals(await getMealTypes(never), null);
  const plain = contextBlock(await buildAthleteContext(never, '2026-09-16', offlineDeps()));
  assertEquals(plain.split('\n').find((l) => l.startsWith('WALK')), 'WALK dinner → lunch (default — never chosen)');
});

Deno.test('a stored walk outside the contract reads as never chosen', async () => {
  const v = testCtx({ user_memories: [setting('meal_types', ['elevenses'])] });
  assertEquals(await getMealTypes(v), null);
});

// ---------------------------------------------------------------- the plan itself
const PLAN = 'aaaaaaaa-0000-4000-8000-000000000030';
const planRow = (over: Record<string, unknown> = {}) => ({ id: PLAN, user_id: U, week_start: weekStartFor(today()), status: 'draft', batch_cooking: true, conversation_id: null, brief: null, rules: [], shopping: [], day_notes: {}, day_notes_stale: false, is_deleted: false, updated_at: '2026-09-16T12:00:00Z', ...over });
const mealRow = (id: string, mealType: string, servings: number, over: Record<string, unknown> = {}) => ({ id, plan_id: PLAN, user_id: U, source: 'library', library_meal_id: `D-${id}`, saved_meal_id: null, name: id, meal_type: mealType, session: null, servings, servings_left: servings, kcal: 700, carbs_g: 70, protein_g: 35, fat_g: 18, swaps_applied: [], comments: [], position: 0, icon: null, created_at: '2026-09-16T12:00:00Z', ...over });

Deno.test('a plan reads its coverage through the athlete\'s period, mode and walk', async () => {
  const v = testCtx({
    user_memories: [setting('period_days', 10), setting('meal_types', ['breakfast', 'dinner'])],
    meal_plans: [planRow()],
    plan_meals: [mealRow('m1', 'dinner', 5), mealRow('m2', 'breakfast', 4), mealRow('m3', 'lunch', 6)],
  });
  const p = (await getPlanById(v, PLAN))!;
  assertEquals(p.coverage.mealTypes, ['breakfast', 'dinner']);
  assertEquals(p.coverage.lunchDinnerSlots, 20);   // two types over ten days
  assertEquals(p.coverage.covered, 9);             // the lunch is not on their walk
  assertEquals(p.coverage.periodDays, 10);
});

Deno.test('per-day mode counts nights, not servings', async () => {
  const v = testCtx({
    meal_plans: [planRow({ batch_cooking: false })],
    plan_meals: [mealRow('m1', 'dinner', 3), mealRow('m2', 'dinner', 3), mealRow('m3', 'lunch', 2)],
  });
  const p = (await getPlanById(v, PLAN))!;
  assertEquals(p.coverage.covered, 3);             // three meals, three nights — eight servings are irrelevant
  assertEquals(p.coverage.lunchDinnerSlots, 14);
});

const ref = (id: string, mealType: string): MealRef => ({ source: 'library', id, name: id, mealType: mealType as MealRef['mealType'], contexts: [], batch: true, prepMinutes: null, kcal: 700, carbsG: 70, proteinG: 35, fatG: 18, allergens: [], dietsOk: [], swaps: null, why: '', attribution: '', attributionShort: '', ingredients: '', libraryMealId: id, score: 1 });

Deno.test('a pick with no servings named goes in with enough to cover the period', async () => {
  const v = testCtx({ user_memories: [setting('period_days', 10)], meal_plans: [planRow()], plan_meals: [] });
  await addMeal(v, ref('D-900', 'dinner'), undefined, null, { planId: PLAN });
  assertEquals(v.fake.writesTo('plan_meals', 'insert')[0].rows[0].servings, 4);   // ten days over three meals

  const perDay = testCtx({ user_memories: [setting('period_days', 10)], meal_plans: [planRow({ batch_cooking: false })], plan_meals: [] });
  await addMeal(perDay, ref('D-900', 'dinner'), undefined, null, { planId: PLAN });
  assertEquals(perDay.fake.writesTo('plan_meals', 'insert')[0].rows[0].servings, 1);
});

// ---------------------------------------------------------------- same as last time (clause 5)
const PREV = 'aaaaaaaa-0000-4000-8000-00000000002f';
function lastTimeTables(over: { batchCooking?: boolean } = {}): Tables {
  const ws = weekStartFor(today());
  return {
    meal_plans: [
      { ...planRow({ id: PREV, week_start: addDays(ws, -7), status: 'confirmed' }) },
      { ...planRow({ conversation_id: 'c-1', batch_cooking: over.batchCooking ?? true }) },
    ],
    plan_meals: [
      { ...mealRow('p1', 'dinner', 3, { plan_id: PREV, library_meal_id: 'D-001', position: 0 }) },
      { ...mealRow('p2', 'lunch', 6, { plan_id: PREV, library_meal_id: 'L-001', position: 1 }) },
    ],
    meal_library: [
      { id: 'D-001', name: 'Lentil bolognese', meal_type: 'dinner', contexts: [], batch: true, kcal: 700, carbs_g: 70, protein_g: 35, fat_g: 18, ingredients: 'lentils, tomatoes', source: 'the library' },
      { id: 'L-001', name: 'Chicken rice bowl', meal_type: 'lunch', contexts: [], batch: true, kcal: 500, carbs_g: 50, protein_g: 30, fat_g: 12, ingredients: 'chicken, rice', source: 'the library' },
    ],
  };
}

Deno.test('"same as last time" copies the last confirmed plan, deterministically and only once', async () => {
  const v = testCtx(lastTimeTables());
  const first = await draftFromLastTime(v, { conversationId: 'c-1' });
  assertEquals(first.meals.map((m) => [m.name, m.servings]), [['Lentil bolognese', 3], ['Chicken rice bowl', 6]]);

  // Tapping it again changes nothing: the same meals, the same servings, never doubled.
  const again = await draftFromLastTime(v, { conversationId: 'c-1' });
  assertEquals(again.meals.map((m) => [m.name, m.servings]), [['Lentil bolognese', 3], ['Chicken rice bowl', 6]]);
});

Deno.test('"same as last time" for an athlete who now cooks the night of is one night per meal', async () => {
  const v = testCtx(lastTimeTables({ batchCooking: false }));
  const p = await draftFromLastTime(v, { conversationId: 'c-1' });
  assertEquals(p.meals.map((m) => m.servings), [1, 1]);
  assertEquals(p.coverage.covered, 2);
});

Deno.test('"same as last time" with nothing confirmed says so rather than inventing a plan', async () => {
  const v = testCtx({ meal_plans: [planRow({ conversation_id: 'c-1' })], plan_meals: [] });
  await assertRejects(() => draftFromLastTime(v, { conversationId: 'c-1' }), Error, 'no confirmed plan to copy');
});
