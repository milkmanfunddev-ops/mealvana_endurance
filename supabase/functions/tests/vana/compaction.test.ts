/**
 * A long conversation keeps its opening, at the server seam (mp-277 clause 1, mp-290 clause 2).
 *
 * History is chunked, never sliding. Every message stays verbatim up to forty; at forty the oldest
 * twenty become one summary message and the last twenty stay; at sixty the same again, rolling the
 * previous summary in. The summary is written in the background when the count reaches thirty and
 * applied from forty, and it lives on the conversation row keyed by the message index it covers.
 *
 * The model call and the background scheduler are injected. What is under test is the replayed
 * shape, when the summary is written, which row and key it lands on, and that the reply never waits.
 */
import { assert, assertEquals } from 'https://deno.land/std@0.177.1/testing/asserts.ts';
import type { UIMessage } from 'npm:ai@6.0.277';
import { compactHistory, conversationMessages, replayHistory, summaryDueAt, summaryIndexAt, SUMMARY_CHUNK, SUMMARY_LEAD, VERBATIM_CAP } from '../../_shared/vana/chat.ts';
import type { ReplayDeps } from '../../_shared/vana/chat.ts';
import { parseSummaries, renderSummaries } from '../../_shared/vana/extract.ts';
import type { SummaryDeps } from '../../_shared/vana/extract.ts';
import { testCtx, TEST_USER_ID } from './support/vana_ctx.ts';
import type { Row, Tables } from './support/fake_db.ts';

const U = TEST_USER_ID;
const CONV = 'conv-long';
const TURN_THREE = 'For Tuesday I will go with the lentil bolognese, and Marco is coming over for it.';

/** `n` stored turns the way the rows hold them: a general conversation the athlete opened by typing,
 *  so row 0 is theirs. The last row is the turn being answered — runChat stores it before replaying. */
const storedTurns = (n: number): Row[] => Array.from({ length: n }, (_, i) => {
  const user = i % 2 === 0;
  return {
    id: `m${String(i).padStart(3, '0')}`, conversation_id: CONV, user_id: U, role: user ? 'user' : 'assistant',
    content: i === 2 ? TURN_THREE : `${user ? 'question' : 'answer'} ${i}`,
    parts: user ? null : [{ type: 'text', text: `answer ${i}` }],
    metadata: null,
    created_at: new Date(Date.UTC(2026, 8, 15, 9, 0, i)).toISOString(),
  };
});
const conversation = (over: Partial<Row> = {}): Row => ({ id: CONV, user_id: U, kind: 'general', title: null, summary: null, summary_index: null, is_deleted: false, read_back_at: null, last_message_at: '2026-09-15T09:30:00Z', created_at: '2026-09-15T09:00:00Z', ...over });
const world = (messages: number, over: Partial<Tables> = {}): Tables => ({ vana_conversations: [conversation()], vana_messages: storedTurns(messages), user_memories: [], vana_calls: [], ...over });

const history = async (v: ReturnType<typeof testCtx>): Promise<UIMessage[]> => (await conversationMessages(v, CONV)).messages;
const textOf = (m: UIMessage) => m.parts.map((p) => (p as { text?: string }).text ?? '').join('');
const row = (v: ReturnType<typeof testCtx>) => v.fake.rows('vana_conversations')[0];

const SUMMARY_20 = 'Planning the week\'s dinners; Tuesday is lentil bolognese with Marco coming over.';
const SUMMARY_40 = 'Dinners planned around evening training; Tuesday is lentil bolognese with Marco; later asked about breakfasts and snacks.';

/** A model that answers only when released, so a test can see what happened before it did. */
function heldModel(summary = SUMMARY_20) {
  const calls: { system: string; prompt: string }[] = [];
  let release!: () => void;
  const released = new Promise<void>((r) => { release = r; });
  const deps: SummaryDeps = { generate: async (input) => { calls.push(input); await released; return { object: { summary }, inputTokens: 900, outputTokens: 120 }; } };
  return { deps, calls, release };
}
/** A scheduler that records the background work instead of handing it to EdgeRuntime. */
function recorder(summary: SummaryDeps): ReplayDeps & { tasks: Promise<unknown>[] } {
  const tasks: Promise<unknown>[] = [];
  return { tasks, summary, background: (p) => { tasks.push(p); } };
}
/** Drives the conversation to `n` stored rows, answers with the held model, and lets its write land. */
async function turnAt(v: ReturnType<typeof testCtx>, n: number, summary: string) {
  v.fake.tables.vana_messages = storedTurns(n);
  const model = heldModel(summary);
  const deps = recorder(model.deps);
  const replayed = await replayHistory(v, CONV, await history(v), deps);
  model.release();
  await Promise.all(deps.tasks);
  return { replayed, model, deps };
}

// ---------------------------------------------------------------- the constants and the arithmetic

Deno.test('the constants say what the decision says: verbatim to forty, chunks of twenty, written ten ahead', () => {
  assertEquals(VERBATIM_CAP, 40);
  assertEquals(SUMMARY_CHUNK, 20);
  assertEquals(SUMMARY_LEAD, 10);
});

Deno.test('the applied index: nothing under forty, then twenty until sixty, then forty', () => {
  assertEquals([1, 29, 30, 39].map(summaryIndexAt), [0, 0, 0, 0]);
  assertEquals([40, 41, 59].map(summaryIndexAt), [20, 20, 20]);
  assertEquals([60, 61, 79].map(summaryIndexAt), [40, 40, 40]);
  assertEquals(summaryIndexAt(80), 60);
});

Deno.test('the due index: the summary for twenty is due at thirty, for forty at fifty', () => {
  assertEquals([1, 29].map(summaryDueAt), [0, 0]);
  assertEquals([30, 39, 49].map(summaryDueAt), [20, 20, 20]);
  assertEquals([50, 69].map(summaryDueAt), [40, 40]);
  assertEquals(summaryDueAt(70), 60);
});

// ---------------------------------------------------------------- the replayed shape (mp-290 clause 2)

const msgs = (n: number): UIMessage[] => Array.from({ length: n }, (_, i) => ({ id: `m${i}`, role: i % 2 === 0 ? 'user' : 'assistant', parts: [{ type: 'text', text: `turn ${i}` }] } as UIMessage));
const parts20 = [{ index: 20, text: SUMMARY_20 }];
const parts40 = [{ index: 20, text: SUMMARY_20 }, { index: 40, text: SUMMARY_40 }];

Deno.test('thirty-nine messages replay all verbatim, whatever summary is stored', () => {
  const m = msgs(39);
  assertEquals(compactHistory(m, []), m);
  assertEquals(compactHistory(m, parts20), m);
});

Deno.test('forty messages replay one summary plus the last twenty', () => {
  const out = compactHistory(msgs(40), parts20);
  assertEquals(out.length, 21);
  assertEquals(out[0].role, 'user');
  assertEquals(textOf(out[0]), `Earlier in this conversation (messages 1–20, summarised): ${SUMMARY_20}`);
  assertEquals(textOf(out[1]), 'turn 20');
  assertEquals(textOf(out.at(-1)!), 'turn 39');
});

Deno.test('sixty-one messages replay one rolled summary plus the twenty of the chunk and the new turn', () => {
  const out = compactHistory(msgs(61), parts40);
  assertEquals(out.length, 22);
  assertEquals(textOf(out[0]), `Earlier in this conversation (messages 1–40, summarised): ${SUMMARY_40}`);
  assert(!textOf(out[0]).includes(SUMMARY_20), 'the rolled summary stands alone; the one it rolled in is not repeated');
  assertEquals(textOf(out[1]), 'turn 40');
  assertEquals(textOf(out.at(-1)!), 'turn 60');
});

Deno.test('between fifty and fifty-nine the pending roll is stored but the applied summary is still the one for twenty', () => {
  const out = compactHistory(msgs(55), parts40);
  assertEquals(out.length, 36);
  assertEquals(textOf(out[0]), `Earlier in this conversation (messages 1–20, summarised): ${SUMMARY_20}`);
  assertEquals(textOf(out[1]), 'turn 20');
});

Deno.test('with no summary stored yet past forty, everything stays verbatim: nothing is invented and nothing is lost', () => {
  const m = msgs(45);
  assertEquals(compactHistory(m, []), m);
  assertEquals(compactHistory(m, [{ index: 20, text: '   ' }]), m);
});

Deno.test('a summary stored for an older boundary than the applied one is still used, with more kept verbatim', () => {
  const out = compactHistory(msgs(61), parts20);
  assertEquals(out.length, 42);
  assertEquals(textOf(out[0]), `Earlier in this conversation (messages 1–20, summarised): ${SUMMARY_20}`);
  assertEquals(textOf(out[1]), 'turn 20');
});

// ---------------------------------------------------------------- the column and its key

Deno.test('the column holds up to two parts, each leading with the index it covers, and reads back the same', () => {
  const text = renderSummaries(parts40);
  assertEquals(text, `Through message 20: ${SUMMARY_20}\n\nThrough message 40: ${SUMMARY_40}`);
  assertEquals(parseSummaries(text), parts40);
  assertEquals(parseSummaries(null), []);
  assertEquals(parseSummaries('An episode sentence written before the column was keyed.'), []);
});

// ---------------------------------------------------------------- when it is written, and that the turn never waits

Deno.test('the turn that reaches thirty writes the summary for twenty in the background and returns before the call does', async () => {
  const v = testCtx(world(SUMMARY_LEAD + SUMMARY_CHUNK));
  const model = heldModel();
  const deps = recorder(model.deps);

  const replayed = await replayHistory(v, CONV, await history(v), deps);

  // The reply went ahead while the model was still thinking: all thirty verbatim, nothing on the row yet.
  assertEquals(replayed.length, 30);
  assertEquals(textOf(replayed[0]), 'question 0');
  assertEquals(deps.tasks.length, 1, 'one background write was scheduled');
  assertEquals(row(v).summary, null);
  assertEquals(row(v).summary_index, null);

  model.release();
  await Promise.all(deps.tasks);

  assertEquals(row(v).summary_index, 20, 'keyed by the index it covers');
  assertEquals(parseSummaries(row(v).summary), parts20);
  assertEquals(model.calls.length, 1);
  assert(model.calls[0].prompt.includes(TURN_THREE), 'turn three reached the model');
  assert(model.calls[0].prompt.includes('answer 19'), 'the whole first chunk reached the model');
  assert(!model.calls[0].prompt.includes('question 20'), 'nothing past the chunk did');
  assertEquals(v.fake.rows('user_memories').length, 0, 'no episode row: the summary is not a memory');
});

Deno.test('under thirty nothing is written; from thirty-one to thirty-nine nothing more is written and all stays verbatim', async () => {
  const v = testCtx(world(29));
  const first = heldModel();
  const early = recorder(first.deps);
  assertEquals((await replayHistory(v, CONV, await history(v), early)).length, 29);
  assertEquals(early.tasks.length, 0);
  assertEquals(first.calls.length, 0);

  await turnAt(v, 30, SUMMARY_20);
  for (const n of [31, 35, 39]) {
    v.fake.tables.vana_messages = storedTurns(n);
    const again = heldModel('A second summary that must never be written.');
    const later = recorder(again.deps);
    const replayed = await replayHistory(v, CONV, await history(v), later);
    assertEquals(replayed.length, n, `all ${n} verbatim`);
    assertEquals(later.tasks.length, 0, 'nothing scheduled once the summary exists');
    assertEquals(again.calls.length, 0);
  }
  assertEquals(row(v).summary_index, 20);
});

Deno.test('from forty the summary is applied: one summary plus twenty, and the row is untouched', async () => {
  const v = testCtx(world(30));
  await turnAt(v, 30, SUMMARY_20);

  v.fake.tables.vana_messages = storedTurns(40);
  const model = heldModel('Must not be written.');
  const deps = recorder(model.deps);
  const replayed = await replayHistory(v, CONV, await history(v), deps);

  assertEquals(replayed.length, 21);
  assertEquals(textOf(replayed[0]), `Earlier in this conversation (messages 1–20, summarised): ${SUMMARY_20}`);
  assertEquals(textOf(replayed[1]), 'question 20');
  assertEquals(textOf(replayed.at(-1)!), 'answer 39');
  assertEquals(deps.tasks.length, 0);
  assertEquals(row(v).summary_index, 20);
});

Deno.test('at fifty the roll is written from the previous summary and the next chunk; it applies at sixty, not before', async () => {
  const v = testCtx(world(30));
  await turnAt(v, 30, SUMMARY_20);
  const { model } = await turnAt(v, 50, SUMMARY_40);

  assertEquals(model.calls.length, 1);
  assert(model.calls[0].prompt.includes(SUMMARY_20), 'the previous summary was rolled in');
  assert(model.calls[0].prompt.includes('question 20') && model.calls[0].prompt.includes('answer 39'), 'the second chunk reached the model');
  assert(!model.calls[0].prompt.includes(TURN_THREE), 'the first chunk did not travel again: the summary stands for it');
  assert(!model.calls[0].prompt.includes('question 40'), 'nothing past the chunk did');
  assertEquals(row(v).summary_index, 40);
  assertEquals(parseSummaries(row(v).summary), parts40);

  // Fifty-nine: still the summary for twenty, thirty-nine verbatim.
  v.fake.tables.vana_messages = storedTurns(59);
  const quiet = recorder(heldModel('Must not be written.').deps);
  const at59 = await replayHistory(v, CONV, await history(v), quiet);
  assertEquals(at59.length, 40);
  assertEquals(textOf(at59[0]), `Earlier in this conversation (messages 1–20, summarised): ${SUMMARY_20}`);
  assertEquals(quiet.tasks.length, 0);

  // Sixty-one: the rolled summary plus the chunk and the new turn.
  v.fake.tables.vana_messages = storedTurns(61);
  const at61 = await replayHistory(v, CONV, await history(v), recorder(heldModel('Must not be written.').deps));
  assertEquals(at61.length, 22);
  assertEquals(textOf(at61[0]), `Earlier in this conversation (messages 1–40, summarised): ${SUMMARY_40}`);
  assertEquals(textOf(at61[1]), 'question 40');
});

Deno.test('a failed write is silent, leaves the row alone, and the next turn tries again', async () => {
  const v = testCtx(world(30));
  const failing: SummaryDeps = { generate: () => Promise.reject(new Error('gateway down')) };
  const deps = recorder(failing);
  await replayHistory(v, CONV, await history(v), deps);
  await Promise.all(deps.tasks);   // must not reject: it runs where nobody is listening
  assertEquals(row(v).summary, null);
  assertEquals(row(v).summary_index, null);

  await turnAt(v, 33, SUMMARY_20);
  assertEquals(row(v).summary_index, 20);
});

Deno.test('a write that missed its window is caught up: past forty with nothing stored, the turn stays verbatim and schedules it', async () => {
  const v = testCtx(world(43));
  const model = heldModel();
  const deps = recorder(model.deps);
  const replayed = await replayHistory(v, CONV, await history(v), deps);
  assertEquals(replayed.length, 43, 'nothing is dropped while no summary can stand in');
  assertEquals(deps.tasks.length, 1);
  model.release();
  await Promise.all(deps.tasks);
  assertEquals(row(v).summary_index, 20);

  v.fake.tables.vana_messages = storedTurns(44);
  const next = await replayHistory(v, CONV, await history(v), recorder(heldModel('Must not be written.').deps));
  assertEquals(next.length, 25);
});

Deno.test('a write landing after a newer one does not roll the row back', async () => {
  const v = testCtx(world(30));
  const slow = heldModel('A stale summary for twenty.');
  const stale = recorder(slow.deps);
  await replayHistory(v, CONV, await history(v), stale);
  // While that call is out, another turn's write for the same index lands.
  await turnAt(v, 31, SUMMARY_20);
  slow.release();
  await Promise.all(stale.tasks);
  assertEquals(parseSummaries(row(v).summary), parts20);
});

Deno.test('a rate-limited write leaves the row alone for the next turn to try', async () => {
  const calls = Array.from({ length: 3 }, (_, i) => ({ id: `c${i}`, user_id: U, function_name: 'vana.summary', created_at: new Date().toISOString() }));
  const v = testCtx(world(30, { vana_calls: calls }));
  const model = heldModel();
  const deps = recorder(model.deps);
  await replayHistory(v, CONV, await history(v), deps);
  model.release();
  await Promise.all(deps.tasks);
  assertEquals(model.calls.length, 0);
  assertEquals(row(v).summary_index, null);
});

Deno.test('an ephemeral turn has no conversation row to summarise onto', async () => {
  const v = testCtx(world(45));
  const deps = recorder(heldModel().deps);
  const replayed = await replayHistory(v, '', await history(v), deps);
  assertEquals(replayed.length, 45);
  assertEquals(deps.tasks.length, 0);
});
