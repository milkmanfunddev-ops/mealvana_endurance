/**
 * The Voodoo Doll at the server seam: the LIKES and GOALS lines, both conversation kinds reading
 * the same block, and the history cap.
 */
import { assert, assertEquals } from 'https://deno.land/std@0.177.1/testing/asserts.ts';
import { buildAthleteContext, contextBlock } from '../../_shared/vana/context.ts';
import { capHistory, HISTORY_CAP, systemPrompt } from '../../_shared/vana/chat.ts';
import { testCtx, offlineDeps, TEST_USER_ID } from './support/vana_ctx.ts';
import type { Tables } from './support/fake_db.ts';
import type { UIMessage } from 'npm:ai@6';

const U = TEST_USER_ID;
const ANCHOR = '2026-09-09';

const base = (): Tables => ({ users: [{ id: U, first_name: 'Lee', dietary_preference: null, allergies: [], gut_training_level: null }] });

const blockFor = async (tables: Tables) => {
  const v = testCtx(tables);
  const c = await buildAthleteContext(v, undefined, ANCHOR, offlineDeps());
  return { c, lines: contextBlock(c).split('\n') };
};
const line = (lines: string[], prefix: string) => lines.find((l) => l.startsWith(prefix)) ?? `«no ${prefix} line»`;

// ---------------------------------------------------------------- LIKES
Deno.test('LIKES: thumbed meals by name and stance, newest first, across both tables', async () => {
  const { lines } = await blockFor({
    ...base(),
    meal_feedback: [
      { user_id: U, library_meal_id: 'D-048', saved_meal_id: null, vote: 1, updated_at: '2026-09-08T10:00:00Z' },
      { user_id: U, library_meal_id: 'D-012', saved_meal_id: null, vote: -1, updated_at: '2026-09-07T10:00:00Z' },
      { user_id: U, library_meal_id: null, saved_meal_id: 'saved-1', vote: 1, updated_at: '2026-09-06T10:00:00Z' },
    ],
    meal_library: [{ id: 'D-048', name: 'Marathon bolognese' }, { id: 'D-012', name: 'Salmon and rice' }],
    saved_meals: [{ id: 'saved-1', name: "Mum's chilli" }],
  });
  assertEquals(line(lines, 'LIKES'), "LIKES 👍 Marathon bolognese | 👎 Salmon and rice | 👍 Mum's chilli");
});

Deno.test('LIKES: no thumbs reads none, and a thumb whose meal is gone is dropped rather than shown blank', async () => {
  assertEquals(line((await blockFor(base())).lines, 'LIKES'), 'LIKES none');
  const { lines } = await blockFor({ ...base(), meal_feedback: [{ user_id: U, library_meal_id: 'D-999', saved_meal_id: null, vote: 1, updated_at: '2026-09-08T10:00:00Z' }], meal_library: [] });
  assertEquals(line(lines, 'LIKES'), 'LIKES none');
});

// ---------------------------------------------------------------- GOALS
Deno.test('GOALS: the onboarding survey answers, or none when the athlete never took it', async () => {
  const { lines } = await blockFor({ ...base(), onboarding_surveys: [{ user_id: U, goals: ['Finish my first 70.3', 'Stop bonking on long rides'], sports: ['triathlon'], pitfalls: [] }] });
  assertEquals(line(lines, 'GOALS'), 'GOALS Finish my first 70.3, Stop bonking on long rides');
  assertEquals(line((await blockFor(base())).lines, 'GOALS'), 'GOALS none');
});

// ---------------------------------------------------------------- one block, both kinds
Deno.test('both conversation kinds embed the identical context block', async () => {
  const { c } = await blockFor({
    ...base(),
    meal_feedback: [{ user_id: U, library_meal_id: 'D-048', saved_meal_id: null, vote: 1, updated_at: '2026-09-08T10:00:00Z' }],
    meal_library: [{ id: 'D-048', name: 'Marathon bolognese' }],
    onboarding_surveys: [{ user_id: U, goals: ['Finish my first 70.3'] }],
  });
  const block = contextBlock(c);
  const general = systemPrompt('general', c, ANCHOR);
  const planning = systemPrompt('meal_planning', c, ANCHOR);

  assert(general.includes(block), 'general mode carries the whole block');
  assert(planning.includes(block), 'planning mode carries the whole block');
  assert(general.includes('LIKES 👍 Marathon bolognese'), 'general mode sees the thumbs');
  assert(general.includes('GOALS Finish my first 70.3'), 'general mode sees the goals');
  // The prompts above the block still differ — one persona, two sets of instructions.
  assertEquals(general.slice(general.indexOf('--- CONTEXT')), planning.slice(planning.indexOf('--- CONTEXT')));
  assert(general.slice(0, general.indexOf('--- CONTEXT')) !== planning.slice(0, planning.indexOf('--- CONTEXT')));
});

// ---------------------------------------------------------------- history cap
const msgs = (n: number): UIMessage[] => Array.from({ length: n }, (_, i) => ({ id: `m${i}`, role: i % 2 === 0 ? 'user' : 'assistant', parts: [{ type: 'text', text: `turn ${i}` }] } as UIMessage));
const textOf = (m: UIMessage) => m.parts.map((p) => (p as { text?: string }).text ?? '').join('');

Deno.test('history cap: under the cap nothing is added or removed', () => {
  const ten = msgs(10);
  assertEquals(capHistory(ten, 'Talked about race-week dinners.'), ten);
  assertEquals(capHistory(msgs(HISTORY_CAP), 'Talked about race-week dinners.').length, HISTORY_CAP);
});

Deno.test('history cap: 21 messages replay the last 20 with the episode sentence prepended once', () => {
  const out = capHistory(msgs(21), 'Talked about race-week dinners.');
  assertEquals(out.length, HISTORY_CAP + 1);
  assertEquals(out[0].role, 'user');
  assertEquals(textOf(out[0]), 'Earlier in this conversation: Talked about race-week dinners.');
  assertEquals(textOf(out[1]), 'turn 1');            // message 0 fell off the front
  assertEquals(textOf(out.at(-1)!), 'turn 20');
});

Deno.test('history cap: with no episode yet, the cap still bites and nothing is invented', () => {
  const out = capHistory(msgs(21), null);
  assertEquals(out.length, HISTORY_CAP);
  assertEquals(textOf(out[0]), 'turn 1');
  assertEquals(capHistory(msgs(21), '   ').length, HISTORY_CAP);
});
