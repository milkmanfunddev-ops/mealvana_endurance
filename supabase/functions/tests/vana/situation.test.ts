/**
 * The Situation resolver: every screen in the spec's table to its sentence, from fixture rows.
 * Nothing here may write anything — the Situation lives for one request.
 */
import { assert, assertEquals } from 'https://deno.land/std@0.177.1/testing/asserts.ts';
import { resolveSituation, screenFor } from '../../_shared/vana/situation.ts';
import { buildAthleteContext, contextBlock } from '../../_shared/vana/context.ts';
import { testCtx, offlineDeps, TEST_USER_ID } from './support/vana_ctx.ts';
import type { Tables } from './support/fake_db.ts';

const U = TEST_USER_ID;
const PLAN = 'plan-1';

const world = (): Tables => ({
  users: [{ id: U, first_name: 'Lee', allergies: [] }],
  activities: [{ id: 'act-1', user_id: U, title: 'Long ride', activity_type: 'cycling', duration_minutes: 180, scheduled_date_time: '2026-09-12T07:00:00', deleted_at: null }],
  events: [{ id: 'ev-1', user_id: U, event_name: 'Chattanooga 70.3', event_date: '2026-09-20', location: 'Chattanooga, TN' }],
  meal_library: [{ id: 'D-048', name: 'Marathon bolognese' }],
  saved_meals: [{ id: 'saved-1', user_id: U, name: "Mum's chilli" }],
  meal_plans: [{ id: PLAN, user_id: U, week_start: '2026-09-06', status: 'confirmed', is_deleted: false }],
});

const resolve = async (situation: Parameters<typeof resolveSituation>[1]) => {
  const v = testCtx(world());
  const out = await resolveSituation(v, situation);
  assertEquals(v.fake.writes, [], 'resolving a Situation wrote something');
  return out;
};

Deno.test('the fuel log for a session names that session', async () => {
  assertEquals(await resolve({ route: '/fuel-log', entityId: 'act-1', date: '2026-09-12' }), 'looking at the fuel log for Long ride on Saturday 2026-09-12 (cycling, 180 min)');
});

Deno.test('the activity detail screen is the same session, framed as the fuel plan', async () => {
  for (const route of ['/current-plan', '/plan']) {
    assertEquals(await resolve({ route, entityId: 'act-1', date: '2026-09-12' }), 'looking at the fuel plan for Long ride on Saturday 2026-09-12 (cycling, 180 min)');
  }
});

Deno.test('a meal detail names the meal, from the library or their own saved meals', async () => {
  assertEquals(await resolve({ route: '/food/meals/:id', entityId: 'D-048' }), 'looking at the meal "Marathon bolognese"');
  assertEquals(await resolve({ route: '/food/meals/:id', entityId: 'saved-1' }), 'looking at the meal "Mum\'s chilli"');
});

Deno.test('cooking mode says they are cooking it now', async () => {
  assertEquals(await resolve({ route: '/food/cook/:id', entityId: 'D-048' }), 'cooking "Marathon bolognese" right now');
});

Deno.test('an event screen names the race and where it is', async () => {
  assertEquals(await resolve({ route: '/events/:eventId/checklist', entityId: 'ev-1' }), 'looking at the event Chattanooga 70.3 on 2026-09-20 in Chattanooga, TN');
});

Deno.test('the Plan tab carries the day and the week\'s status', async () => {
  assertEquals(await resolve({ route: '/food', entityId: PLAN, date: '2026-09-12' }), 'looking at the Plan tab on Saturday 2026-09-12; the week of 2026-09-06 is confirmed');
});

Deno.test('a meal-log screen names the slot and the day', async () => {
  assertEquals(await resolve({ route: '/meal-log/manual', date: '2026-09-12', slot: 'dinner' }), 'logging a dinner on Saturday 2026-09-12');
  assertEquals(await resolve({ route: '/meal-log/photo', date: '2026-09-12' }), 'logging a meal on Saturday 2026-09-12');
});

Deno.test('a main tab carries the day and nothing else', async () => {
  assertEquals(await resolve({ route: '/main', date: '2026-09-12' }), 'in the app on Saturday 2026-09-12');
});

Deno.test('an unknown route resolves to the route alone', async () => {
  assertEquals(await resolve({ route: '/settings/allergies' }), 'on the /settings/allergies screen');
  assertEquals(await resolve({ route: '/learn/video' }), 'on the /learn/video screen');
});

Deno.test('a missing or foreign entity resolves without an error', async () => {
  assertEquals(await resolve({ route: '/fuel-log', entityId: 'gone', date: '2026-09-12' }), 'looking at the fuel log on Saturday 2026-09-12');
  assertEquals(await resolve({ route: '/food/meals/:id', entityId: 'gone' }), 'looking at a meal in the library');
  assertEquals(await resolve({ route: '/events/:eventId/checklist' }), 'looking at their events');
  assertEquals(await resolve({ route: '/food' }), 'looking at the Plan tab');
});

Deno.test('no Situation at all is not a Situation', async () => {
  assertEquals(await resolve(null), null);
  assertEquals(await resolve({ route: '' }), null);
});

Deno.test('the screen table matches sub-routes by longest prefix', () => {
  assertEquals(screenFor('/meal-log/review')?.route, '/meal-log');
  assertEquals(screenFor('/events/:eventId/checklist')?.route, '/events/:eventId/checklist');
  assertEquals(screenFor('/events')?.route, '/events');
  assertEquals(screenFor('/settings'), null);
  // /food/meals/:id must win over /food, or a meal detail would read as the Plan tab.
  assertEquals(screenFor('/food/meals/:id')?.route, '/food/meals/:id');
  assertEquals(screenFor('/food')?.route, '/food');
});

Deno.test('the SITUATION line appears in the block only when a Situation was sent', async () => {
  const v = testCtx(world());
  const c = await buildAthleteContext(v, undefined, '2026-09-12', offlineDeps());
  assert(!contextBlock(c).includes('SITUATION'), 'no Situation, no line');

  c.situation = await resolveSituation(v, { route: '/fuel-log', entityId: 'act-1', date: '2026-09-12' });
  const line = contextBlock(c).split('\n').find((l) => l.startsWith('SITUATION'));
  assertEquals(line, 'SITUATION right now they are looking at the fuel log for Long ride on Saturday 2026-09-12 (cycling, 180 min)');
});
