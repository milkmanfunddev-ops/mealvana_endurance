/**
 * Per-Run overrides at the chat seam (eval-v2 ticket 01): `runChat` takes optional replacements for the persona's
 * sections, Vana's model, the tools that are on, and the tools' and parameters' descriptions. `vana-eval` passes them
 * for one Run; `vana-chat` never does, so with none given the model is sent exactly what it is sent today.
 * The model is a mock behind the AI SDK's default provider, so a string model id resolves the way the gateway's does
 * and the test reads what reached the model call. No network.
 */
import { assert, assertEquals } from 'https://deno.land/std@0.177.1/testing/asserts.ts';
import { MockLanguageModelV3, MockProviderV3, convertArrayToReadableStream } from 'npm:ai@6.0.277/test';
import { runChat, systemMessages, type TurnTrace, type VanaOverrides } from '../../_shared/vana/chat.ts';
import { PERSONA_SECTIONS } from '../../_shared/vana/persona.ts';
import { buildAthleteContext } from '../../_shared/vana/context.ts';
import { makeVanaTools } from '../../_shared/vana/tools.ts';
import { CHAT_MODEL } from '../../_shared/vana/env.ts';
import type { ConversationKind } from '../../_shared/vana/contracts.ts';
import { testCtx, offlineDeps, TEST_USER_ID } from './support/vana_ctx.ts';

const U = TEST_USER_ID;
const ANCHOR = '2026-09-09';
const CONV = 'conv-1';

// deno-lint-ignore no-explicit-any
type CallOptions = any;
/** One model call's input, as the provider received it. */
interface Seen { modelId: string; options: CallOptions }

/** Installs a mock default provider for the test's duration: every model id it is asked for answers one short text
 *  step and records the call. */
function mockGateway(): { seen: Seen[]; restore: () => void } {
  const seen: Seen[] = [];
  const model = (modelId: string) => new MockLanguageModelV3({
    modelId,
    doStream: (options: CallOptions) => {
      seen.push({ modelId, options });
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

/** One turn on an existing conversation whose context is already built for today, so nothing leaves the process. */
async function turn(kind: ConversationKind, overrides?: VanaOverrides) {
  const v = testCtx({ users: [{ id: U, first_name: 'Lee', allergies: [] }] });
  const ctx = await buildAthleteContext(v, ANCHOR, offlineDeps());
  await v.db.from('vana_conversations').insert({ id: CONV, user_id: U, kind, context: ctx, context_day: ANCHOR, last_message_at: `${ANCHOR}T08:00:00Z` });
  const gw = mockGateway();
  const traces: TurnTrace[] = [];
  try {
    const run = await runChat(v, { message: 'what should I eat today', conversation_id: CONV, kind, anchor_date: ANCHOR }, { functionName: 'vana-eval', onTrace: (t) => traces.push(t), overrides });
    assert(run.ok, `the turn ran: ${JSON.stringify(run)}`);
    await run.response.text();
  } finally { gw.restore(); }
  assertEquals(gw.seen.length, 1, 'one model call');
  return { v, ctx, call: gw.seen[0], trace: traces[0] };
}

const systemTexts = (o: CallOptions) => (o.prompt as { role: string; content: string }[]).filter((m) => m.role === 'system').map((m) => m.content);
const offered = (o: CallOptions) => Object.fromEntries((o.tools ?? []).map((t: { name: string; description: string; inputSchema: unknown }) => [t.name, t]));

Deno.test('with no overrides the model gets the model id, persona, context and tools it gets today', async () => {
  for (const kind of ['general', 'meal_planning'] as const) {
    const { v, ctx, call, trace } = await turn(kind);
    assertEquals(call.modelId, CHAT_MODEL, `${kind}: the default chat model`);
    assertEquals(trace.model, CHAT_MODEL);
    assertEquals(systemTexts(call.options), systemMessages(kind, ctx, ANCHOR).map((m) => m.content), `${kind}: persona then context, unchanged`);
    const tools = makeVanaTools(v, ctx, kind, {});
    assertEquals(Object.keys(offered(call.options)).sort(), Object.keys(tools).sort(), `${kind}: every tool of the kind is offered`);
    for (const [name, t] of Object.entries(tools)) assertEquals(offered(call.options)[name].description, (t as { description?: string }).description, `${kind}: ${name}'s description`);
  }
});

Deno.test('an empty overrides object sends the same bytes as none', async () => {
  const none = await turn('general');
  const empty = await turn('general', {});
  assertEquals(JSON.stringify(empty.call.options.prompt), JSON.stringify(none.call.options.prompt));
  assertEquals(JSON.stringify(empty.call.options.tools), JSON.stringify(none.call.options.tools));
  assertEquals(empty.call.modelId, none.call.modelId);
});

Deno.test('a persona section override replaces that section in the system prompt, for either kind', async () => {
  const general = await turn('general', { persona: { writeRules: 'WRITES: test rule.' } });
  const persona = systemTexts(general.call.options)[0];
  assert(persona.includes('- WRITES: test rule.'), 'the replaced section is in the general persona');
  assert(!persona.includes(PERSONA_SECTIONS.writeRules), 'the original section is gone');
  assert(persona.startsWith(PERSONA_SECTIONS.general) && persona.endsWith(PERSONA_SECTIONS.generalAfterWrites), 'the sections around it are untouched');
  assertEquals(general.trace.system.persona, persona, 'the trace records the persona that was sent');

  const planning = await turn('meal_planning', { persona: { core: 'You are Vana, under test.', planning: 'PLAN: test rules.' } });
  assertEquals(systemTexts(planning.call.options)[0], `You are Vana, under test.\n${PERSONA_SECTIONS.writeRules}\nPLAN: test rules.`);
});

Deno.test('a model override is the model called, and the trace records it', async () => {
  const { call, trace } = await turn('general', { model: 'anthropic/claude-sonnet-5' });
  assertEquals(call.modelId, 'anthropic/claude-sonnet-5');
  assertEquals(trace.model, 'anthropic/claude-sonnet-5');
});

Deno.test('a tool set override offers only the tools that are on', async () => {
  const { call, trace } = await turn('general', { tools: ['dayGuidance', 'askChoice'] });
  assertEquals(Object.keys(offered(call.options)).sort(), ['askChoice', 'dayGuidance']);
  assertEquals(trace.tools.sort(), ['askChoice', 'dayGuidance']);
  const none = await turn('general', { tools: [] });
  assertEquals(none.call.options.tools ?? [], [], 'an empty set offers no tools');
});

Deno.test('tool and parameter description overrides reach the tools offered', async () => {
  const { v, ctx, call } = await turn('general', { toolDescriptions: { dayGuidance: { description: 'Test: a day frame.', parameters: { date: 'Test: YYYY-MM-DD.' } } } });
  const t = offered(call.options).dayGuidance as { description: string; inputSchema: { properties: Record<string, { description?: string }> } };
  assertEquals(t.description, 'Test: a day frame.');
  assertEquals(t.inputSchema.properties.date.description, 'Test: YYYY-MM-DD.');
  const other = offered(call.options).searchMeals as { description: string };
  assertEquals(other.description, (makeVanaTools(v, ctx, 'general', {}).searchMeals as { description?: string }).description, 'other tools keep theirs');
});

Deno.test('an override naming a tool or parameter that does not exist is a 400 and no model call', async () => {
  for (const [overrides, name] of [
    [{ tools: ['noSuchTool'] }, 'noSuchTool'],
    [{ toolDescriptions: { noSuchTool: { description: 'x' } } }, 'noSuchTool'],
    [{ toolDescriptions: { dayGuidance: { parameters: { noSuchParam: 'x' } } } }, 'dayGuidance.noSuchParam'],
  ] as [VanaOverrides, string][]) {
    const v = testCtx({ users: [{ id: U, first_name: 'Lee', allergies: [] }] });
    await v.db.from('vana_conversations').insert({ id: CONV, user_id: U, kind: 'general', context: await buildAthleteContext(v, ANCHOR, offlineDeps()), context_day: ANCHOR });
    const gw = mockGateway();
    try {
      const run = await runChat(v, { message: 'hi', conversation_id: CONV, kind: 'general', anchor_date: ANCHOR }, { functionName: 'vana-eval', overrides });
      assertEquals(run.ok ? null : run.status, 400);
      assert(!run.ok && String(run.body.detail).endsWith(name), `names ${name}`);
      assertEquals(gw.seen.length, 0, 'the model is never called');
    } finally { gw.restore(); }
  }
});
