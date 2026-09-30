# True cost in Langfuse, and whether to host Vana on Vercel (2026-09-30)

Two questions from Lee:

- **A.** Langfuse must show what the Vercel AI Gateway actually charged for each call.
- **B.** Would moving Vana from Supabase Edge Functions to Vercel Functions make the official
  Langfuse integration work as documented, and is that easier?

Extends `01-observability.md` (sections 2.7, 3, 4). Three claims in that file are corrected here;
see "Corrections to 01-observability.md" at the end.

Method: Langfuse docs fetched as `<url>.md`; source read from `langfuse/langfuse`,
`langfuse/langfuse-js` (5.11.1) and `vercel/ai` (`ai@7.0.123`, `@ai-sdk/otel@1.0.123`,
`@ai-sdk/gateway@4.0.101`); Vercel and Supabase docs fetched as Markdown. Where the docs were
silent I ran small probes against the dev AI Gateway key (seven calls, about $0.03 in total) and
read the spans locally. Nothing was sent to Langfuse: there are no Langfuse keys in `secrets/`
yet, so every statement about what the Langfuse UI shows rests on server source, not on a live
project.

Markers: **[Measured]** = seen in a probe on 2026-09-30. **[Unverified]** = not confirmed from a
primary source or a probe. **[Inference]** = my reasoning.

---

## Short answers

| # | Question | Answer |
| --- | --- | --- |
| 1 | What reaches Langfuse through the Gateway? | Model `claude-haiku-4-5-20251001` (the upstream ID, not our dotted string), token usage including cache read/write. No cost attribute. Langfuse does not read `providerMetadata.gateway.cost`. |
| 2 | Least code for the exact charge? | A 10-line span processor with `onEnding` that copies `gateway.cost` into `langfuse.observation.cost_details` on the AI SDK's own model-call span. No double count. |
| 3 | If estimated instead? | Works today with no custom models for our three Anthropic models, and matched the Gateway charge to 8 decimals in every probe, cache writes and reads included. |
| 4 | Cost per user? | Yes. Users view, and a v4 dashboard widget can group by `userId` as a top-N table or bar. Not as a time series, and not through Metrics API v2. |
| 5 | What is official on Vercel? | Node + `NodeSDK`/`NodeTracerProvider` + `LangfuseSpanProcessor` + flush in `after()`/`waitUntil`. Four AI SDK 7 integration bugs were filed and fixed June to August 2026. Supabase Edge stays undocumented, but the SDK ran correctly under local Deno 2.7. |
| 6 | What does a Vercel function need? | Nothing exotic: same two Supabase clients as today, `waitUntil`, region `cle1`. About $0.70 a month of usage for 5,000 turns, inside the $20 Pro credit. |
| 7 | Does Vercel run Deno code? | No official Deno runtime. Porting is mechanical for the handlers, but the repo has 985 `Deno.test` call sites. |
| 8 | Hand-built OTLP? | Yes, about 100 to 150 lines, zero dependencies. Loses automatic media upload and automatic span capture; prompt linking and experiments are still possible by setting attributes. |

**Recommendation, ranked:**

1. **Stay on Supabase Edge, use `@langfuse/otel` with an isolated tracer provider and the cost
   tagger** (section A2). Exact cost, real AI SDK spans, about 40 lines shared plus one
   `experimental_telemetry` line per call site. Proven under local Deno; needs one canary deploy
   on the dev project to prove the deployed Edge runtime.
2. **If the canary fails, hand-built OTLP from `onFinish`** (section B8). Vana already computes
   per-step cost there (`_shared/vana/log.ts`, `gatewayCostUsd`).
3. **Do not move Vana to Vercel for this.** The move does not fix cost (the same tagger is needed
   there), and the port is far more work than either option above.

---

## A. Cost

### A1. What reaches Langfuse for a Gateway call

**What the Gateway returns.** [Measured] `providerMetadata.gateway` on every call, AI SDK 6 and 7:

```json
{
  "routing": { "originalModelId": "anthropic/claude-haiku-4.5", "finalProvider": "claudeaws", "…": "…" },
  "cost": "0.000034", "marketCost": "0.000034", "surchargeCost": "0",
  "gatewayCost": "0.000034", "inferenceCost": "0.000034",
  "inputInferenceCost": "0.000014", "outputInferenceCost": "0.00002",
  "generationId": "gen_01M3S2S246PP4MK023S86ADHS8"
}
```

Vercel documents `cost`, `marketCost` and `generationId`: "The `gateway.cost` value is the
inference cost for this request, returned as a decimal string. It does not include other charges
that may apply (for example, Custom Reporting writes or Zero Data Retention surcharges)."
https://vercel.com/docs/ai-gateway/models-and-providers/provider-filtering-and-ordering
The other cost keys are undocumented; the SDK type says "Additional fields may be added without a
package update" (`packages/gateway/src/gateway-provider-metadata.ts` in `vercel/ai`).

**AI SDK 6 with `experimental_telemetry`** [Measured, `ai@6.0.277` under Deno]. The model-call
span `ai.streamText.doStream` (scope `ai`) carries:

- `ai.model.id` and `gen_ai.request.model` = `anthropic/claude-haiku-4.5`
- `ai.response.model` and `gen_ai.response.model` = **`claude-haiku-4-5-20251001`**
- `gen_ai.usage.input_tokens`, `gen_ai.usage.output_tokens`, `ai.usage.cachedInputTokens`,
  `ai.usage.inputTokenDetails.{noCacheTokens,cacheReadTokens,cacheWriteTokens}`
- `ai.response.providerMetadata` = the full JSON string, `anthropic` and `gateway` blocks both

The outer `ai.streamText` span also carries `ai.model.id`, `ai.usage.*` and
`ai.response.providerMetadata`, but no `gen_ai.*` keys.

**AI SDK 7 with `@langfuse/vercel-ai-sdk` 5.11.1** [Measured, `ai@7.0.123` under Node 22]. The
integration is a thin wrapper around `OpenTelemetry` from `@ai-sdk/otel`, passing only `tracer`
and an `enrichSpan` that adds prompt-link and metadata attributes
(`packages/vercel-ai-sdk/src/LangfuseVercelAiSdkIntegration.ts`, `utils.ts`). The model-call span
`chat anthropic/claude-haiku-4.5` (scope `gen_ai`) carries:

- `gen_ai.request.model` = `anthropic/claude-haiku-4.5`
- `gen_ai.response.model` = **`claude-haiku-4-5-20251001`**
- `gen_ai.usage.input_tokens`, `output_tokens`, `cache_read.input_tokens`,
  `cache_creation.input_tokens`
- **No `ai.response.providerMetadata`.** `@ai-sdk/otel` only emits it when constructed with
  `providerMetadata: true` (`packages/otel/src/supplemental-attributes.ts`), and the Langfuse
  integration's options type is `{ tracer?: Tracer }` only. So in v7 the gateway block never
  reaches the span at all.

**What the Langfuse server does with it**
(`packages/shared/src/server/otel/OtelIngestionProcessor.ts`, main, read 2026-09-30):

- Model = first non-empty of `langfuse.observation.model.name`, `gen_ai.response.model`,
  `ai.model.id`, `gen_ai.request.model`, … So the generation's model is
  `claude-haiku-4-5-20251001`.
- `extractCostDetails` reads exactly three things: `langfuse.observation.cost_details` (JSON),
  `gen_ai.usage.cost`, `llm.cost.total`. Nothing else.
- The `ai.response.providerMetadata` parser reads `openai`, `anthropic` and `bedrock` usage keys.
  There is no `gateway` branch. The only "gateway" in the file is
  `AI_GATEWAY_INSTRUMENTATION_SCOPE_NAME = "langfuse-ai-gateway"`, Langfuse's own gateway.
- No cost attribute means cost is inferred: model definition price × usage.

**Anything new in 2026?** No. The Langfuse changelog index has no Vercel AI Gateway cost entry
(https://langfuse.com/llms-changelog.txt). The cost-tracking page still names only OpenRouter and
LiteLLM as gateways whose cost is captured
(https://langfuse.com/docs/observability/features/token-and-cost-tracking#troubleshooting).
Both the Langfuse page for the Gateway and Vercel's page for Langfuse show only the
OpenAI-compatible endpoint with `observeOpenAI` and say nothing about cost
(https://langfuse.com/integrations/gateways/vercel-ai-gateway ,
https://vercel.com/docs/ai-gateway/ecosystem/framework-integrations/langfuse). GitHub discussion
17567 (2026-09-17) proposes reading gateway-reported cost, for LiteLLM in evaluator and playground
generations only; it confirms "the gap is emission-only", meaning the ingestion side already
accepts a supplied cost. https://github.com/orgs/langfuse/discussions/17567

**Net:** out of the box Langfuse shows an estimated cost, not nothing. The estimate is right for
our models today (A3), but it is not the Gateway's number.

### A2. Getting the exact Gateway charge onto the generation

Server rule that makes this safe: "If user has provided any cost point, do not calculate any
other cost points" (`worker/src/services/IngestionService/index.ts`, `calculateUsageCosts`). A
supplied `cost_details` replaces inference for that observation. It cannot add to it.

| Option | Code | Double count? | Notes |
| --- | --- | --- | --- |
| **a. Span processor with `onEnding`** | ~10 lines, once | No | Works for AI SDK 6 as is. Measured. |
| b. AI SDK 7 subclass of the integration | ~8 lines, once | No | Needed in v7 because the span has no providerMetadata. Measured. |
| c. Own generation from `onFinish` | 30+ lines per call shape | Yes, unless the AI SDK generation is filtered out | What `01-observability.md` §4.5 proposed. No longer needed. |
| d. Post cost afterwards | n/a | n/a | No supported way. Observations are immutable once ingested over OTLP; the legacy `generation-update` event goes away on Cloud on 2026-11-16. [Inference from the v4 notice] |
| e. `gen_ai.usage.cost` instead of `cost_details` | same as a | No | Equivalent. The server maps it to `{ total }`. |

**Option a, the one to use on AI SDK 6** [Measured]. `onEnding` runs while the span is still
writable, after the AI SDK has set its end-of-call attributes. It is in
`@opentelemetry/sdk-trace-base` 2.x, marked `@experimental` ("may break in minor versions"), so pin the OTel
version. `BasicTracerProvider` calls it on every registered processor.

```ts
// _shared/langfuse.ts
import { BasicTracerProvider } from "npm:@opentelemetry/sdk-trace-base@2.11.0";
import { AsyncLocalStorageContextManager } from "npm:@opentelemetry/context-async-hooks@2.11.0";
import { context } from "npm:@opentelemetry/api@1";
import { LangfuseSpanProcessor } from "npm:@langfuse/otel@5.11.1";
import { setLangfuseTracerProvider } from "npm:@langfuse/tracing@5.11.1";

// Copies the Gateway's charge onto the AI SDK's model-call span before it ends.
const gatewayCost = {
  onStart() {}, onEnd() {}, forceFlush: async () => {}, shutdown: async () => {},
  onEnding(span: { name: string; attributes: Record<string, unknown>; setAttribute: Function }) {
    if (!/\.do(Generate|Stream|Embed)$/.test(span.name)) return;   // model-call spans only
    const raw = span.attributes["ai.response.providerMetadata"];
    const cost = typeof raw === "string" ? Number(JSON.parse(raw)?.gateway?.cost) : NaN;
    if (Number.isFinite(cost)) {
      span.setAttribute("langfuse.observation.cost_details", JSON.stringify({ total: cost }));
    }
  },
};

export const langfuse = new LangfuseSpanProcessor({
  publicKey: Deno.env.get("LANGFUSE_PUBLIC_KEY")!, secretKey: Deno.env.get("LANGFUSE_SECRET_KEY")!,
  baseUrl: "https://us.cloud.langfuse.com", environment: "dev", exportMode: "immediate",
});
const provider = new BasicTracerProvider({ spanProcessors: [gatewayCost, langfuse] });
context.setGlobalContextManager(new AsyncLocalStorageContextManager().enable());
setLangfuseTracerProvider(provider);            // isolated: nothing registered globally
export const aiTracer = provider.getTracer("ai"); // scope name must stay "ai"

// at each call site
streamText({ …, experimental_telemetry: { isEnabled: true, functionId: "vana-chat", tracer: aiTracer } });
// after building the response
EdgeRuntime.waitUntil(langfuse.forceFlush());
```

Why the name filter: in v6 the outer `ai.streamText` span also has
`ai.response.providerMetadata`. It maps to a plain span (the server's
`Vercel_AI_SDK_Operation_Generation_Like` mapper lists only the `.doGenerate`, `.doStream` and
`.doEmbed` operations), and tagging it too would count the last step's cost twice.
**[Unverified]** whether embedding spans carry `ai.response.providerMetadata`; if not, embeddings
fall back to the estimate.

A multi-step turn has one `.doStream` span per step, each with its own `gateway.cost`, so the
trace total is the sum of the steps. That is the same sum `_shared/vana/log.ts` already computes
for `vana_calls`, which gives a free cross-check: Langfuse trace cost should equal
`vana_calls.cost_usd`.

**Option b, for AI SDK 7** [Measured]. Inside `onLanguageModelCallEnd` the active span is the
model-call span (`trace.getActiveSpan()?.name` printed `chat anthropic/claude-haiku-4.5`) and the
event has `providerMetadata`. Set the attribute before delegating, because the delegate ends the
span:

```ts
import { trace } from "@opentelemetry/api";
import { LangfuseVercelAiSdkIntegration } from "@langfuse/vercel-ai-sdk";

class WithGatewayCost extends LangfuseVercelAiSdkIntegration {
  onLanguageModelCallEnd(event: Parameters<LangfuseVercelAiSdkIntegration["onLanguageModelCallEnd"]>[0]) {
    const cost = Number((event.providerMetadata as any)?.gateway?.cost);
    if (Number.isFinite(cost)) {
      trace.getActiveSpan()?.setAttribute("langfuse.observation.cost_details", JSON.stringify({ total: cost }));
    }
    super.onLanguageModelCallEnd(event);
  }
}
registerTelemetry(new WithGatewayCost());
```

The exported span then carried `"langfuse.observation.cost_details":"{\"total\":0.000034}"`. The
v7 `invoke_agent` and `agent_step` spans are skipped for model, usage and cost by the server
(`isAiSdkAgentOperation`), so there is no double count there either. That skip exists because of
issue 14754, "AI SDK 7 integration: costs are counted twice" (closed 2026-07).

Optional refinement for either option: send `{ input, output, total }` from
`inputInferenceCost`, `outputInferenceCost` and `cost` to get the input/output split in the UI.
Those two keys are undocumented, so treat them as best-effort and always send `total`.

### A3. If cost is estimated instead

**It already works for our Anthropic models.** The name Langfuse matches on is the upstream ID,
and those match the built-in definitions (`worker/src/constants/default-model-prices.json`, 177
entries):

| We call | Gateway response model [Measured] | Built-in match | Built-in price per 1M (in / out) |
| --- | --- | --- | --- |
| `anthropic/claude-haiku-4.5` | `claude-haiku-4-5-20251001` | `claude-haiku-4-5-20251001` | $1 / $5 |
| `anthropic/claude-sonnet-4.6` | `claude-sonnet-4-6` | `claude-sonnet-4-6` | $3 / $15 |
| `anthropic/claude-sonnet-5` | `claude-sonnet-5` | `claude-sonnet-5` | $2 / $10 |

All three probes were served by `claudeaws` or `anthropic`. The Gateway can also fall back to
`bedrock` and `vertexAnthropic`. A Bedrock-style ID (`anthropic.claude-haiku-4-5-20251001-v1:0`)
matches the built-in pattern; a Vertex-style ID (`claude-haiku-4-5@20251001`) does not.
**[Unverified]** what model ID the Gateway reports on those routes. `openai/text-embedding-3-small`
and `anthropic/claude-haiku-4.5-cheaper` were not probed.

**How close is the estimate?** Vercel: "AI Gateway charges no markup and no platform fee on
tokens. You pay the provider's list price", including BYOK
(https://vercel.com/docs/ai-gateway/pricing). [Measured]:

| Call | Tokens (in / cache write / cache read / out) | `gateway.cost` | List-price arithmetic |
| --- | --- | --- | --- |
| Haiku 4.5 | 14 / 0 / 0 / 4 | 0.000034 | 0.000034 |
| Sonnet 4.6 | 14 / 0 / 0 / 4 | 0.000102 | 0.000102 |
| Sonnet 5 | 16 / 0 / 0 / 4 | 0.000072 | 0.000072 |
| Haiku 4.5, cache write | 13 / 18,909 / 0 / 4 | 0.02366925 | 0.02366925 |
| Haiku 4.5, cache read | 13 / 0 / 18,909 / 4 | 0.0019239 | 0.00192390 |

So the estimate equals the charge when the model matches and the token buckets are right. It will
drift when: Langfuse's price table lags a provider price change (defaults update by daily audit PR
and apply only to new generations); a call routes to a provider priced differently (the Gateway
model page shows "variations across different providers"); the model name stops matching; a
surcharge applies (`surchargeCost`, e.g. team-wide ZDR at $0.10 per 1,000 requests); or a volume
discount is negotiated. The exact-cost tagger has none of these problems, which is the reason to
prefer it even though the estimate is currently perfect.

**Cache token pricing.** Built-in Anthropic definitions price `input`, `output`,
`input_cache_read` (0.1× input), `input_cache_creation` and `input_cache_creation_5m` (1.25×),
`input_cache_creation_1h` (2×), plus alias keys. The server subtracts cached tokens from `input`
so the buckets don't overlap. In v6 it gets the 5m/1h split from
`ai.response.providerMetadata.anthropic.usage.cache_creation`. In v7 it only gets
`gen_ai.usage.cache_creation.input_tokens`, so a 1-hour cache write would be priced at the 5-minute
rate. We don't use 1-hour caching today. **[Inference]**

**Adding a custom model definition** (only needed for a name that doesn't match, e.g. a Vertex ID
or the embedding model):

- UI: Project Settings → Models → add, or the "+" next to the model name on a generation.
- API: `POST /api/public/models` (Basic auth `pk:sk`). Fields from the OpenAPI spec:
  `modelName`, `matchPattern` (regex, e.g. `(?i)^(openai/)?text-embedding-3-small$`), optional
  `startDate`, `unit` (`TOKENS`), and `pricingTiers` (one tier with `isDefault: true`,
  `priority: 0`, `conditions: []`, and a `prices` map keyed by usage type). Flat `inputPrice`,
  `outputPrice`, `totalPrice` are deprecated. `GET`/`DELETE /api/public/models/{id}` manage them.
  https://cloud.langfuse.com/generated/api/openapi.yml
- Custom beats built-in; new or changed definitions affect only generations ingested afterwards.
  https://langfuse.com/docs/observability/features/token-and-cost-tracking#custom-model-definitions

**The Gateway's own reporting, as a cross-check:**

- `GET https://ai-gateway.vercel.sh/v1/generation?id=<generationId>` with the Gateway key.
  [Measured] it returned `total_cost`, `market_cost`, `surcharge_cost`, `gateway_cost`, `model`,
  `provider_name`, `tokens_prompt`, `tokens_completion`, `native_tokens_cached`,
  `native_tokens_cache_creation`, `latency`, `generation_time`. Ingested asynchronously, so retry
  on 404. AI SDK wrapper: `gateway.getGenerationInfo({ id })`.
  https://vercel.com/docs/ai-gateway/observability-and-spend/usage
- `GET /v1/credits`: balance and lifetime spend (same page).
- Custom Reporting: tag requests with `providerOptions.gateway.user` and `.tags` (or headers
  `ai-reporting-user`, `ai-reporting-tags`), then `gateway.getSpendReport({ startDate, endDate,
  groupBy: 'model' | 'user' | 'tag' | … })`. Paid add-on: $0.075 per 1,000 tag or user writes,
  $5 per 1,000 report queries.
  https://vercel.com/docs/ai-gateway/observability-and-spend/custom-reporting
- Dashboard: AI Gateway tab has Spend, Requests by Model, per-project and per-key summaries, and
  a Logs page with per-request cost, CSV/JSON export, 36 days of look-back. The Logs list has no
  public API. https://vercel.com/docs/ai-gateway/observability-and-spend/logs
- Trace Drains (Pro): the Gateway pushes an OTLP/HTTP trace per request to any endpoint, with
  `vercel.ai_gateway.cost.total`. Not useful for Langfuse: that attribute isn't one of the three
  Langfuse reads, the traces contain no prompt or completion, and they'd be separate traces from
  ours. $0.05 per 1,000 traces plus $0.50 per GB.
  https://vercel.com/docs/ai-gateway/observability-and-spend/trace-drains

Put `generationId` on the span as `langfuse.observation.metadata.gatewayGenerationId` and any
Langfuse generation can be looked up in the Gateway in one call. **[Inference]**

### A4. Cost per user

- **Users view**: list of users with token usage, trace count and feedback; a detail page per user
  with aggregates and their traces. Needs `userId` on the observations (`propagateAttributes`).
  https://langfuse.com/docs/observability/features/users
- **Dashboards**: the custom-dashboards page lists "Cost per User" as a use case and "Group by
  user, model, time, trace name". The v4 FAQ is specific: a query that groups by `userId` or
  `sessionId` "must specify a row limit and sort order (e.g., 'top 20 users by cost,
  descending'). Time-series charts cannot use high-cardinality dimensions at all." `id`,
  `traceId` and `parentObservationId` are not dimensions in the widget builder. The built-in
  "User consumption" tile already does top-N.
  https://langfuse.com/faq/all/dashboard-changes-in-v4 (section 10),
  https://langfuse.com/docs/metrics/features/custom-dashboards
- **Metrics API v2** cannot group by `userId` (filter only), per `01-observability.md` §4.6.
  For a full per-user table outside the UI, use the Observations API v2 and aggregate, or the
  Gateway's `getSpendReport({ groupBy: 'user' })`.

This closes open question 4 in `01-observability.md` §9: yes, as a top-N table or bar; no, not as
a per-user line over time.

---

## B. Hosting Vana on Vercel

### B5. What is official on Vercel, and what is not on Supabase Edge

**Documented for Vercel / Node** (https://langfuse.com/integrations/frameworks/vercel-ai-sdk):

- AI SDK 7: `NodeSDK({ spanProcessors: [new LangfuseSpanProcessor()] })` +
  `registerTelemetry(new LangfuseVercelAiSdkIntegration())` in `instrumentation.ts`; telemetry is
  then on for every call. Node >= 22 (package `engines`). Peer `ai >=7.0.0 <8`.
- Trace attributes through `propagateAttributes`; prompt link through
  `runtimeContext.langfusePrompt` + `telemetry.includeRuntimeContext`.
- Streaming and flushing are documented only in the AI SDK v6 Next.js section:
  `observe(handler, { endOnExit: false })`, end the root span in `onFinish`/`onError`, and
  `after(async () => await langfuseSpanProcessor.forceFlush())`. The serverless FAQ adds: flush
  before exit, or use `waitUntil`, or flush per event.
  https://langfuse.com/faq/all/aws-lambda-and-serverless-functions
- Vercel side: `waitUntil` from `@vercel/functions` works in Node and Edge runtimes and shares the
  function's `maxDuration`; Next.js 15.1+ should use `after()`.
  https://vercel.com/docs/functions/functions-api-reference/vercel-functions-package
- Nothing in Langfuse's docs mentions Fluid Compute by name. With Fluid, one instance serves many
  requests at once, so `exportMode: "immediate"` or a per-request flush matters more, not less.
  **[Inference]**

**Known issues on the documented path in 2026** (GitHub, `langfuse/langfuse` unless noted):

| Issue | Date | State | What |
| --- | --- | --- | --- |
| 14633 | 2026-06-29 | closed | AI SDK 7 generation output and tool I/O were null |
| 14754 | 2026-07-03 | closed | AI SDK 7 costs counted twice |
| 15952 | 2026-08-10 | closed | AI SDK 7 messages rendered as raw JSON |
| 16409 | 2026-08-21 | closed | AI SDK embedding spans costed twice |
| 15000 | 2026-07-10 | open | Classic observations table shows blank I/O for `{ role, parts }` messages |
| langfuse-js 878 | 2026-07-17 | open | `@langfuse/tracing` spans are non-recording in Next.js 16 App Router route handlers |
| langfuse-js 898 | 2026-07-31 | open | Update the integration to `@ai-sdk/otel@1.0.44` |

The v7 integration shipped on 2026-06-26 (langfuse-js v5.8.0). It is three months old and has
needed four server or SDK fixes. "Works as documented" is true now, but it is the newer, less
settled path; the v6 `experimental_telemetry` mapping is the older one.

**Supabase Edge / Deno: every known risk, and what the probe showed.** Probe: `probe_lf.ts`,
local Deno 2.7.11, `ai@6.0.277`, `@langfuse/otel@5.11.1`, `@opentelemetry/sdk-trace-base@2.11.0`,
exporter pointed at a local HTTP server standing in for Langfuse.

| Risk | Status |
| --- | --- |
| SDK won't load (`engines.node >=20`, npm specifiers) | [Measured] loads and runs under Deno 2.7. **[Unverified]** on the deployed Edge runtime, whose Deno version I did not confirm. |
| Context manager: no nesting or attribute propagation without AsyncLocalStorage | [Measured] `AsyncLocalStorageContextManager` works; `userId`/`sessionId` from `propagateAttributes` reached the AI SDK spans, which were children of the root observation. |
| Exporter transport | [Measured] three POSTs to `/api/public/otel/v1/traces`, `content-type: application/json`, Basic auth, `x-langfuse-*` headers. Plain `fetch`. |
| Env config: SDK reads `process.env`, not `Deno.env` | Pass keys to the constructor, as in the sketch. |
| Flush before the isolate dies | `EdgeRuntime.waitUntil(langfuse.forceFlush())`. Vana already persists from `onFinish` under `waitUntil`, so the pattern is in production. Local `supabase functions serve` kills instances after the response, so the flush can't be tested locally. https://supabase.com/docs/guides/functions/background-tasks **[Unverified]** end to end. |
| Sentry claiming the global tracer provider | Not a problem today: `_shared/sentry.ts` pins `@sentry/deno@8.53.0`, whose `sdk.ts` has no OpenTelemetry setup. Current `@sentry/deno` calls `setupOpenTelemetryTracer()` by default (`enableOpenTelemetrySetup ?? true`), so a Sentry upgrade would start claiming it. The sketch registers nothing globally and passes `tracer` explicitly, which is Langfuse's "isolated TracerProvider" option, so it is unaffected either way. https://langfuse.com/faq/all/existing-sentry-setup |
| CPU limit 2 s per request, memory 256 MB | OTel import cost at cold start and JSON-serialising large prompts count against these. https://supabase.com/docs/guides/functions/limits **[Unverified]**; measure in the canary. |
| Media: meal photos as base64 in `ai.prompt.messages` | `forceFlush()` awaits media uploads (source, per `01-observability.md` §2.6). Not probed. **[Unverified]**; text-only Vana chat is not affected, `analyze-meal-photo` is. |
| `onEnding` is experimental | Pin `@opentelemetry/sdk-trace-base`. If it is removed, mutate `span.attributes` in `onEnd` of a wrapper processor before delegating. **[Inference]** |
| Anyone reported it working? | No. Discussion 6150 (2025-03-21) is still the only thread: one upvote, one maintainer reply ("skip exporting via `langfuse-vercel` and … directly use the langfuse otel endpoint"), unanswered since. No newer issue, discussion or blog post from Supabase or Langfuse turned up in GitHub search on either repo. That thread predates JS SDK v4/v5; the package it failed with (`langfuse-vercel`) no longer exists. https://github.com/orgs/langfuse/discussions/6150 |

The main unknown is therefore narrow: does the same code behave on Supabase's deployed runtime.
One canary function on the dev project answers it.

### B6. What a Vercel-hosted Vana would need

- **Auth.** Today `_shared/vana/auth.ts` does `admin.auth.getUser(token)` with a service-role
  client, then builds an anon-key client with `global.headers.Authorization = Bearer <token>` so
  RLS applies. Both are plain supabase-js over HTTPS and run unchanged on Node. Cheaper
  alternative: verify locally with `supabase.auth.getClaims()` or `jose` against
  `https://<ref>.supabase.co/auth/v1/.well-known/jwks.json`, which only works once the project
  uses asymmetric signing keys. https://supabase.com/docs/guides/auth/jwts ,
  https://supabase.com/docs/guides/auth/signing-keys . `@supabase/server` (`withSupabase`, npm 1.9.0, `engines.node >=22`) wraps this; **[Unverified]** on Vercel.
  What is lost: Supabase's platform-level `verify_jwt` gate in front of the function.
- **Flutter.** `supabase.functions.invoke` targets the Supabase functions URL. A Vercel function
  needs a plain HTTP call with the session's access token and a new base URL per flavor. CORS
  headers only matter for the web build.
- **Streaming NDJSON.** Node runtime streams by default; return a `Response` with a
  `ReadableStream`. https://vercel.com/docs/functions/streaming-functions
- **Background work.** `waitUntil(promise)` from `@vercel/functions`; same timeout as the
  function.
- **Duration.** Pro: 300 s default, 800 s max (1,800 s beta). Supabase paid: 400 s wall clock,
  150 s to first byte. https://vercel.com/docs/functions/limitations ,
  https://supabase.com/docs/guides/functions/limits
- **Request body limit 4.5 MB** on Vercel Functions (413 above it). Matters for anything that
  posts a photo as base64. https://vercel.com/docs/functions/limitations
- **Region.** Both Supabase projects are in AWS `us-east-2` (Ohio; read from the Management API
  today). Vercel defaults to `iad1` (Washington DC); the matching region is `cle1` (Cleveland).
  Set `"regions": ["cle1"]` in `vercel.json`. Same price as `iad1`.
  https://vercel.com/docs/functions/configuring-functions/region
- **Cold starts.** Fluid Compute reuses instances across concurrent requests, caches bytecode
  (Node 20+, production only) and pre-warms production deployments. Vercel publishes no numbers.
  https://vercel.com/docs/fluid-compute **[Unverified]** actual cold-start time for this bundle.
- **Gateway auth.** On Vercel the Gateway can authenticate with the deployment's OIDC token
  instead of an API key. Note the Gateway budgets set on 2026-09-21 are per API key.

**Price.** Pro is $20 a month platform fee, one deploying seat, and $20 of monthly usage credit;
extra seats $20. Fluid Compute in `cle1`/`iad1`: Active CPU $0.128 per hour, Provisioned Memory
$0.0106 per GB-hour, invocations $0.60 per million. CPU is billed only while code runs; memory is
billed for the instance's lifetime while any request is in flight; default size is 2 GB / 1 vCPU.
https://vercel.com/docs/plans/pro-plan , https://vercel.com/docs/functions/usage-and-pricing

Estimate for 5,000 turns a month at 20 s wall clock **[Inference]**:

| Meter | Arithmetic | Monthly |
| --- | --- | --- |
| Memory | 5,000 × 20 s = 27.8 h × 2 GB × $0.0106 (no instance sharing, worst case) | $0.59 |
| Active CPU | 0.3 to 1 s per turn = 0.4 to 1.4 h × $0.128 | $0.05 to $0.18 |
| Invocations | 5,000 × $0.60 / 1M | $0.003 |
| **Usage total** | | **about $0.65 to $0.80**, covered by the $20 credit |

So the real cost is the $20 platform fee, not the compute. Supabase Edge Functions for comparison:
$2 per million invocations above the plan quota. https://supabase.com/docs/guides/functions/pricing

### B7. Does Vercel run Deno-style code?

No. Official runtimes are Node.js, Bun, Edge, Python, Go, Ruby, Rust, Wasm. Deno exists only as a
community runtime (`vercel-deno`, npm 3.2.0, last repo push 2026-03-04), outside Fluid Compute's
supported list. https://vercel.com/docs/functions/runtimes . Using it would put Vana back on an
unofficial path, which defeats the point of moving.

What a port to Node touches, from a grep of `supabase/functions`:

| Deno-ism | Count | Node equivalent |
| --- | --- | --- |
| `Deno.env.get` | 138 | `process.env.X` |
| `serve()` from `deno.land/std/http` / `Deno.serve` | 37 / 8 | `export default { fetch(request) { … } }` or `export function POST` |
| `EdgeRuntime.waitUntil` | 13 | `waitUntil` from `@vercel/functions` |
| `npm:ai`, `npm:zod` specifiers | 26 | bare imports + `package.json` |
| `https://esm.sh/@supabase/supabase-js` | 35 | `@supabase/supabase-js` |
| `https://esm.sh/@sentry/deno` | 2 | `@sentry/node` (then the Sentry/OTel conflict becomes real) |
| `Deno.readTextFile*` | 23 | `node:fs` |
| relative imports ending `.ts` | everywhere | fine with a bundler or `allowImportingTsExtensions` |
| **`Deno.test`** | **985** | rewrite for Vitest, or keep running the shared modules' tests under Deno |

Beyond the mechanical changes: a second deploy pipeline and secret store, the dev/prod split
recreated as Vercel projects or environments, the deploy playbook and `app_config` ordering
rewritten for two backends, the Flutter call sites and their tests, and `_shared/vana/*` (about 40
files) either duplicated or shared across two runtimes. `vana-eval` is already moving to
`../mealvana_eval` on Vercel, so the evals side gets the official path without moving production
chat.

### B8. Middle path: hand-built OTLP JSON by `fetch`

Supported and documented: `POST https://us.cloud.langfuse.com/api/public/otel/v1/traces`,
`Content-Type: application/json`, `Authorization: Basic base64(pk:sk)`, and
`x-langfuse-ingestion-version: 4` (without that header, directly ingested spans can lag up to 10
minutes). HTTP/JSON and HTTP/protobuf both accepted; no gRPC.
https://langfuse.com/integrations/native/opentelemetry

This is what the Langfuse maintainer suggested in discussion 6150, and it is how the SDK's own
exporter talked to the endpoint in the probe.

**Size.** About 100 to 150 lines for one module: random trace and span IDs (hex), nanosecond
timestamps as strings, an attribute encoder, one root span per turn, one `generation` span per AI
SDK step built from `steps` in `onFinish`, optional tool spans, and one `fetch` under
`EdgeRuntime.waitUntil`. Zero dependencies, no context manager, no OTel version pinning, nothing
global. **[Inference]**

Attributes to set (all documented on the page above):

- trace: `langfuse.trace.name`, `user.id`, `session.id`, `langfuse.trace.tags`,
  `langfuse.environment`
- generation: `langfuse.observation.type = "generation"`, `langfuse.observation.model.name`,
  `langfuse.observation.input` / `.output` (JSON strings),
  `langfuse.observation.usage_details` (JSON; subtract cached tokens from `input` yourself),
  `langfuse.observation.cost_details = {"total": <gateway.cost>}`,
  `langfuse.observation.completion_start_time`, `langfuse.observation.metadata.*`

**What is lost against the SDK:**

| Feature | Hand-built |
| --- | --- |
| Exact cost | Kept. Easier, in fact: `gatewayCostUsd` already exists. |
| Prompt linking | Kept. Set `langfuse.observation.prompt.name` and `.version` on the generation. Fetching prompts is separate (`@langfuse/client` or REST). |
| Experiments | Possible by setting the experiment attributes by hand (https://langfuse.com/integrations/native/opentelemetry/experiments); the SDK's experiment runner is not available. |
| Media (meal photos) | Lost unless built: extract base64, `POST /api/public/media`, `PUT` to the presigned URL, reference the media ID. Langfuse warns against sending large base64 inline. https://langfuse.com/docs/observability/features/multi-modality |
| Automatic spans | Lost. Steps, tool calls and timings must be reconstructed from `steps`; per-tool durations are not in `steps` unless we record them. |
| Usage normalisation | Ours to get right (bucket exclusivity, `01-observability.md` §4.2). |
| Masking, sampling, span filter | Ours to write if wanted. |
| Future AI SDK changes | Insulated: no dependency on telemetry attribute names. |

---

## Ranked recommendation

1. **Supabase Edge + `@langfuse/otel` + the `onEnding` cost tagger, on AI SDK 6.** Least code
   that gives exact Gateway cost and real traces. Everything except the deployed runtime is
   measured. Canary: deploy one dev function with the A2 module, make one call, and check in
   Langfuse that (a) the trace arrives after `waitUntil`, (b) the generation's cost is marked as
   ingested and equals `vana_calls.cost_usd`, (c) cold-start time and CPU stay inside limits.
2. **Hand-built OTLP from `onFinish`** if the canary fails or the OTel packages prove too heavy.
   Same exact cost, no runtime risk, fewer features.
3. **Vercel move: not for this.** It costs $20 a month and a large port, the v7 integration still
   needs the subclass in A2 to show exact cost, and the v7 path has had more bugs this summer than
   the v6 one. Revisit only if Vana should move for other reasons. `../mealvana_eval` is already
   on Vercel with `ai@7` and should use option b there.

Whichever path: leave the estimate on as the fallback (no custom model needed for the three
Anthropic models), and store `gateway.generationId` in observation metadata so any number can be
checked against `GET /v1/generation`.

## Corrections to `01-observability.md`

- **§0 item 3 and §4.4**: "those return no match, so no inferred cost" is wrong in practice. The
  model Langfuse sees is `gen_ai.response.model`, which the Gateway fills with the upstream ID
  (`claude-haiku-4-5-20251001`, `claude-sonnet-4-6`, `claude-sonnet-5`). All three match built-in
  prices. The §4.4 caveat guessed this; it is now measured.
- **§4.5 option 2**: "AI SDK spans are already ended and exported by then, so you'd emit your own
  generation" is superseded. `onEnding` (v6) or an `onLanguageModelCallEnd` override (v7) sets the
  cost on the AI SDK's own span before it ends.
- **§9 questions 2 and 4** are answered above (A1, A4). Questions 1 and 3 remain for the canary.

## Still unverified

- The A2 module on the **deployed** Supabase Edge runtime (flush under `waitUntil`, cold start,
  CPU and memory).
- How the Langfuse UI renders an ingested `{ total }` cost with inferred usage. Source says
  ingested cost wins and nothing else is computed; not seen in a live project.
- Model ID reported when the Gateway routes to Bedrock or Vertex.
- Whether embedding spans carry `ai.response.providerMetadata`, and the response model for
  `openai/text-embedding-3-small` and `anthropic/claude-haiku-4.5-cheaper`.
- Base64 meal photos through `@langfuse/otel` under Deno.
- Vercel cold-start time for a Vana-sized bundle; `@supabase/server` on Vercel.
