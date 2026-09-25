/**
 * Ticket 49 (testing-wave, Findings 17-001, 17-003) at the server seam: `list_plans` behind the Previous plans sheet.
 *
 * 17-001: `listPlans` read `.limit(20)` over every non-deleted plan, drafts and empty plans included, so the sheet
 * (which drops the current plan and plans with no meals) showed 17 rows and never the oldest week. 17-003: it counted
 * each plan's meals with its own query, one after another, and one open sat on a spinner for 8 s.
 *
 * Rows are producer-shaped: what `meal_plans` / `plan_meals` return, snake_case and all. The meal count comes back the
 * way PostgREST embeds it (`plan_meals: [{ count }]`), through the `plan_meals.plan_id → meal_plans.id` foreign key.
 */
import { assertEquals } from 'https://deno.land/std@0.177.1/testing/asserts.ts';
import { listPlans } from '../../_shared/vana/plan.ts';
import { testCtx, TEST_USER_ID } from './support/vana_ctx.ts';

const U = TEST_USER_ID;
const OTHER = '22222222-2222-4222-8222-222222222222';

const weekOf = (weeksAgo: number) => {
  const d = new Date(Date.UTC(2026, 8, 20) - weeksAgo * 7 * 86_400_000);
  return d.toISOString().slice(0, 10);
};
const planRow = (id: string, weekStart: string, status: string, over: Record<string, unknown> = {}) => ({
  id, user_id: U, week_start: weekStart, status, batch_cooking: true, conversation_id: null, brief: null, rules: [], shopping: [], days: {},
  day_notes: {}, day_notes_stale: false, is_deleted: false, created_at: `${weekStart}T09:00:00Z`, updated_at: `${weekStart}T09:00:00Z`, ...over,
});
const mealRow = (id: string, planId: string, userId = U) => ({
  id, plan_id: planId, user_id: userId, source: 'library', library_meal_id: `L-${id}`, saved_meal_id: null, name: id, meal_type: 'dinner', session: null,
  servings: 1, servings_left: 1, kcal: 600, carbs_g: 60, protein_g: 30, fat_g: 15, swaps_applied: [], comments: [], position: 0, icon: null,
  created_at: '2026-09-01T12:00:00Z',
});

/** 25 plans with meals, one a week, plus the clutter the test account had: an empty draft in most weeks, a deleted plan,
 *  and another athlete's plan. Before the fix the 20-row read filled up with the empty drafts. */
function account() {
  const plans = [];
  const meals = [];
  for (let i = 0; i < 25; i++) {
    const id = `plan-${String(i).padStart(2, '0')}`;
    // Each week's plan was confirmed once, the older ones since replaced (archived with confirmed_at kept, ticket 73).
    plans.push(planRow(id, weekOf(i), i === 0 ? 'confirmed' : 'archived', { confirmed_at: `${weekOf(i)}T09:30:00Z` }));
    for (let m = 0; m < (i % 4) + 1; m++) meals.push(mealRow(`${id}-m${m}`, id));
    if (i < 15) plans.push(planRow(`empty-${i}`, weekOf(i), 'draft', { updated_at: `${weekOf(i)}T10:00:00Z` }));
  }
  plans.push(planRow('deleted', weekOf(3), 'archived', { is_deleted: true }));
  meals.push(mealRow('deleted-m0', 'deleted'));
  plans.push(planRow('someone-else', weekOf(2), 'confirmed', { user_id: OTHER }));
  meals.push(mealRow('someone-else-m0', 'someone-else', OTHER));
  return testCtx({ meal_plans: plans, plan_meals: meals });
}

Deno.test('listPlans: an account with 25 plans lists them all, newest week first (17-001)', async () => {
  const v = account();
  const out = await listPlans(v);
  assertEquals(out.map((p) => p.id), Array.from({ length: 25 }, (_, i) => `plan-${String(i).padStart(2, '0')}`));
  assertEquals(out[24].weekStart, weekOf(24));
});

Deno.test('listPlans: each row carries its meal count; empty and deleted plans are left out', async () => {
  const v = account();
  const out = await listPlans(v);
  assertEquals(out.map((p) => p.mealCount), Array.from({ length: 25 }, (_, i) => (i % 4) + 1));
  assertEquals(out[0], { id: 'plan-00', name: null, weekStart: weekOf(0), status: 'confirmed', batchCooking: true, mealCount: 1 });
  assertEquals(out.some((p) => p.id.startsWith('empty-') || p.id === 'deleted' || p.id === 'someone-else'), false);
});

Deno.test('listPlans: one query reads the plans and counts their meals (17-003)', async () => {
  const v = account();
  await listPlans(v);
  assertEquals(v.fake.reads, ['meal_plans']);
});
