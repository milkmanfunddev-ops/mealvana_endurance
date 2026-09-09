/**
 * Lazy extraction at the server seam: a fixture transcript in, Memories and one episode out, the
 * conversation stamped read-back so a second run writes nothing.
 *
 * The model call is injected. What is under test is the writing, the claiming, and the selection of
 * which conversation gets read — not the model's judgement, which the live evals cover.
 */
import { assert, assertEquals } from 'https://deno.land/std@0.177.1/testing/asserts.ts';
import { extractConversation, readBackPrevious, pendingReadBack, transcriptOf, extractionPrompt } from '../../_shared/vana/extract.ts';
import type { Extraction, ExtractDeps } from '../../_shared/vana/extract.ts';
import { listMemories, episodeFor } from '../../_shared/vana/memory.ts';
import { testCtx, TEST_USER_ID } from './support/vana_ctx.ts';
import type { Row, Tables } from './support/fake_db.ts';

const U = TEST_USER_ID;
const CONV = 'conv-yesterday';

/** A conversation carrying two durable facts and one plan detail, the way the rows store it.
 *  Note it begins with Vana's turn: the opener's synthetic user message is never written. */
const TRANSCRIPT: Row[] = [
  { id: 'm1', conversation_id: CONV, user_id: U, role: 'assistant', content: 'Saturday is your long ride, so this week wants carbs in the tank. What sounds good for dinners?', parts: [], created_at: '2026-09-08T09:00:00Z' },
  { id: 'm2', conversation_id: CONV, user_id: U, role: 'user', content: 'My partner is vegetarian so dinners have to work for both of us. And I want 5 dinners this week.', parts: [], created_at: '2026-09-08T09:01:00Z' },
  { id: 'm3', conversation_id: CONV, user_id: U, role: 'assistant', content: 'Here are five vegetarian dinners that carry the ride.', parts: [], created_at: '2026-09-08T09:02:00Z' },
  { id: 'm4', conversation_id: CONV, user_id: U, role: 'user', content: 'Wednesdays are chaos for me, nothing that takes an hour.', parts: [], created_at: '2026-09-08T09:03:00Z' },
];

const conversation = (over: Partial<Row> = {}): Row => ({ id: CONV, user_id: U, kind: 'meal_planning', title: null, summary: null, is_deleted: false, read_back_at: null, last_message_at: '2026-09-08T09:03:00Z', created_at: '2026-09-08T09:00:00Z', ...over });

const world = (over: Partial<Tables> = {}): Tables => ({ vana_conversations: [conversation()], vana_messages: TRANSCRIPT, user_memories: [], vana_calls: [], ...over });

/** A model stand-in that answers with a fixed extraction and counts how often it was asked. */
function fixedModel(object: Extraction) {
  const calls: { system: string; prompt: string }[] = [];
  const deps: ExtractDeps = { generate: (input) => { calls.push(input); return Promise.resolve({ object, inputTokens: 900, outputTokens: 60 }); } };
  return { deps, calls };
}
const TWO_FACTS: Extraction = {
  memories: [
    { kind: 'constraint', fact: 'Partner is vegetarian, so dinners must work for both of them.' },
    { kind: 'pattern', fact: 'Wednesdays are chaos — nothing that takes an hour.' },
  ],
  episode: 'Planned five vegetarian dinners around Saturday’s long ride.',
};

Deno.test('two durable facts and one plan detail: two Memories and one episode, the plan detail not written', async () => {
  const v = testCtx(world());
  const { deps, calls } = fixedModel(TWO_FACTS);

  const out = await extractConversation(v, CONV, deps);

  assertEquals(out.memories, 2);
  assertEquals(out.episode, 'Planned five vegetarian dinners around Saturday’s long ride.');
  const memories = await listMemories(v);
  assertEquals(memories.filter((m) => m.kind !== 'episode').map((m) => m.fact).sort(), [
    'Partner is vegetarian, so dinners must work for both of them.',
    'Wednesdays are chaos — nothing that takes an hour.',
  ]);
  assert(!memories.some((m) => /5 dinners|five dinners this week/i.test(m.fact)), 'the plan detail was not written');
  assertEquals(await episodeFor(v, CONV), 'Planned five vegetarian dinners around Saturday’s long ride.');
  assertEquals(memories.every((m) => m.source === 'conversation'), true);

  // The transcript the model saw carried the athlete's words and Vana's, and the existing list.
  assertEquals(calls.length, 1);
  assert(calls[0].prompt.includes('ATHLETE: My partner is vegetarian'), 'the athlete\'s words reached the extractor');
  assert(calls[0].prompt.includes('VANA: Saturday is your long ride'), 'Vana\'s turn reached the extractor');
  assert(calls[0].prompt.includes('(nothing yet)'), 'an empty file says so');
});

Deno.test('the episode also fills the conversation summary, for list previews', async () => {
  const v = testCtx(world());
  await extractConversation(v, CONV, fixedModel(TWO_FACTS).deps);
  assertEquals(v.fake.rows('vana_conversations')[0].summary, 'Planned five vegetarian dinners around Saturday’s long ride.');
});

Deno.test('a second run over the same conversation writes nothing and does not call the model', async () => {
  const v = testCtx(world());
  await extractConversation(v, CONV, fixedModel(TWO_FACTS).deps);
  const before = v.fake.rows('user_memories').length;

  const second = fixedModel(TWO_FACTS);
  const out = await extractConversation(v, CONV, second.deps);

  assertEquals(out.skipped, 'already-read');
  assertEquals(second.calls.length, 0, 'the model was never asked a second time');
  assertEquals(v.fake.rows('user_memories').length, before);
});

Deno.test('a conversation with nothing durable yields zero Memories and still one episode', async () => {
  const v = testCtx(world());
  const out = await extractConversation(v, CONV, fixedModel({ memories: [], episode: 'Asked what to eat before a hot half marathon.' }).deps);
  assertEquals(out.memories, 0);
  const memories = await listMemories(v);
  assertEquals(memories.length, 1);
  assertEquals(memories[0].kind, 'episode');
  assertEquals(await episodeFor(v, CONV), 'Asked what to eat before a hot half marathon.');
});

Deno.test('at most three Memories are written, however many come back', async () => {
  const v = testCtx(world());
  const many: Extraction = { memories: [1, 2, 3].map((n) => ({ kind: 'preference' as const, fact: `Durable fact number ${n} about the athlete.` })), episode: 'A long conversation.' };
  const out = await extractConversation(v, CONV, fixedModel(many).deps);
  assertEquals(out.memories, 3);
  assertEquals((await listMemories(v)).filter((m) => m.kind !== 'episode').length, 3);
});

Deno.test('a transcript too short to read is skipped without charge, and stays readable later', async () => {
  const v = testCtx(world({ vana_messages: [TRANSCRIPT[0]] }));
  const m = fixedModel(TWO_FACTS);
  const out = await extractConversation(v, CONV, m.deps);
  assertEquals(out.skipped, 'too-short');
  assertEquals(m.calls.length, 0);
  // A conversation opened and abandoned after the opener is exactly one stored line. It must not be
  // marked read, or coming back to it tomorrow and talking would never be extracted.
  assertEquals(v.fake.rows('vana_conversations')[0].read_back_at, null);

  // The athlete comes back and talks; now it reads back.
  v.fake.tables.vana_messages = TRANSCRIPT;
  const second = await extractConversation(v, CONV, fixedModel(TWO_FACTS).deps);
  assertEquals(second.memories, 2);
});

Deno.test('a failed model call releases the claim, so the conversation can be read back later', async () => {
  const v = testCtx(world());
  const failing: ExtractDeps = { generate: () => Promise.reject(new Error('gateway down')) };
  await extractConversation(v, CONV, failing).then(() => { throw new Error('expected a throw'); }, () => {});
  assertEquals(v.fake.rows('vana_conversations')[0].read_back_at, null);

  const out = await extractConversation(v, CONV, fixedModel(TWO_FACTS).deps);
  assertEquals(out.memories, 2);
});

Deno.test('the conversation read back is the most recent one that has not been, never the one being opened', async () => {
  const v = testCtx(world({
    vana_conversations: [
      conversation({ id: 'old', last_message_at: '2026-09-01T09:00:00Z' }),
      conversation({ id: 'recent', last_message_at: '2026-09-08T09:00:00Z' }),
      conversation({ id: 'done', last_message_at: '2026-09-09T09:00:00Z', read_back_at: '2026-09-09T09:05:00Z' }),
      conversation({ id: 'opening', last_message_at: '2026-09-09T10:00:00Z' }),
    ],
  }));
  assertEquals(await pendingReadBack(v, 'opening'), 'recent');
});

Deno.test('readBackPrevious is silent when there is nothing pending, and never throws', async () => {
  const v = testCtx(world({ vana_conversations: [conversation({ id: 'opening' })] }));
  assertEquals(await readBackPrevious(v, 'opening', fixedModel(TWO_FACTS).deps), null);

  const broken = testCtx(world(), { errors: { vana_conversations: 'boom' } });
  assertEquals(await readBackPrevious(broken, 'opening', fixedModel(TWO_FACTS).deps), null);
});

Deno.test('the transcript is text only, oldest first, and survives a row whose text is in parts', async () => {
  const v = testCtx(world({ vana_messages: [...TRANSCRIPT, { id: 'm5', conversation_id: CONV, user_id: U, role: 'assistant', content: null, parts: [{ type: 'text', text: 'Five dinners, all vegetarian.' }, { type: 'tool-suggestMeals', output: {} }], created_at: '2026-09-08T09:04:00Z' }] }));
  const lines = await transcriptOf(v, CONV);
  assertEquals(lines.length, 5);
  assertEquals(lines[0].role, 'assistant');
  assertEquals(lines.at(-1)!.text, 'Five dinners, all vegetarian.');
});

Deno.test('the prompt names what is already on file so the extractor does not repeat it', () => {
  const p = extractionPrompt([{ role: 'user', text: 'Hi' }], ['Hates cilantro']);
  assert(p.includes('- Hates cilantro'));
  assert(p.includes('ATHLETE: Hi'));
});
