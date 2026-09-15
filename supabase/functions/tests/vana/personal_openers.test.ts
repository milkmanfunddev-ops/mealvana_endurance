/**
 * Openers that sound like Vana knows the athlete, at the server seam.
 *
 * Three things make that possible, and each is tested here without a model:
 * - The block carries a LAST TALKS line: the newest conversations, one sentence each. Episodes never
 *   crowd the margin notes out of MEMORIES, however many conversations pile up.
 * - The client says when a conversation is idle, and that signal writes its episode once (mp-288), so
 *   the next opener reads what exists and never waits for anything (mp-278).
 * - Every opener tells the model to use the lines that carry the athlete, and every line it names is
 *   one the block renders.
 */
import { assert, assertEquals } from 'https://deno.land/std@0.177.1/testing/asserts.ts';
import { buildAthleteContext, contextBlock } from '../../_shared/vana/context.ts';
import { idleSignal, systemPrompt, type ChatBody } from '../../_shared/vana/chat.ts';
import { IdleAckZ } from '../../_shared/vana/schemas.ts';
import type { Extraction, ExtractDeps } from '../../_shared/vana/extract.ts';
import { episodeFor } from '../../_shared/vana/memory.ts';
import { OPENERS, checkinOpener, debriefOpener } from '../../_shared/vana/persona.ts';
import { preWorkoutOpener, recoveryOpener } from '../../_shared/vana/moment.ts';
import type { MealPlan } from '../../_shared/vana/contracts.ts';
import { testCtx, offlineDeps, TEST_USER_ID } from './support/vana_ctx.ts';
import type { Row, Tables } from './support/fake_db.ts';

const U = TEST_USER_ID;
const ANCHOR = '2026-09-11';

const athlete = (): Tables => ({ users: [{ id: U, first_name: 'Lee', dietary_preference: null, allergies: [], gut_training_level: null }] });

const memory = (id: string, kind: string, fact: string, at: string, key: string | null = null): Row => ({
  id, user_id: U, kind, key, fact, value: null, confidence: 0.9, last_confirmed_at: at, source: 'conversation', is_deleted: false,
});

const blockFor = async (tables: Tables) => {
  const c = await buildAthleteContext(testCtx(tables), ANCHOR, offlineDeps());
  return contextBlock(c).split('\n');
};
const line = (lines: string[], prefix: string) => lines.find((l) => l.startsWith(`${prefix} `)) ?? `«no ${prefix} line»`;

// ---------------------------------------------------------------- LAST TALKS

Deno.test('LAST TALKS: the three newest conversations, dated, newest first; a repeated sentence shows once', async () => {
  const lines = await blockFor({
    ...athlete(),
    user_memories: [
      memory('e1', 'episode', 'Planned a four-hour Saturday ride with Marco.', '2026-09-11T08:00:00Z', 'conv-4'),
      memory('e2', 'episode', 'Asked about coffee before rides.', '2026-09-10T18:00:00Z', 'conv-3'),
      memory('e3', 'episode', 'Asked about coffee before rides.', '2026-09-10T17:00:00Z', 'conv-2'),
      memory('e4', 'episode', 'Confirmed five vegetarian dinners.', '2026-09-09T12:00:00Z', 'conv-1'),
      memory('e5', 'episode', 'Checked the weather in Birmingham.', '2026-09-08T12:00:00Z', 'conv-0'),
    ],
  });
  assertEquals(
    line(lines, 'LAST TALKS'),
    'LAST TALKS (what they said, not their schedule) 09-11 Planned a four-hour Saturday ride with Marco. | 09-10 Asked about coffee before rides. | 09-09 Confirmed five vegetarian dinners.',
  );
});

Deno.test('LAST TALKS: no conversation read back yet reads none', async () => {
  assertEquals(line(await blockFor(athlete()), 'LAST TALKS'), 'LAST TALKS none');
});

Deno.test('MEMORIES: margin notes survive any number of newer conversations, and no episode shows there', async () => {
  const episodes = Array.from({ length: 12 }, (_, i) =>
    memory(`e${i}`, 'episode', `Conversation number ${i}.`, new Date(Date.UTC(2026, 8, 11, 12 - i)).toISOString(), `conv-${i}`));
  const lines = await blockFor({
    ...athlete(),
    user_memories: [...episodes, memory('p1', 'preference', 'Cannot stand the smell of cooked broccoli.', '2026-09-01T10:00:00Z')],
  });
  const memories = line(lines, 'MEMORIES');
  assert(memories.includes('Cannot stand the smell of cooked broccoli.'), memories);
  assert(!memories.includes('Conversation number'), memories);
});

// ---------------------------------------------------------------- the idle signal (mp-277 clause 3, mp-288)

const EPISODE = 'Planned a four-hour Saturday ride with Marco.';
const EXTRACTION: Extraction = { memories: [{ kind: 'pattern', fact: 'Rides long with Marco on Saturdays.' }], episode: EPISODE };
const PREVIOUS = 'conv-yesterday';

/** Last night's conversation, the way the rows store it: it begins with Vana's turn, and nobody has read it back. */
const lastNight = (): Tables => ({
  vana_conversations: [
    { id: PREVIOUS, user_id: U, kind: 'general', title: null, summary: null, is_deleted: false, read_back_at: null, last_message_at: '2026-09-10T19:00:00Z', created_at: '2026-09-10T18:00:00Z' },
  ],
  vana_messages: [
    { id: 'm1', conversation_id: PREVIOUS, user_id: U, role: 'assistant', content: 'Evening. Tomorrow is a rest day, so dinner can be easy.', parts: [], created_at: '2026-09-10T18:00:00Z' },
    { id: 'm2', conversation_id: PREVIOUS, user_id: U, role: 'user', content: 'Riding four hours Saturday with Marco.', parts: [], created_at: '2026-09-10T18:01:00Z' },
    { id: 'm3', conversation_id: PREVIOUS, user_id: U, role: 'assistant', content: 'Then Friday wants carbs in the tank.', parts: [], created_at: '2026-09-10T18:02:00Z' },
    { id: 'm4', conversation_id: PREVIOUS, user_id: U, role: 'user', content: 'He is bringing a stove.', parts: [], created_at: '2026-09-10T18:03:00Z' },
  ],
  user_memories: [],
  vana_calls: [],
});

/** A model stand-in that answers with a fixed extraction and counts how often it was asked. */
function countingModel() {
  let calls = 0;
  const deps: ExtractDeps = { generate: () => { calls++; return Promise.resolve({ object: EXTRACTION, inputTokens: 1, outputTokens: 1 }); } };
  return { deps, calls: () => calls };
}

/** Runs the signal the way the function does, and waits for what it handed to the background. */
async function signal(v: ReturnType<typeof testCtx>, body: ChatBody, model: ExtractDeps) {
  const background: Promise<unknown>[] = [];
  const ack = idleSignal(v, body, (p) => background.push(p), model);
  await Promise.all(background);
  return { ack, background };
}

Deno.test('idle: the first signal for a conversation writes its episode and the notes the tool missed', async () => {
  const v = testCtx(lastNight());
  const model = countingModel();
  const { ack } = await signal(v, { idle: true, conversation_id: PREVIOUS }, model.deps);

  assertEquals(IdleAckZ.parse(ack), { idle: true, conversation_id: PREVIOUS });
  assertEquals(await episodeFor(v, PREVIOUS), EPISODE);
  assertEquals(v.fake.rows('user_memories').filter((m) => m.kind !== 'episode').map((m) => m.fact), ['Rides long with Marco on Saturdays.']);
  // What the next opener reads: the episode is in LAST TALKS before that conversation opens.
  const lines = contextBlock(await buildAthleteContext(v, ANCHOR, offlineDeps())).split('\n');
  assert(line(lines, 'LAST TALKS').includes(EPISODE), line(lines, 'LAST TALKS'));
});

Deno.test('idle: a second signal for the same conversation writes nothing', async () => {
  const v = testCtx(lastNight());
  const model = countingModel();
  await signal(v, { idle: true, conversation_id: PREVIOUS }, model.deps);
  const after = structuredClone(v.fake.rows('user_memories'));

  const { ack } = await signal(v, { idle: true, conversation_id: PREVIOUS }, model.deps);

  assertEquals(ack, { idle: true, conversation_id: PREVIOUS }, 'still acknowledged');
  assertEquals(model.calls(), 1, 'the model is not asked twice');
  assertEquals(v.fake.rows('user_memories'), after);
});

Deno.test('idle: a turn without the flag writes nothing and is not an idle signal', async () => {
  const v = testCtx(lastNight());
  const model = countingModel();
  for (const body of [{ conversation_id: PREVIOUS, message: 'Hi' }, { conversation_id: PREVIOUS, opener: true }, { idle: false, conversation_id: PREVIOUS }] as ChatBody[]) {
    const { ack, background } = await signal(v, body, model.deps);
    assertEquals(ack, null);
    assertEquals(background.length, 0);
  }
  assertEquals(model.calls(), 0);
  assertEquals(v.fake.rows('user_memories'), []);
  assertEquals(v.fake.rows('vana_conversations')[0].read_back_at, null);
});

Deno.test('idle: a signal with no conversation is acknowledged and writes nothing', async () => {
  const v = testCtx(lastNight());
  const model = countingModel();
  const { ack, background } = await signal(v, { idle: true }, model.deps);
  assertEquals(ack, { idle: true, conversation_id: null });
  assertEquals(background.length, 0);
  assertEquals(model.calls(), 0);
});

Deno.test('idle: a failed write never throws, and a later signal can still write the episode', async () => {
  const v = testCtx(lastNight());
  const failing: ExtractDeps = { generate: () => Promise.reject(new Error('gateway down')) };
  await signal(v, { idle: true, conversation_id: PREVIOUS }, failing);
  assertEquals(await episodeFor(v, PREVIOUS), null);

  await signal(v, { idle: true, conversation_id: PREVIOUS }, countingModel().deps);
  assertEquals(await episodeFor(v, PREVIOUS), EPISODE);
});

// ---------------------------------------------------------------- every opener reads the athlete

const PLAN: MealPlan = {
  id: 'plan-1', weekStart: '2026-09-06', status: 'confirmed', batchCooking: true,
  meals: [{ name: 'Lentil bolognese', servings: 4, session: 'cook-sun' }],
  shopping: [],
} as unknown as MealPlan;

const OPENER_TEXTS: Record<string, string> = {
  'general': OPENERS.general,
  'meal_planning': OPENERS.meal_planning,
  'check-in': checkinOpener(PLAN, '2026-09-11', 'cook-sun', ANCHOR),
  'debrief': debriefOpener(PLAN),
  'pre-workout moment': preWorkoutOpener({ title: 'Tempo run', activityType: 'running', durationMinutes: 60, startsAt: '8:15 am', windowOpensAt: '7:15 am' }),
  'recovery moment': recoveryOpener({ title: 'Long ride', activityType: 'cycling', durationMinutes: 180, endedAt: '11:00 am', urgentUntil: null, next: null }),
  'urgent recovery moment': recoveryOpener({ title: 'Long ride', activityType: 'cycling', durationMinutes: 180, endedAt: '11:00 am', urgentUntil: '3:00 pm', next: { title: 'Swim', when: 'at 5:00 pm' } }),
};

/** The lines that carry the athlete rather than their week. */
const PERSONAL = ['LAST TALKS', 'MEMORIES', 'LIKES', 'GOALS'];

Deno.test('every opener tells the model to use what it knows about the athlete', () => {
  for (const [name, text] of Object.entries(OPENER_TEXTS)) {
    for (const prefix of PERSONAL) assert(text.includes(prefix), `${name} opener names ${prefix}`);
  }
});

Deno.test('every line an opener names is a line the block renders', async () => {
  const lines = await blockFor(athlete());
  for (const prefix of PERSONAL) assert(lines.some((l) => l.startsWith(`${prefix} `)), `the block renders ${prefix}`);
});

Deno.test('the context header names the weekday, so a talk about "Saturday" reads against today', async () => {
  const c = await buildAthleteContext(testCtx(athlete()), ANCHOR, offlineDeps());
  assert(systemPrompt('general', c, '2026-09-11').includes('--- CONTEXT (today 2026-09-11, Friday) ---'));
  assert(systemPrompt('meal_planning', c, '2026-09-13').includes('--- CONTEXT (today 2026-09-13, Sunday) ---'));
});
