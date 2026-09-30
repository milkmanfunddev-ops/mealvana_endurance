# Langfuse research 05: simulation, the runner we still own, and evaluators

Researched 2026-09-30. Extends `02-prompts-evals.md`; facts already there are not repeated.
Sources: langfuse.com docs fetched as `.md`, the four `llms-*.txt` indexes, the changelog
directory of `langfuse/langfuse-docs` (the `llms-changelog.txt` index stops at 2026-09-01; the
repo has four later entries), the public OpenAPI spec, and source files in `langfuse/langfuse`,
`langfuse/langfuse-js`, `langfuse/skills` and `langchain-ai/openevals`.

Marking used below:
- **(SOURCE)** read from Langfuse source code on `main`, not from the docs. Cloud may lag or lead.
- **(INFERRED)** follows from the sources but is not stated by them.
- **(UNVERIFIED)** could not be confirmed.
- **(TESTED)** a request we ran ourselves on 2026-09-30.

---

## 1. Does Langfuse run multi-turn simulated conversations for us?

**No. Nothing shipped, in beta, or on the roadmap does this.** Langfuse stores the scenarios,
groups and compares the results, and can judge them. The loop that plays a simulated user
against the agent is code we write and run.

Checked one by one:

| Candidate | Finding | Source |
|---|---|---|
| Experiments via UI (prompt experiments) | One LLM call per dataset item with a stored prompt. No tools, no agent loop, no turns. The page itself says to use the SDK "if you need to evaluate full application or agent logic". | https://langfuse.com/docs/evaluation/experiments/experiments-via-ui |
| Custom Experiment (webhook) | Langfuse POSTs a trigger to our URL and does nothing else. "Your webhook receives the request, fetches the dataset from Langfuse, runs your application against the dataset items, evaluates the results, and ingests the scores back". | https://langfuse.com/docs/evaluation/experiments/experiments-via-sdk#configure-webhook |
| SDK experiment runner | Runs **our** `task(item)` once per item with concurrency, tracing and error isolation. It has no notion of turns or a user. | same page |
| Simulation cookbook | The only simulation material. Python. The simulator is **OpenEvals** (a LangChain library), not Langfuse: `create_llm_simulated_user` plus `run_multiturn_simulation` inside the experiment task. | https://langfuse.com/guides/cookbook/example_simulated_multi_turn_conversations |
| Blog, multi-turn | "Use a framework like OpenEvals to orchestrate multi-turn conversations between your bot and simulated users." | https://langfuse.com/blog/2025-10-09-evaluating-multi-turn-conversations |
| "Langfuse for Agents" (2025-11-05) | Tool-call rendering, trace log view, observation types, agent graphs. Observability only. | https://langfuse.com/changelog/2025-11-05-langfuse-for-agents |
| Langfuse Assistant (beta 2026-06-19, extended 2026-09-03) | Queries data, builds datasets, dashboards, prompts and score configs, runs code over observations in a sandbox. It does not call our agent or run experiments. | https://langfuse.com/docs/langfuse-assistant |
| Agent skill and CLI (CLI 1.0 on 2026-08-21) | API access from a coding agent. The skill's reference files are ci-cd, cli, create-dataset, error-analysis, instrumentation, judge-calibration, prompt-engineering, prompt-migration, setting-up-evals, user-feedback, v4-project-migration. No simulation. | https://github.com/langfuse/skills · https://langfuse.com/docs/api-and-data-platform/features/cli |
| MCP server | Reads and writes Langfuse objects (evaluators and rules since 2026-06-10, experiments read since 2026-07-07). No "run" tool. | https://langfuse.com/changelog/2026-06-10-evaluators-via-mcp · https://langfuse.com/changelog/2026-07-07-experiments-public-api-and-mcp |
| `langfuse/experiment-action` | Runs our experiment script in GitHub Actions, comments on the PR, fails on `RegressionError`. The script is still ours. | https://langfuse.com/docs/evaluation/experiments/experiments-ci-cd |
| Coval integration | A separate paid simulation product (voice and chat agents) that sends traces to Langfuse. Not a Langfuse feature. | https://langfuse.com/integrations/analytics/coval |
| Roadmap | No simulation item. See section 5. | https://langfuse.com/docs/roadmap |

Every changelog entry from 2026-08-01 to today, for completeness: bulk prompt import/export
(08-06), v4 live (08-17), scores to charts (08-19), CLI 1.0 (08-21), reusable evaluators and
rules (08-22), evaluator template gallery (08-24), org feature previews (08-25), restore
evaluator versions (08-27), stable evaluator API (08-27), responsive timeline (08-28),
multi-message judge prompts and multi-modal judge inputs (09-01), self-hosted API reference
(09-01), evaluator alerts (09-02), Assistant sandbox and background runs (09-03), evaluator
backfills (09-07), Jev as a judge (09-22). None is a simulator.
https://github.com/langfuse/langfuse-docs/tree/main/content/changelog

### A TypeScript simulator exists, outside Langfuse

OpenEvals ships the same simulator in its JS package: `createLLMSimulatedUser` and
`runMultiturnSimulation` from `openevals` (npm, 0.2.2 today). It takes `app`, `user`,
`maxTurns`, an optional `stoppingCondition` and optional `trajectoryEvaluators`, and returns a
`trajectory` (message list). The `app` receives only the next user message and must keep its
own history keyed by `threadId`. The simulated user can also be a list of fixed replies, which
covers our scripted Scenarios.
https://github.com/langchain-ai/openevals/blob/main/js/README.md#multiturn-simulation

Cost of using it: the package depends on `langchain`, `langsmith` and `@langchain/openai`
(from the npm manifest). The loop it replaces is about 30 lines. **(INFERRED)** Writing the loop
ourselves with the AI SDK is the smaller dependency.

---

## 2. The minimum code we must own

### 2.1 What Langfuse's UI covers, so we build no web UI

| Job | Where it happens in Langfuse | Source |
|---|---|---|
| Hold Scenarios | Datasets: UI editor, CSV import, API, folders, versioning, JSON Schema on `input` | https://langfuse.com/docs/evaluation/experiments/datasets |
| Start a run | Dataset → Start Experiment → ⚡ Custom Experiment → Run, with an editable config | https://langfuse.com/docs/evaluation/experiments/experiments-via-sdk#configure-webhook |
| See a run | Experiments list and item table; each item links to its trace | https://langfuse.com/changelog/2026-04-13-experiments-rebuild |
| Compare runs | Baseline, score deltas, threshold filters, side-by-side outputs | https://langfuse.com/docs/evaluation/experiments/compare-experiments |
| Judge | Managed LLM judges and code evaluators fire on experiment item roots (section 3) | OpenAPI `EvaluationRuleFilter` |
| Human review | Annotation queues on experiment-item observations, annotate from compare view | https://langfuse.com/changelog/2025-10-23-annotate-from-compare-view |
| Edit judges | Evaluators page, versions, restore | https://langfuse.com/changelog/2026-08-27-restore-evaluator-versions |

What the Langfuse UI does not give: a progress bar or cancel button for a running experiment,
a rendered view of our data diff (it is JSON inside the item output), and any control over the
test athlete's data. **(INFERRED from the pages above; none of them describes such features.)**

### 2.2 Smallest credible shape

One Node/TypeScript module, about 150-250 lines, reachable two ways:

- **`POST /run` on a host that can work for minutes** (a Vercel function in `../mealvana_eval`,
  or a plain Node process). This is the Custom Experiment target.
- **`npx tsx run.ts`** for local runs and for `langfuse/experiment-action` in CI.

What the module does:

1. Verify the signature, return `202` at once, continue in the background.
2. `dataset = await langfuse.dataset.get(datasetName)`.
3. `dataset.runExperiment({ name, runName, metadata, maxConcurrency, task })`.
4. `task(item)`:
   - copy the test athlete named in the item to a fresh athlete (our Supabase RPC);
   - loop up to `maxTurns`: simulated-user model call (or next scripted line) → call Vana →
     collect reply and tool calls; stop on the stop condition;
   - read the rows Vana wrote and diff against the seed;
   - return `{ transcript, toolCalls, dataDiff, turns, stopReason }`.
5. Optional in-process `evaluators` for the tool-call expectations we already check in code.
6. `await otelSdk.shutdown()` so traces flush.

Sketch (signatures from the SDK page; the body is ours):

```ts
const otel = new NodeSDK({ spanProcessors: [new LangfuseSpanProcessor()] });
otel.start();
const langfuse = new LangfuseClient();

const task: ExperimentTask = async (item) => {
  const { persona, scenario, seedAthleteId, script, maxTurns = 6 } = item.input;
  const athleteId = await copyAthlete(seedAthleteId);          // ours
  const transcript = [], toolCalls = [];
  for (let turn = 0; turn < maxTurns; turn++) {
    const userMsg = script?.[turn] ?? await simulatedAthlete(persona, scenario, transcript);
    if (userMsg === "<done>") break;
    const reply = await callVana({ athleteId, threadId: item.id, message: userMsg });
    transcript.push({ role: "user", content: userMsg },
                    { role: "assistant", content: reply.text });
    toolCalls.push(...reply.toolCalls.map((c) => ({ turn, name: c.name, args: c.args })));
  }
  return { transcript, toolCalls, dataDiff: await diffAthlete(seedAthleteId, athleteId) };
};

const dataset = await langfuse.dataset.get("vana/scenarios");
await dataset.runExperiment({ name: "vana", runName, metadata: overrides, task,
  evaluators: [toolExpectations], maxConcurrency: 3 });
await otel.shutdown();
```

The runner needs JS SDK `@langfuse/client` ≥ 5.4 (v4 ingestion, needed for managed evaluators)
and Node OTEL. Default `maxConcurrency` in the JS runner is 50 **(SOURCE)**; set it low, since
each item copies an athlete and runs several model calls.
https://github.com/langfuse/langfuse-js/blob/main/packages/client/src/experiment/ExperimentManager.ts

### 2.3 Dataset item for a Scenario

`input`, `expectedOutput` and `metadata` are free JSON. A JSON Schema on the dataset can
enforce the shape.

```json
{
  "input": {
    "persona": "Marathoner, vegetarian, terse, changes her mind once",
    "scenario": "Wants Thursday's dinner swapped for something she can batch-cook",
    "seedAthleteId": "seed-veg-marathon-01",
    "script": null,
    "maxTurns": 6
  },
  "expectedOutput": {
    "mustCallTools": ["swap_meal"],
    "mustNotCallTools": ["delete_plan"],
    "dataExpectations": "Thursday dinner replaced; no other day changed; shopping list updated",
    "rubricNotes": "Must confirm before writing"
  },
  "metadata": { "kind": "simulated", "feature": "meal-swap", "severity": "core" }
}
```

A scripted Scenario sets `script` to the list of user lines and leaves `persona` for the judge.
The starting data is a **reference** (`seedAthleteId`), not the data itself: items are capped
by the 5 MB request limit and the seed athlete lives in Supabase.
https://langfuse.com/docs/evaluation/experiments/data-model · https://langfuse.com/faq/all/api-limits

Langfuse assumes one result per dataset item per experiment; repetitions are not supported
(tracked in langfuse/langfuse#5855). To run a Scenario three times for variance, start three
runs. https://langfuse.com/docs/evaluation/experiments/data-model

### 2.4 Triggering from the Langfuse UI: the Custom Experiment webhook

Docs: https://langfuse.com/docs/evaluation/experiments/experiments-via-sdk#configure-webhook.
The docs give the flow; the exact wire format below is **(SOURCE)**, from
`web/src/features/datasets/server/dataset-router.ts` (`triggerRemoteExperiment`) and
`remoteExperimentHelpers.ts`.

- **Setup**: per dataset. URL, a default config, optional request signing, optional custom
  headers (each can be marked secret). The config is stored on the dataset as
  `remoteExperimentUrl` and `remoteExperimentPayload`. The URL is validated against the same
  webhook SSRF rules as prompt webhooks, so it must be public.
- **Who can press Run**: a user with `datasets:CUD` scope. **(SOURCE)**
- **Request**: `POST`, `Content-Type: application/json`, `User-Agent: Langfuse/1.0`, body

  ```json
  { "projectId": "...", "datasetId": "...", "datasetName": "vana/scenarios", "payload": "..." }
  ```

  `payload` is the config the user confirmed or edited in the Run dialog, else the stored
  default. Both are typed as a string in the router, so **expect a JSON string and parse it**.
  **(SOURCE)** No experiment or run id is sent: our code names the run.
- **Signing**: when enabled, header `x-langfuse-signature: t=<unix ts>,v1=<hex>`, where the hex
  is HMAC-SHA256 of `${t}.${rawBody}` with the signing secret shown once at setup. Same scheme
  as prompt webhooks. Verify against the raw body.
  https://langfuse.com/docs/prompt-management/features/webhooks-slack-integrations
- **Timeout**: 20 seconds (`REMOTE_EXPERIMENT_TIMEOUT_MS = 20_000`), up to 10 redirects.
  **(SOURCE)** The docs say only "return a 2xx response quickly and run the experiment
  asynchronously".
- **Retries**: none. It is a single fetch made while the user waits; a non-2xx or timeout shows
  an error in the UI. **(SOURCE)** Prompt webhooks retry; this path does not.
- **Dataset version**: not in the body. Put `datasetVersion` in our config JSON if we want to
  pin one. **(INFERRED)**

Consequences for hosting: the endpoint must answer within 20 s and then keep working for the
length of the run (several minutes). On Vercel that means a background continuation
(`waitUntil` or a queue) within the function's maximum duration; on Supabase Edge the same
constraint applies. **(INFERRED; check the host's limits before choosing.)** The body shape is
fixed by Langfuse, so it cannot call GitHub's `workflow_dispatch` API directly (that API needs
a `ref` field); a relay function would be needed to start a CI run from the button.
**(INFERRED)**

### 2.5 The no-hosting variant

Skip the webhook. Run `npx tsx run.ts` from a laptop, or on a pull request with
`langfuse/experiment-action` (Node 24, `@langfuse/client` ≥ 5.3; the action loads the dataset,
adds commit metadata, and fails the job on `RegressionError`). Datasets, results, comparison,
judges and review still live in Langfuse. The only thing lost is the Run button.
https://langfuse.com/docs/evaluation/experiments/experiments-ci-cd

---

## 3. How one experiment item holds a whole conversation

### 3.1 One trace per item

"Each item corresponds to one trace" and "Langfuse expects exactly one trace per experiment
item." The item's **root observation** carries the item input, the expected output and the
actual output; model calls and tool calls are child spans.
https://langfuse.com/integrations/native/opentelemetry/experiments

In the JS runner the root span is named `experiment-item-run`. After `task(item)` returns, the
runner sets on that span: `input = item.input`, `output = <task return value>`, and
`metadata = {...item.metadata, ...experimentMetadata, experiment_name, experiment_run_name,
dataset_id, dataset_item_id}`. The expected output is set as a span attribute, and the
experiment and item ids are propagated to child spans. Environment is `sdk-experiment`.
**(SOURCE, `ExperimentManager.ts`)**

So the whole simulated conversation is **nested inside one trace**: every simulated-user call
and every Vana turn made inside `task` is a child of the item root.

Two caveats:

- **Vana runs in another process** (Supabase edge function). Its spans join the item trace only
  if the runner passes W3C trace context (`traceparent`, plus baggage for the experiment ids) on
  the request and the function's OTEL setup honours it. Otherwise each Vana turn is its own
  trace outside the experiment, and the item trace shows only the runner's view. The managed
  judges are unaffected, because they read the item root, not the children. **(INFERRED)**
- **A session is optional, not the unit.** The task may wrap its work in
  `propagateAttributes({ sessionId })` so the turns also appear as a Langfuse session, which
  allows session annotation and `sessionId` scores. Experiments do not use sessions and judges
  cannot target them (section 5). **(INFERRED; `propagateAttributes` is documented, its use
  inside an experiment task is not.)**

### 3.2 What a managed judge sees on an experiment

Experiment scope is set by rule filters, not a separate target. From the OpenAPI spec:
"`isExperimentItemRootSpan = true` limits execution to experiment item roots" and "`datasetId`
limits execution to experiments for the selected datasets". Other filter columns include
`experimentId`, `environment`, `metadata` (by key), `calledToolNames` and `toolCalls` (count).
https://cloud.langfuse.com/generated/api/openapi.yml (`EvaluationRuleFilter`)

Variables an LLM judge can map (`PromptVariableMappingSource`):

| Source | What it holds for an SDK experiment item root |
|---|---|
| `input` | the dataset item `input` (persona, scenario, seed reference) |
| `output` | whatever `task` returned |
| `metadata` | item metadata merged with run metadata (see 3.1) |
| `tool_calls` | tool calls recorded **on that observation**, as `{id, name, arguments, type, index}` |
| `expected_output` | the item's expected output, "when the observation belongs to an experiment" |
| `experiment_item_metadata` | the item's metadata, same condition |

Each mapping takes an optional `jsonPath`, so one judge can read `$.transcript` and another
`$.dataDiff` from the same output. All mappings are required; a missing field is an evaluator
error.

Code evaluators get the same data without mapping: `ctx.observation.{input, output, metadata,
toolCalls}` and `ctx.experiment.{itemExpectedOutput, itemMetadata}`.
https://langfuse.com/docs/evaluation/evaluation-methods/code-evaluators

Three things to know:

- **`tool_calls` on the item root will be empty.** The root is a plain span, and tool calls are
  recorded on the generation observations beneath it. Evaluators "do not load sibling or child
  observations". The tool-call list must be in the task's return value. **(INFERRED from the
  two documented facts.)**
- **Doc conflict.** The LLM-as-a-judge page says "Expected output and experiment item metadata
  are available only in prompt experiments". The OpenAPI spec and the migration FAQ ("Create an
  `Experiment` successor ... map dataset-item fields to the experiment-item context") say they
  apply to any observation that belongs to an experiment. The SDK sets the expected-output
  attribute on the root. **(UNVERIFIED which is right for SDK runs on Cloud today.)** If it
  fails, have `task` copy `item.expectedOutput` into its return value; nothing else changes.
  https://langfuse.com/docs/evaluation/evaluation-methods/llm-as-a-judge ·
  https://langfuse.com/faq/all/llm-as-a-judge-migration
- **The simulation cookbook's last step is stale.** It says to create a judge "that runs
  against your Dataset Runs". Dataset-target rules are now legacy; the replacement is an
  observation rule with the experiment filters above.

### 3.3 Can the task return transcript + tool calls + data diff?

**Yes.** The task output is arbitrary JSON and lands on the item root's `output`. The cookbook
returns `{trajectory, num_turns}`; ours returns `{transcript, toolCalls, dataDiff, ...}`.

Division of grading work:

| Check | Best place | Why |
|---|---|---|
| Tool-call expectations (must / must not call, argument shape) | Langfuse **code evaluator** on the item root, comparing `output.toolCalls` with `itemExpectedOutput` | Pure data, fits the 2 s / no-network / standard-library limits, editable in the UI |
| Data diff assertions that are pure comparisons | Langfuse code evaluator on `output.dataDiff` | same |
| Anything that must **query Supabase** | In `task` (produce the diff) or an in-process SDK `evaluator` | Code evaluators have no network |
| Conversation quality, persona handling, "confirmed before writing" | Langfuse **LLM judge** on `output.transcript` (+ `expected_output`) | Semantic |
| Pass bar for the run (average ≥ 90, none < 80) | SDK `runEvaluators` (score on the run), or a CI gate | Managed evaluators score items, not runs **(INFERRED)** |

Limits that bound the output: code-evaluator dispatch payload 5.5 MB and result 256 KB; API
request and response 5 MB.

---

## 4. Evaluators: what is prebuilt, and how custom ones get in

### 4.1 The template gallery today (New evaluator → gallery)

Shipped 2026-08-24; the four Jev templates were added 2026-09-22. The docs name only the
categories, so the list below is **(SOURCE)**:
`web/src/features/evals/v2/constants/managedTemplatesCatalog.ts`. 24 templates, all maintained
by Langfuse, all targeting one observation. Picking one creates an editable copy.
https://langfuse.com/changelog/2026-08-24-evaluator-template-gallery

| Category | Template | Kind | Output | Measures |
|---|---|---|---|---|
| Conversational | Detect Chat Intent | LLM | categorical | user's primary intent from a fixed list |
| Conversational, Recommended | Detect Out-of-Scope Request | LLM | boolean | last user message outside the scope set by the system prompt |
| Conversational | Detect User Disagreement | LLM | boolean | user rejects or corrects the assistant's prior reply |
| Conversational | Detect User Frustration (ALL CAPS) | code (TS) | boolean | latest user message ≥ 70% uppercase |
| Conversational | Detect User Distress | LLM | boolean | clear emotional distress in the latest user message |
| Conversational | Flag Out-of-Scope Request | Jev | probability | same as above, decision model |
| Conversational | Rate Customer Frustration | Jev | numeric level | frustration on levels we describe |
| Conversational | Detect Conversation Signals | Jev | seven probabilities | rephrase, correction, human handoff, retry, quoted error, frustration, success |
| Quality | Check Correctness | LLM | boolean | output matches expected output in meaning |
| Quality | Check if Output Is an Exact Match | code (TS) | boolean | output equals expected output |
| Quality | Validate Keyword Overlap | code (TS) | numeric | share of expected keywords present |
| Quality | Check Answer Relevance | LLM | categorical | response addresses the question |
| Quality, Recommended | Judge on One Quality Criterion | LLM | boolean | output meets one criterion we write |
| Classifier, Recommended | Classify Input Topic | LLM | categorical | topic from a fixed list |
| Classifier | Classify Input Language | LLM | categorical | language |
| Classifier, Recommended | Assign Input Topic | Jev | categorical + probabilities | topic, decision model |
| Retrieval | Check Answer Groundedness | LLM | categorical | output supported by context |
| Retrieval | Check Context Precision | LLM | categorical | context useful for the answer |
| Retrieval | Check Context Recall | LLM | categorical | context covers what the answer needs |
| Safety | Detect PII Leakage | LLM | boolean | personal data in output |
| Safety | Check Rule Adherence | LLM | boolean | output follows a stated policy or format |
| Safety | Detect Prompt Injection | LLM | boolean | injection attempt in input |
| Coding agents | Classify Engineering Task Type | LLM | categorical | what the coding agent is used for |
| Coding agents | Classify Coding Agent Usage per Department | LLM | categorical | department bucket |

**There is no agent, tool-use or trajectory template, and no whole-conversation template.** The
"Conversational" ones read the latest user message plus history from a single observation's
input; they are production monitors for user-side signals, not graders of the agent's conduct
across a conversation. "Coding agents" classifies usage, it does not grade trajectories. For
Vana, the useful starting points are *Judge on One Quality Criterion*, *Check Rule Adherence*
and *Check Correctness*; the agent-specific judges are ours to write.

Jev (decision-model) evaluators need a TypeSafe connection, return no written reasoning, and
are labelled experimental in the LLM connections page.
https://langfuse.com/docs/evaluation/evaluation-methods/jev-as-a-judge

### 4.2 The older managed library, including the RAGAS-based judges

`worker/src/constants/managed-evaluators.json` **(SOURCE)** still defines 23 older templates.
All are single-prompt LLM judges. The first eight and the RAGAS ones return a numeric score
0-1; the three added in 2026 return booleans.

- Langfuse: Hallucination, Helpfulness, Relevance, Toxicity, Correctness, Contextrelevance,
  Contextcorrectness, Conciseness, User Distress, User Disagreement, Out-of-Scope Request.
- Partner `ragas`: Answer Correctness, Answer Relevance, Answer Critic, Context Precision,
  Context Recall, Faithfulness (v1 and v2), **Goal Accuracy**, Simple Criteria, SQL Semantic
  Equivalence, **Topic Adherence Classification**, **Topic Adherence Refusal**.

These "RAGAS" entries are prompts adapted from RAGAS, run by Langfuse's worker as ordinary LLM
judges; the RAGAS library is not executed. Goal Accuracy is the only agent-flavoured one: a
three-variable prompt comparing `user_goal`, `desired_outcome` and `achieved_outcome`, 0 or 1.
It is not a trajectory metric.

**(UNVERIFIED)** whether this older set is still selectable in the Cloud UI. The new gallery
code builds its sections only from the 24-template catalog plus "Your templates". The docs FAQ
still says Langfuse "integrates with RAGAS for specialized RAG evaluation metrics" and the
simulation cookbook still mentions picking "Conciseness" "from the pre-made library". Treat
the old prompts as text we can copy into a custom evaluator from the JSON file.
https://github.com/langfuse/langfuse/blob/main/worker/src/constants/managed-evaluators.json

### 4.3 Creating and "importing" custom evaluators

There is no import of evaluator packages. An evaluator is either an LLM-judge definition or a
code function stored in Langfuse, created by one of these routes:

- **UI**: Evaluators → New evaluator → blank LLM-as-a-Judge, blank code evaluator (Python or
  TypeScript), decision-model evaluator, or a template. Test against sample observations before
  saving. Judge prompts may have System, User and Assistant messages (2026-09-01).
- **API**: `POST/GET/PATCH/DELETE /api/public/v2/evaluators`, `GET .../{id}/versions`, and the
  same verbs on `/api/public/v2/evaluation-rules`. Stable since 2026-08-27. `type` is
  `llm_as_judge` or `code`. Stable ids; names are not identifiers; a `PATCH` to the definition
  creates a new version and rules always use the latest. Active rules are test-run on creation.
  The old unstable endpoints end 2026-11-16.
  https://langfuse.com/changelog/2026-08-27-stable-evaluator-api
- **MCP**: `listEvaluators`, `getEvaluator`, `createEvaluator`, and list/get/create/update/delete
  for evaluation rules. https://langfuse.com/changelog/2026-06-10-evaluators-via-mcp
- **CLI**: `npx @langfuse/cli api evaluators create ...` with typed flags for the union body,
  or `--body-file`. https://langfuse.com/changelog/2026-08-21-langfuse-cli-v1
- **Git**: keep each evaluator as a JSON or YAML file in the repo and apply it from CI with the
  API or CLI. Langfuse documents this as the intended use ("Keep evaluation setup in version
  control. Create evaluators from CI"). There is no built-in git sync for evaluators (prompts
  have one; evaluators do not). Version history and restore exist in the UI (2026-08-27).
  Langfuse also suggests keeping judge prompts in Prompt Management for calibration runs.
  https://langfuse.com/guides/llm-as-a-judge-calibration-skill

**Code evaluator limits**: Python or TypeScript (erasable syntax only), standard library only,
no network, 2 s, source < 256 KB, dispatch payload < 5.5 MB, result < 256 KB, at least one score
returned, scores may be numeric, boolean, categorical or text. Available on every Cloud plan.
Needs OTEL-based ingestion. https://langfuse.com/docs/evaluation/evaluation-methods/code-evaluators

### 4.4 External evaluator libraries: where each runs

| Library | Langfuse support | Runs where | TypeScript? |
|---|---|---|---|
| AutoEvals (Braintrust) | `createEvaluatorFromAutoevals(...)` adapter in `@langfuse/client` | our process, as an SDK experiment evaluator | yes |
| RAGAS | docs page wiring RAGAS metrics into `run_experiment` | our process | Python only |
| DeepEval | guide; "third-party packages like DeepEval cannot run" in code evaluators | our process | Python only |
| OpenEvals | used in the simulation cookbook; no adapter | our process | yes (`openevals` npm: simulator, trajectory match, LLM-judge prompts) |
| Promptfoo | integration covers Langfuse-managed prompts only | its own runner | n/a |

https://langfuse.com/docs/evaluation/experiments/experiments-via-sdk#autoevals-integration ·
https://langfuse.com/integrations/frameworks/ragas · https://langfuse.com/resources/engineering/deepeval

Rule: anything from a third-party library runs in our runner and writes scores through the
SDK. Only Langfuse-native LLM judges, Jev evaluators and standard-library code evaluators run
inside Langfuse. OpenEvals' `createTrajectoryMatchEvaluator` (strict, unordered, subset,
superset, with tool-argument match modes) is the closest ready-made trajectory check in
TypeScript; it would run as an SDK evaluator, or its logic can be rewritten as a Langfuse code
evaluator in a few dozen lines. **(INFERRED)**

---

## 5. Session-level, multi-span and trajectory evaluation: status

Nothing of this kind is shipped, and nothing has a date.

- **Roadmap** (https://langfuse.com/docs/roadmap), under "Better evals and experiments":
  "Evaluate complete agent trajectories and other multi-span interactions." Also: "Improve the
  evaluator foundation and use AI to generate code-based evaluators" and "experiments on
  production traffic". Under "Proactive issue detection": "Build a consistent representation of
  agent traces, including long-running and multi-span interactions." The page opens with: "This
  roadmap is directional, not a commitment to ship individual features or dates." It lists no
  dates and does not mention sessions.
- **LLM-as-a-judge page**: "Multi-span evaluations will build on the new observations-first
  data model." Evaluators "do not load sibling or child observations from the same trace."
  https://langfuse.com/docs/evaluation/evaluation-methods/llm-as-a-judge
- **Migration FAQ**: "Any future multi-span support will also use the observations-first data
  model". For a judge that needs several observations today: "Write the required values to a
  root or dedicated evaluation observation, then target it directly."
  https://langfuse.com/faq/all/llm-as-a-judge-migration
- **Sessions**: LLM judges "cannot be applied directly to sessions, as Langfuse does not
  inherently know when a session has concluded." Session scores come only from the SDK/API or
  from annotation queues.
  https://langfuse.com/resources/engineering/evaluating-sessions-conversations
- **Dated facts**: observation-level evaluators shipped 2026-02-13; trace-level evaluators stop
  on Cloud at the v4 cutover 2026-11-16; v4 went live 2026-08-17. No changelog entry through
  2026-09-22 adds session, multi-span or trajectory evaluation.

For simulated runs this gap does not bite: the experiment item root is the "dedicated
evaluation observation", and our task writes the whole conversation onto it. It bites only for
judging real production conversations, which is outside this question.

---

## 6. Judges through the Vercel AI Gateway

### 6.1 LLM connection settings

Project Settings → LLM Connections → Add new LLM API key
(https://langfuse.com/docs/administration/llm-connection):

| Field | Value |
|---|---|
| Provider (adapter) | OpenAI |
| API key | a Vercel AI Gateway key (use a dedicated one so judge spend is separable) |
| Base URL (Advanced) | `https://ai-gateway.vercel.sh/v1` |
| Custom model names | gateway ids, for example `anthropic/claude-haiku-4.5`, `anthropic/claude-sonnet-4.5` |
| Use Responses API | off (the gateway path we tested is Chat Completions) |
| Extra headers | none needed |

The base URL appears in Langfuse's own gateway page:
https://langfuse.com/integrations/gateways/vercel-ai-gateway. On Cloud the URL must be public
`https://`. The connection can also be set by API (`PUT /api/public/llm-connections`). Then set
the project default evaluation model, or pick a model per evaluator. "Provider options" JSON is
set on the evaluator, not the connection.

Note the 02 file's open item: the Anthropic adapter with a direct Anthropic key is the
alternative if the gateway ever fails the save-time check.

### 6.2 Does forced `tool_choice` work there for Anthropic models?

**Yes. (TESTED 2026-09-30)** We sent the exact request shape from Langfuse's LLM connection
page (`tools` with one function `extract` returning `{score, reasoning}`, and `tool_choice:
{type: "function", function: {name: "extract"}}`, `temperature: 0`, `max_tokens: 256`,
`stream: false`) to `https://ai-gateway.vercel.sh/v1/chat/completions`:

| Model | Variant | Result |
|---|---|---|
| `anthropic/claude-haiku-4.5` | forced tool | `finish_reason: "tool_calls"`, one `extract` call with valid `score` and `reasoning` |
| `anthropic/claude-sonnet-4.5` | forced tool | same |
| `anthropic/claude-haiku-4.5` | forced tool plus `top_p: 1`, `frequency_penalty: 0`, `presence_penalty: 0`, `n: 1` (as in Langfuse's sample) | same |
| `anthropic/claude-haiku-4.5` | `response_format: {type: "json_schema", strict: true}` instead of tools | valid JSON matching the schema |

Vercel's reference also lists `tool_choice` ("`auto`, `none`, or specific function") for the
endpoint.
https://vercel.com/docs/ai-gateway/sdks-and-apis/openai-chat-completions/chat-completions

Not verified:

- Which of the two mechanisms Langfuse Cloud sends today. The LLM connection page documents
  forced tool calling; the judge page's troubleshooting text speaks of "structured outputs (JSON
  schema)" and `response_format` errors. Both worked in our test, so either way the save-time
  check should pass. **(UNVERIFIED end to end: we did not create a Langfuse connection.)**
- Anthropic models with extended thinking switched on. Anthropic's API does not allow a forced
  tool together with thinking; keep thinking off for judge models. **(UNVERIFIED through the
  gateway.)**
- Other model families through the gateway.

---

## 7. What we would still build and host

Owned code, all of it small:

1. **The runner** (section 2.2): webhook entry, the simulate loop, the Vana call, run naming.
2. **The Simulated athlete prompt** (can live in Langfuse Prompt Management).
3. **Test-athlete copy and data diff** against Supabase. Langfuse has no access to our data.
4. **Evaluator definitions**: our judge prompts and tool-expectation code, stored in Langfuse,
   optionally mirrored as files in git and applied from CI.
5. **A pass-bar rule** for a run, as an SDK run evaluator or a CI gate.

Hosted by us: one endpoint that answers within 20 s and keeps working for minutes (or nothing,
if runs start from a terminal or CI).

Not needed any more: our eval web app's Scenario store, run list, comparison views, review UI
and Judge plumbing. Langfuse's UI replaces them, with the gaps listed in 2.1.
