# Vercel's AI assistant stack: what it offers and what it costs (Sept 2026)

Researched 2026-09-28 from primary sources only: vercel.com docs, pricing and changelog, ai-sdk.dev,
eve.dev, the npm registry, and GitHub `vercel/ai`. Each claim has a source URL. Claims marked
**[inference]** are my reading and are not stated on any page. Claims marked **[unverified]** could not be
confirmed.

## 0. Where Vana stands today (repo facts)

- Vana already runs on **AI SDK 6** (`npm:ai@6.0.277`) inside Supabase Deno edge functions. It
  routes model calls through **AI Gateway** using `AI_GATEWAY_API_KEY`
  (`supabase/functions/_shared/vana/chat.ts`, `vana-chat/index.ts:43`).
- It uses the models `anthropic/claude-haiku-4.5` and `anthropic/claude-sonnet-4.6`, plus
  `openai/text-embedding-3-small` (`supabase/functions/_shared/vana/env.ts` and siblings).
- So we already rely on two of the Vercel pieces below. The open question covers the rest: SDK 7,
  Workflow, eve, and Vercel hosting.

## 1. AI SDK 7

**Maturity: GA.** Announced 2026-06-25 (https://vercel.com/changelog/ai-sdk-7). The latest npm
version is `ai@7.0.118`, published 2026-09-27. The 6.x line is still being patched: `ai@6.0.293`
shipped the same day (https://github.com/vercel/ai/releases, https://registry.npmjs.org/ai/latest).

**Breaking requirements:** Node.js 22 or later, tested on 22, 24 and 26, and ESM only (`require()`
removed) (https://ai-sdk.dev/docs/migration-guides/migration-guide-7-0). The npm package declares
`engines: {node: ">=22"}` and `type: module` (https://registry.npmjs.org/ai/latest). v7 also renames
many APIs: `system` to `instructions`, `onFinish` to `onEnd`, `fullStream` to `stream`,
`experimental_telemetry` to `telemetry`, `stepCountIs` to `isStepCount`, and the context object
splits into `runtimeContext`/`toolsContext`. Codemods are provided
(https://ai-sdk.dev/docs/migration-guides/migration-guide-7-0).

**Runs outside Vercel / in Deno:** the docs list AI SDK Core as working in "Any JS environment
(e.g. Node.js, Deno, Browser)" (https://ai-sdk.dev/docs/getting-started/navigating-the-library).
The `vercel/ai` repo has no Deno example: its `examples/` folder has express, fastify, hono, nest,
node-http-server and Next variants (https://github.com/vercel/ai/tree/main/examples).
**[unverified]** Whether v7's Node-22 requirements (`AsyncLocalStorage` semantics, native fetch; see
https://vercel.com/changelog/ai-sdk-7) all hold under Supabase's Deno edge runtime. v6 works there
today, as shown in §0. A spike is needed before upgrading.

**Agents / tool loops:** `ToolLoopAgent` (in-memory loop) in the `ai` package
(https://ai-sdk.dev/docs/agents). Tool approvals, timeouts and `prepareStep` are covered in the v7
changelog (https://vercel.com/changelog/ai-sdk-7).

**Structured output:** `generateText`/`streamText` with an output spec (the deprecated
`experimental_output` is removed in v7)
(https://ai-sdk.dev/docs/ai-sdk-core/generating-structured-data,
https://ai-sdk.dev/docs/migration-guides/migration-guide-7-0).

**Streaming protocols, and whether Flutter can consume them:** there are two documented wire
protocols. The text stream carries plain text only. The UI message ("data") stream uses **Server-Sent
Events carrying JSON objects**, and a custom backend must set the `x-vercel-ai-ui-message-stream: v1`
header. The page says it exists so you can "develop custom backends and frontends", with a Python
FastAPI backend as its example (https://ai-sdk.dev/docs/ai-sdk-ui/stream-protocol). Official UI
clients exist only for React, Vue and Svelte
(https://ai-sdk.dev/docs/getting-started/navigating-the-library). **[inference]** A Flutter client
can consume the SSE protocol by hand; we already do this today. **[unverified]** No official or
Vercel-endorsed Dart client was found.

**Memory / context management:** there is no built-in long-term store. The Memory page offers three
routes: provider-defined tools (the Anthropic memory tool, where you implement storage), memory
providers (Letta, Mem0, Supermemory, Hindsight, MongoDB), or a custom tool
(https://ai-sdk.dev/docs/agents/memory). For context: `pruneMessages`, a "Compact Agent Context"
cookbook guide, and message-persistence and resume-stream guides (https://ai-sdk.dev/sitemap.md).

**MCP:** `createMCPClient`. HTTP transport is recommended for production and stdio is for local use
only. MCP Apps is supported (https://ai-sdk.dev/docs/ai-sdk-core/mcp-tools).

**Telemetry:** OpenTelemetry moved to the `@ai-sdk/otel` package and is enabled by default once an
integration is registered (https://ai-sdk.dev/docs/ai-sdk-core/telemetry,
https://ai-sdk.dev/docs/migration-guides/migration-guide-7-0).

**Pricing:** free, open source (https://github.com/vercel/ai).

## 2. AI Gateway

**Maturity: GA** since 2025-08-21 (https://vercel.com/changelog/ai-gateway-is-now-generally-available).

**Runs outside Vercel:** yes. "An AI Gateway API key authenticates requests from any environment…
nothing about AI Gateway requires deploying to Vercel" (https://vercel.com/docs/ai-gateway/faq).
It exposes AI SDK, OpenAI Chat Completions, OpenAI Responses and Anthropic Messages-compatible APIs
(https://vercel.com/docs/ai-gateway/faq).

**Markup:** "no markup and no platform fee on tokens"; you pay provider list price from prepaid
credits, plus any payment-processing fees (https://vercel.com/docs/ai-gateway/pricing). Prompt-cache
hits bill at the provider's cache-read rate (https://vercel.com/docs/ai-gateway/faq). Current rates
for our models (https://ai-gateway.vercel.sh/v1/models):
- `claude-haiku-4.5`: $1/M input, $5/M output, $0.10/M cache read, $1.25/M cache write.
- `claude-sonnet-4.6`: $3/M input, $15/M output, $0.30/M cache read.
- `text-embedding-3-small`: $0.02/M.
- The US/EU regional endpoints cost 10% more.

**Free tier:** a monthly free credit on a subset of models, with lower rate limits. Buying credits
moves the team to the paid tier and ends the free credit (https://vercel.com/docs/ai-gateway/pricing).
**[unverified]** The dollar amount of the free credit is not stated on the docs pages I read.

**BYOK:** available on the paid tier with no fee. If a BYOK request fails, the Gateway retries it on
system credentials, billed to your credits (https://vercel.com/docs/ai-gateway/pricing). BYOK spend
is excluded from budgets
(https://vercel.com/docs/ai-gateway/observability-and-spend/budgets).

**Budgets / spend limits:** team, project (OIDC only), API key, and **user** scopes, with
daily/weekly/monthly/none resets. An exceeded budget returns HTTP 402 `quota_for_entity_exceeded`.
Budgets are a soft cap: the request that crosses the limit still completes
(https://vercel.com/docs/ai-gateway/observability-and-spend/budgets). **Important:** "user" means a
*Vercel team member*, not an end user of our app. The budget covers keys attributed to that member,
and the feature targets things like coding agents
(https://vercel.com/changelog/set-per-user-budgets-on-ai-gateway). **There are no per-end-user
spend caps.** Our monthly $4 per-user AI cost budget stays in our own code. Per-end-user *reporting*
exists through Custom Reporting (`user` field / `ai-reporting-user` header), which is an add-on at
$0.075 per 1,000 tag/user writes and $5 per 1,000 report queries
(https://vercel.com/docs/ai-gateway/pricing,
https://vercel.com/docs/ai-gateway/observability-and-spend/custom-reporting).

**Fallbacks:** a `providerOptions.gateway.models` array tries backup models in order; provider
ordering and filtering and custom provider timeouts are also available
(https://vercel.com/docs/ai-gateway/models-and-providers/model-fallbacks,
https://vercel.com/changelog/provider-level-custom-timeouts-for-faster-fail-over-on-ai-gateway).

**Caching:** `caching: 'auto'` inserts Anthropic `cache_control` breakpoints on the last message and
on the one before the last user message. Without it, Anthropic requests pass through uncached. The
default TTL is 5 minutes, and 1 hour is available through `cache_ttl` on the Responses API
(https://vercel.com/docs/ai-gateway/models-and-providers/automatic-caching). This is prompt caching,
not a response cache.

**Observability:** a dashboard showing requests by model, TTFT, token counts, spend, and per-project
and per-key request logs. Longer retention requires Observability Plus
(https://vercel.com/docs/ai-gateway/observability-and-spend/observability). Trace Drains (Pro)
forward OTel traces at $0.05 per 1,000 traces plus $0.50/GB, with no included allowance
(https://vercel.com/docs/ai-gateway/pricing).

**Other add-ons:** team-wide ZDR costs $0.10 per 1,000 requests (per-request ZDR is free on Pro).
A team-wide provider allowlist costs $0.10 per 1,000 requests (https://vercel.com/docs/ai-gateway/pricing).

## 3. eve (durable-agent framework)

**Maturity: public beta**, "subject to the Vercel beta terms… may change before general
availability" (https://vercel.com/docs/eve). It is Apache-2.0 (https://eve.dev/llms.txt), announced
2026-06-17 (https://vercel.com/changelog/introducing-eve-an-open-source-agent-framework). The latest
version is `0.67.2`, with frequent breaking changes: v0.67.0 removed conversation/task modes and
`outputSchema` from `defineAgent` (https://eve.dev/changelog.md,
https://registry.npmjs.org/eve). It requires Node.js 24 or later
(https://eve.dev/docs/getting-started.md).

**Model:** agents are defined as files (`agent/instructions.md`, `agent/agent.ts`, `agent/tools/*`,
`agent/memory/*`, `agent/schedules/*`) (https://vercel.com/docs/eve). A string model ID routes
through AI Gateway, and a provider package can be used instead
(https://eve.dev/docs/guides/deployment/overview.md).

**Sessions:** each session is one durable workflow built on the Workflow SDK. Turns checkpoint at
steps and survive restarts and redeploys
(https://eve.dev/docs/concepts/execution-model-and-durability.md). Sessions last 30 days by default,
configurable through `limits.sessionTimeoutMs`
(https://eve.dev/docs/concepts/sessions-runs-and-streaming.md).

**Memory:** built in since 2026-09-09. Memory lives in named slots with a scope (for example
`byPrincipal`, meaning per authenticated caller) and a provider. Providers: built-in file memory (one
bounded document per scope, model-driven `save_memory`/`remove_memory`, stored in Vercel Blob when
deployed), Supermemory, Upstash AgentKit, Kybernesis Arcana, or a custom provider. eve runs recall
before each turn and capture after it (https://eve.dev/docs/memory.md,
https://vercel.com/changelog/persistent-memory-for-eve-agents).

**Subagents:** a built-in `agent` tool (copies of the root agent), declared specialist subagents, and
remote eve agents (https://eve.dev/docs/subagents.md).

**Evals:** `evals/*.eval.ts` files with `defineEval` and a `t` driver. They offer deterministic
assertions (`calledTool`, `includes`, …), LLM-as-judge via `t.judge()` (default judge
`typesafe-ai/jev`), gate vs soft thresholds, `mockModel` fixtures, and Braintrust/JUnit reporters.
Run them with `eve eval [--url <deployment>] [--strict]` (https://eve.dev/docs/evals/overview.md).

**Schedules:** `agent/schedules/*.ts` with `cron` plus a markdown prompt or a handler. They run on
Vercel Cron when deployed (https://eve.dev/docs/schedules.md,
https://eve.dev/docs/guides/deployment/vercel.md).

**Channels:** a base HTTP channel plus Slack, Discord, iMessage and any Chat SDK adapter, or a custom
channel (https://eve.dev/docs/channels/overview.md, https://vercel.com/changelog/imessage-support-for-eve-agents,
https://vercel.com/changelog/eve-chat-sdk-channel).

**Frontend clients:** `useEveAgent` for React/Vue/Svelte, and a TypeScript `Client` in `eve/client`
(https://eve.dev/docs/guides/frontend/overview.md, https://eve.dev/docs/guides/client/overview.md).
There is no Dart client. The wire protocol is documented: `POST /eve/v1/session` returns a
`sessionId`, and `GET /eve/v1/session/:id/stream` returns **NDJSON** events (`message.appended`,
`actions.requested`, `input.requested`, …) with reconnect support
(https://eve.dev/docs/concepts/sessions-runs-and-streaming.md). **[inference]** Flutter could speak
this protocol by hand.

**Auth:** fails closed in production. It accepts custom `AuthFn`s, `jwtHmac`, `jwtEcdsa` and generic
`oidc` verifiers (https://eve.dev/docs/guides/auth-and-route-protection.md). **[inference]** This
means Supabase-issued JWTs could be verified. Not tested.

**Hosting:** either Vercel (Functions + Workflows + Sandbox + Cron) or self-hosted as a Nitro Node
server. Self-hosting needs a persistent `.eve/.workflow-data` volume or a custom Workflow "world",
and a proxy that forwards both `/eve/` and `/.well-known/workflow/`
(https://eve.dev/docs/guides/deployment/overview.md,
https://eve.dev/docs/guides/deployment/self-hosting.md). **[inference]** It cannot run inside a
Supabase edge function: it needs a long-lived Node 24 server plus workflow callbacks.

**Billing:** eve has no fee of its own. It is billed through Functions, Workflows, Sandbox (if used),
AI Gateway/model tokens, and Always-on Tracing for Agent Runs (https://vercel.com/docs/eve/pricing).

## 4. Workflow / WorkflowAgent

**What:** `'use workflow'`/`'use step'` directives make durable code that retries steps, waits on
external events, and resumes across crashes and deploys. On Vercel it runs on Functions + Queues +
managed persistence (https://vercel.com/docs/workflows). `WorkflowAgent` (`@ai-sdk/workflow`) is the
`ToolLoopAgent` loop running inside a workflow. Each tool call is a durable step with automatic
retries, tool approvals (`needsApproval`) survive suspension, and `stream()` is the primary API with
no `generate()`. `WorkflowChatTransport` reconnects interrupted streams
(https://ai-sdk.dev/docs/agents/workflow-agent).

**Maturity:** **Workflow 5 is beta.** `@ai-sdk/workflow` "requires Workflow 5, which is currently
available under the `beta` tag" (https://ai-sdk.dev/docs/agents/workflow-agent). On npm, `workflow`
is at latest `4.8.9` and beta `5.0.0-beta.57` (https://registry.npmjs.org/workflow). eve bundles the
5.0.0-beta line (https://eve.dev/changelog.md). **[unverified]** I found no changelog entry declaring
the Vercel Workflows product GA. The last maturity note is "Workflow 4.1 Beta"
(https://vercel.com/changelog/workflow-event-sourcing).

**Outside Vercel:** yes, through pluggable "Worlds": Local, Postgres, Vercel, or custom
(https://workflow-sdk.dev/llms.txt). **[unverified]** Whether it runs in Deno or Supabase edge
functions. I found no documentation saying so.

**Pricing (https://vercel.com/docs/workflows/pricing):**
- Events: $0.02 per 1K (Hobby includes 50K). A normal step writes 3 events.
- Data written: $0.50/GB (Hobby includes 1 GB).
- Data retained: $0.50/GB-month (not available on Hobby).
- Retention after run completion: Hobby 1 day, Pro 7 days, Enterprise 30 days.
- Functions and Queues used by workflows bill at their normal rates.
- Limits: 25,000 events per run, 10,000 steps per run, 240 s max replay, no max run duration.

## 5. Evals (Vercel-native)

- **eve evals:** see §3. The most complete option, but it only exercises eve agents
  (https://eve.dev/docs/evals/overview.md).
- **AI SDK `experimental_evaluate`:** named choice/score/boolean questions graded by an evaluation
  model. It is experimental and "may change in patch releases"
  (https://ai-sdk.dev/docs/ai-sdk-core/evaluation). It is a grading primitive, not a test runner.
- **AI Gateway evaluation modality and evaluation fallbacks** (confidence-based reruns)
  (https://vercel.com/docs/ai-gateway/models-and-providers/model-fallbacks).
- **Agent Runs:** a beta observability tab for eve sessions and traces. It must be enabled for the
  team ("contact your Vercel representative if it does not appear"), is billed at Always-on Tracing
  rates, and keeps 30 days of retention during beta (https://eve.dev/docs/observability/agent-runs.md).
  Always-on Tracing costs $0.50 per 1M span units on Pro (1M included on Hobby), where 1 unit covers
  up to 2 KB (https://vercel.com/docs/tracing/always-on-tracing).

## 6. Memory (built-in long-term / user memory)

- **eve:** yes, first-class per-user slots (see §3). The built-in provider stores to Vercel Blob
  (https://eve.dev/docs/memory.md).
- **AI SDK alone:** no built-in store. It integrates third-party providers or you write a tool
  (https://ai-sdk.dev/docs/agents/memory).
- **[unverified]** I found no standalone Vercel "memory" product outside eve.

## 7. Platform pricing relevant to an agent backend

**Functions (Fluid compute)** (https://vercel.com/docs/functions/usage-and-pricing):
- Active CPU costs $0.128/hr (iad1/pdx1/cle1) and is billed only while code runs, not during I/O.
- Provisioned memory costs $0.0106/GB-hr and bills for the whole instance lifetime, including while
  waiting on the model.
- Invocations cost $0.60 per 1M.
- Hobby includes 4 CPU-hrs, 360 GB-hrs and 1M invocations.

**Max duration:** 300 s default. Pro allows up to 800 s, or 1800 s extended in beta
(https://vercel.com/docs/functions/limitations).

**Edge runtime:** "Edge Functions" is marked deprecated and retired 2025-05-31, superseded by
Functions (https://vercel.com/docs/taxonomy.json). The Edge runtime page recommends migrating to
Node.js (https://vercel.com/docs/functions/runtimes/edge).

**Global Config:** the new name for Edge Config (2026-07-29). It costs $3 per 1M reads and $1 per
100 writes (https://vercel.com/changelog/edge-config-is-now-global-config). It is not relevant to
agents beyond flags.

**Queues:** public beta since 2026-02-27 (https://vercel.com/changelog/vercel-queues-now-in-public-beta).
Billed per API operation in 4 KiB chunks at $0.60 per 1M, with 1M included on Hobby
(https://vercel.com/docs/queues/pricing, https://vercel.com/pricing).

**Sandbox:** GA since 2026-01-30 (https://vercel.com/changelog/vercel-sandboxes-ga). $0.128 per CPU-hr,
$0.0212/GB-hr, $0.60 per 1M creations (https://vercel.com/docs/sandbox/pricing). Not needed for a
chat assistant without code execution.

**Blob:** $0.023/GB storage, with 1 GB included on Hobby (https://vercel.com/pricing). Operations are
priced regionally (https://vercel.com/docs/vercel-blob/usage-and-pricing).

## 8. Plans

- **Hobby: free, but "restricts users to non-commercial, personal use only"**
  (https://vercel.com/docs/plans/hobby). Hobby also "cannot purchase additional usage beyond
  included limits" (https://vercel.com/pricing). Mealvana is a paid app, so **Pro is required.**
- **Pro:** a $20/month platform fee that includes 1 deploying seat and $20/month of usage credit.
  Extra deploying seats cost $20/month each, and viewer seats are free
  (https://vercel.com/docs/plans/pro-plan).

## 9. Rough monthly cost: 1k MAU × 20 turns = 20,000 turns/month

Assumptions **[inference]**:
- Each turn makes 2 model calls (one tool round-trip).
- Each call sends ~6k input tokens, so ~12k input per turn, and the turn produces ~500 output tokens.
- About 60% of input tokens are cache reads once `caching: 'auto'` is on.
- ~150 ms of active CPU per turn and ~15 s instance wall time while streaming.
- 2 GB function memory, iad1 pricing.
- For eve/Workflow: ~30 workflow events and ~50 KB of persisted stream data per turn.

These assumptions are guesses. Measure against real Vana traces before deciding.

**A. Model tokens (the same on every option, because the Gateway adds zero markup):**
- Haiku 4.5 uncached: 20k × (12k × $1/M + 0.5k × $5/M) = 20k × $0.0145 ≈ **$290**.
- Haiku 4.5 with ~60% cache reads: ≈ **$150–180**.
- Sonnet 4.6 costs about 3× those figures.
- Token spend dominates every scenario, and moving to Vercel doesn't change it.

**B. Option 1: keep the Supabase edge functions, AI SDK + Gateway (today).** Vercel cost is $0 beyond
tokens. The Gateway works from anywhere (https://vercel.com/docs/ai-gateway/faq).

**C. Option 2: plain AI SDK 7 route on Vercel Functions (Pro).**
- Invocations: 20k → $0.01.
- Active CPU: 20k × 0.15 s ≈ 0.83 h → $0.11.
- Memory: 20k × 15 s × 2 GB ≈ 167 GB-h → $1.77. This is an upper bound, since Fluid concurrency
  shares instances.
- Infrastructure total ≈ **$2**, covered by the $20 credit.
- **Bill ≈ $20 Pro fee + tokens.**

**D. Option 3: eve or WorkflowAgent on Vercel (Pro).**
- Functions ≈ $2.
- Workflow events: 20k × 30 = 600k → $12.
- Data written ≈ 1 GB → $0.50.
- Data retained ≈ $0.50.
- Queues ≈ 180k ops → $0.11.
- Agent Runs tracing: ~400k spans → $0.20.
- Blob memory: negligible.
- Infrastructure total ≈ **$15–20**, mostly inside the $20 credit.
- **Bill ≈ $20–25 + tokens.** Event count per turn is the most uncertain input: at 100 events per
  turn, Workflow alone reaches $40.

## 10. What I could not verify

1. AI SDK 7 under Supabase's Deno runtime: the Node-22 engine requirement, `AsyncLocalStorage`
   semantics, and ESM-only packaging. There is no Deno example in `vercel/ai`.
2. The dollar amount of the AI Gateway monthly free credit.
3. GA status of Vercel Workflows as a product. Workflow 5 and `@ai-sdk/workflow`'s dependency on it
   are beta, and Queues is public beta.
4. Any official Dart/Flutter client for either the AI SDK UI message stream or the eve NDJSON stream.
5. How eve's 30-day default session lifetime interacts with Pro's 7-day Workflow retention "after run
   completion". Parked sessions may not count as completed.
6. Whether Supabase JWTs verify cleanly with eve's `jwtEcdsa`/`oidc` helpers.
7. Per-turn Workflow event counts for a real eve chat turn. The cost estimate in §9 D depends on this.
