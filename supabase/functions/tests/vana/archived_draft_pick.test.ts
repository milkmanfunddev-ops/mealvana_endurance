/**
 * mp-683 (card mp-675): a conversation whose draft was replaced by a different confirmed plan keeps that draft,
 * read-only. A meal picked there must not land on it, and no fresh draft is made in its place: the pick is refused
 * with a line Vana relays, pointing at "Use this plan instead" (plan_bar.dart), which copies it into a new draft.
 * Rows are producer-shaped: what `meal_plans` / `plan_meals` return, snake_case and all.
 */
import { assertEquals, assertRejects } from 'https://deno.land/std@0.177.1/testing/asserts.ts';
import { addMeal, ArchivedPlanError, ARCHIVED_PLAN_PICK_REFUSAL, getConversationPlan } from '../../_shared/vana/plan.ts';
import { today, weekStartFor } from '../../_shared/vana/env.ts';
import { testCtx, TEST_USER_ID } from './support/vana_ctx.ts';
import type { MealRef } from '../../_shared/vana/contracts.ts';

const U = TEST_USER_ID;
const WEEK = weekStartFor(today());
const CONFIRMED = 'c0f1a2b3-0000-4000-8000-000000000001';
const CONFIRMED_CONV = 'c0f1a2b3-0000-4000-8000-0000000000c1';
const REPLACED = 'a4c1e5d0-0000-4000-8000-000000000002';
const REPLACED_CONV = 'a4c1e5d0-0000-4000-8000-0000000000c2';
const LIVE = 'b7d2f6e1-0000-4000-8000-000000000003';
const LIVE_CONV = 'b7d2f6e1-0000-4000-8000-0000000000c3';

const planRow = (id: string, conversationId: string, status: 'confirmed' | 'draft' | 'archived', confirmedAt: string | null, updatedAt: string) => ({
  id, user_id: U, week_start: WEEK, status, batch_cooking: true, conversation_id: conversationId, brief: null, rules: [], shopping: [], days: {}, day_notes: {}, day_notes_stale: false, is_deleted: false,
  confirmed_at: confirmedAt, created_at: updatedAt, updated_at: updatedAt,
});
const mealRow = (id: string, planId: string, libraryMealId: string) => ({
  id, plan_id: planId, user_id: U, source: 'library', library_meal_id: libraryMealId, saved_meal_id: null, name: libraryMealId, meal_type: 'dinner', session: null,
  servings: 4, servings_left: 4, kcal: 700, carbs_g: 70, protein_g: 35, fat_g: 18, swaps_applied: [], comments: [], position: 0, icon: null, created_at: '2026-09-24T12:00:00Z',
});
const listDefaults = {
  shopping_lists: { name: '', plan_id: null, confirmed_at: null, updated_at: new Date().toISOString() },
  shopping_items: { qty: '', aisle: 'Other', checked: false, have: false, source: 'manual', from_meal_ids: [], edited: false, position: 0 },
};

/** The week after another conversation's plan was confirmed: this conversation's draft is archived, never confirmed. */
function week(replacedConfirmedAt: string | null = null) {
  return testCtx({
    meal_plans: [
      planRow(CONFIRMED, CONFIRMED_CONV, 'confirmed', '2026-09-24T10:00:00Z', '2026-09-24T10:00:00Z'),
      planRow(REPLACED, REPLACED_CONV, 'archived', replacedConfirmedAt, '2026-09-24T10:00:00Z'),
      planRow(LIVE, LIVE_CONV, 'draft', null, '2026-09-24T11:00:00Z'),
    ],
    plan_meals: [mealRow('m1', CONFIRMED, 'D-001'), mealRow('m2', REPLACED, 'D-100'), mealRow('m3', LIVE, 'D-300')],
  }, { defaults: listDefaults });
}

const ref = (id: string): MealRef => ({ source: 'library', id, name: id, mealType: 'dinner', contexts: [], batch: true, prepMinutes: null, kcal: 700, carbsG: 70, proteinG: 35, fatG: 18, allergens: [], dietsOk: [], swaps: null, why: '', attribution: '', attributionShort: '', ingredients: '', libraryMealId: id, score: 1 });

Deno.test('the conversation still reads its replaced draft, read-only (the plan bar shows it)', async () => {
  const v = week();
  const draft = await getConversationPlan(v, REPLACED_CONV, false);
  assertEquals([draft!.id, draft!.status], [REPLACED, 'archived']);
});

Deno.test('a pick in the replaced draft\'s conversation is refused and writes nothing (mp-683)', async () => {
  const v = week();
  const before = v.fake.writes.length;
  const err = await assertRejects(() => addMeal(v, ref('D-200'), 4, null, { conversationId: REPLACED_CONV }), ArchivedPlanError);
  assertEquals(err.message, ARCHIVED_PLAN_PICK_REFUSAL);
  assertEquals(err.message.includes('Use this plan instead'), true);
  // Nothing landed: no plan_meals row, no fresh draft in the conversation's place, no list made.
  assertEquals(v.fake.writes.slice(before), []);
  assertEquals(v.fake.rows('plan_meals').filter((m) => m.plan_id === REPLACED).map((m) => m.library_meal_id), ['D-100']);
  assertEquals(v.fake.rows('meal_plans').length, 3);
  // The draft is still the one the conversation reads, unchanged.
  const draft = await getConversationPlan(v, REPLACED_CONV, false);
  assertEquals([draft!.id, draft!.status, draft!.meals.length], [REPLACED, 'archived', 1]);
});

Deno.test('a pick addressed to the archived plan by id is refused the same way', async () => {
  const v = week();
  await assertRejects(() => addMeal(v, ref('D-200'), 4, null, { planId: REPLACED }), ArchivedPlanError);
});

Deno.test('an earlier plan that was once confirmed takes no new meals either (mp-675)', async () => {
  const v = week('2026-09-20T09:00:00Z');
  await assertRejects(() => addMeal(v, ref('D-200'), 4, null, { conversationId: REPLACED_CONV }), ArchivedPlanError);
});

Deno.test('a live draft in another conversation still takes the pick', async () => {
  const v = week();
  const out = await addMeal(v, ref('D-200'), 4, null, { conversationId: LIVE_CONV });
  assertEquals(out.id, LIVE);
  assertEquals(out.meals.map((m) => m.libraryMealId).sort(), ['D-200', 'D-300']);
});
