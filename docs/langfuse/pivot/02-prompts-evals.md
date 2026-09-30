# Langfuse research 02: prompt management and evaluation

Researched 2026-09-30 against primary sources on langfuse.com (the `.md` variants listed in
`https://langfuse.com/llms-docs.txt`, `llms-academy.txt`, `llms-guides.txt`), the public OpenAPI
spec at `https://cloud.langfuse.com/generated/api/openapi.yml`, the pricing page and the API
limits FAQ. Items marked **(UNCERTAIN)** are inferences the docs do not state outright.

Context for the reader: Vana is a meal-planning chat agent with tools, running as a Supabase
(Deno) edge function; we already built a bespoke Simulated athlete and Judge, and eval-v2 is
moving evals to `../mealvana_eval` (Next.js on Vercel, `vana-eval` edge function).

---

## 0. Headline facts that shape the design

1. **Managed judges cannot evaluate a session.** Langfuse's LLM-as-a-judge and code evaluators
   run on single observations or on experiment items. "They cannot be applied directly to
   sessions, as Langfuse does not inherently know when a session has concluded." The workaround
   is to write the whole conversation onto one observation (for example the root observation of
   the final turn, tagged `conversation_end`) and target that.
   https://langfuse.com/resources/engineering/evaluating-sessions-conversations
2. **Trace-level evaluators are deprecated. On Cloud they stop producing results on
   2026-11-16** (the v4 cutover). New work must use observation-level evaluators, which need
   the JS SDK v5.4.0+ (or v4+ OTEL SDK) or direct OTEL with header
   `x-langfuse-ingestion-version: 4`. The legacy `/api/public/ingestion` REST path does not
   feed them. "Multi-span evaluations" and "complete agent trajectories" are on the roadmap,
   not shipped.
   https://langfuse.com/docs/evaluation/evaluation-methods/llm-as-a-judge ·
   https://langfuse.com/faq/all/llm-as-a-judge-migration ·
   https://langfuse.com/faq/all/observation-eval-not-executing · https://langfuse.com/docs/roadmap
3. **An observation-level evaluator sees only the matched observation's input, output,
   metadata and tool calls.** It does not load sibling or child spans. To judge an agent turn
   including its tool calls, the application must write that context onto the root
   observation (or the generation that carries the full history).
4. **A judge can run on our own model through an OpenAI-compatible gateway.** The docs name
   Vercel AI Gateway explicitly. The gateway must support OpenAI-format **forced tool calling**
   (Langfuse sends `tools` plus `tool_choice: {function: "extract"}` to get `{score, reasoning}`),
   and the base URL must be public `https://` on Cloud (SSRF deny-list).
   https://langfuse.com/docs/administration/llm-connection
5. **Every judge execution is itself stored as a trace (environment `langfuse-llm-as-a-judge`)
   and the scores count as billable units.** "Any trace, observation, or score stored in
   Langfuse counts as a billable unit, whether it is sent by your application or created by
   Langfuse features such as LLM-as-a-Judge, Annotation Queues, or experiments." The judge's
   LLM cost lands on our provider bill, not Langfuse's.
   https://langfuse.com/docs/administration/billable-units
6. **Langfuse's own methodology argues against our current rubric shape.** The Academy says
   one binary (or categorical) judge per failure mode, with no "God evaluator" 1-10 scale and
   no multi-select. Our `eval/rubric.md` uses 0-100 scores, a robotic cap of 50 and a pass bar
   of average ≥90 with none below 80. That can be kept as our own code, but Langfuse's
   agreement analytics (Cohen's kappa, confusion matrix) only fit binary and categorical scores.
   https://langfuse.com/academy/evaluate/writing-evaluators

---

## 1. Prompt management

Primary pages: get-started, data-model (Concepts), version control, variables, composability,
message placeholders, config, link-to-traces, caching, guaranteed availability, A/B testing,
playground, webhooks, GitHub integration, folders, agentic access, and the FAQ pages listed
below. Base: `https://langfuse.com/docs/prompt-management/...`

### 1.1 Prompt object, types
- A prompt is instructions (a string, or an array of messages) plus an optional `config` JSON.
- **Types: `text` and `chat`.** The type is fixed at creation.
  https://langfuse.com/docs/prompt-management/data-model
- Chat messages have `role` (system/user/assistant) and `content`; a chat prompt can also hold
  `{type: "placeholder", name}` entries.
- Creating a prompt with an existing `name` adds a new version (API:
  `POST /api/public/v2/prompts`; JS `langfuse.prompt.create({...})`).
  https://langfuse.com/docs/prompt-management/get-started
- Folders are virtual: slashes in the name (`vana/system`). In REST paths the folder name must
  be URL-encoded. https://langfuse.com/docs/prompt-management/features/folders

### 1.2 Versions and labels
- Versions are immutable and numbered 1, 2, 3 and so on. Labels are movable pointers.
- **`production`** is the default label served when no label or version is given. **`latest`**
  is maintained automatically and always points to the newest version; it is reserved. Custom
  labels (`staging`, `tenant-x`, `prod-a`) are free-form. A label is unique across the versions
  of one prompt.
- **Label resolution table** (important):
  - no label/version → the version labelled `production`, or **404** if none has it
  - `label=staging` → that version, or **404**; there is **no fallback** to production/latest
  - `version=3` → version 3
  - label and version together → **400**
  https://langfuse.com/docs/prompt-management/features/prompt-version-control
- Relabel via `PATCH /api/public/v2/prompts/{name}/versions/{version}` with `{newLabels: [...]}`
  (JS `langfuse.prompt.update({name, version, newLabels})`).
- Rollback means moving `production` back to an older version. Version diffs are shown in the
  UI.
- **Protected labels** (admins/owners only can move or delete `production`, which also blocks
  deleting the prompt): **Pro + Teams add-on, or Enterprise only.** Not on Hobby or Core.
- Prompts are **project-scoped**. Langfuse recommends one project with built-in Environments
  over one project per environment. If you do split projects, prompts must be synced (GitHub
  integration or API scripts). https://langfuse.com/faq/all/managing-different-environments

### 1.3 Variables, references, placeholders
- Variables: `{{name}}` in any text or message content, filled by `prompt.compile({...})`. The
  syntax has no conditionals or loops.
  https://langfuse.com/docs/prompt-management/features/variables
- **Composability**: `@@@langfusePrompt:name=X|version=1@@@` or `|label=production@@@`. Only
  **text** prompts can be referenced. Resolution happens **server-side**: the GET endpoint's
  `resolve` query parameter defaults to `true`, and `resolve=false` returns raw tags but
  "bypasses prompt caching" (for debugging only). The response includes a `resolutionGraph`.
  https://langfuse.com/docs/prompt-management/features/composability · OpenAPI `prompts_get`
- References are static, with no conditional selection. For runtime choice, fetch several
  prompts and pass the chosen text into a parent's variable. The playground and prompt
  experiments do not resolve that pattern.
  https://langfuse.com/faq/all/conditional-prompt-embedding
- External templating (Jinja, Liquid, and so on) is allowed: store the raw template and render
  it client-side. You lose playground rendering, UI prompt experiments and variable detection.
  https://langfuse.com/faq/all/using-external-templating-libraries
- **Message placeholders** insert an array of messages (for example chat history) at a named
  position: `compile(vars, {chat_history: [...]})`. The format is not validated. Needs JS SDK
  ≥3.38.
  https://langfuse.com/docs/prompt-management/features/message-placeholders

### 1.4 Config field
- `config` is an arbitrary JSON object, versioned with the prompt. Typical keys are `model`,
  `temperature`, `max_tokens`, `response_format` (JSON schema) and `tools`/`tool_choice`. Code
  reads `prompt.config` and passes the values to the LLM call. This lets model and tool changes
  ship as prompt versions, with no deploy.
  https://langfuse.com/docs/prompt-management/features/config
- (Note) Our tools are Zod/AI-SDK tool definitions in code. Keeping tool **schemas** in config
  would require building AI-SDK `tool()` objects from JSON Schema at runtime (`jsonSchema()`),
  and the `execute` functions stay in code. **(UNCERTAIN whether worth it.)**

### 1.5 Linking prompts to generations and traces
- Linking puts the prompt version on the generation and enables per-version metrics: median
  latency, input/output tokens, cost, generation count, **median score**, and first/last use.
  These appear in the prompt's Metrics tab.
  https://langfuse.com/docs/prompt-management/features/link-to-traces
- Vercel AI SDK v6: `experimental_telemetry: { isEnabled: true, metadata: { langfusePrompt:
  prompt.toJSON() } }`. AI SDK 7: pass `langfusePrompt` in `runtimeContext` and list it in
  `telemetry.includeRuntimeContext`.
  https://langfuse.com/integrations/frameworks/vercel-ai-sdk
- Raw OTEL (for example Deno native OTEL): set `langfuse.observation.prompt.name` and
  `langfuse.observation.prompt.version` on the **generation** span only.
  https://langfuse.com/integrations/native/opentelemetry
- **A fallback prompt creates no link.** If the fallback fires, the generation shows no prompt
  version.
- For agents that load several prompts or "skills", Langfuse suggests recording each
  name→version pair in trace metadata as flat string keys.
  https://langfuse.com/faq/all/managing-skills-with-prompt-management
  (The OpenAPI also exposes `/api/public/unstable/skills`, so native skills support is being
  built. **(UNCERTAIN / unstable)**)

### 1.6 SDK caching and fallback
- Client-side cache with **default TTL 60 s**, served **stale-while-revalidate**: after the TTL,
  the stale prompt is returned instantly and a background refetch runs. **You need two fetches
  after TTL expiry to see a new version.** `cacheTtlSeconds: 0` disables the cache (dev use).
  https://langfuse.com/docs/prompt-management/features/caching ·
  https://langfuse.com/faq/all/old-prompt-version-caching
- The server side caches prompts in Redis in front of Postgres.
- Measured cold fetch (no cache, Langfuse's benchmark from their notebook): **p50 ≈ 37 ms, p99
  ≈ 69 ms, max 410 ms.** This excludes our Supabase-region to Langfuse-region hop.
- Retries: default 2. Timeout: the JS default is **10 s** (Python 20 s), configurable via
  `fetchTimeoutMs` and `maxRetries`. https://langfuse.com/faq/all/error-handling-and-timeouts
- `get` **throws** when there is no cached copy (fresh or stale) **and** the network fails.
  Mitigations are to pre-fetch at startup, or pass `fallback: "..."` / `fallback: [messages]`;
  then `prompt.isFallback === true`.
  https://langfuse.com/docs/prompt-management/features/guaranteed-availability
- **Rate limit: prompt GET endpoints have "No limit" on every Cloud plan.**
  https://langfuse.com/faq/all/api-limits

### 1.7 How a Deno edge function should fetch prompts
- **REST**: `GET https://<region>.cloud.langfuse.com/api/public/v2/prompts/{urlencoded name}?label=production`
  with Basic auth `publicKey:secretKey`. It returns `{name, version, type, prompt, config,
  labels, tags, ...}`. Compile `{{var}}` ourselves (a trivial regex) or use the SDK.
- **SDK**: `@langfuse/client` is fetch-based and Langfuse's own JS cookbooks run in Deno
  (`js_prompt_management_langchain` says "uses Deno.js for execution"). Importing
  `npm:@langfuse/client` in a Supabase function should work. **(UNCERTAIN: not tested in
  Supabase Edge Runtime.)**
- **Caching caveat for edge (UNCERTAIN, inferred):** the SDK cache is in-memory per isolate.
  Supabase edge isolates are short-lived and recycled, so expect frequent cold misses, each
  costing one ~40 ms + WAN fetch. The stale-while-revalidate background refetch may be killed
  when the isolate finishes the response unless it is wrapped in `EdgeRuntime.waitUntil`.
  Recommendations:
  1. Always pass a **fallback** equal to a checked-in copy of the prompt, so a Langfuse outage
     never breaks Vana. Log `isFallback`. Remember that a fallback loses the trace link.
  2. Consider a small own cache (module-level `Map` plus TTL), or mirror the production prompt
     into a Supabase table via the **prompt webhook**, and read it locally. The webhook
     approach puts Langfuse fully off the request path.
  3. Pin by `label`, never by `latest`, in production. Use `label=staging` or `latest` with
     TTL 0 on dev.
- Known pain point: Vercel AI SDK telemetry plus Deno's native OTEL on Supabase Edge did not
  work out of the box for at least one user. Langfuse has no reference implementation.
  https://github.com/orgs/langfuse/discussions/6150 (tracing is covered in research doc 01).

### 1.8 Playground and prompt experiments
- The playground offers side-by-side variants, each with its own model settings, variables,
  tools and placeholders. It supports tool calling with **mocked tool responses** and
  structured-output schemas saved to the project. "Open in playground" works from a generation,
  but only for tool observations in OpenAI ChatML format. It needs an LLM connection.
  https://langfuse.com/docs/prompt-management/features/playground
- UI prompt experiments are covered in section 6.

### 1.9 Webhooks, Slack, GitHub
- Automations (Prompts → Automations) fire on prompt-version **created**, **updated** (label or
  tag change; two events fire, one for the version that gains the label and one for the version
  that loses it) and **deleted**. They can filter to specific prompts. The target must be an
  HTTPS POST endpoint. Requests are signed HMAC-SHA256 in `x-langfuse-signature: t=..,v1=..`
  over `${t}.${rawBody}`. Langfuse retries with exponential backoff, so the handler must return
  2xx and be idempotent. The payload includes the full prompt, config, labels and
  commitMessage. Slack is supported via OAuth.
  https://langfuse.com/docs/prompt-management/features/webhooks-slack-integrations
- GitHub: `repository_dispatch` triggers an Actions workflow on prompt change, or a webhook
  server syncs prompts into a repo file.
  https://langfuse.com/docs/prompt-management/features/github-integration
- Use for us: a webhook to a Supabase function that upserts `production` prompts into a table
  (removes Langfuse from the hot path), or one that triggers an eval run on a new `staging`
  version.

### 1.10 MCP server, CLI, agent skill
- Native MCP server at `https://cloud.langfuse.com/api/public/mcp` (streamable HTTP, Basic auth
  with a project-scoped key). Read **and write** tools are on by default, including
  `listPrompts`; use a client allowlist for read-only. MCP calls count toward the **General API
  rate limit (Hobby 30/min, Core 100/min)**. Langfuse recommends its Agent Skill plus CLI
  (`npx @langfuse/cli api <resource> <action>`) over MCP where shell access exists.
  https://langfuse.com/docs/api-and-data-platform/features/mcp-server ·
  https://langfuse.com/docs/prompt-management/features/agentic-access
- A separate public **docs** MCP exists at `https://langfuse.com/api/mcp`.

### 1.11 A/B testing
- Label two versions `prod-a` and `prod-b`, pick one at random in code, link the chosen prompt
  to the generation, then compare metrics per version in the Metrics tab. Langfuse provides no
  assignment or stickiness logic; that is our code. Recommended only for apps with good success
  signals that tolerate variance, after offline tests.
  https://langfuse.com/docs/prompt-management/features/a-b-testing

---

## 2. Scores

https://langfuse.com/docs/evaluation/scores/overview ·
https://langfuse.com/docs/evaluation/scores/data-model ·
https://langfuse.com/docs/evaluation/evaluation-methods/scores-via-sdk

- **Data types**: `NUMERIC` (float), `CATEGORICAL` (string from categories), `BOOLEAN` (0/1 on
  write; the v3 read API returns a boolean), `TEXT` (1-500 chars; for open coding and notes).
  **Text scores are excluded from experiments, LLM-as-a-judge and score analytics.** Corrections
  are stored as scores too (`dataType: "CORRECTION"`, `name: "output"`).
- **Source** is set automatically: `API`, `EVAL` (managed evaluators) or `ANNOTATION` (UI and
  queues). Annotation scores carry `authorUserId` and `queueId`, and the scores read API
  filters by both.
- **Target**: exactly one of trace, observation, **session** (`sessionId` only), or **dataset
  run** (`datasetRunId`). Experiment-item scores go on the item's root observation.
- **Score configs** define name, type, min/max, categories and description. They are immutable
  (archive and restore only). Passing `configId` validates the score; the name and type must
  match the config. UI annotation and annotation queues **require** a config. Managed through
  the UI or `/api/public/score-configs`. https://langfuse.com/faq/all/manage-score-configs
- **Idempotency / updates**: a score is overwritten only when `id`, `name` **and** the date of
  `timestamp` all match. Use `id = traceId-scoreName` and keep name and timestamp stable.
  Partial updates are deprecated.
- **Comments** hold judge reasoning or reviewer notes. `metadata` is also available.
- **Frontend user feedback**: `@langfuse/browser` `LangfuseBrowserClient({publicKey})`, then
  `langfuse.score({traceId, id, name, value, dataType})`. This needs **only the public key**
  and sends immediately. The backend must return the trace ID to the client (the example uses
  `generateMessageId: () => getActiveTraceId()`). From Flutter there is no SDK, so call the
  ingestion API directly or proxy through a Supabase function. **(UNCERTAIN: whether the public
  key alone is accepted by the raw REST score endpoint outside the browser SDK; the browser SDK
  uses the ingestion API.)**
  https://langfuse.com/docs/observability/features/user-feedback
- Session-level scores via SDK: `langfuse.score.create({name, value, sessionId})`.
- **Score analytics** (beta; Scores → Analytics) compares two scores of the same type on
  matched objects: Pearson/Spearman/MAE/RMSE for numeric, and **Cohen's kappa, F1, overall
  agreement and a confusion matrix** for categorical and boolean. Use it for human-versus-judge
  agreement. Limited to two scores at a time.
  https://langfuse.com/docs/evaluation/scores/score-analytics
- Alerts: an evaluator has "Add alert" for score threshold (daily average) or judge cost.

---

## 3. LLM-as-a-judge (managed evaluators)

https://langfuse.com/docs/evaluation/evaluation-methods/llm-as-a-judge ·
https://langfuse.com/docs/evaluation/get-started/online ·
https://langfuse.com/docs/evaluation/core-concepts

- **Model**: evaluators and rules. An **evaluator** is the judge prompt with `{{variables}}`, a
  model (the project default or a dedicated one), an output definition
  (numeric/boolean/categorical, optionally multi-match) and default variable mappings. It has a
  stable ID, and edits create new versions. A **rule** is filters plus a **sampling rate** plus
  one or more evaluator assignments (each may override the mapping). Rules always use the
  latest evaluator version. The same evaluator also serves batch evaluation and UI prompt
  experiments.
- **Templates**: a template gallery ("managed evaluators" such as hallucination, relevance,
  conciseness). Picking one creates an editable copy. Custom prompts are fully supported, with
  System/User/Assistant messages (few-shot examples as assistant turns). Advanced fields
  (`scoreReasoningInstructions`, `scoreValueInstructions`) steer the structured output.
- **Targets**: **observations** (recommended; one score per matched observation) and
  **experiments**. Trace-level is deprecated (see section 0). Filters stack observation fields
  (type, name, metadata, **`isRootObservation`**) with propagated trace attributes (userId,
  sessionId, tags, version, metadata). Trace attributes **must be propagated onto observations**
  with `propagateAttributes()` or the rule will not match.
- **Mappable data**: observation input, output, metadata, **tool calls**. In prompt experiments
  also Expected Output and Experiment Item Metadata. All mappings are required; a missing field
  produces an evaluator error, not a skip.
- **Multi-modal**: media in mapped fields is resolved and sent to the judge.
- **Which models**: OpenAI, Azure OpenAI, Anthropic, Google AI Studio, Vertex, Bedrock, and
  **any OpenAI-schema endpoint** (Vercel AI Gateway, OpenRouter, LiteLLM, Portkey). Set the
  OpenAI adapter, the gateway key, the Base URL and custom model names. There is an optional
  "Use Responses API" toggle and "provider options" JSON (for example `reasoning_effort`,
  thinking budgets). **Requirements**: structured output via OpenAI-style forced tool calling
  (checked by a test call on save; failure shows "Model configuration not valid for
  evaluation"), and a public HTTPS base URL on Cloud.
  https://langfuse.com/docs/administration/llm-connection
  - **(UNCERTAIN)** whether Vercel AI Gateway's OpenAI-compatible endpoint honours forced
    `tool_choice` for every underlying model (for example Anthropic via the gateway). Verify
    with the curl in the llm-connection doc before committing.
  - LLM connections are manageable via API (`GET/PUT /api/public/llm-connections`).
- **Where it runs**: the Langfuse worker, on Langfuse infra (Cloud). There is no option to run
  managed evaluators in our infra. Code evaluators run in a separate sandbox.
- **Live traces**: new matching observations are scored "in seconds". The rule UI shows 7-day
  match volume and **estimated LLM cost**, and sampling reduces it. **No explicit "delay"
  setting is documented for observation-level rules (UNCERTAIN; older trace-level evaluators
  had one).** Backfill: "Also run on past observations", up to 6 months and 25,000
  observations, with a cost estimate shown first. Batch evaluation: select traces → Actions →
  Evaluate (requires the v4 preview toggle).
- **Cost**: Langfuse's figure is "$0.01-0.10 per assessment", paid to our provider. Langfuse
  also bills the judge's trace, observations and score as units. Evaluator status shows
  Completed/Error/**Delayed** (provider rate limit, retried with backoff)/Pending. Evaluators
  can be **paused** (`pausedAt`, `pausedReason` in the API), for example on a blocked connection.
- **Execution traces**: filter environment `langfuse-llm-as-a-judge` (code evaluators use
  `langfuse-code-eval`). Both are hidden from the default view.
- **API**: `/api/public/v2/evaluators` (`type: "llm"` or `"code"`), versions endpoint, and
  `/api/public/v2/evaluation-rules`. Evaluators can be versioned in git and deployed from CI.
- **Code evaluators** (Python or TypeScript authored in the UI): `evaluate(ctx)` receives
  `observation.{input, output, metadata, toolCalls}` and, in experiments,
  `experiment.{itemExpectedOutput, itemMetadata}`, and returns one or more scores. **Limits:
  standard library only, no network, 2 s runtime, source <256 KB, payload <5.5 MB.** They suit
  tool-call argument checks and "did the plan satisfy constraint X" rules when the data is on
  the observation.
  https://langfuse.com/docs/evaluation/evaluation-methods/code-evaluators
- **Jev as a judge** (TypeSafe decision model, experimental): typed verdicts at lower cost. It
  needs a TypeSafe connection (direct or via Vercel AI Gateway/OpenRouter).
  https://langfuse.com/docs/evaluation/evaluation-methods/jev-as-a-judge

---

## 4. Human annotation (the Xuan workflow)

https://langfuse.com/docs/evaluation/evaluation-methods/annotation-queues ·
https://langfuse.com/docs/evaluation/evaluation-methods/scores-via-ui ·
https://langfuse.com/docs/observability/features/corrections

- **Annotation queue**: a name, a description (put the review instructions and pass criteria
  here), one or more **score configs**, and optional assigned users. Add traces,
  **observations** or **sessions** in bulk from tables (Actions → Add to queue) or via the API
  (`/api/public/annotation-queues/{id}/items`). The reviewer sees each item and fills the
  configured scores plus a comment, then "Complete + next". Navigation is keyboard-driven
  (`1-9` picks a category, `Cmd+Enter` completes).
- Reviewers can add a **corrected output** (one per trace or observation, with a diff view and
  JSON or plain-text mode). This is Xuan writing what Vana should have said. Corrections do not
  update datasets automatically; an engineer promotes them.
- **Roles**: a reviewer needs **Member** (Viewer can read but cannot score). Queue assignment
  does not grant project access. Project-level RBAC needs Pro + Teams.
- **Plan limits**: annotation queues are **Hobby 1, Core 3, Pro unlimited**. Users are
  **Hobby 2** and unlimited from Core.
- **Queues cannot be modified after creation** (score configs fixed). For a second pass,
  create a new queue and re-add the same items; earlier scores stay visible.
  https://langfuse.com/guides/cookbook/error-analysis-llm-applications
- **Multiple annotators / inter-rater**: queue items have a single `status` and `completedAt`,
  so there is no per-annotator completion. **(UNCERTAIN, inferred from the OpenAPI schema)** For
  two independent raters on the same items, make one queue per rater (or rater-specific score
  names), then compare with Score Analytics (Cohen's kappa) or pull scores filtered by
  `authorUserId`. Langfuse documents no built-in blind double-rating.
- Queues also serve **experiment review**: add experiment-item observations with the source and
  reference answer, and state baseline versus candidate and the release policy in the queue
  description. https://langfuse.com/docs/evaluation/experiments/compare-experiments
- **Custom review UI** is supported: pull root observations (`GET /api/public/v2/observations`
  with `isRootObservation=true`) and write scores back with `configId`. Langfuse mentions a
  "vibe-coded annotation UI" pattern. This is how our Vana judging board could keep its own UI
  and still store labels in Langfuse. https://langfuse.com/guides/human-in-the-loop-scoring
- **Fit for a non-engineer**: annotation queues are the documented path for "domain experts".
  The catch for us is that the conversation must be readable on the observation Xuan opens.
  With OTEL traces the trace-level input/output is often null; annotate the GENERATION or root
  observation that carries the full history. The cookbook calls annotating traces instead of
  observations a common mistake.

---

## 5. Datasets

https://langfuse.com/docs/evaluation/experiments/datasets ·
https://langfuse.com/docs/evaluation/experiments/data-model ·
https://langfuse.com/academy/datasets/designing-great-datasets

- A dataset has a project-unique name (folders via `/`, URL-encoded in the JS SDK and REST),
  a description and metadata.
- An item has `input` (any JSON), optional `expectedOutput`, `metadata`, `sourceTraceId` and
  `sourceObservationId` (provenance from production), `status` (ACTIVE/ARCHIVED), and an `id`
  you can set for upsert. Media attachments are supported via `LangfuseMedia` (SDK
  experiments only; UI experiments do not support media).
- **Versioning**: every add, update, delete or archive creates a new dataset version, keyed by
  timestamp. `dataset.get(name, {version: isoTimestamp})` returns the item set at that time.
  Experiments can run on a pinned version (UI dropdown, SDK, CI action input
  `dataset_version`). Schema changes do not create versions.
- **Schema enforcement**: optional JSON Schema for `input` and/or `expectedOutput`; invalid items
  are rejected.
- **From production**: "+ Add to dataset" on any observation, or batch add from the
  Observations table with field mapping (JSON path or a custom object). It runs as a background
  batch with partial success.
- CSV import is available for text/JSON items.
- Synthetic generation cookbook (LLM loop, RAGAS, DeepEval):
  https://langfuse.com/guides/cookbook/example_synthetic_datasets
- **Datasets API rate limit: Hobby 100/min, Core 200/min, Pro 1000/min.**
- Academy sizing: ~10 items to explore one issue, 15-30 rows for a "minimally complete" first
  version, then grow. Keep separate datasets per job (regression versus adversarial). Keep the
  schema stable and preserve behaviour-shaping fields (history, tool state, user attributes).
  https://langfuse.com/academy/datasets

---

## 6. Experiments

### 6.1 Via SDK (JS/TS)
https://langfuse.com/docs/evaluation/experiments/experiments-via-sdk
- `langfuse.experiment.run({ name, runName?, description?, data | (dataset.runExperiment),
  task, evaluators?, runEvaluators?, maxConcurrency?, metadata? })`.
  - `task(item)` returns the output (it may be async).
  - `evaluators` are item-level: `({input, output, expectedOutput, metadata}) => {name, value,
    comment}` (or an array). They run **in our process**; results become scores on the item
    trace.
  - `runEvaluators` receive `{itemResults}` and become scores on the **dataset run**.
  - `result.format()` prints a summary.
- Works on local data too; with v4 SDKs local runs appear under Experiments without a hosted
  dataset.
- **JS requires OTEL set up** (`NodeSDK` + `LangfuseSpanProcessor`) and `otelSdk.shutdown()` at
  the end, or traces are lost. This is a Node pattern and fits the Next.js/Vercel eval app, not
  the Deno function **(inferred)**.
- AutoEvals adapter: `createEvaluatorFromAutoevals(Factuality())`.
- **Replay and publish saved results**: an experiment's task can look up previously recorded
  outputs, or publish already-graded results as a local-data experiment. This is the documented
  bridge for "we already have our own runner and grader".
  https://langfuse.com/resources/engineering/evaluate-existing-application

### 6.2 Via UI (prompt experiments)
https://langfuse.com/docs/evaluation/experiments/experiments-via-ui
- Dataset → Start Experiment → Prompt experiment. Pick a prompt version, an LLM connection, a
  dataset version, optional structured output, and optional evaluators (LLM-judge or code,
  targeting experiments). The prompt's `{{vars}}` must match keys in the item's input JSON, and
  placeholders can map to an item's message-history key.
- **Limit for us**: this runs a single LLM call per item with the prompt. It does not execute
  our tools or agent loop, so it cannot test Vana end to end. It could test the opener or a
  single-turn prompt in isolation.

### 6.3 Remote experiments (trigger our endpoint from the UI)
- Dataset → Start Experiment → ⚡ **Custom Experiment**. Configure a webhook URL plus a default
  JSON config that users can edit per run. Optional HMAC signing (`x-langfuse-signature`) and
  custom headers. Langfuse POSTs the dataset ID, name and config. **Our endpoint must return 2xx
  quickly** and run asynchronously: fetch the dataset, run the app, ingest scores as a new
  experiment run.
  https://langfuse.com/docs/evaluation/experiments/experiments-via-sdk#configure-webhook
- A fit for us: Xuan or Lee clicks "Run" in Langfuse, which starts `vana-eval` or the
  mealvana_eval runner. The "Run's overrides" (eval-v2 08) map naturally onto the webhook's
  config JSON.

### 6.4 Via OpenTelemetry (for the Deno function)
https://langfuse.com/integrations/native/opentelemetry/experiments
- Without a Langfuse SDK, put experiment Baggage on every span:
  `langfuse.experiment.id/name/dataset.id/metadata.*` and `langfuse.environment=experiment`.
  Each item is one trace whose root span carries `langfuse.observation.input/output`,
  `langfuse.experiment.item.expected_output`, `langfuse.experiment.item.id` (= the DatasetItem
  ID) and `langfuse.experiment.item.root_observation_id` (= its own spanId), with item Baggage
  on children. It needs a `BaggageSpanProcessor`. Scores go to the root span (`traceId` +
  `observationId`). Use a separate `experiment` environment.

### 6.5 Compare and CI
- Compare view: choose a baseline, filter by score thresholds, and view outputs side by side
  plus cost and latency. Langfuse stresses per-case regressions over averages ("both runs 50%")
  and treating a missing case as a failure.
  https://langfuse.com/docs/evaluation/experiments/compare-experiments
- CI: GitHub Action `langfuse/experiment-action`. The script exports
  `experiment(context)`, calls `context.runExperiment`, and throws `RegressionError` to fail. It
  posts a PR comment and outputs `result_json`. Node 24, `@langfuse/client` ≥5.3. Baseline
  approval lives in our repo, not the UI.
  https://langfuse.com/docs/evaluation/experiments/experiments-ci-cd
- Experiments API: `GET /api/public/experiments`, `/api/public/experiment-items` (with scores,
  I/O, metadata) for export.

---

## 7. Multi-turn, agent and simulation evaluation

- **Session-level**: there is no managed judge on sessions (section 0). The options are:
  1. an observation-level judge on an observation carrying the **full history** (every turn, or
     only the final turn via a `conversation_end` tag propagated to observations);
  2. our own judge posting `sessionId` scores via the API;
  3. human annotation of sessions in queues.
  https://langfuse.com/resources/engineering/evaluating-sessions-conversations
- **N+1 evaluation** (Langfuse's main multi-turn pattern): find a failing turn in production,
  save the conversation **up to that turn** as a dataset item input (the messages array), replay
  the app on it for the next response, and judge that single response. Iterate the prompt and
  re-run. https://langfuse.com/guides/cookbook/example_evaluating_multi_turn_conversations
- **Simulation** (Langfuse's recommended approach): make a dataset of **persona × scenario**
  items (plus features or test data). The experiment task runs a multi-turn simulation with
  **OpenEvals** (`create_llm_simulated_user` plus `run_multiturn_simulation`, max_turns ~3,
  Python) against the app keyed by `thread_id`, and returns the trajectory as the task output.
  Then an LLM judge targeted at the experiment scores each run, and run-level averages show
  trends. **This is structurally the same as our Simulated athlete plus Judge.** Langfuse adds
  dataset versioning, run comparison and UI, not a simulator of its own.
  https://langfuse.com/guides/cookbook/example_simulated_multi_turn_conversations
- **Agent evaluation, three levels**:
  https://langfuse.com/guides/cookbook/example_pydantic_ai_mcp_agent_evaluation
  - Final response (black box).
  - **Trajectory** (glass box): the dataset `expected_output.trajectory` holds a list of tool
    names, and a judge compares it with the actual list. Order may be ignored.
  - **Single step** (white box): check one decision, for example a search term or tool args.
  - The task must **return** the tool-call list (or it must be on the root observation) for a
    Langfuse judge to see it. Code evaluators get `toolCalls` of the matched observation only.
- Academy example "customer support chatbot" uses session-level evaluators (`session_outcome`
  categorical judge "when the conversation closes"), session thumbs, and a `ticket_reopened`
  outcome score written back by `sessionId` days later. These are described as scores; given the
  session limitation they would be custom or external judges.
  https://langfuse.com/academy/examples/customer-support-chatbot
- **"Grade the outcome in the environment, not the claim in the transcript"** (Academy, citing
  Anthropic). For Vana: check the meal plan and shopping list rows the tools wrote, not Vana's
  "done, I've added it". https://langfuse.com/academy/evaluate/writing-evaluators

---

## 8. Error analysis methodology and product support

https://langfuse.com/academy/monitoring/error-analysis ·
https://langfuse.com/guides/cookbook/error-analysis-llm-applications

Five steps:
1. **Gather ~100 traces**, chosen for coverage rather than randomness: flagged or tagged, low
   scores, high and low latency, high and low cost, long multi-turn sessions. Synthetic inputs
   are fine before there is production traffic.
2. **Open coding**: create two score configs, `open_coding` (TEXT: "describe what happened and
   what seems wrong; observable behaviour, not root cause") and `pass_fail_assessment`
   (CATEGORICAL Pass/Fail). Create a dated annotation queue and add the **observation** (the
   generation or root with the full conversation), not the trace. Review 30-50 items. Note the
   **first** thing that went wrong. Stop when 20 traces in a row reveal no new category. The
   humans do this part; do not delegate the first 30-50 to an LLM.
3. **Axial coding / cluster**: 5-10 categories, each with a one-sentence definition, named
   after what broke (`missing_device_lookup`, not `information_quality`). Split when root causes
   differ and merge when they are the same. An LLM may draft the clusters from the notes, but a
   human must check them, because LLMs merge by surface similarity.
4. **Label and measure**: one **BOOLEAN** score config per category. Make a **new** queue
   (queues are immutable) and re-add the same items. The failure rate equals the average of the
   boolean score (Dashboards → widget → Scores → Average).
5. **Decide**: in order, fix it (missing or contradicting prompt instruction, tool, bug); an
   evaluator only if the rate and impact justify it and someone will iterate on it (code check
   for objective failures, LLM judge for judgement failures, guardrail for safety); otherwise
   monitor. Re-run after prompt rewrites, model swaps and incidents.

Product support: TEXT scores, categorical and boolean score configs, annotation queues,
keyboard review, dashboards over score averages, and the Agent Skill/CLI to automate sampling
and clustering. A prompt for this exists: "install the Langfuse skill ... guide me step by step
through error analysis". Follow-ups: pick metrics with
https://langfuse.com/academy/evaluate/choosing-what-to-evaluate (goal metrics, guardrails,
operational; fewer is better; tie every metric to a decision; retire metrics stuck at 100%),
then build judges with https://langfuse.com/academy/evaluate/writing-evaluators:
- label 10-20 real cases first (criteria drift);
- write the prompt as onboarding material: context, one precise criterion including what to
  ignore, 2-4 optional labelled examples, reasoning before the verdict, and an explicit
  `unknown` way out;
- binary or categorical output;
- validate per class (TPR and TNR, not raw accuracy).

Judge calibration workflow (the Agent Skill runs it): a dataset of cases whose expected output
is the human label, the judge prompt stored in Prompt Management (for example under
`evaluator-prompts/`), and an experiment runs the judge on each item. The report gives simple
accuracy or a full confusion matrix with a quality gate of TPR/TNR ≥0.90.
https://langfuse.com/guides/llm-as-a-judge-calibration-skill

User signals as cheap labels (explicit, behavioural, conversation and outcome; negatives feed
error analysis; never optimise on positives alone):
https://langfuse.com/academy/monitoring/capturing-signals

---

## 9. TS / Vercel AI SDK examples worth copying

- **Vercel AI SDK integration** (AI SDK 7 `registerTelemetry(new
  LangfuseVercelAiSdkIntegration())` with `@langfuse/vercel-ai-sdk`, **Node ≥22**; or v6
  `experimental_telemetry`). Covers `propagateAttributes({sessionId, userId, tags})`, prompt
  linking, and a Next.js route with `observe()`, `endOnExit:false` for streaming, and
  `forceFlush()` in `after()`.
  https://langfuse.com/integrations/frameworks/vercel-ai-sdk
- **User feedback with Next.js plus AI SDK** (message ID = trace ID, then a browser-SDK score):
  https://langfuse.com/docs/observability/features/user-feedback and repo
  `langfuse/langfuse-examples/applications/user-feedback`.
- **Evaluate an existing application (TS)**: a full `evaluate.ts` creating a dataset, pinning
  the version, running baseline and candidate with a deterministic grader, plus replay and
  publish of saved results. This is the closest template for wrapping our runner.
  https://langfuse.com/resources/engineering/evaluate-existing-application
- **CI gate (TS)** with `RegressionError`: https://langfuse.com/docs/evaluation/experiments/experiments-ci-cd
- **Headless Langfuse from a coding agent** (trace, analyse, dataset, judge, all via the skill
  and CLI): https://langfuse.com/guides/videos/headless-langfuse
- **Replace vibes with evals** (traces, error analysis, dataset, evaluators, experiments):
  https://langfuse.com/guides/videos/replace-vibes-with-evals
- The simulation, N+1 and agent-eval cookbooks are **Python only** (OpenEvals, Pydantic AI);
  the patterns port directly.
- JS/TS SDK cookbook (low-level tracing plus integrations; the notebooks run on Deno):
  https://langfuse.com/guides/cookbook/js_langfuse_sdk

---

## 10. Plan and limit cheat-sheet (Cloud)

| | Hobby | Core $29 | Pro $199 |
|---|---|---|---|
| Units/month incl. | 50k | 100k (+$8/100k) | 100k (+$8/100k) |
| Users | 2 | unlimited | unlimited |
| Data access | 30 days | 90 days | 3 years |
| Annotation queues | 1 | 3 | unlimited |
| Protected prompt labels | no | no | Teams add-on |
| General API (incl. MCP) | 30/min | 100/min | 1000/min |
| Datasets API | 100/min | 200/min | 1000/min |
| Prompt GET | unlimited | unlimited | unlimited |
| Payload | 5 MB request/response | | |

Units = traces + observations + scores, including judge traces, annotation scores and
experiment traces. https://langfuse.com/pricing · https://langfuse.com/faq/all/api-limits

---

## 11. Gotchas and open design decisions

1. **Session judging is ours to build**, or we must write the full transcript and tool results
   onto one "turn root" observation. Choose between: (a) keep our Judge and post `sessionId`
   scores via the API; (b) a Langfuse observation-level judge on a root observation carrying
   the whole conversation, tagged `conversation_end` when the simulated run ends. Vana chats in
   production have no natural end, so (b) only fits simulations or per-turn judging.
2. **v4 ingestion is mandatory** for any managed evaluator: JS SDK ≥5.4 or OTEL header
   `x-langfuse-ingestion-version: 4`, plus `propagateAttributes` for session, user and tags on
   every observation. The Deno and OTEL path is the least documented (discussion #6150).
3. **The judge model via Vercel AI Gateway** is supported in principle. Verify forced tool
   calling on the exact model before relying on it. Judge LLM spend is outside the $4 monthly
   AI budget accounting unless we route it through the same gateway key.
4. **Rubric shape**: our 0-100 multi-criterion Judge conflicts with the Langfuse and Academy
   guidance (one binary judge per failure mode). Langfuse agreement tooling (kappa) will not
   help with 0-100 scores. Decide whether to keep the composite score (as an external numeric
   score) or split into binary failure-mode judges seeded by an error-analysis pass Xuan does in
   an annotation queue.
5. **UI prompt experiments cannot run the Vana agent loop** (no tools or state). Real
   comparisons need the SDK runner (Node/Next.js) or OTEL experiment attributes from `vana-eval`,
   optionally triggered from the UI via a Custom Experiment webhook.
6. **Prompt fetch on Supabase edge**: cold isolates defeat the SDK cache. Ship a fallback (and
   accept losing the prompt link on fallback), or mirror `production` prompts into Postgres via
   the prompt webhook. A missing label is a hard 404, never silent.
7. **Xuan's access**: she needs the **Member** role. Annotation queues are capped (Hobby 1,
   Core 3). Queues are immutable after creation. Inter-rater agreement needs separate queues or
   score names **(UNCERTAIN)**. She must annotate the observation holding the conversation, not
   the trace.
8. **Billing surprise**: judge executions, experiment traces and annotation scores all count as
   units. A 25k-observation backfill with a judge produces 25k scores plus judge traces and
   observations.
9. **Hobby retention is 30 days**. Datasets persist, but trace provenance links from dataset
   items to old traces will dangle after retention **(UNCERTAIN how the UI renders a missing
   source trace)**.
10. **Trace-level evaluator cutover 2026-11-16**: do not build anything on trace-level
    evaluators or trace input/output.
