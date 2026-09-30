# Langfuse observability: research notes (as of 2026-09-30)

Scope: tracing, the JS/TS SDK, Vercel AI SDK and AI Gateway, cost tracking, direct OTLP and REST
ingestion, mobile and client patterns, integrations, and 2025-2026 changelog items.

Method: every `langfuse.com` doc page was fetched as Markdown (`<url>.md`, enumerated from
`https://langfuse.com/llms-docs.txt`, `llms-integrations.txt` and `llms-changelog.txt`). Claims
about behaviour were checked against source in `github.com/langfuse/langfuse` (server) and
`github.com/langfuse/langfuse-js` (SDK, version 5.11.1, published 2026-09-09) where the docs were
thin. **[Unverified]** marks anything I could not confirm from a primary source. **[Inference]**
marks my own reasoning.

Related notes already in the repo: `docs/langfuse/README.md`, `docs/langfuse/research.md`
(eval-v2 mapping, pricing, 2026-09-29).

---

## 0. The facts that force decisions

1. **Langfuse Cloud goes v4-only on 2026-11-16.** On that date `POST /api/public/ingestion` stops
   accepting everything except scores, the v1 read APIs (`/api/public/traces`, `/observations`,
   `/sessions`, metrics v1) go away, and trace-level LLM-as-a-judge evaluators stop.
   Anything new should target OTLP (`/api/public/otel/v1/traces`), Observations API v2,
   Metrics API v2 and Scores API v3.
   Sources: https://langfuse.com/changelog/2026-08-17-langfuse-v4 ,
   https://langfuse.com/docs/api-and-data-platform/features/public-api#ingest-traces ,
   https://langfuse.com/docs/observability/sdk/overview
2. **The JS SDK is v5, not v4.** v5 (the "observations-first" model) replaced
   `updateActiveTrace()` with `propagateAttributes()`, and made a span filter the default: only
   Langfuse, `gen_ai.*` and known LLM-scope spans export.
   https://langfuse.com/docs/observability/sdk/upgrade-path/js-v4-to-v5
3. **Vercel AI Gateway model strings don't match Langfuse's built-in prices for most of our
   models.** Langfuse's default patterns accept an `anthropic/` prefix but expect hyphenated
   versions (`claude-haiku-4-5`). We call `anthropic/claude-haiku-4.5` and
   `anthropic/claude-sonnet-4.6` (dotted). Checked against the current
   `default-model-prices.json` (see §4.4): those return **no match**, so no inferred cost.
   `anthropic/claude-sonnet-5` does match. Langfuse also doesn't read the gateway's
   `providerMetadata.gateway.cost`. Fix options are in §4.5.
4. **There is no Dart/Flutter SDK, official or community.** Tracing SDKs need the secret key, so
   the app must not trace directly. The supported client-side path is score (feedback)
   ingestion with the **public key only**, which a Dart client can reproduce with one HTTP call
   (§5.4).
5. **Deno / Supabase Edge Functions are not an officially supported runtime.** It likely works
   (Langfuse's own cookbooks run in Deno with `npm:` specifiers), but there's no reference
   implementation, `@langfuse/otel` declares `engines.node >=20`, and the one GitHub discussion
   on Supabase Edge is unresolved. Flushing must be tied to `EdgeRuntime.waitUntil` (§2.6).
6. **The AI SDK integration depends on the major version.** The edge functions use
   `npm:ai@6.0.277` (legacy `experimental_telemetry` path). `../mealvana_eval` uses `ai@^7`,
   which uses the new `@langfuse/vercel-ai-sdk` package (Node >= 22, `registerTelemetry`).
7. **Metrics API v2 cannot group by `userId`, `sessionId` or `traceId`** (high cardinality). They
   can only be filtered on. Per-user cost comes from the Users view, filtered queries, or the
   PostHog/Mixpanel/blob exports (§4.7).

---

## 1. Tracing data model

Main pages: https://langfuse.com/docs/observability/data-model ,
https://langfuse.com/docs/observability/features/observation-types ,
https://langfuse.com/docs/observability/best-practices

### 1.1 Observations, traces, sessions

- **Observation**: one step (LLM call, tool call, retrieval and so on). Observations nest.
  Langfuse's word for an OTel span. `span` is also one specific observation type.
- **Trace**: all observations that share a `trace_id`. It is one request or operation (one
  chatbot turn, one agent run). In v4 there is **no separately stored trace entity**: "Langfuse
  stores one observations table, and each row holds the observation-level data plus a copy of
  the trace-level attributes."
- **Session**: optional grouping of traces by `sessionId` (a chat thread, for example). Gives a
  session replay view, public sharing, bookmarking, and session-level scores.
  https://langfuse.com/docs/observability/features/sessions
- Best-practice scoping: one trace per chatbot turn and one session per conversation. Emit one
  `generation` per model call inside an agent loop, not one generation that wraps the whole
  loop. Capture thinking on each generation. Name observations with a verb first
  (`generate-response`), keep dynamic values and model names out of names, and treat names like
  an API, because evaluators and dashboards target them by name.

### 1.2 Observation types

`event`, `span`, `generation`, `agent`, `tool`, `chain`, `retriever`, `evaluator`, `embedding`,
`guardrail`. Set with `asType` (JS SDK >= 4.0.0). **Only `generation` and `embedding` carry
usage and cost.** Any type other than span, event or generation makes the UI infer an **agent
graph** (§7). Integrations set types automatically.

```ts
import { startActiveObservation } from "@langfuse/tracing";
await startActiveObservation("lookup-recipe", async (tool) => {
  tool.update({ input: { q }, output: result });
}, { asType: "tool" });
```

Over OTLP, `langfuse.observation.type` is authoritative. Unknown values fall through to other
conventions, then to "has a model attribute → generation", then to `span`.
https://langfuse.com/integrations/native/opentelemetry#ingestion-transformations

### 1.3 Attributes

| Attribute | Rules | Source |
| --- | --- | --- |
| `userId` | any string; propagated to every observation | /docs/observability/features/users |
| `sessionId` | US-ASCII, **< 200 chars, dropped if longer** | /docs/observability/features/sessions |
| `tags` | string[], each **≤ 200 chars (dropped if longer)**; **immutable, cannot be edited later in the UI**; trace tags = union across observations | /docs/observability/features/tags |
| `metadata` (propagated) | `Record<string,string>`, **values ≤ 200 chars, keys alphanumeric only**; longer values dropped | /docs/observability/features/metadata |
| `metadata` (per observation) | any JSON via `span.update({metadata})`; filterable only on top-level keys | same |
| `environment` | regex `^(?!langfuse)[a-z0-9-_]+$`, ≤ 40 chars; default `default`; set with `LANGFUSE_TRACING_ENVIRONMENT` or the `LangfuseSpanProcessor({environment})` param; environments can't be deleted or renamed | /docs/observability/features/environments |
| `release` | app build (semver or git sha); `LANGFUSE_RELEASE` env or `LangfuseSpanProcessor({release})`; auto-detected on Vercel, Heroku, Netlify | /docs/observability/features/releases-and-versioning |
| `version` | per-observation component version (a prompt or chain) | same |
| `level` | `DEBUG`, `DEFAULT`, `WARNING`, `ERROR`, plus `statusMessage`. Over OTLP an OTel status `ERROR` becomes `ERROR` | /docs/observability/features/log-levels |
| input/output | per observation. Trace input/output = the root observation's; `setTraceIO()` exists only for legacy trace-level judges and is deprecated | /docs/observability/sdk/instrumentation |
| `completionStartTime` | sets time to first token | /docs/observability/sdk/advanced-features |

Note: the v5 migration table says `release` and `environment` were "removed, use env var". That
refers to the per-trace setter. The span processor constructor still accepts
`environment` and `release` (checked in `packages/otel/src/span-processor.ts`).

### 1.4 Trace IDs

W3C format: trace ID is 32 lowercase hex characters, observation ID is 16. You cannot choose
observation IDs. `createTraceId(seed)` gives a deterministic trace ID (async). To start a trace
with a fixed ID, pass `parentSpanContext: { traceId, spanId: "<any 16 hex>", traceFlags: 1 }`.
Doing so detaches the span from the active context. `getActiveTraceId()` and
`getActiveSpanId()` read the current IDs.
https://langfuse.com/docs/observability/features/trace-ids-and-distributed-tracing

```ts
import { createTraceId, startObservation } from "@langfuse/tracing";
const traceId = await createTraceId(`vana-turn-${messageId}`);
const root = startObservation("vana-turn", { input }, {
  parentSpanContext: { traceId, spanId: "0123456789abcdef", traceFlags: 1 },
});
```

Cross-service: `propagateAttributes({..., asBaggage: true}, cb)` puts the attributes into
outbound HTTP headers (OTel baggage). The docs warn to use it only for non-sensitive values.

### 1.5 Sampling

- JS: "Langfuse respects OpenTelemetry's sampling decisions". Configure `sampler: new
  TraceIdRatioBasedSampler(0.2)` on the OTel SDK. Sampling is per trace, and scores in an
  unsampled trace are dropped too. https://langfuse.com/docs/observability/features/sampling
- The docs also list `LANGFUSE_SAMPLE_RATE` for JS, **but that variable doesn't appear anywhere
  in the langfuse-js source** (checked with code search). Treat it as Python-only; in JS use an
  OTel sampler.

### 1.6 Masking and redaction

- JS: `new LangfuseSpanProcessor({ mask: ({ data }) => string })`. It runs on input, output and
  metadata of every observation, and `data` is the stringified JSON.
  https://langfuse.com/docs/observability/features/masking
- Python has a newer export-stage `mask_otel_spans` (changelog 2026-06-16). JS has no equivalent.
- Alternatives: don't record the data (the AI SDK has `recordInputs: false` and
  `recordOutputs: false`), or mask in an OTel Collector.
- Server-side: Cloud offers no masking; self-hosted has an EE "Data Masking" feature (listed in
  llms-self-hosting.txt). **[Unverified detail]**

### 1.7 Multimodal attachments (meal photos)

https://langfuse.com/docs/observability/features/multi-modality

- SDKs find **base64 data URIs** in input, output and metadata, upload them to Langfuse object
  storage through a presigned URL (SHA-256 dedup per project), and replace them with a token:
  `@@@langfuseMedia:type=image/jpeg|id=<mediaId>|source=base64_data_uri@@@`.
- **AI SDK specific:** `@langfuse/otel`'s `MediaService` also parses `ai.prompt.messages` and
  `ai.prompt` on scope `ai`/`gen_ai` spans. It uploads `file` parts and `image` parts whose
  data is a base64 string and whose `mediaType` is set. **URL strings are skipped** (not
  uploaded). It handles AI SDK v7 `gen_ai.input.messages` / `gen_ai.output.messages` blob parts
  too. (Source: `packages/otel/src/MediaService.ts`.)
- **External URLs** (`image_url.url` or markdown image) are not uploaded. The UI renders them
  from the source, so a **signed Supabase Storage URL will stop rendering once it expires**.
  **[Inference]**
- Custom: `new LangfuseMedia({ source: "bytes", contentBytes, contentType })` from
  `@langfuse/core`. Put it in input, output or metadata.
- Resolve back: `langfuse.resolveMediaReferences({ obj, resolveWith: "base64DataUri" })`.
- Raw API: `POST /api/public/media` returns `mediaId` and a presigned URL; then `PUT` the bytes;
  then reference the token.
- Formats: png, jpeg, webp, gif, svg, tiff, bmp, avif, **heic**, plus audio, video, docs.
- Pricing: "currently free on Langfuse Cloud … we reserve the option to roll out a new pricing
  metric."
- Size: self-hosted default max 1 GB per attachment. Cloud API payload limit is **5 MB per
  request** (https://langfuse.com/faq/all/api-limits), so large base64 left inline in a span
  would be a problem. Media upload moves it out of the span.
- Retention deletes media too, except media attached to saved dataset items.
- Deno caveat: Langfuse's Deno cookbook says "The warning about crypto module is expected in
  Deno … Media upload features will be disabled"
  (https://langfuse.com/guides/cookbook/js_langfuse_sdk). The **current** `LangfuseMedia`
  hashes with WebCrypto (`crypto.subtle.digest`), which Deno supports, so that note looks
  stale. **[Unverified: confirm uploads work in the Supabase Edge runtime with a canary.]**
- LLM-as-a-judge can read media from observations (changelog 2026-09-01, "evaluate
  multi-modal inputs").

---

## 2. JS/TS SDK v5 (OpenTelemetry-based)

Pages: https://langfuse.com/docs/observability/sdk/overview ,
https://langfuse.com/docs/observability/sdk/instrumentation ,
https://langfuse.com/docs/observability/sdk/advanced-features

### 2.1 Packages (all 5.11.1 on npm, 2026-09-09)

| Package | Role | `engines` |
| --- | --- | --- |
| `@langfuse/tracing` | `startActiveObservation`, `startObservation`, `observe`, `propagateAttributes`, `createTraceId`, `getActiveTraceId`, `setLangfuseTracerProvider` | node >= 20 |
| `@langfuse/otel` | `LangfuseSpanProcessor`, `isDefaultExportSpan`, etc. Peer deps: `@opentelemetry/api ^1.9`, `core ^2`, `sdk-trace-base ^2`, `exporter-trace-otlp-http >=0.202 <1` | node >= 20 |
| `@langfuse/client` | `LangfuseClient`: prompts, datasets, scores, `api.*` REST wrapper, `getTraceUrl`, `resolveMediaReferences` | none |
| `@langfuse/core` | shared types, logger, `LangfuseMedia` | none |
| `@langfuse/browser` | `LangfuseBrowserClient`, public-key score ingestion only | none |
| `@langfuse/openai`, `@langfuse/langchain` | integrations | |
| `@langfuse/vercel-ai-sdk` | AI SDK **7** integration; deps `@ai-sdk/otel`; peer `ai >=7 <8` | **node >= 22** |

Env vars read by `getEnv()`: `LANGFUSE_PUBLIC_KEY`, `LANGFUSE_SECRET_KEY`, `LANGFUSE_BASE_URL`,
`LANGFUSE_TRACING_ENVIRONMENT`, `LANGFUSE_RELEASE`, `LANGFUSE_FLUSH_AT`,
`LANGFUSE_FLUSH_INTERVAL`, `LANGFUSE_TIMEOUT` (default 5 s),
`LANGFUSE_MEDIA_UPLOAD_ENABLED`, `LANGFUSE_LOG_LEVEL`/`LANGFUSE_DEBUG`. `getEnv` reads
`process.env[key]`, falling back to `globalThis[key]`. It **never reads `Deno.env`**, so in Deno
pass the keys to constructors explicitly unless the Node `process` shim is populated.

Regions: EU `https://cloud.langfuse.com` (default), US `https://us.cloud.langfuse.com`,
JP `https://jp.cloud.langfuse.com`, HIPAA `https://hipaa.cloud.langfuse.com`.

### 2.2 Setup (Node)

```ts
// instrumentation.ts
import { NodeSDK } from "@opentelemetry/sdk-node";
import { LangfuseSpanProcessor } from "@langfuse/otel";
export const langfuseSpanProcessor = new LangfuseSpanProcessor({
  exportMode: "immediate", // serverless: SimpleSpanProcessor instead of BatchSpanProcessor
});
export const sdk = new NodeSDK({ spanProcessors: [langfuseSpanProcessor] });
sdk.start();
```

Processor options (from source): `publicKey`, `secretKey`, `baseUrl`, `flushAt`,
`flushInterval` (seconds), `exportMode: "immediate" | "batched"`, `mask`, `shouldExportSpan`,
`mediaUploadEnabled`, `environment`, `release`, `timeout`, `additionalHeaders`, `exporter`. It
exports to `${baseUrl}/api/public/otel/v1/traces` with Basic auth and `x-langfuse-sdk-name:
javascript` / `x-langfuse-sdk-version` headers. The server treats JS SDK >= 5 as v4-ready, so
data shows in real time. Older SDKs, or bare OTLP without `x-langfuse-ingestion-version: 4`,
can lag 10 to 15 minutes on the v2 read APIs.

### 2.3 Three ways to instrument

```ts
import { startActiveObservation, startObservation, observe,
         propagateAttributes, updateActiveObservation } from "@langfuse/tracing";

// 1. Context manager: active for the callback, auto-ends (even across async)
await startActiveObservation("vana-turn", async (span) => {
  span.update({ input: userMessage });
  // ...
  span.update({ output: reply });
});

// 2. observe() wrapper: captures args/return/errors
const traced = observe(fetchData, { name: "fetch-data", asType: "tool" });
//    options include captureInput/captureOutput and endOnExit (false for streaming)

// 3. Manual: not made active; you MUST .end()
const gen = startObservation("llm-call", { model, input }, { asType: "generation" });
gen.update({ output, usageDetails: { input: 10, output: 5 } }).end();
```

### 2.4 Trace attributes in v5

```ts
await propagateAttributes(
  { traceName: "vana-turn", userId, sessionId, tags: ["vana"], version: "rubric-3",
    metadata: { surface: "chat" } },          // Record<string,string>, values <= 200 chars
  async () => { /* every observation created in here inherits these */ },
);
```

- Spans created **before** the callback are not updated retroactively.
- `setActiveTraceIO()` / `span.setTraceIO()` are deprecated (kept only for legacy trace-level
  judges). `setActiveTraceAsPublic()` / `span.setTraceAsPublic()` make the trace shareable.
- `updateActiveTrace()` and `.updateTrace()` are **removed**.
- Sessions: https://langfuse.com/docs/observability/features/sessions , users:
  https://langfuse.com/docs/observability/features/users

### 2.5 Default span filter (v5 breaking change)

Exported by default: spans from scope `langfuse-sdk`, spans with any `gen_ai.*` attribute, and
known scopes (exact `ai`, plus prefixes `openinference`, `litellm`, `langsmith`, `haystack`,
`strands-agents`, `vllm`, `opentelemetry.instrumentation.{anthropic,openai,bedrock,vertex_ai,…}`).
HTTP, DB and framework spans are dropped. Override with `shouldExportSpan` (a full replacement;
compose with `isDefaultExportSpan`). Dropping a parent can orphan its children. Debug with
`LANGFUSE_LOG_LEVEL=DEBUG`. Unfiltered spans count as billable units.

### 2.6 Flushing in short-lived runtimes

- Generic serverless: `exportMode: "immediate"`, then `await langfuseSpanProcessor.forceFlush()`
  before returning. `forceFlush()` also awaits pending media uploads (source).
- Vercel/Next: `after(async () => await langfuseSpanProcessor.forceFlush())` from
  `next/server`.
- Cloudflare Workers issue #9225 (closed): memory built up under batching. The fix was
  `exportMode: "immediate"` (same effect as `flushAt: 1, flushInterval: 0`), plus flushing in
  `waitUntil`. https://github.com/langfuse/langfuse/issues/9225
- Issue #11984 (closed 2026-02-11): v3 SDK on Workers; `flushAsync()` resolved but nothing was
  persisted. That was the old v3 SDK. https://github.com/langfuse/langfuse/issues/11984

### 2.7 Deno and Supabase Edge Functions

What's documented or known:
- Langfuse's own JS cookbooks run in **Deno** with `npm:` specifiers and `NodeSDK`
  (https://langfuse.com/guides/cookbook/js_langfuse_sdk ,
  https://langfuse.com/integrations/model-providers/anthropic-js). The Vercel AI SDK
  integration page itself contains `import … from "npm:@langfuse/tracing"`.
- GitHub discussion #6150, "reference implementation for Vercel AI SDK and Deno (Deno Deploy,
  Supabase Edge Functions, Cloudflare Workers)", 2025-03-21. **Unresolved, no reference code.**
  Maintainers: "The issue is probably less with the Langfuse Exporter but rather with getting
  Vercel AI SDK OTEL up and running with the Deno runtime." They suggested sending to the OTLP
  endpoint directly. https://github.com/orgs/langfuse/discussions/6150
- Old closed issues: #4499 (TypeError installing the v3 package in Deno, 2024) and #2229
  (Deno + LangChain function output). Neither applies to v5.
- `langfuse-js/packages/core/.../runtime.ts` detects `Deno` for the REST client.
- Supabase: `EdgeRuntime.waitUntil(promise)` keeps the instance alive after the response. Local
  `supabase functions serve` **kills instances after the response, so background flushes don't
  run locally**. https://supabase.com/docs/guides/functions/background-tasks
- Supabase client-side tracing: `supabase` Dart 2.x, supabase-js >= 2.106 and Swift send W3C
  `traceparent`, `tracestate` and `baggage` headers, and Edge Functions receive them.
  https://supabase.com/docs/guides/observability/client-side-tracing

Proposed Deno pattern **[Inference, needs a canary run on the real Edge runtime]**:

```ts
// _shared/langfuse.ts
import { BasicTracerProvider } from "npm:@opentelemetry/sdk-trace-base@2";
import { AsyncLocalStorageContextManager } from "npm:@opentelemetry/context-async-hooks@2";
import { context, trace } from "npm:@opentelemetry/api@1";
import { LangfuseSpanProcessor } from "npm:@langfuse/otel@5";
import { setLangfuseTracerProvider } from "npm:@langfuse/tracing@5";

export const langfuseSpanProcessor = new LangfuseSpanProcessor({
  publicKey: Deno.env.get("LANGFUSE_PUBLIC_KEY")!,   // getEnv() won't read Deno.env
  secretKey: Deno.env.get("LANGFUSE_SECRET_KEY")!,
  baseUrl: Deno.env.get("LANGFUSE_BASE_URL"),
  environment: "dev",                                   // or prod
  exportMode: "immediate",
});
const provider = new BasicTracerProvider({ spanProcessors: [langfuseSpanProcessor] });
context.setGlobalContextManager(new AsyncLocalStorageContextManager().enable()); // nesting across await
trace.setGlobalTracerProvider(provider);   // so AI SDK v6 experimental_telemetry finds it
setLangfuseTracerProvider(provider);

// in the handler, after building the response:
EdgeRuntime.waitUntil(langfuseSpanProcessor.forceFlush());
```

Things this pattern relies on:
- AsyncLocalStorage (`node:async_hooks`) exists in Deno. Without a context manager,
  `propagateAttributes` and nesting silently fail.
- `@opentelemetry/exporter-trace-otlp-http` resolves to a transport that works in the Edge
  runtime.
- The AI SDK v6 alternative to a global provider is `experimental_telemetry.tracer` (v6
  `TelemetrySettings` has `isEnabled`, `recordInputs`, `recordOutputs`, `functionId`,
  `metadata`, `tracer`, `integrations`; checked in `ai@6.0.277` `index.d.ts`).
- If the SDK is too heavy for the Edge runtime (cold start, bundle size), fall back to building
  OTLP/JSON by hand and `fetch`ing `/api/public/otel/v1/traces` (§5.1).

### 2.8 Other SDK notes

- `setLangfuseTracerProvider(provider)` gives an isolated provider, so Langfuse spans don't reach
  other exporters. It shares the global context, so the parent-child mix can orphan spans.
- **Sentry conflict:** Sentry JS v8+ `Sentry.init()` claims the global TracerProvider, which
  stops Langfuse's processor from attaching. Fix: `skipOpenTelemetrySetup: true`, or add
  `LangfuseSpanProcessor` to Sentry's provider.
  https://langfuse.com/faq/all/existing-sentry-setup ,
  https://langfuse.com/faq/all/existing-otel-setup
- Multi-project: register several `LangfuseSpanProcessor`s, each with its own keys and a
  `shouldExportSpan`.
- The SDK "cannot break your application: SDK errors are caught and logged."
- Trace URL: `await langfuse.getTraceUrl(traceId)` on `LangfuseClient`. User deep link:
  `https://<host>/project/{projectId}/users/{userId}`.

---

## 3. Vercel AI SDK integration

Page: https://langfuse.com/integrations/frameworks/vercel-ai-sdk

### 3.1 AI SDK 7 (what `../mealvana_eval` uses: `ai@^7.0.122`)

```bash
npm install ai @langfuse/client @langfuse/vercel-ai-sdk @langfuse/tracing @langfuse/otel @opentelemetry/sdk-node
```

```ts
// instrumentation.ts
import { registerTelemetry } from "ai";
import { LangfuseSpanProcessor } from "@langfuse/otel";
import { LangfuseVercelAiSdkIntegration } from "@langfuse/vercel-ai-sdk";
import { NodeSDK } from "@opentelemetry/sdk-node";
const sdk = new NodeSDK({ spanProcessors: [new LangfuseSpanProcessor()] });
sdk.start();
registerTelemetry(new LangfuseVercelAiSdkIntegration());
```

```ts
const { text } = await propagateAttributes(
  { traceName: "weather-chat", userId, sessionId, tags: ["chat"], metadata: { feature: "x" } },
  () => generateText({
    model, prompt,
    runtimeContext: { route: "weather-chat", langfusePrompt },
    telemetry: { functionId: "weather-chat",
                 includeRuntimeContext: { route: true, langfusePrompt: true } },
  }),
);
```

- In v7, telemetry is **on by default** once an integration is registered. Opt out per call
  with `telemetry: { isEnabled: false }`.
- `runtimeContext` keys only reach telemetry if listed in `includeRuntimeContext`. Langfuse
  maps included keys to observation metadata, and `langfusePrompt` links a prompt version.
- `@langfuse/vercel-ai-sdk` needs **Node >= 22**.
- The server avoids double counting: AI SDK v7 `invoke_agent` and `agent_step` spans carry
  aggregate `gen_ai.usage.*`, so Langfuse skips model, usage and cost on them and keeps cost on
  the model-call span (source comment in `OtelIngestionProcessor.ts`).

### 3.2 AI SDK v6 legacy path (what the edge functions use: `npm:ai@6.0.277`)

```ts
const result = await generateText({
  model, messages,
  experimental_telemetry: {
    isEnabled: true,
    functionId: "vana-chat",                       // name becomes "<functionId>:<operationId>"
    metadata: {
      userId, sessionId, tags: ["vana"],           // mapped to trace user/session/tags
      langfusePrompt: prompt.toJSON(),             // links prompt version
      anyOtherKey: "x",                            // → observation metadata
    },
  },
});
```

Server mapping (`packages/shared/src/server/otel/OtelIngestionProcessor.ts`, checked):
- `ai.telemetry.metadata.userId` → userId, `…sessionId` → sessionId, `…tags` → tags,
  `…langfusePrompt` → prompt link. Other `ai.telemetry.metadata.*` → metadata.
- The observation name comes from `ai.telemetry.functionId` + `ai.operationId`; tool spans use
  `ai.toolCall.name`.
- Model: first of `langfuse.observation.model.name`, `gen_ai.response.model`, `ai.model.id`,
  `gen_ai.request.model`, …
- Usage: `gen_ai.usage.input_tokens` / `output_tokens` (or legacy prompt/completion), plus
  `ai.usage.cachedInputTokens` and `ai.usage.reasoningTokens`. `ai.response.providerMetadata`
  is parsed for `openai` (cached, reasoning, prediction tokens), `anthropic`
  (cache_creation / cache_read, including the 5m and 1h split) and `bedrock`. Cached and
  reasoning tokens are **subtracted** from input and output to keep the buckets exclusive.
- The old `langfuse-vercel` exporter keys (`langfuseTraceId`, `langfuseUpdateParent`) **aren't
  in the current server mapping**. To force a trace ID, wrap the call in a Langfuse observation
  created with `parentSpanContext` (§1.4).
- The docs' streaming pattern for Next.js: `observe(handler, { endOnExit: false })`, end the span
  in `onFinish`/`onError` via `trace.getActiveSpan()?.end()`, and flush in `after()`.
- **Next.js:** `registerOTel` from `@vercel/otel` works only with **`@vercel/otel` v2+**
  (Langfuse needs OTel JS SDK v2; issue https://github.com/vercel/otel/issues/154). A plain
  `NodeTracerProvider` or `NodeSDK` has no version requirement.
- The AI SDK's instrumentation scope is `ai`, which is in the default export allowlist.

### 3.3 Vercel AI Gateway

Page: https://langfuse.com/integrations/gateways/vercel-ai-gateway
- The page only covers the OpenAI-compatible endpoint (`baseURL:
  "https://ai-gateway.vercel.sh/v1"`) with the `@langfuse/openai` `observeOpenAI` wrapper. It
  says nothing about cost.
- The cost-tracking FAQ names only **OpenRouter** and **LiteLLM** as gateways whose returned
  cost Langfuse captures directly.
  https://langfuse.com/docs/observability/features/token-and-cost-tracking#troubleshooting
- Server source: `extractCostDetails` reads only `langfuse.observation.cost_details`,
  `gen_ai.usage.cost` and `llm.cost.total`. The providerMetadata parser handles
  `openai`/`anthropic`/`bedrock` usage keys only, **not `gateway`**. So the AI Gateway's
  `providerMetadata.gateway.cost` is ignored, and cost is **inferred** from the model name ×
  token usage (see §4).
- Side note: the `langfuse/langfuse` repo has an `ai-gateway/` directory, a Rust gateway for
  native OpenAI Responses and Anthropic Messages APIs that ingests generations over OTLP. It is
  not in the public docs. **[Unverified whether it's released or offered on Cloud.]**

---

## 4. Cost and usage tracking

Page: https://langfuse.com/docs/observability/features/token-and-cost-tracking

### 4.1 Ingested vs inferred

- Recorded on `generation` and `embedding` observations only: `usage_details` (units per usage
  type) and `cost_details` (USD per usage type).
- **Ingested beats inferred.** Missing usage: a tokenizer is used if the model definition has
  one (`o200k_base`, `cl100k_base`, or `claude`, which Anthropic says isn't accurate for
  Claude 3+). Missing cost: model price × usage.
- **Inferred cost is computed at ingestion time.** Adding or changing a model price only affects
  **new** generations. There is no backfill.
- Reasoning models: cost can't be inferred without ingested usage.

### 4.2 Usage buckets must be mutually exclusive

`input` excludes `input_*` (e.g. `input_cached_tokens`), and `output` excludes `output_*` (e.g.
`output_reasoning_tokens`). `total` is the sum. OTel `gen_ai.usage.*` and the integrations are
normalized automatically. **A flat `usageDetails` you send yourself is stored unchanged**, so
subtract first or you'll double-count. The OpenAI usage schema (`prompt_tokens`,
`prompt_tokens_details`, …) is auto-mapped **only if it contains no other keys**. A gateway that
adds `cost` makes it flat.

Default Anthropic price keys (from `default-model-prices.json`, e.g. claude-haiku-4-5):
`input`, `input_tokens`, `output`, `output_tokens`, `cache_creation_input_tokens`,
`input_cache_creation`, `input_cache_creation_5m`, `input_cache_creation_1h`,
`cache_read_input_tokens`, `input_cached_tokens`, `input_cache_read`. There is no separate
image-token key. Anthropic bills images as input tokens. **[Inference]**

### 4.3 Model definitions and pricing tiers

- Project Settings → Models, or the API: `GET/POST /api/public/models`,
  `GET/DELETE /api/public/models/{id}`. The matching field is `match_pattern` (a regex against
  the generation's `model`). **User-defined models take priority** over Langfuse-maintained
  ones.
- Pricing tiers: a default tier plus conditional tiers checked in priority order. Conditions
  match on usage-detail regex sums (`gt/gte/lt/lte/eq/neq`), a top-level model-parameter key
  (e.g. `service_tier`), or a **top-level metadata key**. All conditions in a tier must match.
- The defaults are maintained in
  `github.com/langfuse/langfuse/blob/main/worker/src/constants/default-model-prices.json` (177
  entries today). A daily automated price audit opens PRs.

### 4.4 Our models against the default patterns (checked 2026-09-30)

The models come from grepping `supabase/functions` for `'<provider>/<model>'` strings. Matching
used Python `re` with the file's patterns; Langfuse's `(?i)` patterns are simple enough that the
result should be the same. **[Inference]**

| Model string we send | Default match |
| --- | --- |
| `anthropic/claude-haiku-4.5` (18 uses) | **none** |
| `anthropic/claude-sonnet-4.6` (6) | **none** |
| `anthropic/claude-sonnet-5` (5) | `claude-sonnet-5` ($2/M in, $10/M out) |
| `anthropic/claude-haiku-4.5-cheaper` (2) | **none** |
| `anthropic/claude-haiku-4-5` / `anthropic/claude-sonnet-4-6` | match |
| `openai/text-embedding-3-small` | **none** (pattern is `^(text-embedding-3-small)$`, no prefix) |

Caveat: the name Langfuse uses is `gen_ai.response.model` **before** `ai.model.id`. If the AI
Gateway returns the upstream model ID (e.g. `claude-haiku-4-5-20251001`) as the response model,
it would match. **[Unverified: check `model` on a real gateway generation.]**

### 4.5 Options for correct gateway cost (a design decision)

1. **Custom model definitions** for the dotted gateway names, e.g. match pattern
   `(?i)^anthropic/claude-haiku-4\.5(-cheaper)?$` with Anthropic prices. Cheap, but it's an
   estimate that ignores gateway markup or discounts and only applies from the day it's added.
2. **Ingest the real cost.** Read `providerMetadata.gateway.cost` in `onFinish` and write it as
   `langfuse.observation.cost_details` on a generation you create yourself. AI SDK spans are
   already ended and exported by then, so you'd emit your own generation span and **disable or
   filter the AI SDK's own generation to avoid double cost**. More work, exact numbers.
   **[Inference]**
3. **Normalize the model name** to hyphenated IDs before the call. Only works if the gateway
   accepts both forms. **[Unverified]**

### 4.6 Dashboards, metrics, alerts

- **Custom dashboards** (https://langfuse.com/docs/metrics/features/custom-dashboards): widgets
  over traces, observations or scores; line, bar, time-series, pie, number. Curated Latency,
  Cost and Usage dashboards. Home is a dashboard. CSV download per widget. Versioned JSON
  import/export. **Dashboards via API (`/api/public/unstable/…`), CLI and MCP** (changelog
  2026-07-17; unstable).
- **Chart any table** and **Pulse** (§7).
- **Metrics API v2** `GET /api/public/v2/metrics?query=<json>`: views `observations`,
  `scores-numeric`, `scores-categorical`, `scores-boolean`. There is **no `traces` view**. The
  default is 100 rows, max 1,000. **`id`, `traceId`, `userId`, `sessionId` can't be grouping
  dimensions** (filters only). Has an `isRootObservation` dimension. Rate limits on Cloud:
  Hobby 100/day, Core 100/hour, Pro 500/hour. v1 `GET /api/public/metrics` and
  `/metrics/daily` are deprecated and gone from Cloud on 2026-11-16.
  https://langfuse.com/docs/metrics/features/metrics-api

  ```bash
  curl -u pk:sk -G https://cloud.langfuse.com/api/public/v2/metrics --data-urlencode 'query={
    "view":"observations","metrics":[{"measure":"totalCost","aggregation":"sum"}],
    "dimensions":[{"field":"providedModelName"}],"filters":[],
    "fromTimestamp":"2026-09-01T00:00:00Z","toTimestamp":"2026-09-30T00:00:00Z",
    "orderBy":[{"field":"sum_totalCost","direction":"desc"}]}'
  ```
- **Alerts** (a.k.a. Monitors, https://langfuse.com/docs/observability/features/alerts): a
  threshold on an observations or scores metric (e.g. `sum cost` over a 1-day window, filtered
  by tag, user, environment), with warning and alert thresholds, no-data modes and renotify.
  They notify through **Automations**: Slack, an HMAC-signed webhook, or GitHub Actions
  `workflow_dispatch`. Five consecutive delivery failures disable the trigger. Limits per org:
  Hobby 2, Core 20, Pro 50, Enterprise 100. **This is how you alert on LLM spend.**
- **Spend Alerts** (https://langfuse.com/docs/administration/spend-alerts) cover **your
  Langfuse bill**, not LLM cost. Core+ only, email to owners and admins.

### 4.7 Per-user and per-session cost

- The Users view lists per-user token usage, trace count and feedback. The user detail page
  shows aggregates.
- Metrics v2 can filter by one `userId` but can't group by it, so a "top users by cost" query
  needs one of: the dashboard widget (UI), iterating users, the Observations API v2 plus your
  own aggregation, or an export (PostHog/Mixpanel map `user_id` to `distinct_id`; blob export).
  **[Inference: check whether a dashboard widget can break down by user in v4. The v4 dashboard
  changes FAQ wasn't read in full.]**

---

## 5. Direct ingestion, REST, and mobile clients

### 5.1 OTLP endpoint

https://langfuse.com/integrations/native/opentelemetry ,
https://langfuse.com/integrations/native/opentelemetry/migration-to-v4

- `POST {base}/api/public/otel/v1/traces`. OTLP/HTTP with **JSON or protobuf. No gRPC.**
- Auth: `Authorization: Basic base64(pk:sk)`. **Needs the secret key.**
- Send `x-langfuse-ingestion-version: 4` for real-time availability on the v4 read APIs.
  Otherwise it can be delayed up to 10 minutes.
- Attribute mapping (the `langfuse.*` namespace wins):
  - trace-level: `langfuse.trace.name`, `langfuse.user.id` / `user.id`,
    `langfuse.session.id` / `session.id` / `gen_ai.conversation.id`, `langfuse.release`,
    `langfuse.trace.tags` (string[]), `langfuse.trace.public`, `langfuse.trace.metadata.<key>`,
    `langfuse.environment` / `deployment.environment(.name)`, `langfuse.version`
  - observation-level: `langfuse.observation.type`, `.level`, `.status_message`,
    `.input` / `.output` (JSON string), `.metadata.<key>`, `.model.name`,
    `.model.parameters`, `.usage_details`, `.cost_details` (JSON strings),
    `.completion_start_time`, `langfuse.observation.prompt.name` / `.version`. Standard
    `gen_ai.*`, OpenInference, MLflow and AI SDK conventions are also parsed.
  - Unmapped attributes go to `metadata.attributes.*` and resource attributes to
    `metadata.resourceAttributes.*`. **Neither is filterable.**
- **The v4 rules for hand-rolled OTLP:** copy user, session, name, tags, metadata, version,
  release and environment onto **every** span you want filterable; put the overall I/O on the
  root observation; **export each span once**, because re-exporting the same span ID creates
  duplicates in v4 (no read-path dedup); send both timestamps; keep the root span.
- Keys containing `__proto__`, `constructor` or `prototype` segments are silently dropped.

### 5.2 Legacy REST ingestion

`POST /api/public/ingestion` (batched create/update events) is **deprecated and sunset on Cloud
on 2026-11-16**, except `score-create` events, which stay supported. Rate limit on the
deprecated tracing bucket: 100 to 400 req/min. https://langfuse.com/faq/all/api-limits

### 5.3 Read APIs and limits

- Observations API v2 `GET /api/public/v2/observations`: field groups (`core, basic, time, io,
  metadata, model, usage, prompt, metrics, trace_context`), cursor pagination (max 1,000),
  newest first, JSON `filter` param, full-text `matches` on input and output. **No get-by-id
  route** (filter on `id`). Metadata values are cut at 200 characters unless `expandMetadata`.
- Scores API v3 `GET /api/public/v3/scores` (changelog 2026-06-10); JS `api.scoresV3` from
  SDK 5.5.0.
- Cloud payload limit **5 MB per request and 5 MB per response**. Rate buckets per **org**:
  tracing (`/ingestion` + `/otel`) Hobby 1k, Core 4k, Pro 20k req/min; general API 30, 100,
  1,000 req/min; MCP shares the general bucket. 429 responses carry `Retry-After`.
- OpenAPI: https://cloud.langfuse.com/generated/api/openapi.yml ; reference
  https://api.reference.langfuse.com

### 5.4 Dart/Flutter and mobile

- **No Dart or Flutter SDK.** pub.dev has no `langfuse*` package (404 on `langfuse`,
  `langfuse_dart`, `langfuse_flutter`, `dart_langfuse`, `langfuse_client`; search returns
  nothing). The community SDK list in `langfuse/langfuse-examples` covers Rust, Ruby, Elixir,
  PHP, Laravel, .NET, JVM and Go, with no Dart.
- Official guidance
  (https://langfuse.com/docs/observability/sdk/overview#browser): "The tracing SDKs are meant
  for server-side code: they authenticate with a secret key, which must never ship to a browser
  or mobile app. Instrument the backend … and pass the resulting trace ID to the frontend." To
  trace LLM calls that start on the client, "route them through your backend or a proxy you
  control and trace there."
- **Client feedback with the public key only.** `@langfuse/browser` `LangfuseBrowserClient`
  (https://langfuse.com/docs/evaluation/evaluation-methods/scores-via-sdk#browser-score-ingestion).
  From its source (`packages/browser/src/index.ts`) it sends one request per score:

  ```http
  POST {baseUrl}/api/public/ingestion
  Authorization: Bearer pk-lf-...
  X-Langfuse-Public-Key: pk-lf-...
  Content-Type: application/json

  {"batch":[{"id":"<uuid>","type":"score-create","timestamp":"<iso>",
             "body":{"id":"user-feedback-<traceId>","traceId":"<traceId>",
                     "observationId":"<optional>","name":"user-feedback","value":1,
                     "dataType":"BOOLEAN","comment":"optional","environment":"production"}}],
   "metadata":{"batch_size":1,"public_key":"pk-lf-..."}}
  ```

  A Dart client can send the same request with `http`. The body `id` is an idempotency key, so
  re-sending upserts the same score. `score-create` on `/api/public/ingestion` **survives the
  2026-11-16 sunset**. Server-side scoring of the Supabase-authenticated user is the
  alternative, and it keeps a public key out of the app. **[Inference: with the public key a
  holder can post arbitrary scores to any trace ID in that project; I couldn't find any
  server-side check that ties a score to the end user.]**
- Trace ID handoff: the edge function returns the trace ID (`getActiveTraceId()`, or a
  deterministic `createTraceId(messageId)`) with the reply. Deterministic IDs mean Flutter
  never needs to be told the ID. **[Inference]**
- Trace context from Flutter: the `supabase` Dart client (2.x) can send W3C `traceparent` to
  Edge Functions, so an edge function could continue a client-started trace ID. **[Unverified
  for the exact supabase_flutter version and config flag.]**

---

## 6. Other integrations

| Integration | What it is | Source |
| --- | --- | --- |
| OpenAI JS | `observeOpenAI(new OpenAI(), { generationName, … })` from `@langfuse/openai`; captures usage, level, streaming. Works with any OpenAI-compatible base URL (AI Gateway, OpenRouter) | https://langfuse.com/integrations/model-providers/openai-js |
| Anthropic JS | no Langfuse wrapper; uses OpenInference `@arizeai/openinference-instrumentation-anthropic` + `LangfuseSpanProcessor` (the cookbook runs in Deno) | https://langfuse.com/integrations/model-providers/anthropic-js |
| LiteLLM | SDK callback and proxy; Langfuse reads LiteLLM's returned cost | https://langfuse.com/integrations/gateways/litellm |
| OpenRouter | cost captured directly | https://langfuse.com/integrations/gateways/openrouter |
| Langfuse MCP server (authenticated) | `https://cloud.langfuse.com/api/public/mcp`, streamable HTTP, Basic auth with a project key. **Read and write tools on by default** (allowlist for read-only). Tools: prompts, observations, metrics, scores, datasets, comments, annotation queues, evaluators, experiments, dashboards. `claude mcp add --transport http langfuse https://cloud.langfuse.com/api/public/mcp --header "Authorization: Basic <b64>"`. Tool reference: https://mcp.reference.langfuse.com | https://langfuse.com/docs/api-and-data-platform/features/mcp-server |
| Docs MCP server (public) | `https://langfuse.com/api/mcp`; also `GET https://langfuse.com/api/search-docs?query=` | https://langfuse.com/docs/docs-mcp |
| Langfuse CLI | `npx @langfuse/cli api <resource> <action>`; generated from the full OpenAPI spec; uses the `LANGFUSE_*` env vars; exit codes 2 to 6 | https://langfuse.com/docs/api-and-data-platform/features/cli , https://github.com/langfuse/langfuse-cli |
| Agent Skill | `npx skills add langfuse/skills --skill "langfuse"` (Agent Skills standard; works with Claude Code) | https://langfuse.com/docs/api-and-data-platform/features/agent-skill |
| Claude Code tracing | plugin `claude plugin marketplace add langfuse/Claude-Observability-Plugin` then `claude plugin install langfuse-observability@langfuse-observability`; Stop hook reads transcripts; needs Python 3.9+ and `langfuse>=4,<5`; secret key stored in the OS keychain; opt-in per project | https://langfuse.com/integrations/developer-tools/claude-code |
| Claude Agent SDK (Py/JS), Codex, Cursor, Copilot, OpenCode, Kiro | listed integrations | https://langfuse.com/llms-integrations.txt |
| Alerts → Slack / webhook / GitHub Actions | via Automations (§4.6) | /docs/observability/features/alerts |
| Slack app | prompt-change and alert notifications; scopes `channels:read`, `groups:read`, `chat:write`, `chat:write.public` | https://langfuse.com/integrations/other/slack |
| Project notifications | blob-export and evaluator-deactivation alerts to Slack or webhook (changelog 2026-07-10) | changelog |
| Prompt webhooks | on prompt version create, update, delete | /docs/prompt-management/features/webhooks-slack-integrations |
| Web Callouts | a UI button on a trace, observation or session POSTs `{version:1, items:[{projectId, traceId, observationId, sessionId}]}` to your endpoint with static headers; 5 s timeout, no retries, IDs only | https://langfuse.com/docs/observability/features/web-callouts |
| Blob storage export | S3 / S3-compatible (GCS via HMAC) / Azure; every 20 min, hourly, daily or weekly; Parquet (default), CSV, JSON, JSONL (+gzip); selectable field groups; **Pro needs the Teams add-on ($300/mo), Enterprise, or self-hosted** | https://langfuse.com/docs/api-and-data-platform/features/export-to-blob-storage |
| Export from UI | CSV/JSON of tables | /docs/api-and-data-platform/features/export-from-ui |
| PostHog | hourly batch; one `langfuse observation` and one `langfuse score` event each; `user_id`→`$distinct_id`; optional `metadata.$posthog_session_id` | https://langfuse.com/integrations/analytics/posthog |
| Mixpanel | hourly (30 min delay) after an initial full sync; `user_id`→`distinct_id`; optional `metadata.$mixpanel_session_id` | https://langfuse.com/integrations/analytics/mixpanel |
| Comments | on traces, observations, sessions, prompts; markdown, @mentions with email, reactions; API `GET/POST /api/public/comments` | https://langfuse.com/docs/observability/features/comments |
| Corrections | a "corrected output" per trace or observation, stored as a score with `dataType: "CORRECTION"`, `name: "output"`; diff view | https://langfuse.com/docs/observability/features/corrections |
| Public trace and session links | `setTraceAsPublic()` / `langfuse.trace.public`; sessions can be published from the UI | https://langfuse.com/docs/observability/features/url |
| Bookmarks, saved views | bookmark traces and sessions (a `bookmarked` field in the API); saved and shareable table views (changelog 2025-05-20) | changelog |
| MCP tracing | link MCP client and server traces through `_meta` W3C context | https://langfuse.com/docs/observability/features/mcp-tracing |

---

## 7. Changelog 2025-2026 (observability-relevant)

Full list: https://langfuse.com/llms-changelog.txt

| Date | Item |
| --- | --- |
| 2025-03-21 | Traces table peek view |
| 2025-05-20 | Save and share table views |
| 2025-06-04 | All product features open-sourced (MIT) |
| 2025-06-17 | CSV download for dashboard charts |
| 2025-06-28 | Docs MCP server, agentic onboarding |
| 2025-09-30 | Natural-language filtering for traces (Bedrock, zero retention) |
| 2025-11-03 | Filter sidebar; advanced JSON filtering on public traces and observations API |
| 2025-11-04 | Mixpanel integration |
| 2025-11-05 | "Langfuse for Agents": rendered tool calls, agent evals |
| 2025-12-22 | Filter observations by tool calls; tool calls in dashboard widgets |
| 2026-02-13 | Observation-level LLM-as-a-judge |
| 2026-03-10 | "Simplify Langfuse for Scale" (the v4 data-model rollout begins) |
| 2026-05-15 | Blob export column selection and gzip; trace context on `/v2/observations` |
| 2026-05-20 | Exports default to enriched observations for new projects |
| 2026-05-26 | Langfuse agent skill |
| 2026-05-29 | MCP server gains observations, metrics, scores, comments tools |
| 2026-06-10 | Scores API v3; evaluators via MCP |
| 2026-06-16 | Python export-stage masking (`mask_otel_spans`) |
| 2026-06-19 | Langfuse Assistant (public beta, ask questions about traces in plain language); Monitors (alerts) |
| 2026-07-08 | Parquet blob exports |
| 2026-07-10 | Project notifications to Slack or webhooks |
| 2026-07-17 | Dashboards via API, CLI, MCP |
| 2026-07-21 | Boolean score tracking and alerts |
| 2026-07-28 | **Pulse**: count, cost or p95 latency strip above the Observations table; click a spike to filter |
| 2026-08-17 | **Langfuse v4 GA**: one immutable observations table; filter search bar; full-text search; Observations and Metrics API v2; **Cloud v4-only from 2026-11-16**; self-hosted v3 gets security patches through Jan 2027 |
| 2026-08-19 | Chart the Scores table |
| 2026-08-28 | **Responsive Timeline**: the trace timeline fits any trace on one screen, zooms, colour by observation type |
| 2026-09-01 | Multi-message judge prompts; judges on multimodal inputs |

v4 UI features:
- **Agent graphs**: inferred whenever a trace has a type other than span, event or generation.
  Aggregated view (one node per step name, loops drawn as cycles) or Expanded view (one node per
  call, unrolled DAG). https://langfuse.com/docs/observability/features/agent-graphs
- **Filter search bar**: `level:ERROR type:TOOL environment:production latency:>2 name:*chat*
  metadata.region:eu scores.helpfulness:>0.8 tags:(a AND b) -environment:dev`.
  https://langfuse.com/docs/observability/features/filter-search-bar
- **Full-text search** uses ClickHouse text indexes: **whole-token matches only** (`error` does
  not match `errors`), and multi-word queries match as a phrase. The API uses `matches` on
  input and output.
  https://langfuse.com/docs/observability/features/full-text-search
- **Chart any table**: turn the Observations table into a chart (count, latency, cost, tokens,
  broken down by model, name, level, type, environment) and add it to a dashboard. Score,
  metadata, full-text and numeric-measure filters don't apply to charts.
  https://langfuse.com/docs/observability/features/events-table-charts
- I found **no "log view" feature**. The closest are the Timeline and Pulse.

---

## 8. Plans and retention (context only; fuller detail in `docs/langfuse/research.md`)

- Units = traces + observations + scores, **including units that Langfuse features create**
  (judges, experiments). https://langfuse.com/docs/administration/billable-units
- Hobby: free, 50k units, 30-day access, 2 users, 2 alerts. Core: $29, 100k units then
  $8/100k, 90 days. Pro: $199, 3 years. https://langfuse.com/pricing
- Project data retention (min 3 days, nightly delete) is **Pro+ only**. Without it, Cloud keeps
  data for the plan's access window.
  https://langfuse.com/docs/administration/data-retention
- Cost-saving levers: the span filter, sampling, and fewer observations per trace.
  https://langfuse.com/faq/all/cutting-costs

---

## 9. Open questions to settle with a canary

1. Does `@langfuse/otel` 5.x + `BasicTracerProvider` + `AsyncLocalStorageContextManager` export
   from the **deployed** Supabase Edge runtime, and does `EdgeRuntime.waitUntil(forceFlush())`
   finish before shutdown?
2. What `model` string does a generation get for `anthropic/claude-haiku-4.5` through the AI
   Gateway with AI SDK 6: the gateway ID or the upstream ID? Is cost populated?
3. Do meal-photo base64 parts in `ai.prompt.messages` upload as Langfuse media from Deno, and
   does the span stay under the 5 MB request limit?
4. Can a v4 dashboard widget break down cost by `userId`?
