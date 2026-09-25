/**
 * Ticket 34 (testing-wave, Findings 16-001, 18-001, 18-003) at the server seam.
 *
 * A week can hold one CONFIRMED plan and any number of drafts, each owned by a conversation (mp-241). A write that
 * carries its conversation lands on that conversation's draft; one that carries nothing falls back to the week's
 * active plan, which puts the confirmed plan first. Confirm from a Draft's conversation must therefore send its
 * scope — 16-001 saw an unscoped Confirm re-confirm the old plan and archive the Draft on screen.
 *
 * Adding a meal that is already in the plan leaves its servings alone (18-001 / 18-003 saw 4 → 8 from a second Add).
 * Rows are producer-shaped: what `meal_plans` / `plan_meals` return, snake_case and all.
 */
import { assertEquals } from 'https://deno.land/std@0.177.1/testing/asserts.ts';
import { addMeal, confirmPlan, getPlanById, resolvePlan } from '../../_shared/vana/plan.ts';
import { today, weekStartFor } from '../../_shared/vana/env.ts';
import { testCtx, TEST_USER_ID } from './support/vana_ctx.ts';
import type { MealRef } from '../../_shared/vana/contracts.ts';

const U = TEST_USER_ID;
const WEEK = weekStartFor(today());
const OLD_PLAN = 'be6abf2f-0000-4000-8000-000000000001';
const OLD_CONV = 'f6a0f7fa-0000-4000-8000-000000000001';
const DRAFT = '54a02440-0000-4000-8000-000000000002';
const DRAFT_CONV = 'd8efbdb3-0000-4000-8000-000000000002';

const planRow = (id: string, conversationId: string, status: 'confirmed' | 'draft', updatedAt: string) => ({
  id, user_id: U, week_start: WEEK, status, batch_cooking: true, conversation_id: conversationId, brief: null, rules: [], shopping: [], days: {}, day_notes: {}, day_notes_stale: false, is_deleted: false,
  created_at: updatedAt, updated_at: updatedAt,
});
const mealRow = (id: string, planId: string, libraryMealId: string, servings: number) => ({
  id, plan_id: planId, user_id: U, source: 'library', library_meal_id: libraryMealId, saved_meal_id: null, name: libraryMealId, meal_type: 'dinner', session: null,
  servings, servings_left: servings, kcal: 700, carbs_g: 70, protein_g: 35, fat_g: 18, swaps_applied: [], comments: [], position: 0, icon: null, created_at: '2026-09-24T12:00:00Z',
});
const listDefaults = {
  shopping_lists: { name: '', plan_id: null, confirmed_at: null, updated_at: new Date().toISOString() },
  shopping_items: { qty: '', aisle: 'Other', checked: false, have: false, source: 'manual', from_meal_ids: [], edited: false, position: 0 },
};

/** The week of 16-001: the old 4-dinner plan is confirmed, the Draft (one meal) belongs to another conversation. */
function weekWithBoth() {
  const confirmed: { p_plan_id: string }[] = [];
  const v = testCtx({
    meal_plans: [planRow(OLD_PLAN, OLD_CONV, 'confirmed', '2026-09-22T09:00:00Z'), planRow(DRAFT, DRAFT_CONV, 'draft', '2026-09-24T09:23:00Z')],
    plan_meals: [mealRow('m1', OLD_PLAN, 'D-001', 4), mealRow('m2', OLD_PLAN, 'D-002', 4), mealRow('m3', DRAFT, 'D-100', 4)],
  }, {
    defaults: listDefaults,
    rpc: {
      // The SQL function flips the target to confirmed and archives the week's other plans; the fake does the same.
      confirm_meal_plan: (args: { p_plan_id: string; p_shopping: unknown }) => {
        confirmed.push(args);
        const rows = v.fake.rows('meal_plans');
        for (const r of rows) if (r.week_start === WEEK && r.id !== args.p_plan_id && r.status !== 'archived') r.status = 'archived';
        const target = rows.find((r) => r.id === args.p_plan_id)!;
        target.status = 'confirmed'; target.shopping = args.p_shopping;
        return target;
      },
    },
  });
  return { v, confirmed };
}

Deno.test('resolvePlan: the conversation scope lands on its own draft even when the week has a confirmed plan', async () => {
  const { v } = weekWithBoth();
  assertEquals((await resolvePlan(v, { conversationId: DRAFT_CONV }, false))!.id, DRAFT);
  assertEquals((await resolvePlan(v, { planId: DRAFT }, false))!.id, DRAFT);
  // No scope → the week's active plan, and confirmed sorts first. This is the fallback the Review sheet must never rely on.
  assertEquals((await resolvePlan(v, null, false))!.id, OLD_PLAN);
});

Deno.test('confirmPlan with the conversation scope confirms that Draft and archives the old plan (16-001)', async () => {
  const { v, confirmed } = weekWithBoth();
  const out = await confirmPlan(v, { conversationId: DRAFT_CONV });
  assertEquals(confirmed.map((c) => c.p_plan_id), [DRAFT]);
  assertEquals(out.id, DRAFT);
  assertEquals(out.status, 'confirmed');
  assertEquals(out.meals.map((m) => m.libraryMealId), ['D-100']);
  const byId = Object.fromEntries(v.fake.rows('meal_plans').map((r) => [r.id, r.status]));
  assertEquals(byId, { [OLD_PLAN]: 'archived', [DRAFT]: 'confirmed' });
  // The Draft's list is the one marked confirmed, not the old plan's.
  const lists = v.fake.rows('shopping_lists');
  assertEquals(lists.map((l) => [l.plan_id, l.confirmed_at != null]), [[DRAFT, true]]);
});

Deno.test('confirmPlan with the plan id confirms that plan', async () => {
  const { v, confirmed } = weekWithBoth();
  await confirmPlan(v, { planId: DRAFT });
  assertEquals(confirmed.map((c) => c.p_plan_id), [DRAFT]);
});

const ref = (id: string): MealRef => ({ source: 'library', id, name: id, mealType: 'dinner', contexts: [], batch: true, prepMinutes: null, kcal: 700, carbsG: 70, proteinG: 35, fatG: 18, allergens: [], dietsOk: [], swaps: null, why: '', attribution: '', attributionShort: '', ingredients: '', libraryMealId: id, score: 1 });

Deno.test('addMeal on a meal already in the plan leaves its servings alone (18-001, 18-003)', async () => {
  const { v } = weekWithBoth();
  const before = v.fake.writes.length;
  const out = await addMeal(v, ref('D-100'), 4, null, { conversationId: DRAFT_CONV });
  assertEquals(out.meals.map((m) => [m.libraryMealId, m.servings, m.servingsLeft]), [['D-100', 4, 4]]);
  assertEquals(v.fake.writes.slice(before).filter((w) => w.table === 'plan_meals'), []);
  assertEquals((await getPlanById(v, DRAFT))!.meals[0].servings, 4);
});

Deno.test('addMeal on a meal not yet in the plan inserts it once', async () => {
  const { v } = weekWithBoth();
  const out = await addMeal(v, ref('D-200'), 4, null, { conversationId: DRAFT_CONV });
  assertEquals(out.meals.map((m) => m.libraryMealId).sort(), ['D-100', 'D-200']);
  assertEquals(v.fake.writesTo('plan_meals', 'insert').length, 1);
});
