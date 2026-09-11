/**
 * Openers that sound like Vana knows the athlete, at the server seam.
 *
 * Three things make that possible, and each is tested here without a model:
 * - The block carries a LAST TALKS line: the newest conversations, one sentence each. Episodes never
 *   crowd the margin notes out of MEMORIES, however many conversations pile up.
 * - An opener waits a moment for the conversation just before it to be read back, so the context it
 *   is written from already holds that conversation. Past the budget it goes without.
 * - Every opener tells the model to use the lines that carry the athlete, and every line it names is
 *   one the block renders.
 */
import { assert, assertEquals } from 'https://deno.land/std@0.177.1/testing/asserts.ts';
import { buildAthleteContext, contextBlock, withUnreadTalk } from '../../_shared/vana/context.ts';
import { systemPrompt } from '../../_shared/vana/chat.ts';
import { athleteWordsFrom, readBackWithin } from '../../_shared/vana/extract.ts';
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
  const c = await buildAthleteContext(testCtx(tables), undefined, ANCHOR, offlineDeps());
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

// ---------------------------------------------------------------- the read-back an opener waits for

const EPISODE = 'Planned a four-hour Saturday ride with Marco.';
const EXTRACTION: Extraction = { memories: [], episode: EPISODE };
const PREVIOUS = 'conv-yesterday';
const OPENING = 'conv-today';

const withPrevious = (): Tables => ({
  vana_conversations: [
    { id: PREVIOUS, user_id: U, kind: 'general', title: null, summary: null, is_deleted: false, read_back_at: null, last_message_at: '2026-09-10T19:00:00Z', created_at: '2026-09-10T18:00:00Z' },
    { id: OPENING, user_id: U, kind: 'general', title: null, summary: null, is_deleted: false, read_back_at: null, last_message_at: '2026-09-11T08:00:00Z', created_at: '2026-09-11T08:00:00Z' },
  ],
  vana_messages: [
    { id: 'm1', conversation_id: PREVIOUS, user_id: U, role: 'user', content: 'Riding four hours Saturday with Marco.', parts: [], created_at: '2026-09-10T18:00:00Z' },
    { id: 'm2', conversation_id: PREVIOUS, user_id: U, role: 'assistant', content: 'Then Friday wants carbs in the tank.', parts: [], created_at: '2026-09-10T18:01:00Z' },
    { id: 'm3', conversation_id: PREVIOUS, user_id: U, role: 'user', content: 'He is bringing a stove.', parts: [], created_at: '2026-09-10T18:02:00Z' },
    { id: 'm4', conversation_id: PREVIOUS, user_id: U, role: 'assistant', content: 'Oats on the stove at the halfway stop, then.', parts: [], created_at: '2026-09-10T18:03:00Z' },
  ],
  user_memories: [],
  vana_calls: [],
});

/** A model that answers only when released. */
function heldModel() {
  let release!: () => void;
  const gate = new Promise<void>((r) => { release = r; });
  const deps: ExtractDeps = { generate: async () => { await gate; return { object: EXTRACTION, inputTokens: 1, outputTokens: 1 }; } };
  return { deps, release };
}

Deno.test('an opener waits for the conversation before it: a read-back inside the budget lands before the context is read', async () => {
  const v = testCtx(withPrevious());
  const background: Promise<unknown>[] = [];
  const model = heldModel();
  const waited = readBackWithin(v, OPENING, 1000, (p) => background.push(p), model.deps);
  model.release();
  const out = await waited;

  assertEquals(out.outcome?.episode, EPISODE);
  assertEquals(out.late, null);
  assertEquals(await episodeFor(v, PREVIOUS), EPISODE);
  const lines = contextBlock(await buildAthleteContext(v, undefined, ANCHOR, offlineDeps())).split('\n');
  assertEquals(line(lines, 'LAST TALKS'), `LAST TALKS (what they said, not their schedule) ${new Date().toISOString().slice(5, 10)} ${EPISODE}`);
  assertEquals(background.length, 1, 'the read-back is also handed to the background, so it finishes whatever the opener does');
});

Deno.test('an opener never waits past its budget: a slow read-back finishes in the background', async () => {
  const v = testCtx(withPrevious());
  const background: Promise<unknown>[] = [];
  const model = heldModel();
  const started = Date.now();

  const out = await readBackWithin(v, OPENING, 30, (p) => background.push(p), model.deps);

  assertEquals(out, { outcome: null, late: PREVIOUS }, 'names the conversation it could not wait for');
  assert(Date.now() - started < 1000, 'returned at the budget');
  assertEquals(await episodeFor(v, PREVIOUS), null, 'not landed yet');
  model.release();
  await Promise.all(background);
  assertEquals(await episodeFor(v, PREVIOUS), EPISODE, 'landed afterwards, for the next opener');
});

Deno.test('a late read-back still leaves the opener the athlete\'s own last words, first in LAST TALKS', async () => {
  const v = testCtx(withPrevious());
  const words = await athleteWordsFrom(v, PREVIOUS);
  assertEquals(words, 'Riding four hours Saturday with Marco. / He is bringing a stove.');

  const c = withUnreadTalk(await buildAthleteContext(v, undefined, ANCHOR, offlineDeps()), ANCHOR, words);
  assertEquals(line(contextBlock(c).split('\n'), 'LAST TALKS'), 'LAST TALKS (what they said, not their schedule) 09-11 not read back yet; they said: "Riding four hours Saturday with Marco. / He is bringing a stove."');
});

Deno.test('with nothing to read back, there is nothing late and nothing added', async () => {
  const v = testCtx({ ...withPrevious(), vana_conversations: withPrevious().vana_conversations!.slice(1) });
  assertEquals(await readBackWithin(v, OPENING, 30, () => {}, heldModel().deps), { outcome: null, late: null });
  const c = await buildAthleteContext(v, undefined, ANCHOR, offlineDeps());
  assertEquals(withUnreadTalk(c, ANCHOR, null).lastTalks, c.lastTalks);
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
  const c = await buildAthleteContext(testCtx(athlete()), undefined, ANCHOR, offlineDeps());
  assert(systemPrompt('general', c, '2026-09-11').includes('--- CONTEXT (today 2026-09-11, Friday) ---'));
  assert(systemPrompt('meal_planning', c, '2026-09-13').includes('--- CONTEXT (today 2026-09-13, Sunday) ---'));
});
