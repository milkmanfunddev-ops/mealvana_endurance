/**
 * Ticket 97 (testing-wave, Finding 17-004) at the server seam: the order of `list_plans` behind the Previous plans
 * sheet. Within a week the confirmed plan comes first, then the others newest first; plans that tie on `updated_at`
 * (the test account had three to the microsecond) are told apart by `created_at`.
 *
 * Rows are producer-shaped: what `meal_plans` / `plan_meals` return, snake_case and all.
 */
import { assertEquals } from 'https://deno.land/std@0.177.1/testing/asserts.ts';
import { listPlans } from '../../_shared/vana/plan.ts';
import { testCtx, TEST_USER_ID } from './support/vana_ctx.ts';

const U = TEST_USER_ID;
const SEP13 = '2026-09-13';
const SEP06 = '2026-09-06';

const planRow = (id: string, weekStart: string, status: string, over: Record<string, unknown> = {}) => ({
  id, user_id: U, week_start: weekStart, status, batch_cooking: true, conversation_id: null, is_deleted: false, name: null,
  confirmed_at: `${weekStart}T09:30:00Z`, created_at: `${weekStart}T09:00:00Z`, updated_at: `${weekStart}T09:00:00Z`, ...over,
});
const mealRow = (id: string, planId: string) => ({ id, plan_id: planId, user_id: U, source: 'library', library_meal_id: `L-${id}`, name: id, meal_type: 'dinner', servings: 1, position: 0 });

function account() {
  const plans = [
    // Sep 13: the confirmed plan was edited before two later drafts were confirmed and replaced, so on updated_at alone
    // it would sit last. Two of the replaced plans tie on updated_at and differ only in created_at.
    planRow('sep13-confirmed', SEP13, 'confirmed', { updated_at: `${SEP13}T10:00:00Z` }),
    planRow('sep13-old', SEP13, 'archived', { updated_at: `${SEP13}T23:52:00.123456Z`, created_at: `${SEP13}T11:00:00Z` }),
    planRow('sep13-newer', SEP13, 'archived', { updated_at: `${SEP13}T23:52:00.123456Z`, created_at: `${SEP13}T12:00:00Z` }),
    planRow('sep13-latest', SEP13, 'archived', { updated_at: `${SEP13}T23:59:00Z`, created_at: `${SEP13}T13:00:00Z` }),
    // Sep 6: only replaced plans, newest first.
    planRow('sep06-a', SEP06, 'archived', { updated_at: `${SEP06}T10:00:00Z` }),
    planRow('sep06-b', SEP06, 'archived', { updated_at: `${SEP06}T12:00:00Z` }),
  ];
  const meals = plans.map((p) => mealRow(`${p.id}-m0`, p.id));
  return testCtx({ meal_plans: plans, plan_meals: meals });
}

Deno.test('listPlans: within a week the confirmed plan leads, then the rest newest first, ties broken by created_at (17-004)', async () => {
  const out = await listPlans(account());
  assertEquals(out.map((p) => p.id), ['sep13-confirmed', 'sep13-latest', 'sep13-newer', 'sep13-old', 'sep06-b', 'sep06-a']);
});
