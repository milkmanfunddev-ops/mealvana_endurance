/**
 * Vana writes the app's own objects (Lee's playtest 2026-09-16 §10): events, meal logs, a fresh plan, and the Undo
 * behind each receipt. Driven through the real tool map against the fake database, with the rows shaped the way the
 * app's repositories write them (the IRONMAN Cozumel row is the dev row as it stands).
 *
 * The one rule that matters most is in code, not prose: a delete without `confirmed: true` writes nothing.
 */
import { assert, assertEquals, assertRejects } from 'https://deno.land/std@0.224.0/assert/mod.ts';
import { makeVanaTools } from '../../_shared/vana/tools.ts';
import { extraAction, runAction } from '../../_shared/vana/actions.ts';

/** The edge function tries extraAction before runAction; undo_receipt lives in the former. Same order here. */
// deno-lint-ignore no-explicit-any
const act = async (v: any, type: string, payload: Record<string, unknown>) => (await extraAction(v, type, payload)) ?? (await runAction(v, { type: type as never, payload }));
import { eventColumns, startTimeFor, guardDelete } from '../../_shared/vana/writes.ts';
import { VanaPartZ, ReceiptPartZ, NeedsConfirmationPartZ } from '../../_shared/vana/schemas.ts';
import { testCtx, TEST_USER_ID } from './support/vana_ctx.ts';
import type { Row } from './support/fake_db.ts';

const U = TEST_USER_ID;
const OTHER = '22222222-2222-4222-8222-222222222222';
const CALL = { toolCallId: 't', messages: [] };

/** The dev row for IRONMAN Cozumel (events id a7e76d6c…), less nothing: the app hard-deletes, so Undo needs the whole row. */
const COZUMEL: Row = { id: 'a7e76d6c-bbf7-4d29-bebc-59a42c462b0d', user_id: U, event_name: 'IRONMAN Cozumel', location: 'Isla Cozumel, Mexico', registration_url: 'https://www.ironman.com/im-cozumel', start_time: '2026-11-22T06:30:00.000', event_date: '2026-11-22', event_type: 'triathlon', event_subtype: 'ironman', has_carb_loading: false, has_nutrition_plan: false, activity_id: null, origin: null, goal_time_minutes: null, created_at: '2026-03-02T07:38:14.828003', updated_at: '2026-03-02T07:38:14.864224', needs_upload: false, local_updated_at: '2026-03-02T14:38:14.973039' };
const SOMEONE_ELSES: Row = { ...COZUMEL, id: 'e1000000-0000-4000-8000-000000000001', user_id: OTHER, event_name: 'Their race' };

// deno-lint-ignore no-explicit-any
const toolsFor = (v: any) => makeVanaTools(v, {} as never, 'general') as Record<string, any>;
// deno-lint-ignore no-explicit-any
const planningToolsFor = (v: any) => makeVanaTools(v, {} as never, 'meal_planning', { scope: { conversationId: 'conv-1' }, conversationId: 'conv-1' }) as Record<string, any>;

Deno.test('both tool sets carry the write tools; the sheet keeps handOff for what still needs a screen', () => {
  const v = testCtx();
  const general = toolsFor(v); const planning = planningToolsFor(v);
  for (const name of ['startNewPlan', 'deletePlan', 'listEvents', 'createEvent', 'updateEvent', 'deleteEvent', 'listActivities', 'createActivity', 'updateActivity', 'deleteActivity', 'logMeal', 'deleteLoggedMeal']) { assert(general[name], `general has ${name}`); assert(planning[name], `planning has ${name}`); }
  assert(general.handOff, 'general keeps handOff'); assert(!planning.handOff, 'planning has nothing to hand off to');
});

// ---------------------------------------------------------------- the delete guard
Deno.test('deleteEvent without confirmed writes nothing and answers needs_confirmation', async () => {
  const v = testCtx({ events: [COZUMEL] });
  const out = await toolsFor(v).deleteEvent.execute({ id: COZUMEL.id }, CALL);
  NeedsConfirmationPartZ.parse(out); VanaPartZ.parse(out);
  assertEquals(out.kind, 'needs_confirmation');
  assertEquals(out.summary, 'Delete IRONMAN Cozumel on Nov 22?');
  assertEquals(out.entityId, COZUMEL.id);
  assertEquals(v.fake.writes, [], 'nothing reached the database');
  assertEquals(v.fake.rows('events').length, 1);
});

Deno.test('confirmed: false is the same as no confirmation', async () => {
  const v = testCtx({ events: [COZUMEL] });
  const out = await toolsFor(v).deleteEvent.execute({ id: COZUMEL.id, confirmed: false }, CALL);
  assertEquals(out.kind, 'needs_confirmation');
  assertEquals(v.fake.writes, []);
});

Deno.test('deleteLoggedMeal without confirmed writes nothing either', async () => {
  const log: Row = { id: 'l-1', user_id: U, name: 'Lentil salad', log_date: '2026-09-16', slot: 'lunch', source: 'describe', is_deleted: false };
  const v = testCtx({ meal_logs: [log] });
  const out = await toolsFor(v).deleteLoggedMeal.execute({ id: 'l-1' }, CALL);
  assertEquals(out.kind, 'needs_confirmation');
  assertEquals(out.summary, 'Remove Lentil salad from Sep 16?');
  assertEquals(v.fake.writes, []);
});

Deno.test('guardDelete is the one place the rule lives', () => {
  assert(guardDelete(undefined, 'delete_event', 'event', 'x', '1'));
  assert(guardDelete(false, 'delete_event', 'event', 'x', '1'));
  assertEquals(guardDelete(true, 'delete_event', 'event', 'x', '1'), null);
});

// ---------------------------------------------------------------- events
Deno.test('deleteEvent with confirmed: true removes the row and the receipt carries it for Undo', async () => {
  const v = testCtx({ events: [COZUMEL, SOMEONE_ELSES] });
  const out = await toolsFor(v).deleteEvent.execute({ id: COZUMEL.id, confirmed: true }, CALL);
  ReceiptPartZ.parse(out); VanaPartZ.parse(out);
  assertEquals(out.action, 'delete_event'); assertEquals(out.entity, 'event');
  assertEquals(out.summary, 'Removed IRONMAN Cozumel');
  assertEquals(v.fake.rows('events').map((r) => r.id), [SOMEONE_ELSES.id], 'only the athlete\'s row went');
  // The undo carries the row without the device-only columns.
  const row = out.undo.params.row;
  assertEquals(row.event_name, 'IRONMAN Cozumel'); assertEquals(row.start_time, '2026-11-22T06:30:00.000');
  assert(!('needs_upload' in row) && !('local_updated_at' in row));

  // …and undo_receipt puts it back, answering a receipt of its own with no further undo.
  const undone = await act(v, 'undo_receipt', out.undo.params); const undoPart = ReceiptPartZ.parse(undone.parts[0]);
  ReceiptPartZ.parse(undone.parts[0]);
  assertEquals(undone.parts[0], { kind: 'receipt', action: 'undo', entity: 'event', summary: 'Put back IRONMAN Cozumel', entityId: COZUMEL.id, undo: null });
  const back = v.fake.rows('events').find((r) => r.id === COZUMEL.id)!;
  assertEquals(back.event_date, '2026-11-22'); assertEquals(back.user_id, U); assertEquals(back.needs_upload, false);
});

Deno.test('another athlete\'s event is not found — even with confirmed', async () => {
  const v = testCtx({ events: [SOMEONE_ELSES] });
  await assertRejects(() => toolsFor(v).deleteEvent.execute({ id: SOMEONE_ELSES.id, confirmed: true }, CALL), Error, 'event not found');
  assertEquals(v.fake.writes, []);
});

Deno.test('createEvent writes the row the app writes: text uuid, start_time from the date, event_date beside it, origin manual', async () => {
  const v = testCtx();
  const out = await toolsFor(v).createEvent.execute({ name: 'Chicago Marathon', date: '2026-10-11', type: 'running', subtype: 'marathon', location: 'Chicago, IL' }, CALL);
  ReceiptPartZ.parse(out);
  assertEquals(out.action, 'create_event'); assertEquals(out.summary, 'Added Chicago Marathon · Oct 11'); assertEquals(out.undo, null);
  const row = v.fake.rows('events')[0];
  assertEquals(row.id, out.entityId); assert(/^[0-9a-f-]{36}$/.test(row.id));
  assertEquals(row.user_id, U); assertEquals(row.origin, 'manual'); assertEquals(row.event_type, 'running'); assertEquals(row.event_subtype, 'marathon');
  assertEquals(row.event_date, '2026-10-11'); assertEquals(row.start_time, '2026-10-11T07:00:00.000');
  assertEquals(row.has_carb_loading, false); assertEquals(row.activity_id, null);
});

Deno.test('createEvent keeps a named start time', async () => {
  const v = testCtx();
  await toolsFor(v).createEvent.execute({ name: 'Sprint tri', date: '2026-08-01', time: '06:30', type: 'triathlon', subtype: 'sprint' }, CALL);
  assertEquals(v.fake.rows('events')[0].start_time, '2026-08-01T06:30:00.000');
});

Deno.test('updateEvent moves the date with start_time, and Undo restores exactly the columns it touched', async () => {
  const v = testCtx({ events: [COZUMEL] });
  const out = await toolsFor(v).updateEvent.execute({ id: COZUMEL.id, patch: { date: '2026-11-29', location: 'Cozumel, MX' } }, CALL);
  ReceiptPartZ.parse(out);
  assertEquals(out.summary, 'Updated IRONMAN Cozumel · Nov 29');
  const row = v.fake.rows('events')[0];
  assertEquals(row.event_date, '2026-11-29'); assertEquals(row.start_time, '2026-11-29T06:30:00.000'); assertEquals(row.location, 'Cozumel, MX');
  assertEquals(out.undo.params.before, { event_date: '2026-11-22', start_time: '2026-11-22T06:30:00.000', location: 'Isla Cozumel, Mexico' });

  const undone = await act(v, 'undo_receipt', out.undo.params); const undoPart = ReceiptPartZ.parse(undone.parts[0]);
  assertEquals(undoPart.action, 'undo');
  const back = v.fake.rows('events')[0];
  assertEquals(back.event_date, '2026-11-22'); assertEquals(back.start_time, '2026-11-22T06:30:00.000'); assertEquals(back.location, 'Isla Cozumel, Mexico');
});

Deno.test('updateEvent with an empty patch changes nothing', async () => {
  const v = testCtx({ events: [COZUMEL] });
  await assertRejects(() => toolsFor(v).updateEvent.execute({ id: COZUMEL.id, patch: {} }, CALL), Error, 'nothing to change');
  assertEquals(v.fake.writes, []);
});

Deno.test('eventColumns / startTimeFor: the date and time move together, a bad shape never reaches the row', () => {
  assertEquals(startTimeFor('2026-11-22'), '2026-11-22T07:00:00.000');
  assertEquals(startTimeFor('2026-11-22', '06:30'), '2026-11-22T06:30:00.000');
  assertEquals(eventColumns({ time: '09:00' }, COZUMEL), { event_date: '2026-11-22', start_time: '2026-11-22T09:00:00.000' });
  assertEquals(eventColumns({ name: 'IM Cozumel' }, COZUMEL), { event_name: 'IM Cozumel' });
  let threw = false; try { startTimeFor('Nov 22'); } catch { threw = true; } assert(threw, 'date must be ISO');
});

Deno.test('listEvents answers every event with its id, newest first, this athlete only', async () => {
  const v = testCtx({ events: [COZUMEL, SOMEONE_ELSES, { ...COZUMEL, id: 'e-old', event_name: 'Spring 10k', event_date: '2026-04-05', event_type: 'running', event_subtype: '10k' }] });
  const out = await toolsFor(v).listEvents.execute({}, CALL);
  assertEquals(out.map((e: { id: string }) => e.id), [COZUMEL.id, 'e-old']);
  assertEquals(out[0].distance, 'ironman'); assertEquals(out[1].name, 'Spring 10k');
});

// ---------------------------------------------------------------- meal logs
Deno.test('logMeal by name writes the Describe row: source describe, slot, items, macros as given, and Undo tombstones it', async () => {
  const v = testCtx();
  const out = await toolsFor(v).logMeal.execute({ name: 'Lentil salad', mealType: 'lunch', carbsG: 52, proteinG: 18, items: [{ name: 'lentils', portion: '1 cup' }, { name: 'feta', portion: '30 g' }] }, CALL);
  ReceiptPartZ.parse(out);
  assertEquals(out.action, 'log_meal'); assertEquals(out.entity, 'meal_log'); assertEquals(out.summary, 'Logged Lentil salad');
  const row = v.fake.rows('meal_logs')[0];
  assertEquals(row.id, out.entityId); assertEquals(row.user_id, U); assertEquals(row.source, 'describe'); assertEquals(row.slot, 'lunch'); assertEquals(row.name, 'Lentil salad');
  assertEquals(row.items, [{ name: 'lentils', portion: '1 cup' }, { name: 'feta', portion: '30 g' }]);
  assertEquals(row.carbs_g, 52); assertEquals(row.protein_g, 18); assertEquals(row.calories, null); assertEquals(row.fat_g, null);
  assertEquals(row.log_date, new Date().toISOString().slice(0, 10)); assertEquals(row.is_deleted, false);
  assert(row.eaten_at, 'eaten_at is stamped');

  const undone = await act(v, 'undo_receipt', out.undo.params); const undoPart = ReceiptPartZ.parse(undone.parts[0]);
  assertEquals(undoPart.summary, 'Unlogged Lentil salad');
  assertEquals(v.fake.rows('meal_logs')[0].is_deleted, true, 'the app\'s soft delete, so the device sees the tombstone');
});

Deno.test('logMeal sums item macros when the meal has none of its own, and never invents a number', async () => {
  const v = testCtx();
  await toolsFor(v).logMeal.execute({ name: 'Oats and banana', mealType: 'breakfast', date: '2026-09-15', items: [{ name: 'oats', portion: '80 g', carbG: 54, calories: 300 }, { name: 'banana', carbG: 27, calories: 105 }] }, CALL);
  const row = v.fake.rows('meal_logs')[0];
  assertEquals(row.carbs_g, 81); assertEquals(row.calories, 405); assertEquals(row.protein_g, null);
  assertEquals(row.log_date, '2026-09-15'); assertEquals(row.eaten_at, '2026-09-15T12:00:00Z');
});

Deno.test('logMeal on a plan meal runs the same plan_log_from_plan transaction as "Ate it", and Undo gives the serving back', async () => {
  const pm: Row = { id: 'pm-1', plan_id: 'p-1', user_id: U, name: 'Chicken & rice', meal_type: 'dinner', servings: 4, servings_left: 4 };
  const v = testCtx({ plan_meals: [pm], meal_logs: [] }, { rpc: { plan_log_from_plan: (a: { p_plan_meal_id: string; p_meal_type: string | null; p_log_date: string }) => { const m = v.fake.rows('plan_meals').find((r) => r.id === a.p_plan_meal_id)!; m.servings_left -= 1; v.fake.rows('meal_logs').push({ id: 'log-1', user_id: U, name: m.name, slot: a.p_meal_type ?? m.meal_type, log_date: a.p_log_date, source: 'plan', plan_meal_id: m.id, is_deleted: false }); return 'log-1'; } } });
  const out = await toolsFor(v).logMeal.execute({ planMealId: 'pm-1' }, CALL);
  ReceiptPartZ.parse(out);
  assertEquals(out.summary, 'Logged Chicken & rice · 3 left'); assertEquals(out.entityId, 'log-1');
  assertEquals(out.undo.params, { action: 'log_meal', logId: 'log-1', planMealId: 'pm-1' });

  await act(v, 'undo_receipt', out.undo.params);
  assertEquals(v.fake.rows('plan_meals')[0].servings_left, 4);
  assertEquals(v.fake.rows('meal_logs')[0].is_deleted, true);
});

Deno.test('logMeal without a plan meal needs a name and a meal type', async () => {
  const v = testCtx();
  await assertRejects(() => toolsFor(v).logMeal.execute({ mealType: 'lunch' }, CALL), Error, 'name is required');
  await assertRejects(() => toolsFor(v).logMeal.execute({ name: 'Toast' }, CALL), Error, 'mealType is required');
  assertEquals(v.fake.writes, []);
});

Deno.test('deleteLoggedMeal with confirmed: true leaves the app\'s tombstone, and Undo lifts it', async () => {
  const log: Row = { id: 'l-1', user_id: U, name: 'Lentil salad', log_date: '2026-09-16', slot: 'lunch', source: 'describe', is_deleted: false };
  const v = testCtx({ meal_logs: [log, { ...log, id: 'l-2', user_id: OTHER }] });
  const out = await toolsFor(v).deleteLoggedMeal.execute({ id: 'l-1', confirmed: true }, CALL);
  ReceiptPartZ.parse(out);
  assertEquals(out.summary, 'Removed Lentil salad');
  assertEquals(v.fake.rows('meal_logs').find((r) => r.id === 'l-1')!.is_deleted, true);
  assertEquals(v.fake.rows('meal_logs').find((r) => r.id === 'l-2')!.is_deleted, false);
  assertEquals(v.fake.rows('meal_logs').length, 2, 'a tombstone, not a delete: the device syncs it as one');

  const undone = await act(v, 'undo_receipt', out.undo.params); const undoPart = ReceiptPartZ.parse(undone.parts[0]);
  assertEquals(undoPart.summary, 'Put back Lentil salad');
  assertEquals(v.fake.rows('meal_logs').find((r) => r.id === 'l-1')!.is_deleted, false);
});

Deno.test('a log already deleted, or another athlete\'s, is not found', async () => {
  const v = testCtx({ meal_logs: [{ id: 'l-1', user_id: U, name: 'x', log_date: '2026-09-16', source: 'describe', is_deleted: true }, { id: 'l-2', user_id: OTHER, name: 'y', log_date: '2026-09-16', source: 'describe', is_deleted: false }] });
  await assertRejects(() => toolsFor(v).deleteLoggedMeal.execute({ id: 'l-1', confirmed: true }, CALL), Error, 'not found');
  await assertRejects(() => toolsFor(v).deleteLoggedMeal.execute({ id: 'l-2', confirmed: true }, CALL), Error, 'not found');
  assertEquals(v.fake.writes, []);
});

// ---------------------------------------------------------------- the plan
Deno.test('startNewPlan archives the conversation\'s draft (never deletes it) and opens an empty one; no confirmation, no undo', async () => {
  const draft: Row = { id: 'p-1', user_id: U, conversation_id: 'conv-1', week_start: '2026-09-13', status: 'draft', batch_cooking: true, is_deleted: false, created_at: '2026-09-14T00:00:00Z', updated_at: '2026-09-14T00:00:00Z' };
  const v = testCtx({ meal_plans: [draft], plan_meals: [{ id: 'pm-1', plan_id: 'p-1', user_id: U, name: 'Chili', meal_type: 'dinner', servings: 4, servings_left: 4, source: 'library', library_meal_id: 'D-1' }] });
  const out = await planningToolsFor(v).startNewPlan.execute({}, CALL);
  ReceiptPartZ.parse(out);
  assertEquals(out.action, 'new_plan'); assertEquals(out.entity, 'plan'); assertEquals(out.undo, null);
  const plans = v.fake.rows('meal_plans');
  assertEquals(plans.find((p) => p.id === 'p-1')!.status, 'archived');
  const fresh = plans.find((p) => p.id === out.entityId)!;
  assertEquals(fresh.status, 'draft'); assertEquals(fresh.conversation_id, 'conv-1'); assertEquals(fresh.is_deleted, false);
  assertEquals(v.fake.writesTo('meal_plans', 'delete'), []);
  assertEquals(v.fake.rows('plan_meals').length, 1, 'the old plan keeps its meals in history');
});

// ---------------------------------------------------------------- undo edge
Deno.test('undo_receipt refuses what it cannot undo', async () => {
  const v = testCtx();
  await assertRejects(() => act(v, 'undo_receipt', { action: 'create_event' }), Error, 'nothing to undo');
  await assertRejects(() => act(v, 'undo_receipt', {}), Error, 'nothing to undo');
});

// ---------------------------------------------------------------- deletePlan (Lee, 2026-09-16: he could not delete the demo's plan by hand or through Vana)
const PLAN_ROW: Row = { id: 'p-9', user_id: U, conversation_id: 'conv-1', week_start: '2026-09-13', status: 'confirmed', batch_cooking: true, is_deleted: false, shopping: [], created_at: '2026-09-13T00:00:00Z', updated_at: '2026-09-13T00:00:00Z' };
const PLAN_MEALS: Row[] = [
  { id: 'pm-9a', plan_id: 'p-9', user_id: U, name: 'Chili', meal_type: 'dinner', servings: 4, servings_left: 4, source: 'library', library_meal_id: 'D-1', is_deleted: false },
  { id: 'pm-9b', plan_id: 'p-9', user_id: U, name: 'Salmon bowl', meal_type: 'dinner', servings: 2, servings_left: 2, source: 'library', library_meal_id: 'D-2', is_deleted: false },
];

Deno.test('deletePlan without confirmed writes nothing and names the plan by its period and meal count', async () => {
  const v = testCtx({ meal_plans: [PLAN_ROW], plan_meals: PLAN_MEALS });
  const out = await planningToolsFor(v).deletePlan.execute({}, CALL);
  NeedsConfirmationPartZ.parse(out);
  assertEquals(out.kind, 'needs_confirmation'); assertEquals(out.entity, 'plan'); assertEquals(out.entityId, 'p-9');
  assertEquals(out.summary, 'Delete the plan for Sep 13 – Sep 19 (2 meals)?');
  assertEquals(v.fake.writes, []);
});

Deno.test('deletePlan with confirmed: true leaves the is_deleted tombstone the app syncs as gone; Undo lifts it', async () => {
  const v = testCtx({ meal_plans: [PLAN_ROW], plan_meals: PLAN_MEALS });
  const out = await planningToolsFor(v).deletePlan.execute({ confirmed: true }, CALL);
  ReceiptPartZ.parse(out); VanaPartZ.parse(out);
  assertEquals(out.action, 'delete_plan'); assertEquals(out.entity, 'plan'); assertEquals(out.entityId, 'p-9');
  assertEquals(out.summary, 'Deleted the plan for Sep 13 – Sep 19');
  assertEquals(out.undo, { action: 'undo_receipt', params: { action: 'delete_plan', id: 'p-9' } });
  assertEquals(v.fake.rows('meal_plans')[0].is_deleted, true);
  assertEquals(v.fake.writesTo('meal_plans', 'delete'), [], 'a tombstone, never a hard delete');
  assertEquals(v.fake.rows('plan_meals').length, 2, 'the meals stay attached for Undo');

  const undone = await act(v, 'undo_receipt', out.undo.params);
  assertEquals(undone.parts[0], { kind: 'receipt', action: 'undo', entity: 'plan', summary: 'Put back the plan for Sep 13 – Sep 19', entityId: 'p-9', undo: null });
  assertEquals(v.fake.rows('meal_plans')[0].is_deleted, false);
});

Deno.test('the Plan tab\'s delete_plan action is the confirmed delete (its own dialog stood in for askChoice) and takes an explicit id', async () => {
  const other: Row = { ...PLAN_ROW, id: 'p-8', conversation_id: null, week_start: '2026-09-06', status: 'archived' };
  const v = testCtx({ meal_plans: [PLAN_ROW, other], plan_meals: PLAN_MEALS });
  const res = await act(v, 'delete_plan', { id: 'p-8' });
  const r = ReceiptPartZ.parse(res.parts[0]);
  assertEquals(r.action, 'delete_plan'); assertEquals(r.entityId, 'p-8');
  assertEquals(res.parts.length, 1, 'no batch part — the plan is gone');
  assertEquals(v.fake.rows('meal_plans').find((p) => p.id === 'p-8')!.is_deleted, true);
  assertEquals(v.fake.rows('meal_plans').find((p) => p.id === 'p-9')!.is_deleted, false);
});

Deno.test('deletePlan on an athlete with no plan is an error, not a receipt', async () => {
  const v = testCtx({ meal_plans: [] });
  await assertRejects(() => toolsFor(v).deletePlan.execute({ confirmed: true }, CALL), Error, 'no plan to delete');
});

// ---------------------------------------------------------------- activities (planned workouts)
/** The `activities` row the app uploads for a planned session: text id, naive local scheduled_date_time, status planned. */
const LONG_RIDE: Row = { id: 'a-ride', user_id: U, title: 'Long ride', activity_type: 'cycling', status: 'planned', scheduled_date_time: '2026-09-19T07:00:00.000', duration_minutes: 180, distance_miles: 60, intensity_level: 'moderate', notes: null, deleted_at: null, completed_at: null, synced_from_provider: null, created_at: '2026-09-10T00:00:00Z', updated_at: '2026-09-10T00:00:00Z' };
const GARMIN_RUN: Row = { ...LONG_RIDE, id: 'a-run', title: 'Tempo run', activity_type: 'running', scheduled_date_time: '2026-09-15T06:00:00.000', duration_minutes: 50, distance_miles: 7, intensity_level: 'hard', synced_from_provider: 'garmin', completed_at: '2026-09-15T07:05:00.000', status: 'completed' };
const GONE: Row = { ...LONG_RIDE, id: 'a-gone', title: 'Old swim', status: 'deleted', deleted_at: '2026-09-01T00:00:00Z' };
const THEIRS: Row = { ...LONG_RIDE, id: 'a-theirs', user_id: OTHER };

Deno.test('listActivities answers the athlete\'s live sessions with ids, never tombstones or another athlete\'s', async () => {
  const v = testCtx({ activities: [LONG_RIDE, GARMIN_RUN, GONE, THEIRS] });
  const out = await toolsFor(v).listActivities.execute({ from: '2026-09-13', to: '2026-09-20' }, CALL);
  assertEquals(out.map((a: { id: string }) => a.id), ['a-run', 'a-ride']);
  assertEquals(out[1], { id: 'a-ride', title: 'Long ride', type: 'cycling', date: '2026-09-19', time: '07:00', durationMinutes: 180, distanceMiles: 60, intensity: 'moderate', status: 'planned', completed: false, from: 'manual' });
  assertEquals(out[0].from, 'garmin'); assertEquals(out[0].completed, true);
});

Deno.test('createActivity writes the row the app\'s mapper writes and the receipt undoes it with the app\'s tombstone', async () => {
  const v = testCtx({ activities: [] });
  const out = await toolsFor(v).createActivity.execute({ title: 'Easy spin', date: '2026-09-20', type: 'cycling', durationMinutes: 45, intensity: 'easy' }, CALL);
  ReceiptPartZ.parse(out); VanaPartZ.parse(out);
  assertEquals(out.action, 'create_activity'); assertEquals(out.entity, 'activity'); assertEquals(out.summary, 'Added Easy spin · Sep 20');
  const row = v.fake.rows('activities')[0];
  assertEquals(row.id, out.entityId); assertEquals(row.user_id, U); assertEquals(row.status, 'planned');
  assertEquals(row.scheduled_date_time, '2026-09-20T06:30:00.000', 'a naive local ISO at the training-hour default');
  assertEquals(row.activity_type, 'cycling'); assertEquals(row.duration_minutes, 45); assertEquals(row.intensity_level, 'easy'); assertEquals(row.distance_miles, null);
  assert(!('needs_upload' in row));

  const undone = await act(v, 'undo_receipt', out.undo.params);
  const u = ReceiptPartZ.parse(undone.parts[0]); assertEquals(u.action, 'undo'); assertEquals(u.entity, 'activity');
  const after = v.fake.rows('activities')[0];
  assertEquals(after.status, 'deleted'); assert(after.deleted_at, 'the app\'s tombstone, so every device drops it');
});

Deno.test('updateActivity moves date and time together, flags the fuelling refresh, and Undo restores what it touched', async () => {
  const v = testCtx({ activities: [LONG_RIDE] });
  const out = await toolsFor(v).updateActivity.execute({ id: 'a-ride', patch: { date: '2026-09-20', durationMinutes: 240 } }, CALL);
  ReceiptPartZ.parse(out);
  assertEquals(out.action, 'update_activity'); assertEquals(out.summary, 'Updated Long ride · Sep 20');
  const row = v.fake.rows('activities')[0];
  assertEquals(row.scheduled_date_time, '2026-09-20T07:00:00.000', 'the time it had, on the new day');
  assertEquals(row.duration_minutes, 240); assertEquals(row.needs_nutrition_refresh, true); assert(row.schedule_changed_at);
  assertEquals(out.undo.params.before.scheduled_date_time, '2026-09-19T07:00:00.000');
  assertEquals(out.undo.params.before.duration_minutes, 180);

  const undone = await act(v, 'undo_receipt', out.undo.params);
  assertEquals(ReceiptPartZ.parse(undone.parts[0]).summary, 'Reverted Long ride');
  const back = v.fake.rows('activities')[0];
  assertEquals(back.scheduled_date_time, '2026-09-19T07:00:00.000'); assertEquals(back.duration_minutes, 180);
});

Deno.test('updateActivity with a time alone keeps the day', async () => {
  const v = testCtx({ activities: [LONG_RIDE] });
  await toolsFor(v).updateActivity.execute({ id: 'a-ride', patch: { time: '15:30' } }, CALL);
  assertEquals(v.fake.rows('activities')[0].scheduled_date_time, '2026-09-19T15:30:00.000');
});

Deno.test('deleteActivity asks first, then leaves the app\'s status=deleted tombstone; Undo brings the old status back', async () => {
  const v = testCtx({ activities: [LONG_RIDE, GARMIN_RUN] });
  const ask = await toolsFor(v).deleteActivity.execute({ id: 'a-ride' }, CALL);
  NeedsConfirmationPartZ.parse(ask);
  assertEquals(ask.summary, 'Delete Long ride · Sep 19?'); assertEquals(v.fake.writes, []);

  const out = await toolsFor(v).deleteActivity.execute({ id: 'a-run', confirmed: true }, CALL);
  ReceiptPartZ.parse(out);
  assertEquals(out.summary, 'Removed Tempo run'); assertEquals(out.entity, 'activity');
  const row = v.fake.rows('activities').find((r) => r.id === 'a-run')!;
  assertEquals(row.status, 'deleted'); assert(row.deleted_at);
  assertEquals(v.fake.writesTo('activities', 'delete'), [], 'never a hard delete — the sync matcher needs the tombstone');

  const undone = await act(v, 'undo_receipt', out.undo.params);
  assertEquals(ReceiptPartZ.parse(undone.parts[0]).summary, 'Put back Tempo run');
  const back = v.fake.rows('activities').find((r) => r.id === 'a-run')!;
  assertEquals(back.status, 'completed', 'the status it had, not a blanket planned'); assertEquals(back.deleted_at, null);
});

Deno.test('a deleted workout, or another athlete\'s, is not found — even with confirmed', async () => {
  const v = testCtx({ activities: [GONE, THEIRS] });
  await assertRejects(() => toolsFor(v).deleteActivity.execute({ id: 'a-gone', confirmed: true }, CALL), Error, 'workout not found');
  await assertRejects(() => toolsFor(v).updateActivity.execute({ id: 'a-theirs', patch: { title: 'Mine now' } }, CALL), Error, 'workout not found');
  assertEquals(v.fake.writes, []);
});
