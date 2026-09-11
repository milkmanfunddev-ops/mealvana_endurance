/**
 * An episode for a conversation still in progress, at the server seam.
 *
 * Past HISTORY_CAP messages a turn replays only the last twenty, and the episode sentence stands in
 * for what fell off the front. Lazy extraction writes episodes only for conversations the athlete has
 * left, so the turn that first crosses the cap writes one itself, in the background, and the next
 * turn picks it up.
 *
 * The model call and the background scheduler are injected. What is under test is when the episode
 * is written, which row it lands in, and that the reply never waits for it.
 */
import { assert, assertEquals } from 'https://deno.land/std@0.177.1/testing/asserts.ts';
import type { UIMessage } from 'npm:ai@6';
import { conversationMessages, replayHistory, HISTORY_CAP } from '../../_shared/vana/chat.ts';
import type { ReplayDeps } from '../../_shared/vana/chat.ts';
import { extractConversation } from '../../_shared/vana/extract.ts';
import type { EpisodeDeps, ExtractDeps } from '../../_shared/vana/extract.ts';
import { episodeFor } from '../../_shared/vana/memory.ts';
import { testCtx, TEST_USER_ID } from './support/vana_ctx.ts';
import type { Row, Tables } from './support/fake_db.ts';

const U = TEST_USER_ID;
const CONV = 'conv-today';
const FIRST_WORDS = 'Riding four hours on Saturday with Marco, he is bringing the stove.';

/** `n` stored turns the way the rows hold them: a general conversation the athlete opened by typing,
 *  so row 0 is theirs. The last row is the turn being answered — runChat stores it before replaying. */
const storedTurns = (n: number, from = 0): Row[] => Array.from({ length: n }, (_, j) => {
  const i = from + j;
  const user = i % 2 === 0;
  return {
    id: `m${String(i).padStart(2, '0')}`, conversation_id: CONV, user_id: U, role: user ? 'user' : 'assistant',
    content: i === 0 ? FIRST_WORDS : `${user ? 'question' : 'answer'} ${i}`,
    parts: user ? null : [{ type: 'text', text: `answer ${i}` }],
    metadata: null,
    created_at: new Date(Date.UTC(2026, 8, 10, 9, i)).toISOString(),
  };
});

const conversation = (over: Partial<Row> = {}): Row => ({ id: CONV, user_id: U, kind: 'general', title: null, summary: null, is_deleted: false, read_back_at: null, last_message_at: '2026-09-10T09:30:00Z', created_at: '2026-09-10T09:00:00Z', ...over });
const world = (messages: number, over: Partial<Tables> = {}): Tables => ({ vana_conversations: [conversation()], vana_messages: storedTurns(messages), user_memories: [], vana_calls: [], ...over });

/** What runChat replays from: the conversation's stored rows, read by the same reader it uses. */
const history = async (v: ReturnType<typeof testCtx>): Promise<UIMessage[]> => (await conversationMessages(v, CONV)).messages;
const textOf = (m: UIMessage) => m.parts.map((p) => (p as { text?: string }).text ?? '').join('');

const EPISODE = 'Planning food for a four-hour Saturday ride with Marco, who brings the stove.';

/** A model that answers only when released, so a test can see what happened before it did. */
function heldModel(episode = EPISODE) {
  const calls: { system: string; prompt: string }[] = [];
  let release!: () => void;
  const released = new Promise<void>((r) => { release = r; });
  const deps: EpisodeDeps = { generate: async (input) => { calls.push(input); await released; return { object: { episode }, inputTokens: 700, outputTokens: 30 }; } };
  return { deps, calls, release };
}
/** A scheduler that records the background work instead of handing it to EdgeRuntime. */
function recorder(episode: EpisodeDeps): ReplayDeps & { tasks: Promise<unknown>[] } {
  const tasks: Promise<unknown>[] = [];
  return { tasks, episode, background: (p) => { tasks.push(p); } };
}
const episodeRows = (v: ReturnType<typeof testCtx>) => v.fake.rows('user_memories').filter((r) => r.kind === 'episode');

Deno.test('the turn that crosses the cap writes an episode in the background and does not wait for it', async () => {
  const v = testCtx(world(HISTORY_CAP + 1));
  const model = heldModel();
  const deps = recorder(model.deps);

  const replayed = await replayHistory(v, CONV, await history(v), deps);

  // The reply went ahead while the model was still thinking: nothing is written yet, and this turn
  // replays the last twenty with nothing prepended — the episode is for the next turn.
  assertEquals(replayed.length, HISTORY_CAP);
  assertEquals(textOf(replayed[0]), 'answer 1');
  assertEquals(deps.tasks.length, 1, 'one background write was scheduled');
  assertEquals(episodeRows(v).length, 0);

  model.release();
  await Promise.all(deps.tasks);

  assertEquals(await episodeFor(v, CONV), EPISODE);
  assertEquals(model.calls.length, 1);
  assert(model.calls[0].prompt.includes(FIRST_WORDS), 'the words about to fall off the front reached the model');
});

Deno.test('the next turn prepends the episode, and the turn after that does not write a second one', async () => {
  const v = testCtx(world(HISTORY_CAP + 1));
  const first = heldModel();
  const crossing = recorder(first.deps);
  await replayHistory(v, CONV, await history(v), crossing);
  first.release();
  await Promise.all(crossing.tasks);

  // Vana answers, the athlete speaks again.
  v.fake.tables.vana_messages = storedTurns(HISTORY_CAP + 3);
  const again = heldModel('A second episode that must never be written.');
  const next = recorder(again.deps);
  const replayed = await replayHistory(v, CONV, await history(v), next);

  assertEquals(replayed.length, HISTORY_CAP + 1);
  assertEquals(textOf(replayed[0]), `Earlier in this conversation: ${EPISODE}`);
  assertEquals(next.tasks.length, 0, 'nothing scheduled once the episode exists');
  assertEquals(again.calls.length, 0, 'the model was not asked again');

  v.fake.tables.vana_messages = storedTurns(HISTORY_CAP + 5);
  const later = recorder(again.deps);
  await replayHistory(v, CONV, await history(v), later);
  assertEquals(later.tasks.length, 0);
  assertEquals(episodeRows(v).length, 1);
});

Deno.test('the mid-conversation episode is the row lazy extraction later rewrites, not a second one', async () => {
  const v = testCtx(world(HISTORY_CAP + 1));
  const model = heldModel();
  const deps = recorder(model.deps);
  await replayHistory(v, CONV, await history(v), deps);
  model.release();
  await Promise.all(deps.tasks);

  // Writing the episode is not reading the conversation back: its margin notes are still owed.
  assertEquals(v.fake.rows('vana_conversations')[0].read_back_at, null);
  assertEquals(v.fake.rows('vana_conversations')[0].summary, EPISODE);

  // The athlete leaves; opening the next conversation reads this one back.
  const lazy: ExtractDeps = { generate: () => Promise.resolve({ object: { memories: [{ kind: 'pattern', fact: 'Does long rides with Marco on Saturdays.' }], episode: 'Planned ride food with Marco and then talked race-week breakfasts.' } }) };
  const out = await extractConversation(v, CONV, lazy);

  assertEquals(out.memories, 1);
  assertEquals(episodeRows(v).length, 1, 'one episode row for the conversation');
  assertEquals(await episodeFor(v, CONV), 'Planned ride food with Marco and then talked race-week breakfasts.');
});

Deno.test('a conversation that never crosses the cap writes nothing', async () => {
  const v = testCtx(world(HISTORY_CAP));
  const model = heldModel();
  const deps = recorder(model.deps);

  const replayed = await replayHistory(v, CONV, await history(v), deps);

  assertEquals(replayed.length, HISTORY_CAP);
  assertEquals(deps.tasks.length, 0);
  assertEquals(model.calls.length, 0);
  assertEquals(v.fake.rows('user_memories').length, 0);
});

Deno.test('an ephemeral turn has no conversation to write an episode for', async () => {
  const v = testCtx(world(HISTORY_CAP + 1));
  const deps = recorder(heldModel().deps);
  const replayed = await replayHistory(v, '', await history(v), deps);
  assertEquals(replayed.length, HISTORY_CAP);
  assertEquals(deps.tasks.length, 0);
});

Deno.test('a failed episode write is silent and leaves the next turn free to try again', async () => {
  const v = testCtx(world(HISTORY_CAP + 1));
  const failing: EpisodeDeps = { generate: () => Promise.reject(new Error('gateway down')) };
  const deps = recorder(failing);
  await replayHistory(v, CONV, await history(v), deps);
  await Promise.all(deps.tasks);   // must not reject: it runs where nobody is listening
  assertEquals(episodeRows(v).length, 0);

  v.fake.tables.vana_messages = storedTurns(HISTORY_CAP + 3);
  const model = heldModel();
  const retry = recorder(model.deps);
  await replayHistory(v, CONV, await history(v), retry);
  model.release();
  await Promise.all(retry.tasks);
  assertEquals(await episodeFor(v, CONV), EPISODE);
});

Deno.test('an open-conversation episode that lands after lazy extraction does not overwrite it', async () => {
  const v = testCtx(world(HISTORY_CAP + 1));
  const model = heldModel('A partial episode, written from the first twenty-one messages.');
  const deps = recorder(model.deps);
  await replayHistory(v, CONV, await history(v), deps);

  // While that model call is still out, the athlete leaves and the next conversation reads this one back.
  const lazy: ExtractDeps = { generate: () => Promise.resolve({ object: { memories: [], episode: 'The finished conversation, read back whole.' } }) };
  await extractConversation(v, CONV, lazy);

  model.release();
  await Promise.all(deps.tasks);
  assertEquals(episodeRows(v).length, 1);
  assertEquals(await episodeFor(v, CONV), 'The finished conversation, read back whole.');
});

Deno.test('two episode rows for one conversation still prepend one, and schedule no further writes', async () => {
  // No index keeps an episode unique, so two writers racing can leave two rows. That must cost a
  // duplicate, never the prepend — and never a write on every turn from then on.
  const ep = (id: string, fact: string, at: string): Row => ({ id, user_id: U, kind: 'episode', key: CONV, fact, value: null, confidence: 0.9, source: 'conversation', is_deleted: false, last_confirmed_at: at });
  const v = testCtx(world(HISTORY_CAP + 3, { user_memories: [ep('e1', 'The older sentence.', '2026-09-10T09:21:00Z'), ep('e2', 'The newer sentence.', '2026-09-10T09:22:00Z')] }));
  const model = heldModel();
  const deps = recorder(model.deps);

  const replayed = await replayHistory(v, CONV, await history(v), deps);

  assertEquals(textOf(replayed[0]), 'Earlier in this conversation: The newer sentence.');
  assertEquals(deps.tasks.length, 0);
});
