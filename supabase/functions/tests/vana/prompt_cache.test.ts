/**
 * The cached prefix at the chat seam (mp-276, mp-420 clauses 4 and 5, mp-290): the prompt order is tools, persona,
 * context, messages; the persona and the context are two system messages with their own cache markers, so a context
 * rebuild leaves the persona's entry (and the tools before it) readable; the call is pinned to Anthropic and carries a
 * session id per conversation; the tool list never varies per turn; a stored conversation replays as the bytes first
 * sent, the screen line and the opener's hidden first message included; the cache-read count reaches vana_calls and
 * the NDJSON `done` line. No model is called — the stream is fed producer-shaped AI SDK parts.
 */
import { assert, assertEquals, assertNotEquals } from 'https://deno.land/std@0.177.1/testing/asserts.ts';
import type { UIMessage } from 'npm:ai@6.0.277';
import { systemPrompt, systemMessages, CACHE_PROVIDER_OPTIONS, chatProviderOptions, chatHeaders, situationNote, withSituation, openerMessage, userMessageRow, assistantMessageRow, conversationMessages, replayModelMessages, partsFromSteps } from '../../_shared/vana/chat.ts';
import { PLANNING_PROMPT, GENERAL_PROMPT, OPENERS } from '../../_shared/vana/persona.ts';
import { buildAthleteContext, contextBlock } from '../../_shared/vana/context.ts';
import { makeVanaTools } from '../../_shared/vana/tools.ts';
import { logCall } from '../../_shared/vana/log.ts';
import { ndjsonFromFullStream, cacheReadTokens } from '../../_shared/vana/stream.ts';
import { transcriptFromMessages } from '../../_shared/vana/extract.ts';
import { testCtx, offlineDeps, TEST_USER_ID } from './support/vana_ctx.ts';
import type { Row } from './support/fake_db.ts';

const U = TEST_USER_ID;
const ANCHOR = '2026-09-09';
const CONV = 'conv-1';

// ---------------------------------------------------------------- the prompt shape (mp-420 clause 4)

Deno.test('the system prompt is two messages, persona then context, each with its own cache marker', async () => {
  const v = testCtx({ users: [{ id: U, first_name: 'Lee', allergies: [] }] });
  const c = await buildAthleteContext(v, ANCHOR, offlineDeps());
  for (const [kind, persona] of [['meal_planning', PLANNING_PROMPT], ['general', GENERAL_PROMPT]] as const) {
    const [first, second, ...rest] = systemMessages(kind, c, ANCHOR);
    assertEquals(rest, [], `${kind}: exactly two system messages`);
    assertEquals(first, { role: 'system', content: persona, providerOptions: { anthropic: { cacheControl: { type: 'ephemeral', ttl: '1h' } } } }, `${kind}: the persona, at the one-hour lifetime`);
    assertEquals(second, { role: 'system', content: `--- CONTEXT (today 2026-09-09, Wednesday) ---\n${contextBlock(c)}`, providerOptions: { anthropic: { cacheControl: { type: 'ephemeral' } } } }, `${kind}: the context, at the default lifetime`);
    // The one string the older tests read is the two contents in order, nothing added.
    assertEquals(systemPrompt(kind, c, ANCHOR), `${first.content}\n${second.content}`);
  }
  // The persona's lifetime is a setting, so the dev result can turn it off without touching the shape.
  assertEquals(systemMessages('general', c, ANCHOR, '', null)[0].providerOptions, { anthropic: { cacheControl: { type: 'ephemeral' } } });
});

Deno.test('a context rebuild leaves the first system message byte-identical and changes only the second', async () => {
  const v = testCtx({ users: [{ id: U, first_name: 'Lee', allergies: [] }] });
  const before = await buildAthleteContext(v, ANCHOR, offlineDeps());
  // A plan write: the PLAN line changes, the way a tap on a picker changes it.
  const after = { ...before, plan: { ...before.plan, exists: true, status: 'draft', mealsLeft: 8 } };
  const a = systemMessages('meal_planning', before, ANCHOR);
  const b = systemMessages('meal_planning', after, ANCHOR);
  assertEquals(JSON.stringify(a[0]), JSON.stringify(b[0]), 'the persona message is the same bytes');
  assertNotEquals(a[1].content, b[1].content, 'the context message carries the change');
  // The standing extra (NEW PLAN, DEBRIEF PENDING) rides on the context message, never the persona.
  const withExtra = systemMessages('meal_planning', before, ANCHOR, '\nDEBRIEF PENDING plan p1');
  assertEquals(JSON.stringify(withExtra[0]), JSON.stringify(a[0]));
  assert(withExtra[1].content.endsWith('\nDEBRIEF PENDING plan p1'));
  // Two turns on one day, no writes between: the same bytes go to the model.
  assertEquals(JSON.stringify(systemMessages('general', before, ANCHOR)), JSON.stringify(systemMessages('general', await buildAthleteContext(v, ANCHOR, offlineDeps()), ANCHOR)));
});

Deno.test('the call keeps automatic caching for the tail, is pinned to Anthropic, and carries the conversation as its session', () => {
  assertEquals(CACHE_PROVIDER_OPTIONS, { anthropic: { cacheControl: { type: 'ephemeral' } } });
  assertEquals(chatProviderOptions(), { anthropic: { cacheControl: { type: 'ephemeral' } }, gateway: { only: ['anthropic'] } });
  assertEquals(chatHeaders(CONV), { 'x-session-affinity': CONV });
  assertEquals(chatHeaders(''), {}, 'an ephemeral turn has no conversation to pin a session to');
});

Deno.test('the tool list never varies per turn: two turns of one kind build the same names and descriptions', () => {
  // deno-lint-ignore no-explicit-any
  const v = {} as any; const ctx = {} as any;
  const describe = (t: Record<string, { description?: string }>) => Object.entries(t).map(([name, tool]) => [name, tool.description]);
  for (const kind of ['meal_planning', 'general'] as const) {
    const turnOne = makeVanaTools(v, ctx, kind, { scope: null, conversationId: CONV, shownIds: [] });
    const turnTwo = makeVanaTools(v, ctx, kind, { scope: { conversationId: CONV }, conversationId: CONV, shownIds: ['D-001', 'D-002'] });
    assertEquals(describe(turnTwo as never), describe(turnOne as never), `${kind}: what was shown and what was written change what a tool DOES, never what the model is sent`);
  }
});

// ---------------------------------------------------------------- a stored conversation replays as first sent (mp-420 clause 5)

const SITUATION = 'looking at the Plan tab; no plan for the week of 2026-09-06 yet';
const SECTION = 'DAY PLAN Wednesday 2026-09-09: nothing planned';
// deno-lint-ignore no-explicit-any
const tools = makeVanaTools({} as any, {} as any, 'meal_planning');
const bytes = (m: unknown) => JSON.stringify(m);
/** A finished step, the way the SDK hands it to onFinish: text, one askChoice, its result. */
const askStep = (text: string, toolCallId: string) => ({ text, toolCalls: [{ toolName: 'askChoice' }], toolResults: [{ toolName: 'askChoice', toolCallId, input: { options: ['Something new', 'Quick weeknights'] }, output: { kind: 'choices', question: undefined, options: ['Something new', 'Quick weeknights'] } }] });
/** Stores a row the way the fake database would return it. */
const stored = (row: Record<string, unknown>, i: number): Row => ({ id: `m${i}`, created_at: new Date(Date.UTC(2026, 8, 9, 9, 0, i)).toISOString(), ...row });

Deno.test('the opener turn: the hidden first message and its screen line replay as the bytes first sent', async () => {
  const v = testCtx({ vana_conversations: [{ id: CONV, user_id: U, kind: 'meal_planning' }], vana_messages: [] });
  const note = situationNote(SITUATION, SECTION)!;
  // First send: the opener text is the first user message, the screen line rides on it.
  const sent = withSituation(await replayModelMessages([openerMessage(OPENERS.meal_planning)], tools), SITUATION, SECTION);
  assertEquals(sent.length, 1);
  // The row the turn stores, then what the next turn reads back.
  const step = askStep('Chattanooga is 11 days out, so this week eats for the taper.', 'call-1');
  const { parts } = partsFromSteps('', [step], 8);
  const row = assistantMessageRow({ conversationId: CONV, userId: U, text: step.text, parts, steps: [step], started: Date.now(), opener: true, openerVariant: 'plan', newPlan: false, kind: 'meal_planning', planSnapshot: null, openerPrompt: OPENERS.meal_planning, situation: note });
  assertEquals(row.metadata.opener_prompt, OPENERS.meal_planning);
  assertEquals(row.metadata.situation, note);
  v.fake.tables.vana_messages.push(stored(row, 0));
  const { messages } = await conversationMessages(v, CONV);
  assertEquals(messages.map((m) => m.role), ['user', 'assistant'], 'the hidden first message comes back before the opener row');
  // The app never sees it: a user row was not written, and the assistant row's content and parts are untouched.
  assertEquals(v.fake.rows('vana_messages').filter((r) => r.role === 'user'), []);
  assertEquals(row.content, step.text);
  const replayed = await replayModelMessages(messages, tools);
  assertEquals(bytes(replayed[0]), bytes(sent[0]), 'the first message replays byte-for-byte');
  assertEquals(replayed[1].role, 'assistant');
});

Deno.test('an athlete turn: the screen line is stored with the row and the whole prefix replays as sent', async () => {
  const v = testCtx({ vana_conversations: [{ id: CONV, user_id: U, kind: 'meal_planning' }], vana_messages: [] });
  const note = situationNote(SITUATION, null)!;
  // Turn 1 (the opener) as stored.
  const step1 = askStep('The taper starts Thursday.', 'call-1');
  const p1 = partsFromSteps('', [step1], 8).parts;
  v.fake.tables.vana_messages.push(stored(assistantMessageRow({ conversationId: CONV, userId: U, text: step1.text, parts: p1, steps: [step1], started: Date.now(), opener: true, openerVariant: 'plan', newPlan: false, kind: 'meal_planning', planSnapshot: null, openerPrompt: OPENERS.meal_planning, situation: note }), 0));
  // Turn 2: the athlete answers. What runChat sends is the stored history plus the new message with this turn's screen line.
  const history = (await conversationMessages(v, CONV)).messages;
  const answer = { id: 'u-1', role: 'user', parts: [{ type: 'text', text: 'Something new' }] } as UIMessage;
  const sent = withSituation(await replayModelMessages([...history, answer], tools), SITUATION, null);
  // The user row stores the line beside the text, never inside it: the app reads `content` and draws that alone.
  const userRow = userMessageRow({ conversationId: CONV, userId: U, text: 'Something new', parts: answer.parts, situation: note });
  assertEquals(userRow.content, 'Something new');
  assertEquals(userRow.metadata, { situation: note });
  v.fake.tables.vana_messages.push(stored(userRow, 1));
  const step2 = askStep('Three dinners, then.', 'call-2');
  const p2 = partsFromSteps('', [step2], 8).parts;
  v.fake.tables.vana_messages.push(stored(assistantMessageRow({ conversationId: CONV, userId: U, text: step2.text, parts: p2, steps: [step2], started: Date.now(), opener: false, openerVariant: 'plan', newPlan: false, kind: 'meal_planning', planSnapshot: null }), 2));
  // Turn 3: the replayed history's prefix is exactly what turn 2 sent, whatever screen the athlete is on now.
  const next = (await conversationMessages(v, CONV)).messages;
  const replayed = withSituation(await replayModelMessages([...next, { id: 'u-2', role: 'user', parts: [{ type: 'text', text: 'Other options' }] } as UIMessage], tools), 'in settings', null);
  assertEquals(bytes(replayed.slice(0, sent.length)), bytes(sent), 'every earlier message replays byte-for-byte');
  assertEquals(replayed.length, sent.length + 3, 'then the stored reply (its text and call, then the tool result) and the new message');
  // A row stored before this ticket, with no screen line, replays as it always did.
  v.fake.tables.vana_messages.push(stored({ conversation_id: CONV, user_id: U, role: 'user', content: 'Older turn', parts: null, metadata: null }, 3));
  const older = (await conversationMessages(v, CONV)).messages.at(-1)!;
  assertEquals(older.parts, [{ type: 'text', text: 'Older turn' }]);
});

Deno.test('the summariser reads what was said, not the replayed instruction or the screen line', async () => {
  const v = testCtx({ vana_conversations: [{ id: CONV, user_id: U, kind: 'meal_planning' }], vana_messages: [] });
  const note = situationNote(SITUATION, null)!;
  const step = askStep('The taper starts Thursday.', 'call-1');
  v.fake.tables.vana_messages.push(stored(assistantMessageRow({ conversationId: CONV, userId: U, text: step.text, parts: partsFromSteps('', [step], 8).parts, steps: [step], started: Date.now(), opener: true, openerVariant: 'plan', newPlan: false, kind: 'meal_planning', planSnapshot: null, openerPrompt: OPENERS.meal_planning, situation: note }), 0));
  v.fake.tables.vana_messages.push(stored(userMessageRow({ conversationId: CONV, userId: U, text: 'Something new', parts: [{ type: 'text', text: 'Something new' }], situation: note }), 1));
  const lines = transcriptFromMessages((await conversationMessages(v, CONV)).messages);
  assertEquals(lines, [{ role: 'assistant', text: 'The taper starts Thursday.' }, { role: 'user', text: 'Something new' }]);
});

// ---------------------------------------------------------------- the log and the wire (mp-276 clause 1)

Deno.test('the cache-read count is written to vana_calls beside the input tokens', async () => {
  const v = testCtx();
  await logCall(v.admin, { userId: U, conversationId: 'conv-1', functionName: 'vana.chat.general', model: 'anthropic/claude-haiku-4.5', inputTokens: 5200, outputTokens: 90, cacheReadTokens: 4900 });
  await logCall(v.admin, { userId: U, conversationId: 'conv-1', functionName: 'vana.chat.general', model: 'anthropic/claude-haiku-4.5', inputTokens: 5200, outputTokens: 90 });
  const rows = v.fake.writesTo('vana_calls', 'insert').map((w) => w.values);
  assertEquals(rows[0].input_tokens, 5200); assertEquals(rows[0].cache_read_tokens, 4900);
  assertEquals(rows[1].cache_read_tokens, null, 'a call that reported nothing logs null, not a fake zero');
});

Deno.test('cacheReadTokens reads the v6 usage shape, the deprecated one, and nothing', () => {
  assertEquals(cacheReadTokens({ inputTokens: 100, inputTokenDetails: { cacheReadTokens: 80 } }), 80);
  assertEquals(cacheReadTokens({ inputTokens: 100, inputTokenDetails: { cacheReadTokens: 0 } }), 0);
  assertEquals(cacheReadTokens({ inputTokens: 100, cachedInputTokens: 42 }), 42);
  assertEquals(cacheReadTokens({ inputTokens: 100 }), null);
  assertEquals(cacheReadTokens(undefined), null);
});

async function* parts(finishUsage: unknown) {
  yield { type: 'text-start' };
  yield { type: 'text-delta', text: 'Rice.' };
  yield { type: 'finish', totalUsage: finishUsage };
}
const lines = async (usage: unknown) => {
  const body = await new Response(ndjsonFromFullStream(parts(usage))).text();
  return body.trim().split('\n').map((l) => JSON.parse(l));
};

Deno.test('the done line carries cache_read_tokens for the eval', async () => {
  const out = await lines({ inputTokens: 5200, outputTokens: 90, inputTokenDetails: { noCacheTokens: 300, cacheReadTokens: 4900, cacheWriteTokens: 0 } });
  // `steps` (mp-471) counts finish-step parts; this stream has none.
  assertEquals(out.at(-1), { type: 'done', usage: { input_tokens: 5200, output_tokens: 90, cache_read_tokens: 4900, steps: 0 } });
  const none = await lines({ inputTokens: 5200, outputTokens: 90 });
  assertEquals(none.at(-1), { type: 'done', usage: { input_tokens: 5200, output_tokens: 90, cache_read_tokens: null, steps: 0 } });
});
