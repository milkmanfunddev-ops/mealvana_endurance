/**
 * Ticket 97 (testing-wave, Findings 16-006, 18-007) at the server seam: `list_conversations` tells the app which plan
 * each meal-plan conversation holds, so the list can title a row by week and state ("Sep 20 week · Draft") instead of
 * "This week's plan" fifteen times over.
 *
 * Rows are producer-shaped: what `vana_conversations` / `meal_plans` / `plan_meals` return, snake_case and all. The meal
 * count comes back the way PostgREST embeds it (`plan_meals: [{ count }]`).
 */
import { assertEquals } from 'https://deno.land/std@0.177.1/testing/asserts.ts';
import { listConversations } from '../../_shared/vana/chat.ts';
import { extraAction } from '../../_shared/vana/actions.ts';
import { testCtx, TEST_USER_ID } from './support/vana_ctx.ts';

const U = TEST_USER_ID;

const conv = (id: string, over: Record<string, unknown> = {}) => ({
  id, user_id: U, kind: 'meal_planning', title: "This week's plan", summary: null, is_deleted: false,
  last_message_at: `2026-09-${id.slice(-2)}T09:00:00Z`, created_at: `2026-09-${id.slice(-2)}T08:00:00Z`, ...over,
});
const planRow = (id: string, conversationId: string | null, weekStart: string, status: string, over: Record<string, unknown> = {}) => ({
  id, user_id: U, week_start: weekStart, status, batch_cooking: true, conversation_id: conversationId, is_deleted: false, name: null,
  created_at: `${weekStart}T09:00:00Z`, updated_at: `${weekStart}T09:00:00Z`, ...over,
});
const mealRow = (id: string, planId: string) => ({ id, plan_id: planId, user_id: U, source: 'library', library_meal_id: `L-${id}`, name: id, meal_type: 'dinner', servings: 1, position: 0 });

function account() {
  return testCtx({
    vana_conversations: [
      conv('conv-20'),                       // this week's draft, 2 meals
      conv('conv-13'),                       // last week's confirmed plan
      conv('conv-12'),                       // an old opener that never built anything
      conv('conv-11'),                       // an empty draft only
      conv('conv-10'),                       // scrapped once: an archived plan and the newer confirmed one
      conv('conv-09', { kind: 'general', title: 'Quick question' }),
      conv('conv-08', { is_deleted: true }),
    ],
    meal_plans: [
      planRow('p-20', 'conv-20', '2026-09-20', 'draft'),
      planRow('p-13', 'conv-13', '2026-09-13', 'confirmed'),
      planRow('p-11', 'conv-11', '2026-09-13', 'draft'),
      planRow('p-10a', 'conv-10', '2026-09-06', 'archived', { updated_at: '2026-09-06T12:00:00Z' }),
      planRow('p-10b', 'conv-10', '2026-09-06', 'confirmed', { updated_at: '2026-09-06T11:00:00Z' }),
      planRow('p-tab', null, '2026-09-20', 'confirmed'),
    ],
    plan_meals: [
      mealRow('m1', 'p-20'), mealRow('m2', 'p-20'),
      mealRow('m3', 'p-13'),
      mealRow('m4', 'p-10a'), mealRow('m5', 'p-10b'),
      mealRow('m6', 'p-tab'),
    ],
  });
}

Deno.test('listConversations: each planning conversation carries its plan\'s week, state and meal count', async () => {
  const out = await listConversations(account(), 30, 'meal_planning');
  assertEquals(out.map((c) => [c.id, c.plan]), [
    ['conv-20', { weekStart: '2026-09-20', status: 'draft', mealCount: 2 }],
    ['conv-13', { weekStart: '2026-09-13', status: 'confirmed', mealCount: 1 }],
    ['conv-12', null],
    ['conv-11', { weekStart: '2026-09-13', status: 'draft', mealCount: 0 }],
    ['conv-10', { weekStart: '2026-09-06', status: 'confirmed', mealCount: 1 }],
  ]);
});

Deno.test('listConversations: a general conversation has no plan; the stored title is untouched', async () => {
  const out = await listConversations(account(), 30);
  const general = out.find((c) => c.id === 'conv-09')!;
  assertEquals(general.plan, null);
  assertEquals(general.title, 'Quick question');
  assertEquals(out.find((c) => c.id === 'conv-20')!.title, "This week's plan");
  assertEquals(out.some((c) => c.id === 'conv-08'), false);
});

Deno.test('listConversations: the plans come in one read; none when the list is empty', async () => {
  const v = account();
  await listConversations(v, 30, 'meal_planning');
  assertEquals(v.fake.reads, ['vana_conversations', 'meal_plans']);

  const empty = testCtx({ vana_conversations: [] });
  assertEquals(await listConversations(empty, 30, 'meal_planning'), []);
  assertEquals(empty.fake.reads, ['vana_conversations']);
});

// ---- Ticket 126 (88-002, 89-007, 88-021): the app reads the list through `list_conversations`, so the row titles come
// from the same plan pick as everything else, and it pages with `offset` so an account with 80 conversations reaches them all.

Deno.test('list_conversations: the action answers the same rows and plans as listConversations, for one kind', async () => {
  const v = account();
  const out = await extraAction(v, 'list_conversations', { kind: 'meal_planning', limit: 50 });
  assertEquals(out!.parts, []);
  assertEquals(out!.conversations, await listConversations(account(), 50, 'meal_planning'));
  assertEquals((out!.conversations as { id: string }[]).map((c) => c.id), ['conv-20', 'conv-13', 'conv-12', 'conv-11', 'conv-10']);
});

Deno.test('list_conversations: offset pages through the list in order, with no row twice and an empty page at the end', async () => {
  const v = account();
  const page = async (offset: number) => ((await extraAction(v, 'list_conversations', { kind: 'meal_planning', limit: 2, offset }))!.conversations as { id: string }[]).map((c) => c.id);
  assertEquals(await page(0), ['conv-20', 'conv-13']);
  assertEquals(await page(2), ['conv-12', 'conv-11']);
  assertEquals(await page(4), ['conv-10']);
  assertEquals(await page(6), []);
});

Deno.test('list_conversations: a bad limit or offset falls back instead of failing', async () => {
  const v = account();
  const out = await extraAction(v, 'list_conversations', { kind: 'general', limit: 'x', offset: -3 });
  assertEquals((out!.conversations as { id: string }[]).map((c) => c.id), ['conv-09']);
});
