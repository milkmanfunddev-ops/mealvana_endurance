/**
 * A chat Turn as Langfuse receives it (langfuse ticket 01, spec seam 1): the real `runChat` over the fake database and
 * a mock model behind the AI SDK's default provider, with a span collector standing in for Langfuse's exporter.
 *
 * What is asserted is what leaves the system: the spans handed to the exporter, the reply the athlete gets and the
 * Call log row. The model's finish parts carry the gateway's charge in the shape the gateway reports it
 * (`providerMetadata.gateway.cost`, a decimal string), so the cost on each Generation and the cost in `vana_calls`
 * are both read from producer-shaped data and compared with each other.
 */
import { assert, assertEquals } from 'https://deno.land/std@0.177.1/testing/asserts.ts';
import { MockLanguageModelV3, MockProviderV3, convertArrayToReadableStream } from 'npm:ai@6.0.277/test';
import { InMemorySpanExporter, type ReadableSpan, type SpanExporter } from 'npm:@opentelemetry/sdk-trace-base@2.11.0';
import { runChat, type FinishedUsage } from '../../_shared/vana/chat.ts';
import { createTracing, type Tracing } from '../../_shared/langfuse/tracing.ts';
import { buildAthleteContext } from '../../_shared/vana/context.ts';
import { testCtx, offlineDeps, TEST_USER_ID } from './support/vana_ctx.ts';

const U = TEST_USER_ID;
const ANCHOR = '2026-09-09';
const CONV = 'conv-1';
/** What the gateway charged for the tool step and for the answering step. */
const STEP_COSTS = ['0.000125', '0.00034'];

// deno-lint-ignore no-explicit-any
type CallOptions = any;
const usage = { inputTokens: { total: 10, noCache: 10, cacheRead: 0, cacheWrite: 0 }, outputTokens: { total: 5, text: 5, reasoning: 0 } };

/** A mock default provider for the test's duration: the first model call asks for the athlete's workouts, the second
 *  answers. Each finish part carries that step's gateway charge. */
function mockGateway(): { calls: number; restore: () => void } {
  const state = { calls: 0, restore: () => {} };
  const finish = (reason: 'stop' | 'tool-calls', cost: string) => ({ type: 'finish', finishReason: { unified: reason, raw: reason }, usage, providerMetadata: { gateway: { generationId: `gen_${state.calls}`, cost } } });
  const model = (modelId: string) => new MockLanguageModelV3({
    modelId,
    doStream: (options: CallOptions) => {
      state.calls++;
      const answering = (options.prompt as { role: string }[]).at(-1)?.role === 'tool';
      const parts = answering
        ? [{ type: 'text-start', id: 't' }, { type: 'text-delta', id: 't', delta: 'Nothing on the calendar, so eat normally.' }, { type: 'text-end', id: 't' }, finish('stop', STEP_COSTS[1])]
        : [{ type: 'tool-call', toolCallId: 'c1', toolName: 'getWorkouts', input: JSON.stringify({ days: 7 }) }, finish('tool-calls', STEP_COSTS[0])];
      // deno-lint-ignore no-explicit-any
      return Promise.resolve({ stream: convertArrayToReadableStream([{ type: 'stream-start', warnings: [] }, ...parts] as any) });
    },
  });
  // deno-lint-ignore no-explicit-any
  const g = globalThis as any;
  const before = g.AI_SDK_DEFAULT_PROVIDER;
  g.AI_SDK_DEFAULT_PROVIDER = new MockProviderV3({ languageModels: {} });
  g.AI_SDK_DEFAULT_PROVIDER.languageModel = model;
  state.restore = () => { g.AI_SDK_DEFAULT_PROVIDER = before; };
  return state;
}

/** The runtime's background-work hook, recorded: what `runChat` hands it, and whether each promise has settled. */
function edgeRuntime(): { background: Promise<unknown>[]; settled: () => Promise<void>; restore: () => void } {
  // deno-lint-ignore no-explicit-any
  const g = globalThis as any;
  const before = g.EdgeRuntime;
  const background: Promise<unknown>[] = [];
  g.EdgeRuntime = { waitUntil: (p: Promise<unknown>) => { background.push(p.catch(() => {})); } };
  return {
    background,
    // A background task may hand the hook another one, so wait until none is added.
    settled: async () => { for (let n = -1; n !== background.length;) { n = background.length; await Promise.all(background); } },
    restore: () => { g.EdgeRuntime = before; },
  };
}

interface Turn { reply: string; spans: ReadableSpan[]; callRow: Record<string, unknown>; settled: FinishedUsage[] }
/** One two-step turn on an existing conversation. `tracing` undefined is the app with no Langfuse keys. */
async function turn(tracing: Tracing | undefined, collector?: InMemorySpanExporter): Promise<Turn> {
  const v = testCtx({ users: [{ id: U, first_name: 'Lee', allergies: [] }], activities: [] });
  const ctx = await buildAthleteContext(v, ANCHOR, offlineDeps());
  await v.db.from('vana_conversations').insert({ id: CONV, user_id: U, kind: 'general', context: ctx, context_day: ANCHOR, last_message_at: `${ANCHOR}T08:00:00Z` });
  const gw = mockGateway(); const rt = edgeRuntime();
  const settled: FinishedUsage[] = [];
  try {
    const run = await runChat(v, { message: 'what is on this week', conversation_id: CONV, kind: 'general', anchor_date: ANCHOR },
      { functionName: 'vana-chat', tracing, afterFinish: (u) => { settled.push(u); return Promise.resolve(); } });
    assert(run.ok, `the turn ran: ${JSON.stringify(run)}`);
    const reply = await run.response.text();
    await rt.settled();
    assertEquals(gw.calls, 2, 'a tool step and an answering step');
    const callRow = v.fake.tables.vana_calls.at(-1)!;
    return { reply, spans: collector?.getFinishedSpans() ?? [], callRow, settled };
  } finally { gw.restore(); rt.restore(); }
}

const collected = () => {
  const collector = new InMemorySpanExporter();
  return { collector, tracing: createTracing({ publicKey: 'pk-test', secretKey: 'sk-test', baseUrl: 'http://langfuse.invalid', environment: 'dev', release: 'test-release', exporter: collector }) };
};
const generations = (spans: ReadableSpan[]) => spans.filter((s) => s.name.endsWith('.doStream'));
const costOf = (s: ReadableSpan) => JSON.parse(String(s.attributes['langfuse.observation.cost_details'] ?? 'null')) as { total: number } | null;

Deno.test('a Turn is one Trace under a vana-turn root, carrying the athlete and the Conversation as Session', async () => {
  const { collector, tracing } = collected();
  const { spans } = await turn(tracing, collector);
  assertEquals(new Set(spans.map((s) => s.spanContext().traceId)).size, 1, 'every span is in the one Trace');
  const roots = spans.filter((s) => !s.parentSpanContext);
  assertEquals(roots.map((s) => s.name), ['vana-turn'], 'one root, named by the Turn root contract');
  const root = roots[0];
  assertEquals(root.attributes['langfuse.observation.input'], 'what is on this week');
  assertEquals(root.attributes['langfuse.observation.output'], 'Nothing on the calendar, so eat normally.');
  assertEquals(JSON.parse(String(root.attributes['langfuse.observation.metadata.toolCalls'])), ['getWorkouts']);
  // Langfuse filters and evaluators match on observations, so every one carries these, not only the root.
  for (const s of spans) {
    assertEquals(s.attributes['user.id'], U, `${s.name}: the athlete`);
    assertEquals(s.attributes['session.id'], CONV, `${s.name}: the Conversation`);
    assertEquals(s.attributes['langfuse.environment'], 'dev', `${s.name}: the environment`);
    assertEquals(s.attributes['langfuse.release'], 'test-release', `${s.name}: the release`);
    assertEquals(s.attributes['langfuse.trace.metadata.kind'], 'general', `${s.name}: the conversation kind`);
  }
  assertEquals(generations(spans).length, 2, 'one Generation per Step');
  assertEquals(spans.filter((s) => s.name === 'ai.toolCall').map((s) => s.attributes['ai.toolCall.name']), ['getWorkouts'], 'one observation per Tool call');
});

Deno.test("each Generation's cost is the gateway's charge, and the Trace total is the Call log's figure", async () => {
  const { collector, tracing } = collected();
  const { spans, callRow } = await turn(tracing, collector);
  assertEquals(generations(spans).map((s) => costOf(s)?.total).sort(), STEP_COSTS.map(Number).sort());
  // A supplied cost replaces Langfuse's own inference for that observation. Only the model-call spans carry one: the
  // outer streamText span also holds the last step's provider metadata, and costing it would count that step twice.
  const costed = spans.filter((s) => costOf(s) != null);
  assertEquals(costed.length, 2, 'no span other than the two Generations is costed');
  const traceTotal = costed.reduce((sum, s) => sum + costOf(s)!.total, 0);
  assertEquals(traceTotal, callRow.gateway_cost_usd, "Langfuse's total equals vana_calls.gateway_cost_usd");
});

Deno.test('a failing exporter changes neither the reply, the Call log nor the budget settlement', async () => {
  const plain = await turn(undefined);
  const failing: SpanExporter = {
    export: () => { throw new Error('langfuse is down'); },
    shutdown: () => Promise.reject(new Error('langfuse is down')),
    forceFlush: () => Promise.reject(new Error('langfuse is down')),
  };
  const traced = await turn(createTracing({ publicKey: 'pk-test', secretKey: 'sk-test', baseUrl: 'http://langfuse.invalid', environment: 'dev', exporter: failing }));
  assertEquals(traced.reply, plain.reply, 'the same NDJSON reaches the athlete');
  const stable = ({ id: _i, created_at: _c, updated_at: _u, ...row }: Record<string, unknown>) => row;
  assertEquals(stable(traced.callRow), stable(plain.callRow), 'the same Call log row');
  assertEquals(traced.settled, plain.settled, 'the same usage settles the budget');
  assertEquals(traced.settled.length, 1);
});

Deno.test('the flush runs under the background-work hook and the reply does not wait for it', async () => {
  const collector = new InMemorySpanExporter();
  let release = () => {}; const held = new Promise<void>((r) => { release = r; });
  let flushed = false;
  // An exporter that cannot finish a flush until it is released: Langfuse being slow.
  const slow: SpanExporter = {
    export: (spans, done) => collector.export(spans, done),
    shutdown: () => collector.shutdown(),
    forceFlush: async () => { await held; flushed = true; },
  };
  const tracing = createTracing({ publicKey: 'pk-test', secretKey: 'sk-test', baseUrl: 'http://langfuse.invalid', environment: 'dev', exporter: slow });
  const v = testCtx({ users: [{ id: U, first_name: 'Lee', allergies: [] }], activities: [] });
  await v.db.from('vana_conversations').insert({ id: CONV, user_id: U, kind: 'general', context: await buildAthleteContext(v, ANCHOR, offlineDeps()), context_day: ANCHOR });
  const gw = mockGateway(); const rt = edgeRuntime();
  try {
    const run = await runChat(v, { message: 'what is on this week', conversation_id: CONV, kind: 'general', anchor_date: ANCHOR }, { functionName: 'vana-chat', tracing });
    assert(run.ok);
    const reply = await run.response.text();
    assert(reply.includes('Nothing on the calendar'), 'the whole reply arrived while the flush was still held');
    assertEquals(flushed, false);
    release();
    await rt.settled();
    assertEquals(flushed, true, 'the flush was handed to the background-work hook, which kept it alive');
  } finally { gw.restore(); rt.restore(); }
});

Deno.test('with no Langfuse keys nothing is traced and the Turn runs as before', async () => {
  const { reply, callRow } = await turn(createTracing({ publicKey: undefined, secretKey: undefined }));
  assert(reply.includes('Nothing on the calendar'));
  assertEquals(callRow.gateway_cost_usd, STEP_COSTS.map(Number).reduce((a, b) => a + b, 0));
});
