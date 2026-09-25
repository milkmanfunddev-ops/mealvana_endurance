/** Several shopping lists (2026-09-16): the merge rule that keeps a hand-added or hand-edited line through a re-plan,
 *  and the wire shape of every shopping action, over the fake db. */
import { assertEquals, assert, assertRejects } from 'https://deno.land/std@0.177.1/testing/asserts.ts';
import { mergePlanItems, syncPlanList, toItem } from '../../_shared/vana/shopping.ts';
import { extraAction } from '../../_shared/vana/actions.ts';
import { ShoppingListDetailZ, ShoppingListSummaryZ, ActionResultZ } from '../../_shared/vana/schemas.ts';
import type { ShoppingItem, ShoppingListItem } from '../../_shared/vana/contracts.ts';
import { testCtx, TEST_USER_ID } from './support/vana_ctx.ts';
import { currentWeekStart } from '../../_shared/vana/plan.ts';

const U = TEST_USER_ID;
const plain = (name: string, over: Partial<ShoppingItem> = {}): ShoppingItem => ({ aisle: 'Produce', name, qty: '1', checked: false, have: false, fromMealIds: ['m1'], ...over });
const row = (id: string, name: string, over: Partial<ShoppingListItem> = {}): ShoppingListItem => ({ id, listId: 'L', ...plain(name), source: 'plan', edited: false, position: 0, ...over });
const listDefaults = { shopping_lists: { name: '', plan_id: null, confirmed_at: null, updated_at: new Date().toISOString() }, shopping_items: { qty: '', aisle: 'Other', checked: false, have: false, source: 'manual', from_meal_ids: [], edited: false, position: 0 } };
const ctx = (tables = {}) => testCtx(tables, { defaults: listDefaults });

Deno.test('merge: manual and edited rows survive a plan change; plain plan rows are replaced', () => {
  const prev = [row('a', 'Broccoli'), row('b', 'Eggs', { source: 'manual' }), row('c', 'Chicken thighs', { edited: true, qty: '2 lb' }), row('d', 'Rice')];
  const fresh = [plain('Broccoli', { qty: '2' }), plain('Salmon')];
  const { keep, insert, drop } = mergePlanItems(prev, fresh);
  assertEquals(keep.map((k) => k.id), ['b', 'c']);
  assertEquals(insert.map((i) => i.name), ['Broccoli', 'Salmon']);
  assertEquals(insert[0].qty, '2');
  assertEquals(drop, ['a', 'd']);
});

Deno.test('merge: checked / have carry over by name from the row being replaced', () => {
  const prev = [row('a', 'Broccoli', { checked: true }), row('b', 'Rice', { have: true })];
  const { insert } = mergePlanItems(prev, [plain('broccoli'), plain('Rice'), plain('Oats')]);
  assertEquals(insert.map((i) => [i.name, i.checked, i.have]), [['broccoli', true, false], ['Rice', false, true], ['Oats', false, false]]);
});

Deno.test('merge: a fresh line whose name a kept row already carries is not doubled', () => {
  const prev = [row('b', 'Eggs', { source: 'manual', qty: '12' })];
  const { keep, insert } = mergePlanItems(prev, [plain('Eggs', { qty: '4' })]);
  assertEquals(keep.length, 1); assertEquals(insert.length, 0);
});

Deno.test('syncPlanList: makes the plan list once, replaces plan rows, keeps the hand-added row, answers plain lines', async () => {
  const v = ctx();
  const plan = { id: 'p1', weekStart: '2026-09-13', status: 'draft' };
  const first = await syncPlanList(v, plan, [plain('Broccoli'), plain('Rice')]);
  assertEquals(first.map((i) => i.name), ['Broccoli', 'Rice']);
  const lists = v.fake.rows('shopping_lists'); assertEquals(lists.length, 1); assertEquals(lists[0].plan_id, 'p1'); assertEquals(lists[0].name, 'Week of 2026-09-13');
  const listId = String(lists[0].id);
  await v.db.from('shopping_items').insert({ list_id: listId, user_id: U, name: 'Coffee', qty: '1 bag', aisle: 'Beverages', source: 'manual' });
  const second = await syncPlanList(v, plan, [plain('Salmon')]);
  assertEquals(v.fake.rows('shopping_lists').length, 1);
  assertEquals(second.map((i) => i.name), ['Salmon', 'Coffee']);
  assertEquals(v.fake.rows('shopping_items').map((r) => [r.name, r.source]), [['Coffee', 'manual'], ['Salmon', 'plan']]);
});

Deno.test('actions: create → add → update → delete → get → list, each answering the contract shape', async () => {
  const v = ctx();
  const created = await extraAction(v, 'create_shopping_list', { name: 'Costco run' });
  assert(created); ActionResultZ.parse(created);
  const list = ShoppingListDetailZ.parse(created.list);
  assertEquals(list.name, 'Costco run'); assertEquals(list.planId, null); assertEquals(list.items, []);

  const added = ShoppingListDetailZ.parse((await extraAction(v, 'add_shopping_item', { listId: list.id, name: 'Chicken breast', qty: '2 lb' }))!.list);
  assertEquals(added.items.length, 1); assertEquals(added.items[0].aisle, 'Protein'); assertEquals(added.items[0].source, 'manual'); assertEquals(added.itemCount, 1);

  const item = added.items[0];
  const renamed = ShoppingListDetailZ.parse((await extraAction(v, 'update_shopping_item', { id: item.id, name: 'Chicken thighs', checked: true }))!.list);
  assertEquals(renamed.items[0].name, 'Chicken thighs'); assertEquals(renamed.items[0].edited, true); assertEquals(renamed.items[0].checked, true);
  const ticked = ShoppingListDetailZ.parse((await extraAction(v, 'update_shopping_item', { id: item.id, checked: false }))!.list);
  assertEquals(ticked.items[0].checked, false);

  const gone = ShoppingListDetailZ.parse((await extraAction(v, 'delete_shopping_item', { id: item.id }))!.list);
  assertEquals(gone.items, []);

  const got = ShoppingListDetailZ.parse((await extraAction(v, 'get_shopping_list', {}))!.list);
  assertEquals(got.id, list.id);
  const named = ShoppingListDetailZ.parse((await extraAction(v, 'rename_shopping_list', { id: list.id, name: 'Sunday shop' }))!.list);
  assertEquals(named.name, 'Sunday shop');
  const lists = (await extraAction(v, 'list_shopping_lists', {}))!.lists as unknown[];
  assertEquals(lists.length, 1); ShoppingListSummaryZ.parse(lists[0]);
});

Deno.test('actions: the most recent list wins by coalesce(confirmed_at, created_at); an empty account answers null', async () => {
  const v = ctx({ shopping_lists: [
    { id: 'old', user_id: U, name: 'old', created_at: '2026-09-01T00:00:00Z', confirmed_at: '2026-09-15T00:00:00Z' },
    { id: 'new', user_id: U, name: 'new', created_at: '2026-09-10T00:00:00Z', confirmed_at: null },
  ] });
  assertEquals(((await extraAction(v, 'get_shopping_list', {}))!.list as { id: string }).id, 'old'); // confirmed later than the other was created
  assertEquals(((await extraAction(v, 'list_shopping_lists', {}))!.lists as { id: string }[]).map((l) => l.id), ['old', 'new']);
  assertEquals((await extraAction(ctx(), 'get_shopping_list', {}))!.list, null);
});

Deno.test('actions: deleting a plan-built row leaves a tombstone the merge keeps; name and qty edits set edited', async () => {
  const v = ctx({ shopping_lists: [{ id: 'L', user_id: U, plan_id: 'p1', name: 'w', created_at: '2026-09-13T00:00:00Z' }], shopping_items: [{ id: 'i1', list_id: 'L', user_id: U, name: 'Egg & veggie scramble', qty: '4 serving', aisle: 'Protein', source: 'plan' }], meal_plans: [{ id: 'p1', user_id: U, week_start: '2026-09-13', shopping: [] }] });
  const after = ShoppingListDetailZ.parse((await extraAction(v, 'delete_shopping_item', { id: 'i1' }))!.list);
  assertEquals(after.items.map((i) => [i.have, i.edited]), [[true, true]]); assertEquals(after.itemCount, 0);
  const { keep } = mergePlanItems(after.items, [plain('Egg & veggie scramble')]);
  assertEquals(keep.length, 1);
  // the mirror followed
  assertEquals((v.fake.rows('meal_plans')[0].shopping as ShoppingItem[]).map((i) => i.have), [true]);
  const q = ShoppingListDetailZ.parse((await extraAction(v, 'update_shopping_item', { id: 'i1', qty: '8 eggs' }))!.list);
  assertEquals(q.items[0].qty, '8 eggs');
  await assertRejects(() => extraAction(v, 'update_shopping_item', { id: 'i1', name: '  ' }), Error, 'name required');
  assertEquals(toItem(v.fake.rows('shopping_items')[0]).source, 'plan');
});

Deno.test('actions: delete_shopping_list takes the rows with it, empties a plan mirror, answers the most recent list left, then null', async () => {
  const v = ctx({
    shopping_lists: [
      { id: 'a', user_id: U, name: 'a', created_at: '2026-09-01T00:00:00Z' },
      { id: 'b', user_id: U, name: 'b', plan_id: 'p1', created_at: '2026-09-10T00:00:00Z' },
      { id: 'x', user_id: 'someone-else', name: 'x', created_at: '2026-09-12T00:00:00Z' },
    ],
    shopping_items: [
      { id: 'i1', list_id: 'b', user_id: U, name: 'Eggs', source: 'plan' },
      { id: 'i2', list_id: 'a', user_id: U, name: 'Oats' },
    ],
    meal_plans: [{ id: 'p1', user_id: U, week_start: '2026-09-13', shopping: [plain('Eggs')] }],
  });
  const after = await extraAction(v, 'delete_shopping_list', { id: 'b' });
  assert(after); ActionResultZ.parse(after);
  assertEquals(ShoppingListDetailZ.parse(after.list).id, 'a');
  assertEquals(v.fake.rows('shopping_items').map((r) => r.id), ['i2']);
  assertEquals(v.fake.rows('meal_plans')[0].shopping, []);
  // another athlete's list is not this athlete's to delete
  await assertRejects(() => extraAction(v, 'delete_shopping_list', { id: 'x' }), Error, 'not found');
  assertEquals((await extraAction(v, 'delete_shopping_list', { id: 'a' }))!.list, null);
  assertEquals(v.fake.rows('shopping_lists').map((r) => r.id), ['x']);
});

// ---- ticket 35 (Findings 19-001, 18-002, 19-006): the tab's default list is the confirmed plan's (mp-244).

/** An account mid-week, as the Food tab sees it: this week's confirmed plan with its list, a newer draft's list (Browse
 *  and chat edits build one, mp-244), an archived draft's list, a newer hand-made list, and an older week's confirmed
 *  plan whose list was confirmed later than anything else. Every list but this week's confirmed one is "newer". */
async function midWeek(over: { dropConfirmedList?: boolean; noConfirmed?: boolean; noHandMade?: boolean } = {}) {
  const week = await currentWeekStart(ctx());
  const lists = [
    { id: 'confirmedList', user_id: U, plan_id: 'confirmed', name: `Week of ${week}`, created_at: '2026-09-20T10:00:00Z', confirmed_at: '2026-09-20T11:00:00Z' },
    { id: 'draftList', user_id: U, plan_id: 'draft', name: `Week of ${week}`, created_at: '2026-09-24T21:09:25Z' },
    { id: 'archivedList', user_id: U, plan_id: 'archived', name: `Week of ${week}`, created_at: '2026-09-24T09:00:00Z' },
    { id: 'handMade', user_id: U, name: 'List 2026-09-24', created_at: '2026-09-24T16:55:00Z' },
    { id: 'olderHandMade', user_id: U, name: 'List 2026-09-02', created_at: '2026-09-02T10:00:00Z' },
    { id: 'lastWeekList', user_id: U, plan_id: 'lastWeek', name: 'Week of 2020-01-05', created_at: '2020-01-05T10:00:00Z', confirmed_at: '2026-09-25T00:00:00Z' },
  ].filter((l) => !(over.dropConfirmedList && l.id === 'confirmedList') && !(over.noHandMade && ['handMade', 'olderHandMade'].includes(l.id)));
  const plans = [
    { id: 'confirmed', user_id: U, week_start: week, status: over.noConfirmed ? 'archived' : 'confirmed', is_deleted: false, shopping: [] },
    { id: 'draft', user_id: U, week_start: week, status: 'draft', conversation_id: 'c1', is_deleted: false, shopping: [] },
    { id: 'archived', user_id: U, week_start: week, status: 'archived', is_deleted: false, shopping: [] },
    { id: 'lastWeek', user_id: U, week_start: '2020-01-05', status: 'confirmed', is_deleted: false, shopping: [] },
  ];
  return ctx({ shopping_lists: lists, meal_plans: plans });
}
const defaultId = async (v: ReturnType<typeof ctx>) => ((await extraAction(v, 'get_shopping_list', {}))!.list as { id: string } | null)?.id ?? null;
const firstListed = async (v: ReturnType<typeof ctx>) => ((await extraAction(v, 'list_shopping_lists', {}))!.lists as { id: string }[])[0]?.id ?? null;

Deno.test("get_shopping_list{}: the confirmed plan's list wins over newer draft, archived and hand-made lists (19-001, 18-002, 19-006)", async () => {
  const v = await midWeek();
  assertEquals(await defaultId(v), 'confirmedList');
  // the lists' order agrees, so the tab marks the plan's list as the current one
  assertEquals(await firstListed(v), 'confirmedList');
  // a new hand-made list answers itself when made, but does not become the default
  const made = ShoppingListDetailZ.parse((await extraAction(v, 'create_shopping_list', {}))!.list);
  assert(made.id !== 'confirmedList');
  assertEquals(await defaultId(v), 'confirmedList');
  assertEquals(await firstListed(v), 'confirmedList');
});

Deno.test("delete_shopping_list on the confirmed plan's list answers the newest hand-made list, never an archived or draft plan's list (19-001)", async () => {
  const v = await midWeek();
  const after = await extraAction(v, 'delete_shopping_list', { id: 'confirmedList' });
  assertEquals(ShoppingListDetailZ.parse(after!.list).id, 'handMade');
  assertEquals(await defaultId(v), 'handMade');
  assertEquals(await firstListed(v), 'handMade');
  // with no hand-made list, the tab shows its empty state
  const bare = await midWeek({ noHandMade: true });
  assertEquals((await extraAction(bare, 'delete_shopping_list', { id: 'confirmedList' }))!.list, null);
  assertEquals(await defaultId(bare), null);
});

Deno.test("get_shopping_list{}: with no confirmed plan this week, the newest hand-made list, else null; a draft's or another week's list never", async () => {
  assertEquals(await defaultId(await midWeek({ noConfirmed: true })), 'handMade');
  assertEquals(await defaultId(await midWeek({ noConfirmed: true, noHandMade: true })), null);
  assertEquals(await defaultId(await midWeek({ dropConfirmedList: true })), 'handMade');
});
