/**
 * A repeated Vana write runs once (testing-wave 134, IMPROVEMENTS #82).
 *
 * The seam is `withRequestId` around the real `runAction` / `extraAction`: producer-shaped rows go into the fake
 * database, the claim RPCs below are the migration's semantics in TypeScript (first insert wins, a fresh `running`
 * claim refuses, a finished one answers its stored result, a failed run releases, a TTL-expired claim is taken over),
 * and what is asserted is how many times each write reached the table.
 *
 * Run: deno test --allow-read --allow-write --allow-env --allow-sys --node-modules-dir=none \
 *        supabase/functions/tests/vana/request_id.test.ts
 */
import { assert, assertEquals, assertRejects } from 'https://deno.land/std@0.177.1/testing/asserts.ts';
import { extraAction, runAction } from '../../_shared/vana/actions.ts';
import type { ActionResult } from '../../_shared/vana/actions.ts';
import { IDEMPOTENT_ACTIONS, RequestInProgressError, REQUEST_TTL_SECONDS, requestIdOf, withRequestId } from '../../_shared/vana/idempotency.ts';
import { saveLibraryMeal } from '../../_shared/vana/meals.ts';
import { today, weekStartFor } from '../../_shared/vana/env.ts';
import { testCtx, TEST_USER_ID } from './support/vana_ctx.ts';
import type { Row, Tables } from './support/fake_db.ts';

const U = TEST_USER_ID;
const PLAN = 'aaaaaaaa-0000-4000-8000-000000000134';
const REQ = '6d1f5b0e-3f0b-4a3e-9d2e-000000000001';

// ---------------------------------------------------------------- the claim RPCs, as the migration defines them
interface Claim { action_type: string; status: 'running' | 'done'; result: unknown; claimed_at: number }
function claimHandlers(now = () => Date.now()) {
  const rows = new Map<string, Claim>();
  const rpc = {
    vana_claim_action_request: ({ p_request_id, p_action_type, p_ttl_seconds }: { p_request_id: string; p_action_type: string; p_ttl_seconds: number }) => {
      const cur = rows.get(p_request_id);
      const stale = cur && cur.status === 'running' && cur.claimed_at < now() - (p_ttl_seconds ?? REQUEST_TTL_SECONDS) * 1000;
      if (!cur || stale) { rows.set(p_request_id, { action_type: p_action_type, status: 'running', result: null, claimed_at: now() }); return { claimed: true }; }
      return { claimed: false, status: cur.status, action_type: cur.action_type, result: cur.result };
    },
    vana_finish_action_request: ({ p_request_id, p_result }: { p_request_id: string; p_result: unknown }) => { const cur = rows.get(p_request_id); if (cur) { cur.status = 'done'; cur.result = p_result; } return null; },
    vana_release_action_request: ({ p_request_id }: { p_request_id: string }) => { const cur = rows.get(p_request_id); if (cur?.status === 'running') rows.delete(p_request_id); return null; },
  };
  return { rows, rpc };
}

// ---------------------------------------------------------------- producer-shaped fixtures
const planRow = (): Row => ({ id: PLAN, user_id: U, week_start: weekStartFor(today()), status: 'draft', batch_cooking: true, conversation_id: null, brief: null, rules: [], shopping: [], days: {}, day_notes: {}, day_notes_stale: false, is_deleted: false, created_at: '2026-09-26T09:00:00Z', updated_at: '2026-09-26T09:00:00Z' });
const mealRow = (id: string, libraryMealId: string, servings: number): Row => ({ id, plan_id: PLAN, user_id: U, source: 'library', library_meal_id: libraryMealId, saved_meal_id: null, name: libraryMealId, meal_type: 'dinner', session: null, servings, servings_left: servings, kcal: 700, carbs_g: 70, protein_g: 35, fat_g: 18, swaps_applied: [], comments: [], position: 0, icon: null, created_at: '2026-09-26T09:00:00Z' });
const libRow = (id: string): Row => ({ id, name: id, meal_type: 'dinner', contexts: [], batch: true, kcal: 650, carbs_g: 70, protein_g: 35, fat_g: 18, ingredients: 'rice', ingredients_json: [{ name: 'Rice', qty: '80 g' }], source: 'the library', icon: null });
const listDefaults = {
  shopping_lists: { name: '', plan_id: null, confirmed_at: null, updated_at: new Date().toISOString() },
  shopping_items: { qty: '', aisle: 'Other', checked: false, have: false, source: 'manual', from_meal_ids: [], edited: false, position: 0 },
  saved_meals: { is_deleted: false },
};
const world = (over: Partial<Tables> = {}): Tables => ({ meal_plans: [planRow()], plan_meals: [], meal_library: [libRow('D-001'), libRow('D-002')], saved_meals: [], meal_logs: [], user_memories: [], shopping_lists: [], shopping_items: [], pantry_items: [], ...over });

function ctx(tables: Tables = world(), now?: () => number) {
  const claims = claimHandlers(now);
  const logged: string[] = [];
  const v = testCtx(tables, {
    defaults: listDefaults,
    rpc: {
      ...claims.rpc,
      // "Ate it" as the SQL function does it: one serving off, one meal_logs row.
      plan_log_from_plan: (a: { p_plan_meal_id: string; p_meal_type: string | null; p_log_date: string }) => {
        const m = v.fake.rows('plan_meals').find((r) => r.id === a.p_plan_meal_id)!;
        m.servings_left -= 1;
        const id = `log-${logged.length + 1}`;
        logged.push(id);
        v.fake.rows('meal_logs').push({ id, user_id: U, name: m.name, slot: a.p_meal_type ?? m.meal_type, log_date: a.p_log_date, source: 'plan', plan_meal_id: m.id, is_deleted: false });
        return id;
      },
    },
  });
  return { v, claims, logged };
}

/** vana-action's own composition: the extras first, then the UiAction switch, under the request id. */
// deno-lint-ignore no-explicit-any
const act = (v: ReturnType<typeof testCtx>, type: string, payload: Record<string, any>) =>
  withRequestId(v, type, payload, async () => (await extraAction(v, type, payload)) ?? (await runAction(v, { type, payload } as Parameters<typeof runAction>[1])));

// ---------------------------------------------------------------- the three writes
Deno.test('pick_meals with the same requestId adds the meal once and answers the same plan', async () => {
  const { v } = ctx();
  const payload = { meals: [{ source: 'library', id: 'D-001' }], servings: 4, requestId: REQ };
  const first = await act(v, 'pick_meals', payload);
  const second = await act(v, 'pick_meals', payload);
  assertEquals(v.fake.writesTo('plan_meals', 'insert').length, 1);
  assertEquals(second, first);
  assertEquals(v.fake.rows('plan_meals').map((m) => m.library_meal_id), ['D-001']);
});

Deno.test('log_from_plan with the same requestId logs one serving and answers the same logged part', async () => {
  const { v, logged } = ctx(world({ plan_meals: [mealRow('pm1', 'D-001', 4)] }));
  const payload = { planMealId: 'pm1', requestId: REQ };
  const first = await act(v, 'log_from_plan', payload);
  const second = await act(v, 'log_from_plan', payload);
  assertEquals(logged, ['log-1']);
  assertEquals(v.fake.rows('plan_meals')[0].servings_left, 3);
  assertEquals(second, first);
  assertEquals((second.parts[0] as { servingsLeft: number }).servingsLeft, 3);
  assertEquals(second.logId, 'log-1');
});

Deno.test('save_meal with the same requestId inserts one saved copy and answers the same meal', async () => {
  const { v } = ctx();
  const payload = { libraryMealId: 'D-002', requestId: REQ };
  const first = await act(v, 'save_meal', payload);
  const second = await act(v, 'save_meal', payload);
  assertEquals(v.fake.writesTo('saved_meals', 'insert').length, 1);
  assertEquals((second.meal as { id: string }).id, (first.meal as { id: string }).id);
});

// ---------------------------------------------------------------- the claim's edges
Deno.test('a repeat while the first run is still on the server is refused as in progress, and nothing runs twice', async () => {
  const { v } = ctx();
  let release!: () => void;
  const gate = new Promise<void>((r) => { release = r; });
  let runs = 0;
  const slow = async (): Promise<ActionResult> => { runs++; await gate; return { parts: [] }; };
  const first = withRequestId(v, 'pick_meals', { requestId: REQ }, slow);
  await Promise.resolve();
  await assertRejects(() => withRequestId(v, 'pick_meals', { requestId: REQ }, slow), RequestInProgressError);
  release();
  await first;
  assertEquals(runs, 1);
});

Deno.test('a run that throws releases its claim, so the retry with the same id runs again', async () => {
  const { v, claims } = ctx();
  let runs = 0;
  await assertRejects(() => withRequestId(v, 'pick_meals', { requestId: REQ }, () => { runs++; return Promise.reject(new Error('meal not found')); }), Error, 'meal not found');
  assertEquals(claims.rows.has(REQ), false);
  const out = await withRequestId(v, 'pick_meals', { requestId: REQ }, () => { runs++; return Promise.resolve({ parts: [] }); });
  assertEquals(runs, 2);
  assertEquals(out, { parts: [] });
  assertEquals(claims.rows.get(REQ)?.status, 'done');
});

Deno.test('a running claim older than the TTL is taken over (an isolate died mid-write)', async () => {
  let t = 1_000_000;
  const { v, claims } = ctx(world(), () => t);
  claims.rows.set(REQ, { action_type: 'pick_meals', status: 'running', result: null, claimed_at: t });
  t += (REQUEST_TTL_SECONDS + 1) * 1000;
  let runs = 0;
  await withRequestId(v, 'pick_meals', { requestId: REQ }, () => { runs++; return Promise.resolve({ parts: [] }); });
  assertEquals(runs, 1);
});

Deno.test('no requestId, or an action outside the three, runs every time as before', async () => {
  const { v } = ctx();
  let runs = 0;
  const run = () => { runs++; return Promise.resolve({ parts: [] }); };
  await withRequestId(v, 'pick_meals', {}, run);
  await withRequestId(v, 'pick_meals', {}, run);
  await withRequestId(v, 'set_servings', { requestId: REQ }, run);
  await withRequestId(v, 'set_servings', { requestId: REQ }, run);
  assertEquals(runs, 4);
  assertEquals(v.fake.writes.length, 0);
  // use_plan_again joined the set with ticket 162: it confirms a fresh copy on every run.
  assertEquals([...IDEMPOTENT_ACTIONS].sort(), ['log_from_plan', 'pick_meals', 'save_meal', 'use_plan_again']);
});

Deno.test('the claim RPC missing (a project the migration has not reached) fails open: the write runs unguarded', async () => {
  const v = testCtx(world(), { defaults: listDefaults });   // no rpc handlers at all
  let runs = 0;
  await withRequestId(v, 'pick_meals', { requestId: REQ }, () => { runs++; return Promise.resolve({ parts: [] }); });
  assertEquals(runs, 1);
});

Deno.test('requestId is read in both spellings and refused when malformed', () => {
  assertEquals(requestIdOf({ requestId: ` ${REQ} ` }), REQ);
  assertEquals(requestIdOf({ request_id: REQ }), REQ);
  assertEquals(requestIdOf({}), null);
  assertEquals(requestIdOf({ requestId: '' }), null);
  let threw = false;
  try { requestIdOf({ requestId: 'x'.repeat(65) }); } catch { threw = true; }
  assert(threw, 'a 65-character id is refused');
});

Deno.test('the same id sent for another action type is refused, never answered with the wrong result', async () => {
  const { v } = ctx();
  await withRequestId(v, 'pick_meals', { requestId: REQ }, () => Promise.resolve({ parts: [] }));
  await assertRejects(() => withRequestId(v, 'save_meal', { requestId: REQ }, () => Promise.resolve({ parts: [] })), Error, 'was used for pick_meals');
});

// ---------------------------------------------------------------- save_meal's own race (two different ids)
Deno.test('two saves of one library meal in flight at once leave one saved copy, and both answer it', async () => {
  const { v } = ctx();
  const [a, b] = await Promise.all([saveLibraryMeal(v, 'D-001'), saveLibraryMeal(v, 'D-001')]);
  const live = v.fake.rows('saved_meals').filter((r) => !r.is_deleted);
  assertEquals(live.length, 1);
  assertEquals(a.id, b.id);
  assertEquals(a.id, String(live[0].id));
});
