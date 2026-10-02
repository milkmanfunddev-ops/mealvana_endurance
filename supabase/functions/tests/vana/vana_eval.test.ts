/**
 * vana-eval at its seam (eval-v2 ticket 02, test seam 1): requests in, responses and rows out.
 *
 * The handler runs as deployed, over the fake database, a fake auth admin and the real `runChat`. The model is a
 * mock behind the AI SDK's default provider (as in run_overrides.test.ts), scripted per turn by the athlete's
 * message: "workouts" calls the getWorkouts data tool, "broken" files feedback, anything else is one text step.
 */
import { assert, assertEquals, assertNotEquals } from 'https://deno.land/std@0.177.1/testing/asserts.ts';
import { MockLanguageModelV3, MockProviderV3, convertArrayToReadableStream } from 'npm:ai@6.0.277/test';
import { makeVanaEvalHandler, type CopyAuth } from '../../vana-eval/handler.ts';
import type { AthleteSnapshot } from '../../vana-eval/copy.ts';
import { testCtx, type TestCtx } from './support/vana_ctx.ts';
import { PERSONA_SECTIONS } from '../../_shared/vana/persona.ts';
import { makeVanaTools } from '../../_shared/vana/tools.ts';
import { CHAT_MODEL } from '../../_shared/vana/env.ts';
import type { AthleteContext } from '../../_shared/vana/contracts.ts';

const ADMIN = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
const ATHLETE = 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb';
const SOURCE = 'cccccccc-cccc-4ccc-8ccc-cccccccccccc';
const ACTIVITY = 'dddddddd-dddd-4ddd-8ddd-dddddddddddd';
const EVENT = 'eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee';
const MEMORY = 'ffffffff-ffff-4fff-8fff-ffffffffffff';
const TODAY = new Date().toISOString().slice(0, 10);
const TOMORROW = new Date(Date.now() + 86400_000).toISOString().slice(0, 10);

/** The Eval athlete, producer-shaped: rows as the tables return them. No weight and no home, so building the
 *  context reaches no macro engine and no weather service. */
const SNAPSHOT: AthleteSnapshot = {
  user_id: SOURCE,
  tables: {
    users: [{ id: SOURCE, first_name: 'Sam', email: 'sam@example.com', allergies: ['peanut'], is_admin: true, is_internal: false }],
    activities: [{ id: ACTIVITY, user_id: SOURCE, title: 'Tempo run', activity_type: 'run', scheduled_date_time: `${TOMORROW}T07:00:00Z`, duration_minutes: 50, deleted_at: null }],
    events: [{ id: EVENT, user_id: SOURCE, name: 'City Half', activity_id: ACTIVITY, date: TOMORROW }],
    user_memories: [{ id: MEMORY, user_id: SOURCE, kind: 'preference', fact: 'Sam likes oats before a run.', is_deleted: false, confidence: 0.8 }],
  },
};

// deno-lint-ignore no-explicit-any
type CallOptions = any;
const usage = { inputTokens: { total: 10, noCache: 10, cacheRead: 0, cacheWrite: 0 }, outputTokens: { total: 5, text: 5, reasoning: 0 } };
let generation = 0;
const finish = (reason: 'stop' | 'tool-calls') => ({ type: 'finish', finishReason: { unified: reason, raw: reason }, usage, providerMetadata: { gateway: { generationId: `gen_${++generation}`, cost: '0.0001' } } });
const text = (t: string) => [{ type: 'text-start', id: 't' }, { type: 'text-delta', id: 't', delta: t }, { type: 'text-end', id: 't' }];

/** The last user text in a model call's prompt. */
function lastUserText(o: CallOptions): string {
  const users = (o.prompt as { role: string; content: { type: string; text?: string }[] }[]).filter((m) => m.role === 'user');
  return (users.at(-1)?.content ?? []).map((p) => p.text ?? '').join('\n');
}
const hasToolResult = (o: CallOptions) => (o.prompt as { role: string }[]).at(-1)?.role === 'tool';

/** A mock default provider for the test's duration. Records every model call. */
function mockGateway(): { seen: { modelId: string; options: CallOptions }[]; restore: () => void } {
  const seen: { modelId: string; options: CallOptions }[] = [];
  const model = (modelId: string) => new MockLanguageModelV3({
    modelId,
    doStream: (options: CallOptions) => {
      seen.push({ modelId, options });
      const said = lastUserText(options);
      const parts = hasToolResult(options) ? [...text('You have a tempo run tomorrow.'), finish('stop')]
        : said.includes('workouts') ? [{ type: 'tool-call', toolCallId: `c${generation}`, toolName: 'getWorkouts', input: JSON.stringify({ days: 7 }) }, finish('tool-calls')]
        : said.includes('broken') ? [{ type: 'tool-call', toolCallId: `c${generation}`, toolName: 'saveFeedback', input: JSON.stringify({ message: 'the app is broken', sentiment: 'negative', about: 'app' }) }, finish('tool-calls')]
        : [...text(`Reply ${seen.length}.`), finish('stop')];
      // deno-lint-ignore no-explicit-any
      return Promise.resolve({ stream: convertArrayToReadableStream([{ type: 'stream-start', warnings: [] }, ...parts] as any) });
    },
  });
  // deno-lint-ignore no-explicit-any
  const g = globalThis as any;
  const before = g.AI_SDK_DEFAULT_PROVIDER;
  g.AI_SDK_DEFAULT_PROVIDER = new MockProviderV3({ languageModels: {} });
  g.AI_SDK_DEFAULT_PROVIDER.languageModel = model;
  return { seen, restore: () => { g.AI_SDK_DEFAULT_PROVIDER = before; } };
}

/** Dev as the test sees it: one admin, one athlete, the source athlete's own rows, and an auth admin that
 *  creates and deletes users in memory. */
function harness() {
  const v: TestCtx = testCtx({
    users: [{ id: ADMIN, is_admin: true }, { id: ATHLETE, is_admin: false }, ...structuredClone(SNAPSHOT.tables.users!)],
    activities: structuredClone(SNAPSHOT.tables.activities!), events: structuredClone(SNAPSHOT.tables.events!), user_memories: structuredClone(SNAPSHOT.tables.user_memories!),
  });
  let now = Date.now();
  const authUsers = new Map<string, { email: string; password: string; createdAt: string }>();
  const auth: CopyAuth = {
    create: (email, password) => { const id = crypto.randomUUID(); authUsers.set(id, { email, password, createdAt: new Date(now).toISOString() }); return Promise.resolve(id); },
    signIn: (email, password) => {
      const hit = [...authUsers.entries()].find(([, u]) => u.email === email && u.password === password);
      return hit ? Promise.resolve(`token-${hit[0]}`) : Promise.reject(new Error('invalid login'));
    },
    remove: (id) => { authUsers.delete(id); return Promise.resolve(); },
    listStale: (beforeIso) => Promise.resolve([...authUsers.entries()].filter(([, u]) => u.createdAt < beforeIso).map(([id]) => id)),
  };
  const handle = makeVanaEvalHandler({
    caller: (req) => Promise.resolve(({ 'Bearer admin': ADMIN, 'Bearer athlete': ATHLETE } as Record<string, string>)[req.headers.get('Authorization') ?? ''] ?? null),
    admin: v.db,
    auth,
    secret: 'test-secret',
    // The fake has no RLS, so the copy's client is the same fake acting as the copy.
    ctxFor: (userId, token) => ({ db: v.db, admin: v.db, userId, token }),
    now: () => now,
  });
  const call = (body: unknown, who = 'admin') => handle(new Request('http://x/vana-eval', { method: 'POST', headers: { Authorization: `Bearer ${who}` }, body: JSON.stringify(body) }));
  return { v, authUsers, call, advance: (ms: number) => { now += ms; } };
}

// deno-lint-ignore no-explicit-any
type Line = Record<string, any>;
const lines = async (r: Response): Promise<Line[]> => (await r.text()).split('\n').filter(Boolean).map((l) => JSON.parse(l));
const traceOf = (ls: Line[]) => ls.find((l) => l.type === 'trace')!;

async function start(h: ReturnType<typeof harness>) {
  const r = await h.call({ action: 'start', snapshot: SNAPSHOT });
  assertEquals(r.status, 200);
  return (await r.json()) as { run_user_id: string; before: AthleteSnapshot };
}

Deno.test('a caller who is not an admin is refused before any user is created', async () => {
  const h = harness();
  for (const who of ['athlete', 'nobody']) {
    for (const body of [{ action: 'start', snapshot: SNAPSHOT }, { action: 'sweep' }, { action: 'end', run_user_id: ADMIN }, { action: 'defaults' }]) {
      const r = await h.call(body, who);
      assertEquals(r.status, who === 'athlete' ? 403 : 401);
    }
  }
  assertEquals(h.authUsers.size, 0, 'no user was created');
  assertEquals(h.v.fake.writes.length, 0, 'nothing was written');
});

Deno.test('start seeds a copy under a new user; the source athlete and the snapshot are unchanged', async () => {
  const h = harness();
  const sent = structuredClone(SNAPSHOT);
  const { run_user_id: copy, before } = await start(h);
  assert(h.authUsers.has(copy), 'the copy is a new auth user');
  assertNotEquals(copy, SOURCE);
  const users = h.v.fake.rows('users').find((u) => u.id === copy)!;
  assertEquals(users.first_name, 'Sam');
  assertEquals(users.is_admin, false, 'a copy is never an admin');
  assertNotEquals(users.email, 'sam@example.com');
  const act = before.tables.activities![0];
  assertNotEquals(act.id, ACTIVITY, 'the copy has its own ids');
  assertEquals(act.user_id, copy);
  assertEquals(before.tables.events![0].activity_id, act.id, 'references follow the copy');
  assertEquals(before.tables.user_memories![0].fact, 'Sam likes oats before a run.');
  assertEquals(SNAPSHOT, sent, 'the snapshot object is untouched');
  assertEquals(h.v.fake.rows('activities').filter((r) => r.user_id === SOURCE), SNAPSHOT.tables.activities, 'the source rows are untouched');
});

Deno.test('start refuses a snapshot it cannot copy, and leaves no user behind', async () => {
  const h = harness();
  for (const snapshot of [null, { user_id: SOURCE, tables: { users: [] } }, { user_id: SOURCE, tables: { users: SNAPSHOT.tables.users, vana_calls: [] } }]) {
    const r = await h.call({ action: 'start', snapshot });
    assertEquals(r.status, 400);
  }
  assertEquals(h.authUsers.size, 0);
});

Deno.test('a three-turn conversation keeps its history, and each trace carries full tool inputs and outputs', async () => {
  const h = harness();
  const { run_user_id: copy } = await start(h);
  const gw = mockGateway();
  try {
    const t1 = await lines(await h.call({ action: 'turn', run_user_id: copy, message: 'what workouts do I have', kind: 'general' }));
    const trace1 = traceOf(t1);
    assert(trace1, 'turn 1 ends with a trace line');
    const conv = trace1.conversation_id as string;
    assert(conv, 'the trace names the conversation');
    assertEquals(trace1.persisted, true, 'the turn was stored before the trace went out');
    // The data tool: full input and full output, not just its name.
    const step0 = trace1.trace.steps[0];
    assertEquals(step0.toolCalls, [{ toolCallId: step0.toolCalls[0].toolCallId, toolName: 'getWorkouts', input: { days: 7 } }]);
    assertEquals(step0.toolResults[0].input, { days: 7 });
    assertEquals(step0.toolResults[0].output.map((a: { title: string }) => a.title), ['Tempo run'], "the output is the copy's own workouts");
    assertEquals(step0.toolResults[0].modelOutput?.type, 'json', "the model's view of the result, as the SDK sent it");
    assertEquals(step0.toolResults[0].modelOutput.value.map((a: { title: string }) => a.title), ['Tempo run']);
    assertEquals(trace1.trace.steps.map((s: { generationId: string }) => s.generationId), ['gen_1', 'gen_2'], 'a gateway generation id per step');
    assert(trace1.trace.system.persona.length > 0 && trace1.trace.system.context.includes('Sam'), 'system prompt and Context block');
    assert(trace1.trace.tools.includes('getWorkouts'), 'tools offered');
    assert(trace1.trace.modelMessages.length > 0, 'model messages');
    assert(t1.some((l) => l.type === 'text' && l.delta.includes('tempo run')), 'the reply streamed live');

    const t2 = await lines(await h.call({ action: 'turn', run_user_id: copy, conversation_id: conv, message: 'and what about dinner', kind: 'general' }));
    const t3 = await lines(await h.call({ action: 'turn', run_user_id: copy, conversation_id: conv, message: 'thanks, sounds good', kind: 'general' }));
    assertEquals(traceOf(t2).conversation_id, conv);
    assertEquals(traceOf(t3).conversation_id, conv);
    const third = JSON.stringify(gw.seen.at(-1)!.options.prompt);
    for (const said of ['what workouts do I have', 'You have a tempo run tomorrow.', 'and what about dinner', 'Reply 3.', 'thanks, sounds good']) assert(third.includes(said), `turn 3 replays "${said}"`);
  } finally { gw.restore(); }
});

Deno.test("overrides reach the model call, and Vana's writes land on the copy", async () => {
  const h = harness();
  const { run_user_id: copy } = await start(h);
  const gw = mockGateway();
  try {
    const overrides = {
      model: 'anthropic/claude-sonnet-5', tools: ['saveFeedback'], persona: { everyChat: 'You are Vana, under test.' },
      toolDescriptions: { saveFeedback: { description: 'Test: file feedback.', parameters: { message: 'Test: their words.' } } },
    };
    const t = await lines(await h.call({ action: 'turn', run_user_id: copy, message: 'the app is broken', kind: 'general', overrides }));
    const sent = gw.seen[0];
    assertEquals(sent.modelId, 'anthropic/claude-sonnet-5');
    assertEquals(traceOf(t).trace.tools, ['saveFeedback']);
    assert((sent.options.prompt[0].content as string).startsWith('You are Vana, under test.'), 'the persona section reached the model');
    const tool = sent.options.tools[0] as { name: string; description: string; inputSchema: { properties: Record<string, { description?: string }> } };
    assertEquals([tool.name, tool.description, tool.inputSchema.properties.message.description], ['saveFeedback', 'Test: file feedback.', 'Test: their words.']);
    const bad = await h.call({ action: 'turn', run_user_id: copy, message: 'hi', kind: 'general', overrides: { tools: ['noSuchTool'] } });
    assertEquals(bad.status, 400);
    // A section the kind's persona is not built from (here, one from before the sections were renamed) is refused too.
    const stale = await h.call({ action: 'turn', run_user_id: copy, message: 'hi', kind: 'general', overrides: { persona: { core: 'You are Vana.' } } });
    assertEquals(stale.status, 400);
  } finally { gw.restore(); }
  const feedback = h.v.fake.rows('user_feedback');
  assertEquals(feedback.map((r) => r.user_id), [copy], 'the feedback row is the copy\'s');
  assertEquals(h.v.fake.rows('vana_messages').every((r) => r.user_id === copy), true, "the conversation is the copy's");
  for (const t of ['users', 'activities', 'events', 'user_memories'] as const) {
    assertEquals(h.v.fake.rows(t).filter((r) => (t === 'users' ? r.id : r.user_id) === SOURCE), SNAPSHOT.tables[t], `the source athlete's ${t} are unchanged after a turn`);
  }
});

Deno.test('a turn is refused for a user that is not a copy', async () => {
  const h = harness();
  for (const user of [ATHLETE, SOURCE]) {
    const r = await h.call({ action: 'turn', run_user_id: user, message: 'hi', kind: 'general' });
    assertEquals(r.status, 404);
  }
});

Deno.test('end returns the before and after snapshots and the copy no longer exists', async () => {
  const h = harness();
  const { run_user_id: copy, before } = await start(h);
  const gw = mockGateway();
  try { await lines(await h.call({ action: 'turn', run_user_id: copy, message: 'the app is broken', kind: 'general' })); } finally { gw.restore(); }
  const r = await h.call({ action: 'end', run_user_id: copy });
  assertEquals(r.status, 200);
  const body = await r.json() as { before: AthleteSnapshot; after: AthleteSnapshot };
  assertEquals(body.before, before);
  assertEquals(body.before.tables.user_feedback, undefined);
  assertEquals(body.after.tables.user_feedback!.length, 1, 'the after snapshot holds what Vana wrote');
  assertEquals(body.after.tables.activities, before.tables.activities);
  assert(!h.authUsers.has(copy), 'the auth user is gone');
  // The call logs reference auth.users ON DELETE CASCADE on dev, so they go with the auth user; the fake has no
  // cascade, so they are left out here. Every table the copy was seeded into or Vana wrote is checked.
  const cascadedWithAuthUser = ['vana_calls', 'ai_usage'];
  for (const [t, rows] of Object.entries(h.v.fake.tables).filter(([t]) => !cascadedWithAuthUser.includes(t))) assertEquals(rows.filter((row) => row.user_id === copy || (t === 'users' && row.id === copy)).length, 0, `${t} holds nothing of the copy`);
  assertEquals(h.v.fake.rows('users').find((u) => u.id === SOURCE)!.email, 'sam@example.com', 'the source athlete is untouched');
  assertEquals(h.v.fake.rows('ai_usage').map((r) => [r.user_id, r.function_name]), [[ADMIN, 'vana-eval']], "the turn's cost stays on record once, under the admin");
  assertEquals((await h.call({ action: 'end', run_user_id: copy })).status, 404, 'a second end finds nothing');
});

Deno.test('the sweep removes a copy a Run left behind, and only once it is old', async () => {
  const h = harness();
  const { run_user_id: stale } = await start(h);
  let swept = await (await h.call({ action: 'sweep' })).json();
  assertEquals(swept.deleted, [], 'a young copy stays');
  h.advance(3 * 3600_000);
  const { run_user_id: fresh } = await start(h);
  assert(!h.authUsers.has(stale), 'starting a Run sweeps the stale copy');
  assert(h.authUsers.has(fresh));
  assertEquals(h.v.fake.rows('activities').filter((r) => r.user_id === stale).length, 0);
  h.advance(3 * 3600_000);
  swept = await (await h.call({ action: 'sweep' })).json();
  assertEquals(swept.deleted, [fresh]);
  assertEquals(h.authUsers.size, 0);
});

Deno.test('the sweep also removes a copy whose Run died before it was recorded', async () => {
  const h = harness();
  // A user marked as a copy with no vana_eval_run_users row: the Run died between creating it and recording it.
  h.authUsers.set('orphan', { email: 'vana-eval+orphan@eval.mealvana.invalid', password: 'x', createdAt: new Date().toISOString() });
  assertEquals((await (await h.call({ action: 'sweep' })).json()).deleted, []);
  h.advance(3 * 3600_000);
  assertEquals((await (await h.call({ action: 'sweep' })).json()).deleted, ['orphan']);
  assertEquals(h.authUsers.size, 0);
});

Deno.test("defaults show what a Run may override, as the app runs it: the model, each persona section, and each kind's tools with their descriptions", async () => {
  const h = harness();
  const r = await h.call({ action: 'defaults' });
  assertEquals(r.status, 200);
  const d = await r.json();
  assertEquals(d.model, CHAT_MODEL);
  assertEquals(d.persona, PERSONA_SECTIONS);
  assertEquals(d.kinds.meal_planning.persona, ['everyChat', 'writeRules', 'planningChat']);
  assertEquals(d.kinds.general.persona, ['everyChat', 'writeRules', 'generalChat']);
  for (const kind of ['general', 'meal_planning'] as const) {
    // deno-lint-ignore no-explicit-any
    const tools = makeVanaTools(h.v, {} as AthleteContext, kind, {}) as Record<string, any>;
    assertEquals(Object.keys(d.kinds[kind].tools), Object.keys(tools), `${kind}: every tool of the kind, in order`);
    for (const [name, t] of Object.entries(tools)) {
      assertEquals(d.kinds[kind].tools[name].description, t.description, `${kind}: ${name}'s description`);
      const params = Object.fromEntries(Object.entries(t.inputSchema.shape).map(([k, s]) => [k, (s as { description?: string }).description ?? '']));
      assertEquals(d.kinds[kind].tools[name].parameters, params, `${kind}: ${name}'s parameters`);
    }
  }
  assertEquals(d.kinds.general.tools.dayGuidance.parameters.date !== undefined, true, 'a parameter is listed even with no description');
  assertEquals(h.v.fake.writes.length, 0, 'nothing was written');
});
