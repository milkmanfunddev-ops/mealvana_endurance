/**
 * Ticket 73 (testing-wave, Finding 17-002) at the server seam: plans are a list (mp-675). From Previous plans the athlete
 * opens an earlier plan and can rename it, delete it, or use it again; a draft that was never confirmed is not listed
 * (mp-677). Example from the ruling: the draft fc9687ff, made after that week's plan f2c0bc78 was confirmed, does not
 * appear; f2c0bc78 does.
 *
 * Ticket 162 (Lee 2026-09-28, 89-006): Use this plan again confirms at once. The copy is this week's confirmed plan,
 * the plan it replaces is archived as on any confirm, its list is built, and no draft row is left anywhere.
 *
 * Rows are producer-shaped: what `meal_plans` / `plan_meals` / `meal_library` return, snake_case and all. `confirmed_at`
 * is the column migration 20260925150000 adds and `confirm_meal_plan` stamps; a plan a later plan replaced is archived
 * with it set, a draft archived by another plan's confirm is archived without it.
 */
import { assert, assertEquals, assertRejects } from 'https://deno.land/std@0.177.1/testing/asserts.ts';
import { listPlans, usePlanAgain, renamePlan, getPlanById, setServings } from '../../_shared/vana/plan.ts';
import { deletePlan } from '../../_shared/vana/writes.ts';
import { extraAction } from '../../_shared/vana/actions.ts';
import { IDEMPOTENT_ACTIONS } from '../../_shared/vana/idempotency.ts';
import { addDays, today, weekStartFor } from '../../_shared/vana/env.ts';
import { testCtx, TEST_USER_ID } from './support/vana_ctx.ts';

const U = TEST_USER_ID;
const WS = weekStartFor(today());
const THIS_WEEK = 'aaaaaaaa-0000-4000-8000-000000000001';
const SEP14 = 'aaaaaaaa-0000-4000-8000-000000000014';     // a confirmed plan a later plan replaced (archived, confirmed_at set)
const LEFTOVER = 'fc9687ff-0000-4000-8000-000000000000';  // 17-002: a draft made after its week's plan was confirmed
const SWEPT = 'aaaaaaaa-0000-4000-8000-0000000000d2';     // a draft another plan's confirm archived, never confirmed itself
const CONFIRMED_OLD = 'f2c0bc78-0000-4000-8000-000000000000';

const planRow = (id: string, weekStart: string, status: string, over: Record<string, unknown> = {}) => ({
  id, user_id: U, week_start: weekStart, status, batch_cooking: true, conversation_id: null, brief: null, rules: [], shopping: [], days: {},
  day_notes: {}, day_notes_stale: false, is_deleted: false, name: null, confirmed_at: null,
  created_at: `${weekStart}T09:00:00Z`, updated_at: `${weekStart}T09:00:00Z`, ...over,
});
const mealRow = (id: string, planId: string, libraryId: string, name: string, servings: number, position: number) => ({
  id, plan_id: planId, user_id: U, source: 'library', library_meal_id: libraryId, saved_meal_id: null, name, meal_type: 'dinner', session: 'cook-sun',
  servings, servings_left: Math.max(0, servings - 1), kcal: 650, carbs_g: 70, protein_g: 35, fat_g: 18, swaps_applied: [], comments: [], position, icon: null,
  created_at: '2026-09-14T12:00:00Z',
});
const lib = (id: string, name: string) => ({ id, name, meal_type: 'dinner', contexts: [], batch: true, kcal: 650, carbs_g: 70, protein_g: 35, fat_g: 18, ingredients: 'rice', source: 'the library' });

const listDefaults = {
  shopping_lists: { name: '', plan_id: null, confirmed_at: null, updated_at: new Date().toISOString() },
  shopping_items: { qty: '', aisle: 'Other', checked: false, have: false, source: 'manual', from_meal_ids: [], edited: false, position: 0 },
};

function account() {
  const sep14 = addDays(WS, -21);
  const sep13 = addDays(WS, -14);
  const v: ReturnType<typeof testCtx> = testCtx({
    meal_plans: [
      planRow(THIS_WEEK, WS, 'confirmed', { confirmed_at: `${WS}T10:00:00Z` }),
      planRow(SEP14, sep14, 'archived', { name: 'Race block', confirmed_at: `${sep14}T10:00:00Z` }),
      planRow(CONFIRMED_OLD, sep13, 'confirmed', { confirmed_at: `${sep13}T00:27:00Z` }),
      planRow(LEFTOVER, sep13, 'draft', { updated_at: `${sep13}T23:52:00Z` }),
      planRow(SWEPT, sep14, 'archived', { updated_at: `${sep14}T11:00:00Z` }),
    ],
    plan_meals: [
      mealRow('t1', THIS_WEEK, 'D-100', 'Salmon traybake', 4, 0),
      mealRow('s1', SEP14, 'D-001', 'Lentil bolognese', 3, 0),
      mealRow('s2', SEP14, 'D-002', 'Chicken rice bowl', 4, 1),
      mealRow('s3', SEP14, 'D-003', 'Tofu stir fry', 2, 2),
      mealRow('s4', SEP14, 'D-004', 'Mushroom risotto', 3, 3),
      mealRow('c1', CONFIRMED_OLD, 'D-005', 'Mushroom risotto', 4, 0),
      mealRow('l1', LEFTOVER, 'D-006', 'Quinoa, mixed veg & walnuts', 9, 0),
      mealRow('w1', SWEPT, 'D-007', 'Pesto pasta', 2, 0),
    ],
    meal_library: [lib('D-001', 'Lentil bolognese'), lib('D-002', 'Chicken rice bowl'), lib('D-003', 'Tofu stir fry'), lib('D-004', 'Mushroom risotto'), lib('D-005', 'Mushroom risotto'), lib('D-100', 'Salmon traybake')],
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

// ---------------------------------------------------------------- drafts are not listed (mp-677)
Deno.test('listPlans: confirmed plans are listed, including ones a later plan replaced; a never-confirmed draft is not (17-002)', async () => {
  const out = await listPlans(account());
  assertEquals(out.map((p) => p.id), [THIS_WEEK, CONFIRMED_OLD, SEP14]);
  assertEquals(out.find((p) => p.id === SEP14)?.name, 'Race block');
  assertEquals(out.find((p) => p.id === CONFIRMED_OLD)?.name, null);
});

// ---------------------------------------------------------------- use again (mp-675, ticket 162: confirms at once)
Deno.test('usePlanAgain: the copy is this week\'s confirmed plan with the earlier plan\'s name and meals; the earlier plan is as it was', async () => {
  const v = account();
  const copy = await usePlanAgain(v, SEP14);

  assert(copy.id !== SEP14 && copy.id !== THIS_WEEK);
  assertEquals(copy.weekStart, WS);
  assertEquals(copy.status, 'confirmed');
  assertEquals(copy.name, 'Race block');
  assertEquals(copy.meals.map((m) => [m.name, m.servings, m.servingsLeft]), [['Lentil bolognese', 3, 3], ['Chicken rice bowl', 4, 4], ['Tofu stir fry', 2, 2], ['Mushroom risotto', 3, 3]]);
  // Confirmed, so its list is built and confirmed with it (110-012).
  const list = v.fake.rows('shopping_lists').find((r) => r.plan_id === copy.id);
  assertEquals(list != null && list.confirmed_at != null, true, 'the copy has a confirmed list');

  // The earlier plan keeps its four meals and stays where it was in the list.
  const before = (await getPlanById(v, SEP14))!;
  assertEquals(before.status, 'archived');
  assertEquals(before.meals.map((m) => m.id), ['s1', 's2', 's3', 's4']);
  // The plan this week had is replaced: archived with its confirmed_at, so it stays listed (mp-674).
  const replaced = (await getPlanById(v, THIS_WEEK))!;
  assertEquals(replaced.status, 'archived');
  assertEquals(v.fake.rows('meal_plans').find((r) => r.id === THIS_WEEK)!.confirmed_at != null, true);
  // The list leads with the copy; the replaced plan and the earlier ones follow.
  assertEquals((await listPlans(v)).map((p) => p.id), [copy.id, THIS_WEEK, CONFIRMED_OLD, SEP14]);
  // No draft row was left anywhere in the week.
  assertEquals(v.fake.rows('meal_plans').filter((r) => r.week_start === WS && r.status === 'draft'), []);
});

Deno.test('usePlanAgain: a conversation\'s live draft in the week is archived like any confirm archives it (mp-241)', async () => {
  const v = account();
  const CONVO_DRAFT = 'cccccccc-0000-4000-8000-000000000001';
  v.fake.tables.meal_plans.push(planRow(CONVO_DRAFT, WS, 'draft', { conversation_id: 'conv-1', updated_at: `${WS}T11:00:00Z` }));

  const copy = await usePlanAgain(v, SEP14);
  assertEquals(copy.status, 'confirmed');
  assertEquals((await getPlanById(v, CONVO_DRAFT))!.status, 'archived');
  // Nothing in an earlier week moved.
  assertEquals((await getPlanById(v, LEFTOVER))!.status, 'draft');
});

Deno.test('usePlanAgain twice: each copy confirms and replaces the one before; the week holds one confirmed plan', async () => {
  const v = account();
  const first = await usePlanAgain(v, SEP14);
  const second = await usePlanAgain(v, CONFIRMED_OLD);
  assert(first.id !== second.id);
  const live = v.fake.tables.meal_plans.filter((r) => r.week_start === WS && r.status !== 'archived').map((r) => r.id);
  assertEquals(live, [second.id]);
  assertEquals((await getPlanById(v, first.id))!.status, 'archived');
});

Deno.test('usePlanAgain with no plan this week: confirms the copy the same way, nothing to replace', async () => {
  const v = account();
  v.fake.tables.meal_plans = v.fake.tables.meal_plans.filter((r) => r.id !== THIS_WEEK);
  const copy = await usePlanAgain(v, SEP14);
  assertEquals([copy.status, copy.weekStart, copy.meals.length], ['confirmed', WS, 4]);
  assertEquals((await listPlans(v)).map((p) => p.id), [copy.id, CONFIRMED_OLD, SEP14]);
});

Deno.test('usePlanAgain: a meal the library no longer has is left out rather than copied blind', async () => {
  const v = account();
  v.fake.tables.meal_library = v.fake.tables.meal_library.filter((m) => m.id !== 'D-003');
  const copy = await usePlanAgain(v, SEP14);
  assertEquals(copy.meals.map((m) => m.name), ['Lentil bolognese', 'Chicken rice bowl', 'Mushroom risotto']);
});

Deno.test('usePlanAgain: a plan whose meals cannot be copied confirms nothing and leaves no row behind', async () => {
  const v = account();
  v.fake.tables.meal_library = v.fake.tables.meal_library.filter((m) => m.id !== 'D-005');
  const rows = v.fake.tables.meal_plans.length;
  await assertRejects(() => usePlanAgain(v, CONFIRMED_OLD), Error, 'no meals');
  assertEquals((await getPlanById(v, THIS_WEEK))!.status, 'confirmed');
  assertEquals(v.fake.tables.meal_plans.filter((r) => r.is_deleted !== true).length, rows);
});

Deno.test('usePlanAgain: a plan that is not there says so', async () => {
  await assertRejects(() => usePlanAgain(account(), 'nope'), Error, 'plan not found');
});

// ---------------------------------------------------------------- delete, rename, edit
Deno.test('delete removes a plan from the list', async () => {
  const v = account();
  await deletePlan(v, SEP14, null, true);
  assertEquals((await listPlans(v)).map((p) => p.id), [THIS_WEEK, CONFIRMED_OLD]);
  assertEquals(await getPlanById(v, SEP14), null);
});

Deno.test('renamePlan: trims the name; an empty name clears it back to the week', async () => {
  const v = account();
  assertEquals((await renamePlan(v, CONFIRMED_OLD, '  Taper   week ')).name, 'Taper week');
  assertEquals((await listPlans(v)).find((p) => p.id === CONFIRMED_OLD)?.name, 'Taper week');
  assertEquals((await renamePlan(v, CONFIRMED_OLD, '   ')).name, null);
  await assertRejects(() => renamePlan(v, 'nope', 'x'), Error, 'plan not found');
});

Deno.test('an earlier plan\'s servings are edited in place, on that plan', async () => {
  const v = account();
  const out = await setServings(v, 's2', 6);
  assertEquals(out.id, SEP14);
  assertEquals(out.meals.find((m) => m.id === 's2')?.servings, 6);
});

// ---------------------------------------------------------------- the vana-action wiring
// use_plan_again fires the day-notes refresh under waitUntil (like confirm_plan); its fetch outlives the test.
Deno.test({ name: 'vana-action: rename_plan and use_plan_again answer a batch part with the plan', sanitizeOps: false, sanitizeResources: false, fn: async () => {
  const v = account();
  const renamed = await extraAction(v, 'rename_plan', { id: SEP14, name: 'Build week' });
  assertEquals((renamed!.parts[0] as unknown as { plan: { id: string; name: string } }).plan.name, 'Build week');
  const again = await extraAction(v, 'use_plan_again', { id: SEP14 });
  const plan = (again!.parts[0] as unknown as { kind: string; plan: { weekStart: string; status: string; meals: unknown[] } });
  assertEquals([plan.kind, plan.plan.weekStart, plan.plan.status, plan.plan.meals.length], ['batch', WS, 'confirmed', 4]);
  // Like confirm_plan, the shopping list rides along as its own part: the app lands on Shopping.
  assertEquals(again!.parts[1]?.kind, 'shopping_list');
} });

Deno.test('vana-action: use_plan_again is deduped by requestId, so a double tap or a retry after a timeout confirms one copy', () => {
  assert(IDEMPOTENT_ACTIONS.has('use_plan_again'));
});
