/**
 * A described meal and a meal photo as Langfuse receives them (langfuse ticket 09).
 *
 * Each function's real `index.ts` runs in-process through the serve harness: its own auth, gate, budget, limiter and
 * model call. Supabase is a stub behind `fetch`, the model is a mock behind the AI SDK's default provider, and a span
 * collector stands in for Langfuse's exporter. What is asserted is what leaves the function: the spans handed to the
 * exporter, the response the athlete gets, the Call log row and the budget settlement. The model's answer carries the
 * gateway's charge the way the gateway reports it, so the cost on the Generation and the cost in `vana_calls` are both
 * read from producer-shaped data and compared with each other.
 *
 * Imported by `describe-meal/index.test.ts` and `analyze-meal-photo/index.test.ts`; each runs it for its own function.
 */
import { assert, assertEquals } from 'https://deno.land/std@0.177.1/testing/asserts.ts';
import { MockLanguageModelV3, MockProviderV3 } from 'npm:ai@6.0.277/test';
import { InMemorySpanExporter, type ReadableSpan, type SpanExporter } from 'npm:@opentelemetry/sdk-trace-base@2.11.0';
import { createTracing, setDefaultTracing, type Tracing } from '../_shared/langfuse/tracing.ts';
import { type Call, loadFunction, setStubEnv, STUB_SUPABASE_URL } from './paywall/support/serve_harness.ts';

export const USER = 'c18d3737-0000-4000-8000-0000000000a1';
const LANGFUSE_URL = 'http://langfuse.invalid';
/** What the gateway charged for the one model call. */
const COST = '0.013695';
/** A small JPEG's first bytes, then filler: enough to be a photo as far as anything here reads it. */
export const PHOTO_BYTES = new Uint8Array([0xff, 0xd8, 0xff, 0xe0, ...Array.from({ length: 600 }, (_, i) => (i * 37) % 256)]);

const ANSWER = {
  name: 'Eggs on toast',
  suggested_slot: 'breakfast',
  confidence: 'high',
  items: [{ name: 'Eggs on toast', portion: '2 eggs, 2 slices', calories: 420, carb_g: 30, protein_g: 22, fat_g: 23, sodium_mg: 610 }],
};

// deno-lint-ignore no-explicit-any
type CallOptions = any;
/** What left the function for the length of one request. */
export interface Seen {
  /** Each model call, as the provider received it. */
  modelCalls: { modelId: string; options: CallOptions }[];
  /** The patch that finished the Call log row. */
  callLog: Record<string, unknown>[];
  /** What the budget reservation was settled to. */
  settled: Record<string, unknown>[];
  /** What Langfuse's media store was asked to take. */
  media: Record<string, unknown>[];
  /** Every request that was not Supabase's or Langfuse's media store. */
  elsewhere: string[];
}

const json = (body: unknown, status = 200) => new Response(JSON.stringify(body), { status, headers: { 'content-type': 'application/json' } });

/** Runs `body` with an active subscriber behind `fetch`, the model mocked and the background-work hook recorded.
 *  Resolves once everything the function handed to the hook has settled. */
export async function withMealWorld<T>(body: (seen: Seen) => Promise<T>, model: { fail?: boolean } = {}): Promise<T> {
  const seen: Seen = { modelCalls: [], callLog: [], settled: [], media: [], elsewhere: [] };
  // deno-lint-ignore no-explicit-any
  const g = globalThis as any;
  const before = { fetch: g.fetch, provider: g.AI_SDK_DEFAULT_PROVIDER, runtime: g.EdgeRuntime };
  const background: Promise<unknown>[] = [];
  g.EdgeRuntime = { waitUntil: (p: Promise<unknown>) => { background.push(p.catch(() => {})); } };
  g.AI_SDK_DEFAULT_PROVIDER = new MockProviderV3({ languageModels: {} });
  g.AI_SDK_DEFAULT_PROVIDER.languageModel = (modelId: string) => new MockLanguageModelV3({
    modelId,
    doGenerate: (options: CallOptions) => {
      seen.modelCalls.push({ modelId, options });
      if (model.fail) return Promise.reject(new Error('the gateway refused'));
      return Promise.resolve({
        content: [{ type: 'text', text: JSON.stringify(ANSWER) }],
        finishReason: { unified: 'stop', raw: 'stop' },
        usage: { inputTokens: { total: 2368, noCache: 2368, cacheRead: 0, cacheWrite: 0 }, outputTokens: { total: 162, text: 162, reasoning: 0 } },
        providerMetadata: { gateway: { generationId: 'gen_1', cost: COST } },
        warnings: [],
        // deno-lint-ignore no-explicit-any
      } as any);
    },
  });
  g.fetch = (async (input: Request | URL | string, init?: RequestInit) => {
    const req = input instanceof Request ? input : new Request(input, init);
    const url = new URL(req.url);
    if (url.origin === LANGFUSE_URL && url.pathname === '/api/public/media') {
      seen.media.push(await req.json());
      // No upload URL: Langfuse already holds these bytes, so the SDK sends nothing further.
      return json({ mediaId: 'media-stub', uploadUrl: null });
    }
    if (url.origin !== STUB_SUPABASE_URL) { seen.elsewhere.push(`${req.method} ${req.url}`); return json({ error: 'stub: not routed' }, 404); }
    switch (url.pathname) {
      case '/auth/v1/user': return json({ id: USER, aud: 'authenticated', role: 'authenticated', email: 'athlete@example.test' });
      case '/rest/v1/user_entitlements': {
        const row = { user_id: USER, active_until: '2099-01-01T00:00:00.000Z', period_type: 'NORMAL' };
        return (req.headers.get('accept') ?? '').includes('vnd.pgrst.object') ? json(row) : json([row]);
      }
      case '/rest/v1/rpc/ai_budget_reserve': return json({ allowed: true, reservation_id: 'res-stub', balance: 4_000_000, allowance: 0, allowance_monthly: 0, allowance_expires_at: null });
      case '/rest/v1/rpc/ai_budget_settle': seen.settled.push(await req.json()); return json({ settled: true });
      case '/rest/v1/rpc/vana_reserve_call': return json('call-1');
      case '/rest/v1/vana_calls': if (req.method === 'PATCH') seen.callLog.push(await req.json()); return json([]);
      case '/rest/v1/ai_usage': return json([], 201);
      default:
        if (url.pathname.startsWith('/storage/v1/object/meal-photos/')) return new Response(PHOTO_BYTES, { headers: { 'content-type': 'image/jpeg' } });
        if (url.pathname.startsWith('/rest/v1/') && req.method === 'GET') return json([]);
        return json({ message: `stub: no route for ${req.method} ${url.pathname}` }, 404);
    }
  }) as typeof fetch;
  try {
    const out = await body(seen);
    // A background task may hand the hook another one, so wait until none is added.
    for (let n = -1; n !== background.length;) { n = background.length; await Promise.all(background); }
    return out;
  } finally { g.fetch = before.fetch; g.AI_SDK_DEFAULT_PROVIDER = before.provider; g.EdgeRuntime = before.runtime; }
}

export const post = (fn: string, body: unknown) => new Request(`${STUB_SUPABASE_URL}/functions/v1/${fn}`, { method: 'POST', headers: { Authorization: 'Bearer user-jwt', 'Content-Type': 'application/json' }, body: JSON.stringify(body) });

/** A collector in place of Langfuse's exporter, installed as the function instance's tracing. */
export function collecting(exporter?: SpanExporter): { collector: InMemorySpanExporter; tracing: Tracing } {
  const collector = new InMemorySpanExporter();
  const tracing = createTracing({ publicKey: 'pk-test', secretKey: 'sk-test', baseUrl: LANGFUSE_URL, environment: 'dev', release: 'test-release', exporter: exporter ?? collector });
  setDefaultTracing(tracing);
  return { collector, tracing };
}

const generations = (spans: ReadableSpan[]) => spans.filter((s) => s.name.endsWith('.doGenerate'));
const costOf = (s: ReadableSpan) => JSON.parse(String(s.attributes['langfuse.observation.cost_details'] ?? 'null')) as { total: number } | null;
/** The supabase-js clients the function builds start refresh timers that outlive one request: the deployed code's
 *  behaviour, so the op sanitizers are off (as in the paywall and budget tests). */
const test = (name: string, fn: () => Promise<void>) => Deno.test({ name, fn, sanitizeOps: false, sanitizeResources: false });

export interface MealFunction {
  /** The function's folder and the name its Trace carries. */
  fn: 'describe-meal' | 'analyze-meal-photo';
  request: Record<string, unknown>;
  /** What the root observation's input must hold, given the collected root. */
  input: (root: ReadableSpan) => void;
}

export function mealAnalysisIsTraced(f: MealFunction): { call: () => Promise<Call> } {
  setStubEnv();
  let loaded: Promise<Call> | null = null;
  const call = () => (loaded ??= loadFunction(new URL(`../${f.fn}/index.ts`, import.meta.url).href));

  test(`${f.fn}: one call is one Trace named for the function, carrying the athlete, its input and the analysis`, async () => {
    const { collector } = collecting();
    try {
      const out = await withMealWorld(async () => await (await (await call())(post(f.fn, f.request))).json());
      const spans = collector.getFinishedSpans();
      assertEquals(new Set(spans.map((s) => s.spanContext().traceId)).size, 1, 'every span is in the one Trace');
      const roots = spans.filter((s) => !s.parentSpanContext);
      assertEquals(roots.map((s) => s.name), [f.fn], 'one root, named for the entry point');
      assertEquals(roots[0].attributes['langfuse.trace.name'], f.fn);
      f.input(roots[0]);
      const output = JSON.parse(String(roots[0].attributes['langfuse.observation.output']));
      assertEquals(output.name, out.name, 'the analysis the athlete was sent');
      assertEquals(output.totals, out.totals);
      for (const s of spans) {
        assertEquals(s.attributes['user.id'], USER, `${s.name}: the athlete`);
        assertEquals(s.attributes['langfuse.environment'], 'dev', `${s.name}: the environment`);
        assertEquals(s.attributes['langfuse.release'], 'test-release', `${s.name}: the release`);
        assertEquals(s.attributes['langfuse.trace.tags'], [f.fn], `${s.name}: the tags`);
        assertEquals(s.attributes['session.id'], undefined, `${s.name}: a logged meal belongs to no Conversation`);
      }
      assertEquals(generations(spans).length, 1, 'one Generation');
    } finally { setDefaultTracing(null); }
  });

  test(`${f.fn}: the Generation's cost is the gateway's charge, the figure the Call log stores`, async () => {
    const { collector } = collecting();
    try {
      const seen = await withMealWorld(async (seen) => { await (await (await call())(post(f.fn, f.request))).body?.cancel(); return seen; });
      const spans = collector.getFinishedSpans();
      const costed = spans.filter((s) => costOf(s) != null);
      assertEquals(costed.map((s) => s.name), generations(spans).map((s) => s.name), 'only the Generation is costed');
      assertEquals(seen.callLog.length, 1, 'one Call log row');
      assertEquals(costOf(costed[0])!.total, seen.callLog[0].gateway_cost_usd, "Langfuse's cost equals vana_calls.gateway_cost_usd");
      assertEquals(costOf(costed[0])!.total, Number(COST));
    } finally { setDefaultTracing(null); }
  });

  test(`${f.fn}: a failing exporter changes neither the response, the Call log nor the budget settlement`, async () => {
    const run = async () => await withMealWorld(async (seen) => { const res = await (await call())(post(f.fn, f.request)); return { status: res.status, body: await res.json(), seen }; });
    setDefaultTracing(null);
    const plain = await run();
    const failing: SpanExporter = {
      export: () => { throw new Error('langfuse is down'); },
      shutdown: () => Promise.reject(new Error('langfuse is down')),
      forceFlush: () => Promise.reject(new Error('langfuse is down')),
    };
    collecting(failing);
    try {
      const traced = await run();
      assertEquals(traced.status, 200);
      assertEquals([traced.status, traced.body], [plain.status, plain.body], 'the same response');
      assertEquals(traced.seen.callLog, plain.seen.callLog, 'the same Call log row');
      assertEquals(traced.seen.settled, plain.seen.settled, 'the same settlement');
      assertEquals(traced.seen.settled.length, 1);
    } finally { setDefaultTracing(null); }
  });

  test(`${f.fn}: a failed model call is an error on its Trace, and the athlete is answered as before`, async () => {
    const run = async () => await withMealWorld(async () => { const res = await (await call())(post(f.fn, f.request)); return { status: res.status, body: await res.json() }; }, { fail: true });
    setDefaultTracing(null);
    const plain = await run();
    const { collector } = collecting();
    try {
      const traced = await run();
      assertEquals(traced, plain, 'the same refusal');
      const root = collector.getFinishedSpans().find((s) => s.name === f.fn);
      assert(root, 'the failed call still sent its root');
      assertEquals(root.attributes['langfuse.observation.level'], 'ERROR');
      assertEquals(root.attributes['langfuse.observation.status_message'], 'the gateway refused');
    } finally { setDefaultTracing(null); }
  });

  return { call };
}

export { generations };
