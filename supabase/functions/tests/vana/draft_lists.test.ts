/**
 * Ticket 101 (Lee's ruling 2026-09-25, follow-on to Finding 19-002): when a draft plan is archived or replaced, its
 * shopping list goes with it. Only a confirmed plan's list (including one a later plan replaced) and hand-made lists
 * stay in Previous lists.
 *
 * Every server path that archives a draft: confirm (the `confirm_meal_plan` SQL function archives the week's other
 * plans, mp-241), `new_plan` (newPlan), and `use_plan_again` (usePlanAgain archives the week's conversation-less
 * draft). Rows are producer-shaped: what `meal_plans` / `shopping_lists` / `shopping_items` return. A plan that was
 * ever confirmed carries `confirmed_at` (migration 20260925150100); its list carries its own `confirmed_at`
 * (markListConfirmed).
 */
import { assertEquals } from 'https://deno.land/std@0.177.1/testing/asserts.ts';
import { confirmPlan, newPlan, usePlanAgain } from '../../_shared/vana/plan.ts';
import { dropArchivedDraftLists } from '../../_shared/vana/shopping.ts';
import { addDays, today, weekStartFor } from '../../_shared/vana/env.ts';
import { testCtx, TEST_USER_ID } from './support/vana_ctx.ts';

const U = TEST_USER_ID;
const WEEK = weekStartFor(today());
const OLD_CONFIRMED = 'aaaaaaaa-0000-4000-8000-000000000001'; // this week's confirmed plan
const MONDAY_DRAFT = 'aaaaaaaa-0000-4000-8000-000000000002';  // Monday's conversation's draft
const WEDNESDAY_DRAFT = 'aaaaaaaa-0000-4000-8000-000000000003'; // Wednesday's conversation's draft
const TAB_DRAFT = 'aaaaaaaa-0000-4000-8000-000000000004';     // the Plan tab's conversation-less draft
const EARLIER = 'aaaaaaaa-0000-4000-8000-000000000005';       // an earlier week's confirmed plan
const MONDAY_CONV = 'c0000000-0000-4000-8000-000000000002';
const WEDNESDAY_CONV = 'c0000000-0000-4000-8000-000000000003';

const planRow = (id: string, weekStart: string, status: string, over: Record<string, unknown> = {}) => ({
  id, user_id: U, week_start: weekStart, status, batch_cooking: true, conversation_id: null, brief: null, rules: [], shopping: [], days: {},
  day_notes: {}, day_notes_stale: false, is_deleted: false, name: null, confirmed_at: null,
  created_at: `${weekStart}T09:00:00Z`, updated_at: `${weekStart}T09:00:00Z`, ...over,
});
const mealRow = (id: string, planId: string, libraryId: string) => ({
  id, plan_id: planId, user_id: U, source: 'library', library_meal_id: libraryId, saved_meal_id: null, name: libraryId, meal_type: 'dinner', session: null,
  servings: 2, servings_left: 2, kcal: 650, carbs_g: 70, protein_g: 35, fat_g: 18, swaps_applied: [], comments: [], position: 0, icon: null,
  created_at: '2026-09-20T12:00:00Z',
});
const listRow = (id: string, planId: string | null, confirmedAt: string | null = null) => ({
  id, user_id: U, plan_id: planId, name: planId ? `Week of ${WEEK}` : 'Costco run', created_at: `${WEEK}T09:30:00Z`, updated_at: `${WEEK}T09:30:00Z`, confirmed_at: confirmedAt,
});
const itemRow = (id: string, listId: string, name: string, source = 'plan') => ({
  id, list_id: listId, user_id: U, name, qty: '1', aisle: 'Produce', checked: false, have: false, source, from_meal_ids: [], edited: false, position: 0, created_at: `${WEEK}T09:30:00Z`,
});
const listDefaults = {
  shopping_lists: { name: '', plan_id: null, confirmed_at: null, updated_at: new Date().toISOString() },
  shopping_items: { qty: '', aisle: 'Other', checked: false, have: false, source: 'manual', from_meal_ids: [], edited: false, position: 0 },
};

/** mp-241's example: this week has a confirmed plan, a draft in Monday's conversation, one in Wednesday's, and one on the
 *  Plan tab; each has its list. The athlete also has a hand-made list and an earlier week's confirmed plan's list. */
function account() {
  const earlierWeek = addDays(WEEK, -7);
  const v = testCtx({
    meal_plans: [
      planRow(OLD_CONFIRMED, WEEK, 'confirmed', { confirmed_at: `${WEEK}T08:00:00Z` }),
      planRow(MONDAY_DRAFT, WEEK, 'draft', { conversation_id: MONDAY_CONV }),
      planRow(WEDNESDAY_DRAFT, WEEK, 'draft', { conversation_id: WEDNESDAY_CONV }),
      planRow(TAB_DRAFT, WEEK, 'draft'),
      planRow(EARLIER, earlierWeek, 'archived', { confirmed_at: `${earlierWeek}T08:00:00Z` }),
    ],
    plan_meals: [
      mealRow('m1', OLD_CONFIRMED, 'D-001'), mealRow('m2', MONDAY_DRAFT, 'D-002'), mealRow('m3', WEDNESDAY_DRAFT, 'D-003'),
      mealRow('m4', TAB_DRAFT, 'D-004'), mealRow('m5', EARLIER, 'D-005'),
    ],
    shopping_lists: [
      listRow('L-confirmed', OLD_CONFIRMED, `${WEEK}T08:00:00Z`),
      listRow('L-monday', MONDAY_DRAFT),
      listRow('L-wednesday', WEDNESDAY_DRAFT),
      listRow('L-tab', TAB_DRAFT),
      listRow('L-earlier', EARLIER, `${earlierWeek}T08:00:00Z`),
      listRow('L-hand', null),
    ],
    shopping_items: [
      itemRow('i1', 'L-confirmed', 'Rice'), itemRow('i2', 'L-monday', 'Eggs'), itemRow('i3', 'L-wednesday', 'Oats'),
      itemRow('i4', 'L-tab', 'Kale'), itemRow('i5', 'L-earlier', 'Beans'), itemRow('i6', 'L-hand', 'Coffee', 'manual'),
    ],
    meal_library: ['D-001', 'D-002', 'D-003', 'D-004', 'D-005'].map((id) => ({ id, name: id, meal_type: 'dinner', contexts: [], batch: true, kcal: 650, carbs_g: 70, protein_g: 35, fat_g: 18, ingredients: 'rice', source: 'the library' })),
  }, {
    defaults: listDefaults,
    rpc: {
      // What the SQL function does: archive the week's other plans, confirm the target, stamp confirmed_at once.
      confirm_meal_plan: (args: { p_plan_id: string; p_shopping: unknown }) => {
        const rows = v.fake.rows('meal_plans');
        const target = rows.find((r) => r.id === args.p_plan_id)!;
        for (const r of rows) if (r.week_start === target.week_start && r.id !== target.id && r.status !== 'archived') r.status = 'archived';
        target.status = 'confirmed'; target.confirmed_at ??= new Date().toISOString(); target.shopping = args.p_shopping;
        return target;
      },
    },
  });
  return v;
}

const listIds = (v: ReturnType<typeof account>) => v.fake.rows('shopping_lists').map((r) => r.id).sort();
const itemLists = (v: ReturnType<typeof account>) => [...new Set(v.fake.rows('shopping_items').map((r) => r.list_id))].sort();

Deno.test("confirm: the week's other drafts lose their lists; the replaced confirmed plan's list, the new plan's list and a hand-made list stay (mp-241)", async () => {
  const v = account();
  await confirmPlan(v, { conversationId: WEDNESDAY_CONV });
  assertEquals(listIds(v), ['L-confirmed', 'L-earlier', 'L-hand', 'L-wednesday']);
  // The deleted lists' rows are gone; the kept lists' rows are not touched (Wednesday's are rebuilt by the confirm).
  assertEquals(itemLists(v).filter((id) => id !== 'L-wednesday'), ['L-confirmed', 'L-earlier', 'L-hand']);
  const wednesday = v.fake.rows('shopping_lists').find((r) => r.id === 'L-wednesday')!;
  assertEquals(wednesday.confirmed_at != null, true, 'the confirmed plan keeps its list, now confirmed');
});

Deno.test('new_plan on a draft: the draft is archived and its list is deleted', async () => {
  const v = account();
  await newPlan(v, { conversationId: MONDAY_CONV });
  assertEquals(v.fake.rows('meal_plans').find((r) => r.id === MONDAY_DRAFT)!.status, 'archived');
  assertEquals(listIds(v), ['L-confirmed', 'L-earlier', 'L-hand', 'L-tab', 'L-wednesday']);
  assertEquals(itemLists(v).includes('L-monday'), false);
});

Deno.test('new_plan on the confirmed plan: it is archived but keeps its list (it was confirmed)', async () => {
  const v = account();
  await newPlan(v, { planId: OLD_CONFIRMED });
  assertEquals(v.fake.rows('meal_plans').find((r) => r.id === OLD_CONFIRMED)!.status, 'archived');
  assertEquals(listIds(v).includes('L-confirmed'), true);
  assertEquals(listIds(v).length, 6);
});

Deno.test("use_plan_again: the Plan tab's draft it replaces loses its list; conversation drafts and the confirmed plan keep theirs", async () => {
  const v = account();
  const copy = await usePlanAgain(v, EARLIER);
  assertEquals(v.fake.rows('meal_plans').find((r) => r.id === TAB_DRAFT)!.status, 'archived');
  const ids = listIds(v);
  assertEquals(ids.includes('L-tab'), false);
  for (const kept of ['L-confirmed', 'L-monday', 'L-wednesday', 'L-earlier', 'L-hand']) assertEquals(ids.includes(kept), true, kept);
  // The copy is a live draft and builds its own list.
  assertEquals(v.fake.rows('shopping_lists').some((r) => r.plan_id === copy.id), true);
});

Deno.test('dropArchivedDraftLists: a list marked confirmed is kept even when its plan lacks confirmed_at (pre-backfill plans)', async () => {
  const v = account();
  const rows = v.fake.rows('meal_plans');
  for (const r of rows) if (r.id === MONDAY_DRAFT || r.id === TAB_DRAFT) r.status = 'archived';
  v.fake.rows('shopping_lists').find((r) => r.id === 'L-tab')!.confirmed_at = `${WEEK}T07:00:00Z`;
  const dropped = await dropArchivedDraftLists(v, WEEK);
  assertEquals(dropped, 1);
  assertEquals(listIds(v), ['L-confirmed', 'L-earlier', 'L-hand', 'L-tab', 'L-wednesday']);
  // Idempotent: nothing left to drop.
  assertEquals(await dropArchivedDraftLists(v, WEEK), 0);
});
