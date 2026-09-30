/**
 * Vana's wording comes from the prompt source (langfuse ticket 02, spec seam 1): the real `runChat` over the fake
 * database and a mock model, with a fake in place of Langfuse's prompt API. The tests read what reached the model
 * call and what the fake was asked for; nothing here builds the prompt with the code under test.
 */
import { assert, assertEquals } from 'https://deno.land/std@0.177.1/testing/asserts.ts';
import { MockLanguageModelV3, MockProviderV3, convertArrayToReadableStream } from 'npm:ai@6.0.277/test';
import { InMemorySpanExporter } from 'npm:@opentelemetry/sdk-trace-base@2.11.0';
import { runChat, systemMessages, type ChatBody } from '../../_shared/vana/chat.ts';
import { createPromptSource, type FetchPrompt, type PromptLabel, type PromptSource } from '../../_shared/langfuse/prompts.ts';
import { createTracing } from '../../_shared/langfuse/tracing.ts';
import { PROMPT_TEMPLATES, OPENERS, NEW_PLAN_OPENER } from '../../_shared/vana/persona.ts';
import { CHIP_LABELS } from '../../_shared/vana/chip-labels.ts';
import { buildAthleteContext } from '../../_shared/vana/context.ts';
import type { ConversationKind } from '../../_shared/vana/contracts.ts';
import { testCtx, offlineDeps, TEST_USER_ID } from './support/vana_ctx.ts';

const U = TEST_USER_ID;
const ANCHOR = '2026-09-09';
const CONV = 'conv-1';

// deno-lint-ignore no-explicit-any
type CallOptions = any;
/** A mock default provider: every model call answers one short text step and is recorded. */
function mockGateway(): { seen: CallOptions[]; restore: () => void } {
  const seen: CallOptions[] = [];
  const model = (modelId: string) => new MockLanguageModelV3({
    modelId,
    doStream: (options: CallOptions) => {
      seen.push(options);
      return Promise.resolve({ stream: convertArrayToReadableStream([
        { type: 'stream-start', warnings: [] },
        { type: 'text-start', id: 't1' }, { type: 'text-delta', id: 't1', delta: 'Rest day, so keep it simple.' }, { type: 'text-end', id: 't1' },
        { type: 'finish', finishReason: { unified: 'stop', raw: 'stop' }, usage: { inputTokens: { total: 10, noCache: 10, cacheRead: 0, cacheWrite: 0 }, outputTokens: { total: 5, text: 5, reasoning: 0 } } },
      // deno-lint-ignore no-explicit-any
      ] as any) });
    },
  });
  // deno-lint-ignore no-explicit-any
  const g = globalThis as any;
  const before = g.AI_SDK_DEFAULT_PROVIDER;
  g.AI_SDK_DEFAULT_PROVIDER = new MockProviderV3({ languageModels: {} });
  g.AI_SDK_DEFAULT_PROVIDER.languageModel = model;
  return { seen, restore: () => { g.AI_SDK_DEFAULT_PROVIDER = before; } };
}

/** Langfuse's prompt API, faked: holds a text per name, records what it was asked for. */
function fakePromptApi(texts: Record<string, string> = {}) {
  const asked: { name: string; label: PromptLabel }[] = [];
  const fetchPrompt: FetchPrompt = (name, label) => {
    asked.push({ name, label });
    return Promise.resolve({ text: texts[name] ?? `[${name} as Langfuse holds it]`, version: 7 });
  };
  return { asked, fetchPrompt };
}
const source = (label: PromptLabel, fetchPrompt: FetchPrompt | undefined, over: { timeoutMs?: number } = {}): PromptSource =>
  createPromptSource({ label, fetchPrompt, bundled: PROMPT_TEMPLATES, ...over });

/** One turn on a conversation whose context is already built, so nothing leaves the process. */
async function turn(kind: ConversationKind, body: Partial<ChatBody>, prompts: PromptSource | undefined, collector?: InMemorySpanExporter) {
  const v = testCtx({ users: [{ id: U, first_name: 'Lee', allergies: [] }] });
  const ctx = await buildAthleteContext(v, ANCHOR, offlineDeps());
  await v.db.from('vana_conversations').insert({ id: CONV, user_id: U, kind, context: ctx, context_day: ANCHOR, last_message_at: `${ANCHOR}T08:00:00Z` });
  const tracing = collector ? createTracing({ publicKey: 'pk', secretKey: 'sk', environment: 'dev', exporter: collector }) : undefined;
  const gw = mockGateway();
  try {
    const run = await runChat(v, { conversation_id: CONV, kind, anchor_date: ANCHOR, ...body }, { functionName: 'vana-chat', prompts, tracing });
    assert(run.ok, `the turn ran: ${JSON.stringify(run)}`);
    const reply = await run.response.text();
    await new Promise((r) => setTimeout(r, 0));
    assertEquals(gw.seen.length, 1, 'one model call');
    return { ctx, call: gw.seen[0], reply };
  } finally { gw.restore(); }
}
const systemTexts = (o: CallOptions) => (o.prompt as { role: string; content: string }[]).filter((m) => m.role === 'system').map((m) => m.content);
const firstUserText = (o: CallOptions) => (o.prompt as { role: string; content: { text: string }[] }[]).find((m) => m.role === 'user')!.content.map((p) => p.text).join('\n');

Deno.test("the persona is the prompt source's text, asked for by `latest` on dev and `production` on prod", async () => {
  for (const label of ['latest', 'production'] as const) {
    const api = fakePromptApi();
    const general = await turn('general', { message: 'what should I eat today' }, source(label, api.fetchPrompt));
    assertEquals(systemTexts(general.call)[0], '[vana/persona/general as Langfuse holds it]\n- [vana/persona/write-rules as Langfuse holds it]\n[vana/persona/general-after-writes as Langfuse holds it]');
    assert(api.asked.length > 0 && api.asked.every((a) => a.label === label), `every prompt was asked for by ${label}`);
    const planning = await turn('meal_planning', { message: 'dinners first' }, source(label, api.fetchPrompt));
    assertEquals(systemTexts(planning.call)[0], '[vana/persona/core as Langfuse holds it]\n[vana/persona/write-rules as Langfuse holds it]\n[vana/persona/planning as Langfuse holds it]');
  }
});

Deno.test("an opener is the prompt source's text, with what makes it theirs and the chip labels filled in", async () => {
  const api = fakePromptApi({
    'vana/opener/make-it-theirs': 'MAKE IT THEIRS, as edited.',
    'vana/opener/general': '[General opener, as edited. {{make_it_theirs}}]',
    'vana/opener/meal-planning': '[Plan opener, as edited. {{make_it_theirs}} Offer exactly "{{chip_same_as_last_time}}".]',
    'vana/opener/new-plan': '[New plan, as edited.] {{plan_opener}}',
  });
  const prompts = source('latest', api.fetchPrompt);
  assertEquals(firstUserText((await turn('general', { opener: true }, prompts)).call), '[General opener, as edited. MAKE IT THEIRS, as edited.]');
  const plan = `[Plan opener, as edited. MAKE IT THEIRS, as edited. Offer exactly "${CHIP_LABELS.sameAsLastTime}".]`;
  assertEquals(firstUserText((await turn('meal_planning', { opener: true }, prompts)).call).split('\n')[0], plan);
  assertEquals(firstUserText((await turn('meal_planning', { opener: true, new_plan: true }, prompts)).call).split('\n')[0], `[New plan, as edited.] ${plan}`);
});

Deno.test('chip labels in a persona section are filled from code, whichever copy of the prompt runs', async () => {
  const api = fakePromptApi({ 'vana/persona/planning': 'After confirmPlan offer "{{chip_open_shopping_list}}" and "{{chip_adjust}}".' });
  const { call } = await turn('meal_planning', { message: 'confirm' }, source('latest', api.fetchPrompt));
  assert(systemTexts(call)[0].endsWith(`After confirmPlan offer "${CHIP_LABELS.openShoppingList}" and "${CHIP_LABELS.adjust}".`));
});

Deno.test('when the prompt source fails or times out the Turn completes on the bundled copy and the Trace says so', async () => {
  const failing: FetchPrompt = () => Promise.reject(new Error('langfuse is down'));
  const hanging: FetchPrompt = () => new Promise(() => {});
  for (const [what, prompts] of [['fails', source('latest', failing)], ['times out', source('latest', hanging, { timeoutMs: 20 })]] as const) {
    const collector = new InMemorySpanExporter();
    const { ctx, call, reply } = await turn('general', { message: 'what should I eat today' }, prompts, collector);
    assert(reply.includes('Rest day, so keep it simple.'), `${what}: the athlete still gets the reply`);
    assertEquals(systemTexts(call), systemMessages('general', ctx, ANCHOR).map((m) => m.content), `${what}: the bundled persona, then the context`);
    const root = collector.getFinishedSpans().find((s) => s.name === 'vana-turn')!;
    assertEquals(root.attributes['langfuse.trace.metadata.promptSource'], 'fallback', `${what}: the Trace records the fallback`);
  }
  // A Turn worded from Langfuse says that instead.
  const collector = new InMemorySpanExporter();
  await turn('general', { message: 'hi' }, source('latest', fakePromptApi().fetchPrompt), collector);
  assertEquals(collector.getFinishedSpans().find((s) => s.name === 'vana-turn')!.attributes['langfuse.trace.metadata.promptSource'], 'langfuse');
});

Deno.test('fetched prompts are kept in the instance, so a second Turn fetches nothing', async () => {
  const api = fakePromptApi();
  const prompts = source('latest', api.fetchPrompt);
  await turn('general', { message: 'one' }, prompts);
  const afterFirst = api.asked.length;
  assertEquals(new Set(api.asked.map((a) => a.name)).size, afterFirst, 'each prompt was fetched once');
  await turn('general', { message: 'two' }, prompts);
  await turn('meal_planning', { opener: true }, prompts);
  assertEquals(api.asked.length, afterFirst, 'the later Turns made no fetch');
});

Deno.test('a kept prompt past its time is served while it is fetched again in the background', async () => {
  let now = 1_000; let edit = 'first';
  const asked: string[] = []; const background: Promise<unknown>[] = [];
  const prompts = createPromptSource({
    label: 'latest', bundled: { p: 'bundled' }, ttlMs: 60_000, now: () => now, background: (p) => { background.push(p); },
    fetchPrompt: (name) => { asked.push(name); return Promise.resolve({ text: edit, version: asked.length }); },
  });
  assertEquals((await prompts.resolve(['p'])).p.text, 'first');
  edit = 'second'; now += 61_000;
  assertEquals((await prompts.resolve(['p'])).p.text, 'first', 'the Turn does not wait for the refresh');
  await Promise.all(background);
  assertEquals((await prompts.resolve(['p'])).p, { name: 'p', text: 'second', version: 2, config: {}, fallback: false });
  assertEquals(asked.length, 2);
});

Deno.test('with no Langfuse to ask, and with Langfuse holding today\'s text, the model is sent the same bytes', async () => {
  const bundled = await turn('meal_planning', { opener: true, new_plan: true }, source('latest', undefined));
  const fetched = await turn('meal_planning', { opener: true, new_plan: true }, source('latest', fakePromptApi(PROMPT_TEMPLATES).fetchPrompt));
  // Tools, persona, context, messages, and the cache markers on each: the whole call.
  assertEquals(JSON.stringify(fetched.call.prompt), JSON.stringify(bundled.call.prompt));
  assertEquals(JSON.stringify(fetched.call.tools), JSON.stringify(bundled.call.tools));
  assertEquals(firstUserText(bundled.call).split('\n')[0], NEW_PLAN_OPENER);
  assert(NEW_PLAN_OPENER.endsWith(OPENERS.meal_planning));
});
