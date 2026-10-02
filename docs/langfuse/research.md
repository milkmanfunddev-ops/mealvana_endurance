# Langfuse: what eval-v2 could use it for

> **Decision, 2026-09-30:** Lee chose to adopt Langfuse. Sections 1 to 5 still stand as
> researched. Section 6 recommended against adopting it, and Lee decided otherwise; it's kept as a
> record of the tradeoffs. What happens next is in [README.md](README.md).

Researched 2026-09-29 against langfuse.com (docs, pricing, changelog), the `langfuse/langfuse`
GitHub repo, Anthropic's Claude Code legal page and Consumer Terms, Vercel docs and Marketplace,
Deno docs, and AWS pricing. Prices and features were fetched live on that date and will drift.
Scope: whether Langfuse should replace, complement, or stay out of the eval-v2 system described in
`../mealvana_eval/CONTEXT.md` and `../mealvana_eval/.scratch/eval-v2/spec.md` (which lists Langfuse as "optional later").

Facts carry a link. Lines marked **Judgement** are mine.

## Summary

- Langfuse is an open-source (MIT core) LLM tracing and evaluation platform: traces and sessions,
  scores, managed LLM-as-a-judge, datasets and experiments, annotation queues, prompt management,
  cost tracking, dashboards, and a full public API. [self-hosting](https://langfuse.com/self-hosting),
  [public API](https://langfuse.com/docs/api-and-data-platform/features/public-api)
- Getting AI SDK traces out of Vana's Deno edge function is unproven. Langfuse's documented path
  needs Node's OpenTelemetry `NodeSDK`, and a Langfuse discussion about Supabase Edge is still open.
  Our Next.js engine already receives the full `TurnTrace` for every turn, so it can forward those
  traces from Node instead, and Deno never has to change.
- The managed judge doesn't fit our Mark. Trace-level evaluators are deprecated from 2026-11-16,
  observation-level evaluators see one observation, and nothing scores a whole multi-turn
  conversation natively. We would still compute the weighted Mark and robotic cap in code.
- The cost is low. Our estimated volume, roughly 20k to 95k billable units a month, fits Hobby
  (free, 50k units, 2 users, 30-day retention) at the low end and Core ($29/mo, 100k units, 90
  days) at the high end. [pricing](https://langfuse.com/pricing)
- LLM connections: OpenAI, Azure OpenAI, Anthropic, Google AI Studio, Vertex, Bedrock, and any
  OpenAI-compatible base URL. Vercel AI Gateway is named as one of those.
  [LLM connections](https://langfuse.com/docs/administration/llm-connection)
- A Claude Pro/Max/Claude Code subscription can't power it. Anthropic says third parties may not
  route requests through subscription credentials and should use API keys.
  [Claude Code legal](https://code.claude.com/docs/en/legal-and-compliance)
- Billing: there is no Vercel Marketplace listing. AWS Marketplace billing exists only through a
  private offer or an Enterprise yearly commitment.
- **Judgement:** don't adopt it now. We already have everything Langfuse would duplicate. If we
  later want a second trace viewer or human-review queues, the lean option (forward stored traces
  and Marks from Next.js, about 1 to 2 days) is the only one worth doing.

## 1. What Langfuse offers, checked against our needs

### Tracing and ingestion

- **OTLP endpoint:** `https://cloud.langfuse.com/api/public/otel` (EU), `us.` and `jp.` variants.
  It accepts HTTP/JSON and HTTP/protobuf, not gRPC. Auth is Basic with public:secret keys.
  Attributes such as `langfuse.session.id`, `langfuse.observation.type`, `…input`, `…output`,
  `…usage_details` and `gen_ai.*` map onto Langfuse fields.
  [OpenTelemetry](https://langfuse.com/integrations/native/opentelemetry)
- **Legacy ingestion is going away.** The batch ingestion API used by JS SDK v3 and older is
  removed on Cloud on 2026-11-16. New work has to use OTel-based SDKs (JS v4+/v5).
  [public API](https://langfuse.com/docs/api-and-data-platform/features/public-api),
  [Langfuse v4](https://langfuse.com/docs/v4),
  [JS v4 to v5](https://langfuse.com/docs/observability/sdk/upgrade-path/js-v4-to-v5)
- **Vercel AI SDK:** v6 uses `experimental_telemetry: { isEnabled: true }` plus
  `@langfuse/otel`'s `LangfuseSpanProcessor` inside an OTel `NodeSDK`. AI SDK 7 uses
  `@langfuse/vercel-ai-sdk` and needs Node 22+. Serverless code must call `forceFlush()`. The page
  doesn't mention Deno or edge runtimes.
  [Vercel AI SDK integration](https://langfuse.com/integrations/frameworks/vercel-ai-sdk)
- **Deno / Supabase Edge:** discussion #6150, opened 2025-03-21 and still open, reports that
  Supabase Edge's native Deno OTel "couldn't [be] configure[d] to work with Langfuse". Maintainers
  suggest pointing Deno's OTel at Langfuse's OTLP endpoint directly.
  [discussion](https://github.com/orgs/langfuse/discussions/6150). Deno's built-in OTel
  (`OTEL_DENO=true`, `OTEL_EXPORTER_OTLP_ENDPOINT/HEADERS`) picks up `npm:@opentelemetry/api`
  spans automatically but is "in development".
  [Deno OTel](https://docs.deno.com/runtime/fundamentals/open_telemetry/). Supabase's telemetry
  docs don't say whether hosted Edge Functions accept these env vars.
  [Supabase telemetry](https://supabase.com/docs/guides/telemetry). **Judgement:** unverified,
  and it would mean a backend deploy in this repo for something we already capture.
- **Manual observations from Node:** `startObservation(name, attrs, { asType: "generation" |
  "tool" | "agent" | "span" | … , startTime })`, with `.update({ input, output, model,
  usageDetails, costDetails })` and `.end(endTime)`. Timestamps can be backdated, so a stored Run
  can be replayed into Langfuse after the fact.
  [instrumentation](https://langfuse.com/docs/observability/sdk/instrumentation),
  [StartObservationOptions](https://js.reference.langfuse.com/types/_langfuse_tracing.StartObservationOptions.html)

### Sessions

A `sessionId` groups traces, and the session view shows "a simple session replay of the entire
interaction". Sessions can be scored via SDK/API and queued for human annotation.
[sessions](https://langfuse.com/docs/observability/features/sessions),
[session-level scores](https://langfuse.com/changelog/2025-04-28-session-level-scores).
**Judgement:** a Run maps to a session and a turn maps to a trace.

### Scores

Types are `NUMERIC`, `CATEGORICAL`, `BOOLEAN` and `TEXT` (1 to 500 chars), with `comment`,
`metadata`, and a target of trace, observation, session, or dataset run. A `configId` validates the
value against a score config (range or categories). A stable `id` makes the write idempotent.
[scores via SDK](https://langfuse.com/docs/evaluation/evaluation-methods/scores-via-sdk).
Score analytics compares two scores (e.g. LLM judge against human, Cohen's kappa) and shows
distributions. [score analytics](https://langfuse.com/docs/evaluation/evaluation-methods/score-analytics)

### Managed LLM-as-a-judge

- Prompt templates with `{{input}}`, `{{output}}`, `{{ground_truth}}` plus system, user, and
  few-shot assistant messages. Variables map to observation fields including tool calls. The judge
  returns "a structured score and reasoning", as numeric, categorical, or boolean. It uses the
  project default model or one set per evaluator, runs on live data with filters and sampling or in
  batch on historical data, and traces each execution in environment
  `langfuse-llm-as-a-judge`. [LLM-as-a-judge](https://langfuse.com/docs/evaluation/evaluation-methods/llm-as-a-judge)
- **Targets:** observations, and experiments/dataset runs. "Trace-level evaluators are deprecated
  as of Langfuse v4, with cutover on November 16, 2026." (same page). Observation-level evaluators
  target one observation. For multi-span data, Langfuse says to "write the required values to a
  root or dedicated evaluation observation". Multi-span and session evaluators are planned with no
  date. [migration FAQ](https://langfuse.com/faq/all/llm-as-a-judge-migration)
- Evaluator models must support "tool calling in the OpenAI format".
  [LLM connections](https://langfuse.com/docs/administration/llm-connection)

### Datasets and experiments

- Dataset items have `input`, `expectedOutput`, and `metadata`, with optional JSON Schema
  validation. Every add, update, delete, or archive creates a new dataset version, and a run can
  target a past version. [datasets](https://langfuse.com/docs/evaluation/experiments/datasets)
- Experiments via SDK (JS/TS ≥5.6.0): a `task(item)` function can call anything, including HTTP.
  They support item-level and run-level evaluators and `maxConcurrency`. Results land as dataset
  runs "available for comparison in the UI".
  [experiments via SDK](https://langfuse.com/docs/evaluation/experiments/experiments-via-sdk)
- Multi-turn: the official simulated-conversation cookbook stores persona/scenario pairs as
  dataset items, runs the dialogue with OpenEvals' `run_multiturn_simulation` inside the task, and
  judges the dataset run output. [cookbook](https://langfuse.com/guides/cookbook/example_simulated_multi_turn_conversations),
  [multi-turn blog](https://langfuse.com/blog/2025-10-09-evaluating-multi-turn-conversations).
  This is the same shape as our Scenario, Simulated athlete, and Judge.

### Annotation queues

Humans score traces, observations, or sessions against a required score config and can add
corrected outputs. [annotation queues](https://langfuse.com/docs/evaluation/evaluation-methods/annotation-queues).
Plan limits: 1 queue on Hobby, 3 on Core, unlimited on Pro. [pricing](https://langfuse.com/pricing)

### Prompt management

Versioned prompts with labels (e.g. `production`) are fetched by the SDK with client-side caching
and linked to traces for per-version analysis.
[prompt management](https://langfuse.com/docs/prompt-management/overview). Prompts can embed other
prompts with `@@@langfusePrompt:name=X|label=production@@@`.
[composability](https://langfuse.com/docs/prompt-management/features/composability).
**Judgement:** it could hold Vana's `persona.ts` sections, but Vana would then fetch her prompt from
a third party at runtime in prod. That changes the app, not just the eval tool, so it's out of scope.

### Cost, dashboards, playground, API

- **Cost:** ingested `costDetails` take priority over inferred cost. Cache read/write tokens are
  supported. [cost tracking](https://langfuse.com/docs/observability/features/token-and-cost-tracking).
  We could send the Gateway's `/v1/generation` cost as-is.
- **Dashboards:** cost, latency (P95/P99), score distributions over time, grouped by user, model,
  trace name, or session, and filtered by metadata.
  [custom dashboards](https://langfuse.com/docs/metrics/features/custom-dashboards)
- **Playground:** side-by-side prompt variants, tools with mocked responses, JSON-schema outputs,
  and "Open in Playground" from a generation. Tool observations open only in OpenAI ChatML format.
  [playground](https://langfuse.com/docs/playground)
- **Public API:** "All Langfuse data and features are available via the API": observations v2,
  scores v3, experiments, metrics v2, prompts, and OTel ingestion, with an OpenAPI spec and
  scheduled blob-storage exports.
  [public API](https://langfuse.com/docs/api-and-data-platform/features/public-api)

## 2. Mapping to eval-v2

| Our part | Langfuse fit | What we'd still build |
| --- | --- | --- |
| Trace storage and drill-down (Run, turn, step, span) | **Complement.** Session and trace views show nested generations and tool calls with inputs, outputs, tokens, and cost. | A forwarder from our stored `TurnTrace`. The data diff (before/after snapshot) has no Langfuse equivalent, and failed Tool expectations shown at the failing step stay ours. |
| Run list | **Complement.** Sessions list with filters by metadata and tags. | The Run list with Mark, verdict, and round stays ours, since Supabase is the source of truth. |
| Judge and Mark | **Doesn't fit as a replacement.** Managed evaluators give one score per evaluator (**Judgement** from the docs' score types), cover one observation, and have no session target. Ten dimensions would mean ten judge calls, and the weighted Mark and robotic cap still need code. | Keep our Judge. Push its output as scores: 10 dimension scores (NUMERIC 0 to 100, comment = reason), `mark`, and `robotic_cap` (BOOLEAN). |
| Rubric versioning | **Doesn't fit.** Score configs validate ranges, and evaluator prompts version on their own, but neither holds weights, anchors, cap, or pass bar. | Keep ours. Put `rubric_version` in score metadata. |
| Tool expectations | **Doesn't fit.** Langfuse has no code evaluators on the server. SDK experiments can run code evaluators, but that code is ours anyway. | Keep ours. Optionally push each result as a BOOLEAN score on the failing observation. |
| Scenarios and Eval rounds | **Could replace storage, adds little.** Datasets hold Scenarios and experiments act as rounds, with UI comparison. | The runner, the Simulated athlete, throwaway users, and snapshots all stay ours. Two sources of truth for Scenarios is a cost. |
| Comparing Runs | **Complement.** Dataset run comparison and score dashboards across rounds. | Only works if rounds are sent as dataset runs, which means mirroring Scenarios as dataset items. |
| Improvements backlog | **Doesn't fit.** Langfuse has no backlog concept. | Keep ours. |
| Per-Run overrides | **Doesn't fit.** Prompt management serves versioned prompts, not ad hoc per-Run edits sent to `vana-eval`. | Keep ours. Record overrides in trace metadata so they're filterable. |
| Human review (not in spec) | **Adds something new.** Annotation queues over sessions let Xuan and Lee mark Runs by hand and compare with the Judge via kappa. | A score config per dimension. |

**Multi-turn Simulated athlete.** Langfuse has no built-in user simulator. Its own cookbook runs
the simulation inside the experiment task with a third-party library, and judges the dataset-run
output. [cookbook](https://langfuse.com/guides/cookbook/example_simulated_multi_turn_conversations).
So our engine keeps running the loop in every option. The managed judge could only Mark a whole
conversation if we write the full transcript and trace into one "evaluation observation", as the
[migration FAQ](https://langfuse.com/faq/all/llm-as-a-judge-migration) suggests. That takes the same
work as the Judge we already have.

### Lean option: forward traces and Marks (about 1 to 2 days, **Judgement**)

1. Add `@langfuse/tracing` + `@langfuse/otel` to the Next.js app (Node runtime,
   `instrumentation.ts`), with keys in Vercel env.
2. When a Run finishes, replay its stored turns: a session per Run, a trace per turn, a generation
   per step (model, input, output, `usageDetails` incl. cache, `costDetails` from the Gateway), a
   tool observation per tool call, backdated with `startTime`/`end(endTime)`. Metadata carries
   scenario, Eval athlete, round id, overrides hash, and rubric version. Call `forceFlush()`.
3. Push the Judge output as session scores with stable ids, plus Tool expectation results as
   BOOLEAN scores.
4. Deep-link from our Run page to the Langfuse session.

No change to `vana-eval` or Deno, and it's easy to remove. Supabase stays the source of truth.

### Heavy option: move to Langfuse's model (about 1 to 2 weeks, **Judgement**)

Mirror Scenarios as dataset items. Run Eval rounds through `experiment.run` with our engine as the
task. Instrument Deno with OTel (unproven, needs a backend deploy). Replace our Run list and
comparison screens with Langfuse's views. Optionally use annotation queues for human Marks. The
Judge, Mark arithmetic, Rubric, Tool expectations, throwaway users, data diff, overrides, and
Improvements all stay ours, so the gain is some UI we've already built. It also puts
anonymized-but-real athlete data with a second vendor.

## 3. Pricing (fetched 2026-09-29)

Cloud tiers, from [langfuse.com/pricing](https://langfuse.com/pricing):

| Tier | Price/mo | Included units | Overage | Retention | Users | Notes |
| --- | --- | --- | --- | --- | --- | --- |
| Hobby | $0 | 50k | none available | 30 days | 2 | 1 annotation queue, community support |
| Core | $29 | 100k | $8 / 100k | 90 days | unlimited | 3 annotation queues |
| Pro | $199 | 100k | $8 / 100k | 3 years | unlimited | unlimited queues, SOC2/ISO reports, BAA |
| Teams add-on (on Pro) | +$300 | | | | | Enterprise SSO, fine-grained RBAC |
| Enterprise | $2,499 | 100k | $8 / 100k, custom | 3 years | unlimited | audit logs, SCIM, SLAs; yearly commitment can bill via AWS Marketplace |

Graduated overage: $8.00/100k up to 1M, $7.00 to 10M, $6.50 to 50M, $6.00 beyond. Discounts
include 50% off the first year for early-stage startups. **Billable unit:** "any tracing data point
sent to the platform -- including traces …, observations (… spans, events, and generations), and
scores". LLM-as-a-judge execution traces and their scores are units too.

**Our usage estimate (Judgement).** Per turn: 1 trace, 3 to 6 generations, about as many tool
observations, and 1 Simulated athlete generation, so about 8 to 16 units. Per Run of 5 to 10 turns
that's 40 to 160 units, plus about 15 scores (10 dimensions, Mark, cap, a few Tool expectations).
That gives about 55 to 175 units per Run and 1.4k to 4.4k per Eval round of 25 Scenarios. At 3 to 5
rounds a week plus ad hoc Runs, that's about 20k to 95k units a month.

- Typical weeks fit **Hobby** (free). It has exactly 2 users, which is Lee and Xuan, but no
  overage, so a heavy month is capped.
- Heavy weeks fit **Core** ($29/mo, 90-day retention).
- Long retention isn't needed because Supabase keeps our history.

**Self-hosting.** Code outside `ee/`, `web/src/ee/` and `worker/src/ee/` is MIT Expat. Those
directories fall under `ee/LICENSE`. [LICENSE](https://github.com/langfuse/langfuse/blob/main/LICENSE).
Open source is free and includes annotation queues, LLM-as-a-judge, playground, and prompt
experiments. Enterprise self-host (custom price) adds project RBAC, retention policies, audit logs,
SCIM, and data masking. [self-host pricing](https://langfuse.com/pricing-self-host). Infra: Web and
Worker containers, Postgres, ClickHouse, Redis/Valkey, and S3-compatible blob storage.
[self-hosting](https://langfuse.com/self-hosting). Docker Compose needs at least 4 cores and 16 GiB
(e.g. t3.xlarge) plus about 100 GiB disk, and "lacks high-availability, scaling capabilities, and
backup functionality". [docker compose](https://langfuse.com/self-hosting/deployment/docker-compose).
A t3.xlarge is $0.1664/h on demand in us-east-1, about $121/month before storage.
[EC2 on-demand pricing](https://aws.amazon.com/ec2/pricing/on-demand/). **Judgement:** that's more
than Core and adds a server to run, so it isn't worth it for two users.

## 4. Model access for judge and playground

- **Supported connections:** "OpenAI, Azure OpenAI, Anthropic, Google AI Studio, Google Vertex AI,
  Amazon Bedrock, TypeSafe (experimental)", plus any OpenAI-schema endpoint by replacing the base
  URL, "including Groq, OpenRouter, Vercel AI Gateway, LiteLLM". Custom headers are supported. Judge
  models need OpenAI-format tool calling. Bedrock needs `bedrock:InvokeModel` and
  `InvokeModelWithResponseStream`, or a Bedrock API key for the Mantle endpoint.
  [LLM connections](https://langfuse.com/docs/administration/llm-connection)
- **Vercel AI Gateway:** its OpenAI-compatible base URL `https://ai-gateway.vercel.sh/v1` supports
  chat completions with tool calling and structured outputs, including Anthropic models such as
  `anthropic/claude-opus-5`, authenticated by a Gateway API key.
  [Gateway Chat Completions](https://vercel.com/docs/ai-gateway/sdks-and-apis/openai-chat-completions).
  So Langfuse's judge and playground could bill to our existing Gateway account.
- **Claude Pro/Max or Claude Code subscription: no.** Anthropic's Claude Code legal page says
  OAuth "is intended exclusively for purchasers of Claude Free, Pro, Max, Team, and Enterprise
  subscription plans and is designed to support ordinary use of Claude Code and other native
  Anthropic applications". Developers "should use API key authentication through Claude Console or
  a supported cloud provider". "Anthropic does not permit third-party developers … to route
  requests through Free, Pro, or Max plan credentials on behalf of their users", and they may not
  "collect, store, or intermediate Claude.ai credentials or session tokens".
  [Claude Code legal and compliance](https://code.claude.com/docs/en/legal-and-compliance). The
  Consumer Terms (effective 2025-10-08) bar access "through automated or non-human means … Except
  when you are accessing our Services via an Anthropic API Key".
  [Consumer Terms](https://www.anthropic.com/legal/consumer-terms). Langfuse's Anthropic connection
  takes an API key, and a subscription can't stand in for one.
- **Cost doesn't go away.** Judge calls cost model tokens wherever they run. Langfuse quotes
  "$0.01-0.10 per assessment" for its managed evaluators.
  [LLM-as-a-judge](https://langfuse.com/docs/evaluation/evaluation-methods/llm-as-a-judge). Our
  Judge already runs through the Gateway, so moving it to Langfuse saves nothing and adds Langfuse
  units for the judge's own traces.

## 5. Marketplace billing

- **Vercel Marketplace: not listed.** `vercel.com/marketplace/langfuse` falls back to the generic
  Marketplace page (checked 2026-09-29), and the observability category lists Braintrust, Sentry,
  Dash0, Datadog, and others, but not Langfuse. [marketplace](https://vercel.com/marketplace),
  [Braintrust for Vercel](https://vercel.com/marketplace/braintrust). Vercel documents Langfuse only
  as a Gateway framework integration using `observeOpenAI`, last updated 2026-09-08.
  [Langfuse with AI Gateway](https://vercel.com/docs/ai-gateway/ecosystem/framework-integrations/langfuse)
- **AWS Marketplace: yes, but through sales.** Langfuse has a seller profile.
  [seller profile](https://aws.amazon.com/marketplace/seller-profile?id=seller-nmyz7ju7oafxu). Its
  changelog says to "talk to us to request a private offer".
  [changelog](https://langfuse.com/changelog/2024-09-20-aws-marketplace). The pricing page lists
  "AWS Marketplace billing" under Enterprise's optional yearly commitment.
  [pricing](https://langfuse.com/pricing). Hobby/Core self-serve plans can't be billed through an
  AWS account.

## 6. Recommendation (Judgement)

**Don't add Langfuse now.** Our spec already covers what Langfuse would contribute: full traces with
tool I/O, drill-down, cost, Run comparison. The pieces that make our evals ours (the 10-dimension
Rubric with a code-computed Mark and robotic cap, Tool expectations at the failing step, the data
diff, throwaway Eval athletes, per-Run overrides, Improvements) have no Langfuse home. Its managed
judge covers one observation, so it can't Mark a multi-turn Run without us building the same
bundle our Judge already reads. Adopting it would mean a second vendor holding athlete-derived
data, a second place to look, and a Nov 2026 migration (v4, ingestion API removal) happening under
us.

**Reasons to revisit:**
- We want human Marks from Xuan alongside the Judge and a Judge-vs-human agreement number.
  Annotation queues and score analytics do this well.
- Our own trace UI turns into a maintenance burden.

The lean option (forward stored traces and Marks from Next.js on Hobby or Core, about 1 to 2 days,
no Deno or backend change) is then the right size. Skip the heavy option and self-hosting.

If we want a hosted tool with Vercel billing, Braintrust is the one on the Vercel Marketplace. That
would be a separate note.
