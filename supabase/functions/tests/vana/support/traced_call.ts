/**
 * What a test needs to watch one background model call leave for Langfuse (langfuse ticket 10): a mock model behind
 * the AI SDK's default provider, answering one structured object with the gateway's charge the way the gateway
 * reports it; a span collector in place of Langfuse's exporter, installed as the function instance's tracing; and the
 * runtime's background-work hook, recorded so the flush can be waited for.
 */
import { assert, assertEquals } from 'https://deno.land/std@0.177.1/testing/asserts.ts';
import { MockLanguageModelV3, MockProviderV3 } from 'npm:ai@6.0.277/test';
import { InMemorySpanExporter, type ReadableSpan, type SpanExporter } from 'npm:@opentelemetry/sdk-trace-base@2.11.0';
import { createTracing, setDefaultTracing } from '../../../_shared/langfuse/tracing.ts';

// deno-lint-ignore no-explicit-any
type CallOptions = any;
export interface ModelCall { modelId: string; options: CallOptions }
const LANGFUSE_URL = 'http://langfuse.invalid';

/** The exporter that is Langfuse being down. */
export const failingExporter: SpanExporter = {
  export: () => { throw new Error('langfuse is down'); },
  shutdown: () => Promise.reject(new Error('langfuse is down')),
  forceFlush: () => Promise.reject(new Error('langfuse is down')),
};

export interface TracedWorld {
  /** Each model call, as the provider received it. */
  modelCalls: ModelCall[];
  /** Every span handed to the exporter, once the background work has settled. */
  spans: () => Promise<ReadableSpan[]>;
  /** What Langfuse's media store was asked to take (a photo on a span is moved there by the SDK). */
  media: Record<string, unknown>[];
}

/**
 * Runs `body` with the model answering `answer` (charged `cost`, a decimal string as the gateway sends it) and with
 * tracing collected. `exporter: null` is the app with no Langfuse keys; a given exporter stands in for the collector.
 */
export async function withTracedModel<T>(answer: unknown, cost: string, body: (world: TracedWorld) => Promise<T>, opts: { exporter?: SpanExporter | null } = {}): Promise<T> {
  // deno-lint-ignore no-explicit-any
  const g = globalThis as any;
  const before = { provider: g.AI_SDK_DEFAULT_PROVIDER, runtime: g.EdgeRuntime, fetch: g.fetch };
  const modelCalls: ModelCall[] = [];
  const media: Record<string, unknown>[] = [];
  // Langfuse's media store, the one address the SDK reaches past the exporter. It answers "already held", so nothing
  // further is sent. Every other request goes where it went before.
  g.fetch = (async (input: Request | URL | string, init?: RequestInit) => {
    const req = input instanceof Request ? input : new Request(input, init);
    if (req.url !== `${LANGFUSE_URL}/api/public/media`) return before.fetch(input, init);
    media.push(await req.json());
    return new Response(JSON.stringify({ mediaId: 'media-stub', uploadUrl: null }), { headers: { 'content-type': 'application/json' } });
  }) as typeof fetch;
  const background: Promise<unknown>[] = [];
  const collector = new InMemorySpanExporter();
  g.EdgeRuntime = { waitUntil: (p: Promise<unknown>) => { background.push(p.catch(() => {})); } };
  g.AI_SDK_DEFAULT_PROVIDER = new MockProviderV3({ languageModels: {} });
  g.AI_SDK_DEFAULT_PROVIDER.languageModel = (modelId: string) => new MockLanguageModelV3({
    modelId,
    doGenerate: (options: CallOptions) => {
      modelCalls.push({ modelId, options });
      return Promise.resolve({
        content: [{ type: 'text', text: JSON.stringify(answer) }],
        finishReason: { unified: 'stop', raw: 'stop' },
        usage: { inputTokens: { total: 900, noCache: 900, cacheRead: 0, cacheWrite: 0 }, outputTokens: { total: 60, text: 60, reasoning: 0 } },
        providerMetadata: { gateway: { generationId: `gen_${modelCalls.length}`, cost } },
        warnings: [],
        // deno-lint-ignore no-explicit-any
      } as any);
    },
  });
  setDefaultTracing(opts.exporter === null ? null : createTracing({ publicKey: 'pk-test', secretKey: 'sk-test', baseUrl: LANGFUSE_URL, environment: 'dev', release: 'test-release', exporter: opts.exporter ?? collector }));
  // A background task may hand the hook another one, so wait until none is added.
  const settled = async () => { for (let n = -1; n !== background.length;) { n = background.length; await Promise.all(background); } };
  try {
    return await body({ modelCalls, media, spans: async () => { await settled(); return collector.getFinishedSpans(); } });
  } finally { await settled(); setDefaultTracing(null); g.AI_SDK_DEFAULT_PROVIDER = before.provider; g.EdgeRuntime = before.runtime; g.fetch = before.fetch; }
}

export const generations = (spans: ReadableSpan[]) => spans.filter((s) => /\.do(Generate|Stream)$/.test(s.name));
export const costOf = (s: ReadableSpan) => JSON.parse(String(s.attributes['langfuse.observation.cost_details'] ?? 'null')) as { total: number } | null;

/** The spans are one Trace named `name` for `userId`, in `sessionId` when there is a Conversation, with one Generation
 *  whose cost is `cost`. Returns the root. */
export function assertOneTrace(spans: ReadableSpan[], want: { name: string; userId: string; sessionId?: string; cost: number | null | undefined }): ReadableSpan {
  assertEquals(new Set(spans.map((s) => s.spanContext().traceId)).size, 1, 'every span is in the one Trace');
  const roots = spans.filter((s) => !s.parentSpanContext);
  assertEquals(roots.map((s) => s.name), [want.name], 'one root, named for what the call does');
  assertEquals(roots[0].attributes['langfuse.trace.name'], want.name);
  for (const s of spans) {
    assertEquals(s.attributes['user.id'], want.userId, `${s.name}: the athlete`);
    assertEquals(s.attributes['session.id'], want.sessionId, `${s.name}: the Conversation`);
    assertEquals(s.attributes['langfuse.environment'], 'dev', `${s.name}: the environment`);
  }
  const costed = spans.filter((s) => costOf(s) != null);
  assertEquals(costed.map((s) => s.name), generations(spans).map((s) => s.name), 'only the Generation is costed');
  assertEquals(costed.length, 1, 'one Generation');
  assert(want.cost != null, 'the Call log holds a gateway charge to compare with');
  assertEquals(costOf(costed[0])!.total, want.cost, "Langfuse's cost equals vana_calls.gateway_cost_usd");
  return roots[0];
}
