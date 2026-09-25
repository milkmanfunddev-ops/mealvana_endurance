/** Testing-wave ticket 127: a plan edit's list is the plan's list in every way.
 *  - 89-004: a list rebuilt by an edit on a confirmed (or once-confirmed) plan carries `confirmed_at`, like Rebuild's.
 *  - 88-019: a deleted plan's list leaves the Shopping tab and Previous lists, and Undo brings it back.
 *  Rows are producer-shaped (`meal_plans`, `plan_meals`, `meal_library.ingredients_json`) over the fake db. */
import { assert, assertEquals } from 'https://deno.land/std@0.177.1/testing/asserts.ts';
import { extraAction, runAction } from '../../_shared/vana/actions.ts';
import { currentWeekStart } from '../../_shared/vana/plan.ts';
import { ShoppingListDetailZ, ShoppingListSummaryZ } from '../../_shared/vana/schemas.ts';
import { testCtx, TEST_USER_ID } from './support/vana_ctx.ts';

const U = TEST_USER_ID;
const PLAN = 'f2c0bc78-0000-4000-8000-000000000000';
const HAND = 'hand-made-list';
const listDefaults = { shopping_lists: { name: '', plan_id: null, confirmed_at: null, updated_at: new Date().toISOString() }, shopping_items: { qty: '', aisle: 'Other', checked: false, have: false, source: 'manual', from_meal_ids: [], edited: false, position: 0 } };
const ctx = (tables = {}) => testCtx(tables, { defaults: listDefaults });

async function week(status: 'confirmed' | 'draft' | 'archived', confirmedAt: string | null, withHandMade = false) {
  const week = await currentWeekStart(ctx());
  const meal = (id: string, lib: string, name: string, position: number) => ({
    id, plan_id: PLAN, user_id: U, source: 'library', library_meal_id: lib, saved_meal_id: null, name, meal_type: 'dinner', session: 'cook-sun',
    servings: 4, servings_left: 4, kcal: 650, carbs_g: 70, protein_g: 35, fat_g: 18, swaps_applied: [], comments: [], position, icon: null, created_at: `${week}T09:00:00Z`,
  });
  return ctx({
    meal_plans: [{ id: PLAN, user_id: U, week_start: week, status, batch_cooking: true, conversation_id: null, brief: null, rules: [], shopping: [], days: {}, day_notes: {}, day_notes_stale: false, is_deleted: false, name: null, confirmed_at: confirmedAt, created_at: `${week}T09:00:00Z`, updated_at: `${week}T10:00:00Z` }],
    plan_meals: [meal('pm1', 'D-1', 'Seitan bowl', 0), meal('pm2', 'D-2', 'Toast with peanut butter', 1)],
    meal_library: [
      { id: 'D-1', name: 'Seitan bowl', ingredients_json: [{ name: 'Seitan', qty: '150 g' }, { name: 'Rice', qty: '80 g' }] },
      { id: 'D-2', name: 'Toast with peanut butter', ingredients_json: [{ name: 'Bread', qty: '2 slices' }, { name: 'Peanut butter', qty: '1 tbsp' }] },
    ],
    // A list made before this week's plan, so the plan's list sorts first while it is there.
    shopping_lists: withHandMade ? [{ id: HAND, user_id: U, plan_id: null, name: 'Costco run', confirmed_at: null, created_at: '2020-01-01T00:00:00Z' }] : [],
  });
}
const act = (v: ReturnType<typeof ctx>, type: string, payload: Record<string, unknown>) => runAction(v, { type, payload } as Parameters<typeof runAction>[1]);
const planList = (v: ReturnType<typeof ctx>) => v.fake.rows('shopping_lists').find((l) => l.plan_id === PLAN);
const rowNames = (v: ReturnType<typeof ctx>, listId: unknown) => v.fake.rows('shopping_items').filter((i) => i.list_id === listId).map((i) => String(i.name)).sort();

// ---- 89-004

Deno.test('set_servings on a confirmed plan rebuilds its list with confirmed_at, like Rebuild (89-004)', async () => {
  const v = await week('confirmed', '2026-09-20T10:00:00Z');
  await act(v, 'set_servings', { planMealId: 'pm1', servings: 5 });
  const list = planList(v);
  assert(list, 'the edit built the plan\'s list');
  assert(list.confirmed_at != null, 'an edit-built list of a confirmed plan is confirmed');
});

Deno.test('remove_meal on a confirmed plan drops the meal\'s rows and leaves the list confirmed (88-003, 89-004)', async () => {
  const v = await week('confirmed', '2026-09-20T10:00:00Z');
  await extraAction(v, 'rebuild_shopping_list', { planId: PLAN });
  const stamped = planList(v)!.confirmed_at;
  await act(v, 'remove_meal', { planMealId: 'pm2' });
  const list = planList(v)!;
  assertEquals(rowNames(v, list.id), ['Rice', 'Seitan']);
  assertEquals(list.confirmed_at, stamped, 'a list that has its stamp keeps it');
});

Deno.test('an edit on an archived plan that was once confirmed stamps its list too (89-004)', async () => {
  const v = await week('archived', '2026-09-13T10:00:00Z');
  await act(v, 'set_servings', { planMealId: 'pm1', servings: 2 });
  assert(planList(v)?.confirmed_at != null);
});

Deno.test('an edit on a draft leaves its list unconfirmed', async () => {
  const v = await week('draft', null);
  await act(v, 'set_servings', { planMealId: 'pm1', servings: 2 });
  const list = planList(v);
  assert(list);
  assertEquals(list.confirmed_at, null);
});

// ---- 88-019

const listed = async (v: ReturnType<typeof ctx>) => ((await extraAction(v, 'list_shopping_lists', {}))!.lists as unknown[]).map((l) => ShoppingListSummaryZ.parse(l).id);
const shown = async (v: ReturnType<typeof ctx>, id?: string) => {
  const list = (await extraAction(v, 'get_shopping_list', id ? { id } : {}))!.list;
  return list == null ? null : ShoppingListDetailZ.parse(list).id;
};

Deno.test("delete_plan hides the plan's list from list_shopping_lists and get_shopping_list; Undo brings it back (88-019)", async () => {
  const v = await week('confirmed', '2026-09-20T10:00:00Z', true);
  await extraAction(v, 'rebuild_shopping_list', { planId: PLAN });
  const listId = String(planList(v)!.id);
  assertEquals(await listed(v), [listId, HAND]);
  assertEquals(await shown(v), listId);

  const deleted = await extraAction(v, 'delete_plan', { id: PLAN });
  assertEquals(await listed(v), [HAND], 'Previous lists no longer offers the deleted plan\'s list');
  assertEquals(await shown(v), HAND, 'the tab falls back to the next default');
  assertEquals(await shown(v, listId), HAND, 'a tab still holding the list id is moved off it');

  const receipt = deleted!.parts[0] as { undo?: { params: Record<string, unknown> } };
  await extraAction(v, 'undo_receipt', receipt.undo!.params);
  assertEquals(await listed(v), [listId, HAND]);
  assertEquals(await shown(v), listId);
  assertEquals(await shown(v, listId), listId);
});

Deno.test('delete_plan with no other list leaves the Shopping tab empty', async () => {
  const v = await week('confirmed', '2026-09-20T10:00:00Z');
  await extraAction(v, 'rebuild_shopping_list', { planId: PLAN });
  await extraAction(v, 'delete_plan', { id: PLAN });
  assertEquals(await listed(v), []);
  assertEquals(await shown(v), null);
});
