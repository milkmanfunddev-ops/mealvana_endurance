/**
 * Tracing to Langfuse — the one module every AI call site uses (langfuse spec, "Runtime" and "Trace shape").
 *
 * A Trace is one Turn. `turn()` opens the root observation and runs the AI SDK call inside it, so the SDK's own spans
 * (one per Step, one per Tool call) nest under the root and carry the athlete, the Session and the environment: Langfuse
 * filters and evaluators match on observations, so those attributes are propagated to every span and not only set on
 * the root. `telemetry()` is what a call passes as `experimental_telemetry`.
 *
 * The tracer provider is isolated: nothing is registered as the global provider, so Sentry's telemetry setup is not
 * touched and a Sentry upgrade that claims the global provider cannot block these spans. The one global is the
 * context manager, which OpenTelemetry keeps per process; without it spans do not nest across awaits.
 *
 * Cost: a span hook copies the gateway's reported charge for each model call onto that Generation before it ends.
 * Langfuse skips its own price inference for an observation that arrives with a cost, so nothing is counted twice.
 * The hook (`onEnding`) is marked experimental in OpenTelemetry, which is why the versions below are pinned.
 *
 * Photos: a photo sent to a model is image data on its Generation, which Langfuse's SDK uploads to its media store
 * and replaces with a reference, so the photo stays visible and no expiring signed URL is sent. The same hook takes
 * the bytes off the SDK's outer span, where they would otherwise ride inline.
 *
 * Export is immediate (one request per ended span) and `flush()` is handed to the runtime's background-work hook after
 * the response, so a reply never waits on Langfuse. The SDK reads `process.env`, never `Deno.env`: keys are passed in.
 *
 * Prompt versions: a Turn names the Langfuse prompt its model calls ran on, and the same hook links each Generation to
 * that name and version, so Langfuse can total spend and Scores per version. A bundled copy is no version and links to
 * nothing.
 *
 * Tracing never changes a Turn. Every entry point here catches and logs; with no keys it does nothing at all.
 */
import { context, trace, SpanStatusCode, type Span, type Tracer } from 'npm:@opentelemetry/api@1.9.0';
import { BasicTracerProvider, type SpanExporter, type SpanProcessor } from 'npm:@opentelemetry/sdk-trace-base@2.11.0';
import { AsyncLocalStorageContextManager } from 'npm:@opentelemetry/context-async-hooks@2.11.0';
import { LangfuseSpanProcessor } from 'npm:@langfuse/otel@5.11.1';
import { propagateAttributes } from 'npm:@langfuse/core@5.11.1';
import { gatewayCostUsd } from '../ai/usage.ts';
import { background } from './runtime.ts';

export type TracingEnvironment = 'dev' | 'production' | 'experiment';

export interface TracingConfig {
  publicKey: string | undefined;
  secretKey: string | undefined;
  baseUrl?: string;
  /** The environment a Trace carries unless its Turn names another. */
  environment?: TracingEnvironment;
  release?: string;
  /** In place of Langfuse's exporter. A test collects spans here. */
  exporter?: SpanExporter;
}

/** A prompt as a Turn ran on it: its Langfuse version, or the bundled copy (no version, or standing in as fallback). */
export interface PromptRef { name: string; version: number | null; fallback: boolean }

export interface TurnAttributes {
  /** The root observation's name, and the Trace's: the entry point (`vana-turn` for a chat Turn). */
  name: string;
  /** The athlete's auth id. */
  userId: string;
  /** The Conversation. Absent for a call that belongs to none. */
  sessionId?: string | null;
  environment?: TracingEnvironment;
  /** Filterable facts about the Turn, propagated to every observation. Values are short strings. */
  metadata?: Record<string, string>;
  tags?: string[];
  /** The prompt the Turn's Generations link to. A bundled copy links to nothing. */
  prompt?: PromptRef | null;
  /** Every prompt the Turn was built from, by name, with its Langfuse version (null for a bundled copy). For a Turn
   *  built from more than one: a Generation links to one prompt only, so the rest are listed on the root. */
  promptVersions?: Record<string, number | null>;
  /** What the athlete sent. */
  input?: unknown;
}

/** The open root observation of a Turn. Ending it twice is harmless; the first ending stands. */
export interface TurnRoot {
  finish(result: { output?: unknown; toolCalls?: string[] }): void;
  fail(error: unknown): void;
}

export interface Tracing {
  /** The `experimental_telemetry` value for an AI SDK call made inside `turn()`. */
  telemetry(functionId: string): { isEnabled: boolean; functionId?: string; tracer?: Tracer };
  /** Runs `fn` inside a new root observation. `fn` runs exactly once whether or not tracing works. */
  turn<T>(attributes: TurnAttributes, fn: (root: TurnRoot) => T): T;
  /** One model call that is a Trace of its own (a described meal, a background job). The root ends with what `fn`
   *  resolves to, as `output` reads it, or as an error with what it rejects with; the flush is handed to the runtime's
   *  background-work hook. What `fn` resolves to or rejects with is the caller's, unchanged. */
  call<T>(attributes: TurnAttributes, fn: () => Promise<T>, output?: (result: T) => unknown): Promise<T>;
  /** Resolves when every ended span has been sent. Never rejects. */
  flush(): Promise<void>;
}

const NO_ROOT: TurnRoot = { finish: () => {}, fail: () => {} };
const NO_TRACING: Tracing = { telemetry: () => ({ isEnabled: false }), turn: (_a, fn) => fn(NO_ROOT), call: (_a, fn) => fn(), flush: () => Promise.resolve() };

const warn = (what: string, e: unknown) => console.error(`[langfuse] ${what}:`, (e as Error)?.message ?? e);
const serialized = (v: unknown): string => (typeof v === 'string' ? v : JSON.stringify(v));

/** The AI SDK's model-call spans, which Langfuse reads as Generations. The outer `ai.streamText` / `ai.generateObject`
 *  span holds the last step's provider metadata too; costing it would count that step twice. */
const MODEL_CALL = /\.do(Generate|Stream)$/;
const IMAGE_NOTE = '(image: shown on the Generation under this span)';
/** The outer span's prompt with any image bytes replaced by a note, or null when it holds none. The SDK records the
 *  prompt there as the caller passed it, in a shape Langfuse's media handling does not read, so a photo would ride
 *  inline on it as base64. The Generation under it carries the same photo as a reference to Langfuse's stored copy. */
function withoutImageBytes(prompt: string): string | null {
  if (!prompt.includes('"image"') && !prompt.includes('"file"')) return null;
  const parsed = JSON.parse(prompt) as { messages?: { content?: unknown }[] };
  let changed = false;
  for (const message of Array.isArray(parsed?.messages) ? parsed.messages : []) {
    for (const part of (Array.isArray(message?.content) ? message.content : []) as Record<string, unknown>[]) {
      if (part?.type !== 'image' && part?.type !== 'file') continue;
      for (const key of ['image', 'data']) if (typeof part[key] === 'string' && !/^https?:/.test(part[key] as string)) { part[key] = IMAGE_NOTE; changed = true; }
    }
  }
  return changed ? JSON.stringify(parsed) : null;
}
const PROMPT_NAME = 'langfuse.trace.metadata.promptName';
const PROMPT_VERSION = 'langfuse.trace.metadata.promptVersion';
/** What is changed on a span while it is still writable: the gateway's charge and the prompt version go onto each
 *  model-call span, and image bytes come off the SDK's outer span. */
const beforeExport = {
  onStart() {}, onEnd() {}, forceFlush: () => Promise.resolve(), shutdown: () => Promise.resolve(),
  onEnding(span: Span & { name: string; attributes: Record<string, unknown> }) {
    try {
      if (!MODEL_CALL.test(span.name)) {
        const prompt = span.attributes['ai.prompt'];
        const without = typeof prompt === 'string' ? withoutImageBytes(prompt) : null;
        if (without != null) span.setAttribute('ai.prompt', without);
        return;
      }
      const name = span.attributes[PROMPT_NAME]; const version = Number(span.attributes[PROMPT_VERSION]);
      if (typeof name === 'string' && Number.isInteger(version)) {
        span.setAttribute('langfuse.observation.prompt.name', name);
        span.setAttribute('langfuse.observation.prompt.version', version);
      }
      const raw = span.attributes['ai.response.providerMetadata'];
      const cost = typeof raw === 'string' ? gatewayCostUsd(JSON.parse(raw)) : null;
      if (cost != null) span.setAttribute('langfuse.observation.cost_details', JSON.stringify({ total: cost }));
    } catch (e) { warn('span hook failed', e); }
  },
} as SpanProcessor;

let contextManagerSet = false;
/** One context manager per process; a second registration is refused by OpenTelemetry, so it is only tried once. */
function ensureContextManager() {
  if (contextManagerSet) return;
  contextManagerSet = true;
  context.setGlobalContextManager(new AsyncLocalStorageContextManager().enable());
}

export function createTracing(config: TracingConfig): Tracing {
  if (!config.exporter && (!config.publicKey || !config.secretKey)) return NO_TRACING;
  try {
    const langfuse = new LangfuseSpanProcessor({
      publicKey: config.publicKey, secretKey: config.secretKey, baseUrl: config.baseUrl,
      environment: config.environment, release: config.release, exporter: config.exporter,
      exportMode: 'immediate',
      // Spans sent without this header are read through the legacy path and can lag by minutes.
      additionalHeaders: { 'x-langfuse-ingestion-version': '4' },
    });
    const provider = new BasicTracerProvider({ spanProcessors: [beforeExport, langfuse] });
    ensureContextManager();
    // The scope names are read by Langfuse: `ai` marks AI SDK spans, `langfuse-sdk` its own observations.
    const aiTracer = provider.getTracer('ai');
    const rootTracer = provider.getTracer('langfuse-sdk');

    const open = (a: TurnAttributes): { span: Span; root: TurnRoot } => {
      // `root`: the deployed runtime has a request span of its own in the active context, which Langfuse never receives.
      const span = rootTracer.startSpan(a.name, { root: true, attributes: {
        'langfuse.observation.type': 'span',
        ...(a.input == null ? {} : { 'langfuse.observation.input': serialized(a.input) }),
        ...(a.promptVersions ? { 'langfuse.observation.metadata.promptVersions': JSON.stringify(a.promptVersions) } : {}),
      } });
      let ended = false;
      const end = (write: () => void) => { if (ended) return; ended = true; try { write(); span.end(); } catch (e) { warn('ending the root failed', e); } };
      return { span, root: {
        finish: ({ output, toolCalls }) => end(() => {
          if (output != null) span.setAttribute('langfuse.observation.output', serialized(output));
          if (toolCalls) span.setAttribute('langfuse.observation.metadata.toolCalls', JSON.stringify(toolCalls));
        }),
        fail: (error) => end(() => {
          const message = String((error as Error)?.message ?? error);
          span.setAttribute('langfuse.observation.level', 'ERROR');
          span.setAttribute('langfuse.observation.status_message', message);
          span.setStatus({ code: SpanStatusCode.ERROR, message });
        }),
      } };
    };

    const tracing: Tracing = {
      telemetry: (functionId) => ({ isEnabled: true, functionId, tracer: aiTracer }),
      call<T>(a: TurnAttributes, fn: () => Promise<T>, output: (result: T) => unknown = (r) => r): Promise<T> {
        return tracing.turn(a, (root) => fn().then(
          (result) => { try { root.finish({ output: output(result) }); } catch (e) { warn('reading the output failed', e); root.finish({}); } return result; },
          (error) => { root.fail(error); throw error; },
        ).finally(() => background(tracing.flush())));
      },
      turn<T>(a: TurnAttributes, fn: (root: TurnRoot) => T): T {
        // `fn` is the Turn: it runs once, and what it throws is the caller's to see. Only the tracing around it is guarded.
        let ran = false; let result!: T; let thrown: { error: unknown } | null = null;
        const run = (root: TurnRoot) => { ran = true; try { result = fn(root); } catch (error) { thrown = { error }; root.fail(error); } };
        // Propagated like the rest, so the span hook finds the prompt on each model call made inside the Turn.
        const linked: Record<string, string> = a.prompt && a.prompt.version != null && !a.prompt.fallback ? { promptName: a.prompt.name, promptVersion: String(a.prompt.version) } : {};
        try {
          propagateAttributes({ userId: a.userId, sessionId: a.sessionId || undefined, environment: a.environment, traceName: a.name, metadata: { ...a.metadata, ...linked }, tags: a.tags }, () => {
            const { span, root } = open(a);
            context.with(trace.setSpan(context.active(), span), () => run(root));
          });
        } catch (e) { warn('opening the root failed', e); }
        if (!ran) run(NO_ROOT);
        if (thrown) throw (thrown as { error: unknown }).error;
        return result;
      },
      // A task later, not now: a caller flushing from an SDK callback is ahead of the SDK ending its own outer span.
      flush: () => new Promise<void>((r) => setTimeout(r, 0)).then(() => langfuse.forceFlush()).catch((e) => warn('flush failed', e)),
    };
    return tracing;
  } catch (e) { warn('setup failed, tracing is off', e); return NO_TRACING; }
}

let fromEnv: Tracing | null = null;
let inPlace: Tracing | null = null;
/** In place of the instance's tracing, for a test that drives a function through its own entry point. Null puts it back. */
export function setDefaultTracing(tracing: Tracing | null): void { inPlace = tracing; }
/** The function instance's tracing, built once from the function secrets. With no keys set it does nothing. */
export function defaultTracing(): Tracing {
  if (inPlace) return inPlace;
  if (fromEnv) return fromEnv;
  const environment = Deno.env.get('LANGFUSE_TRACING_ENVIRONMENT');
  fromEnv = createTracing({
    publicKey: Deno.env.get('LANGFUSE_PUBLIC_KEY'), secretKey: Deno.env.get('LANGFUSE_SECRET_KEY'),
    baseUrl: Deno.env.get('LANGFUSE_BASE_URL') ?? 'https://us.cloud.langfuse.com',
    environment: environment === 'dev' || environment === 'production' || environment === 'experiment' ? environment : undefined,
    release: Deno.env.get('LANGFUSE_RELEASE') ?? Deno.env.get('SENTRY_RELEASE') ?? undefined,
  });
  return fromEnv;
}
