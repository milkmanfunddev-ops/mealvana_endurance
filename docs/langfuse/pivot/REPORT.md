# Langfuse pivot: research report and open questions

Written 2026-09-30, at the start of a `/grill-with-docs` session. Lee is replacing the bespoke
eval and observability work with Langfuse and wants every Langfuse feature that fits: tracing,
cost breakdowns, prompt management, evals, experiments, and review by Xuan. Nothing has been
decided yet. Every item under "Open questions" still needs Lee's answer.

The notes one level up (`../README.md`, `../research.md`, `../alternatives-and-costs.md`,
2026-09-29) argued against adopting Langfuse and preferred the "lean" option. Lee has overruled
that. Read them for background only.

## Sources in this folder

| File | What it covers |
|---|---|
| `01-observability.md` | Trace data model, JS SDK v5, Vercel AI SDK integration, Deno and Supabase Edge, cost tracking, OTLP, Flutter options, MCP, integrations, 2025–26 changelog, canary checklist |
| `02-prompts-evals.md` | Prompt management, scores, LLM-as-a-judge, annotation queues, datasets, experiments (SDK, UI, remote), multi-turn simulation, error-analysis method |
| `03-hosting-pricing.md` | Cloud plans, self-host architecture and cost, EE-gated features, running both, migration, privacy |
| `04-video-summary.md` | "Langfuse Walkthrough" (Langfuse channel, 2026-09-18, youtube `THfB4p2xCFY`) mapped onto Vana |
| `video-transcript.md` | Timestamped paraphrase of the video (not verbatim) with the `yt-dlp` command to pull exact captions |

## Current state

**Langfuse project.** `https://us.cloud.langfuse.com/project/cmumt1xgp01usad0cw9fw4ow5`:
"Lee's Organization" / "My Project", **Hobby** plan, US region, no traces yet. No `LANGFUSE_*`
key exists anywhere in either repo, and neither repo has any Langfuse code.

**AI call sites** (all in `supabase/functions`, Deno). Every call goes through `npm:ai@6.0.277`
using AI Gateway `"provider/model"` strings. There is no OpenTelemetry and no
`experimental_telemetry`; Sentry (`@sentry/deno` from esm.sh) is the only telemetry.

| Entry point | Call | Default model |
|---|---|---|
| `vana-chat`, `jade-chat`, `vana-eval` via `_shared/vana/chat.ts` `runChat` | `streamText`, about 50 tools, up to 6–8 steps | `anthropic/claude-haiku-4.5` |
| Summary and idle extraction (`extract.ts`) | `generateObject` | background model (haiku-4.5) |
| `vana-day-notes`, `pantry_photo`, saved-meal ingredients | `generateObject`; pantry uses vision | haiku-4.5 |
| `describe-meal`, `analyze-meal-photo` | `generateObject`; photo uses vision | `anthropic/claude-sonnet-4.6` |
| Embeddings | `embed` / `embedMany` | `openai/text-embedding-3-small` |
| Outside functions: `scripts/changelog/generate_and_publish.mjs` | raw `fetch` to the Gateway | sonnet-4.6 |

- Prompts are hardcoded in code: `_shared/vana/persona.ts`, `extract.ts`, `daynotes.ts`,
  `_shared/meal_analysis/prompt.ts`, and `pantry.ts`.
- `runChat` has one tracing seam, `onTrace(TurnTrace)`. Only `vana-eval` sets it.

**Cost tracking that already exists:**
- `ai_usage` records exact Gateway cost per call.
- `vana_calls`, the Call log, adds cache tokens and step counts.
- The Wallet and Monthly budget ($4) enforce spending.
- A daily cost alert fires to Sentry at $1.50 per account.
- `eval_traces` was dropped.

**Identifiers we could send to Langfuse:**
- `auth.uid()` as the user.
- `vana_conversations.id` as the session. It is returned in the `x-conversation-id` header.
- The NDJSON `done` line has no message ID or generation ID.

**Feedback:**
- Vana's `saveFeedback` tool writes to `user_feedback` with a `rating` of -1/1.
- Wiredash handles shake-to-report.
- Replies have no thumbs up or down.

**`../mealvana_eval`** (Next 16, `ai@^7`, Node, on Vercel):
- Tickets 01–07 are built. 04–07 are not yet deployed.
- Ticket 08 is merged on the Mealvana side; its eval-app half is built but uncommitted.
- Tickets 09–11 are not built: batch rounds, Rubric editors, compare Runs.
- Domain terms (`../mealvana_eval/CONTEXT.md`): Scenario, Eval athlete, Run, Simulated athlete,
  Judge, Tool expectation, Mark (0–100; the glossary says avoid "score"), Rubric, Eval round,
  Improvement.
- `decisions.md` records the 2026-09-30 decision to adopt Langfuse, pending this grilling.

## Facts that constrain the design

1. **Langfuse Cloud becomes v4-only on 2026-11-16.** The legacy `/api/public/ingestion` then
   accepts only scores. The old read APIs, metrics v1 and trace-level LLM-as-judge are removed.
   Build on OpenTelemetry (`/api/public/otel/v1/traces`) or JS SDK v5.4 or later, and read
   through the Observations v2, Metrics v2 and Scores v3 APIs.
2. **The JS SDK is at v5.** `updateActiveTrace()` is gone. Set user, session, tags and metadata
   with `propagateAttributes()`, and propagate them to every observation, or evaluator filters
   silently match nothing.
3. **Supabase Edge Functions are not an officially supported runtime.** Langfuse's GitHub
   discussion #6150 is unresolved. The likely working recipe:
   - Pass keys to the constructor; the SDK does not read `Deno.env`.
   - Set `exportMode: "immediate"`.
   - Register an AsyncLocalStorage context manager.
   - Call `forceFlush` inside `EdgeRuntime.waitUntil`.

   Local `supabase functions serve` kills background flushes, so only a deployed canary proves
   it works. Sentry's JS SDK can take the OpenTelemetry provider and block Langfuse's span
   processor; check whether `@sentry/deno@8` does.
4. **AI SDK versions.** `ai@6` (edge functions) works with `experimental_telemetry` and the
   metadata keys `userId`, `sessionId`, `tags` and `langfusePrompt`. `ai@7` (eval app) needs
   `@langfuse/vercel-ai-sdk` on Node 22 or later.
5. **Cost.**
   - Langfuse's built-in prices expect hyphens (`anthropic/claude-haiku-4-5`). Our dotted names
     (`claude-haiku-4.5`, `claude-sonnet-4.6`) match nothing, so those calls show no cost.
   - Langfuse ignores `providerMetadata.gateway.cost`.
   - Fix it by ingesting cost ourselves (exact) or by adding custom model definitions
     (estimated).
   - Metrics v2 cannot group by user or session, only filter by them. For cost per athlete,
     use the Users view or a dashboard.
6. **Flutter has no SDK and the secret key must never ship in the app.** The phone can post
   scores with the public key, but then anyone holding that key can score any trace. Scoring
   through the server is safer.
7. **Built-in judges score one observation or one experiment item, never a whole session.**
   - Session-level (whole-conversation) evaluation is on Langfuse's roadmap.
   - A judge sees only its target observation's input, output, metadata and tool calls, so the
     transcript has to be written onto that observation.
   - Langfuse recommends one binary judge per failure mode, found by error analysis. Our Judge
     gives one weighted 0–100 Mark.
   - Langfuse's tools for measuring agreement between a judge and a human work only on boolean
     and categorical scores.
8. **In-UI prompt experiments are one model call per item, with no tools.** They cannot run
   Vana. What can:
   - The SDK experiment runner (`langfuse.experiment.run`, on Node).
   - A **Custom Experiment** webhook: Langfuse POSTs `{datasetId, config}` to our endpoint, which
     returns 2xx quickly and runs asynchronously. Its config JSON maps onto the existing Run
     overrides.
9. **Prompt management.**
   - A cold fetch takes about 37 ms, with unlimited fetches.
   - The SDK cache lasts 60 s and serves a stale copy while it refreshes; cold edge isolates
     will mostly miss it.
   - A missing label returns a hard 404.
   - Using a fallback prompt drops the link between the generation and the prompt version.
   - A signed webhook fires on prompt changes, which could mirror prompts into Postgres.
   - Protected labels require Pro plus the Teams add-on.
10. **Media.** Base64 images in AI SDK prompts are uploaded to Langfuse. URL images are not, so
    expiring Supabase signed URLs will stop rendering. Cloud allows 5 MB per request.
11. **Plans.**
    - **Hobby:** $0, 50k units, 30 days of data, 2 users, 1 annotation queue, 30 API
      requests/min, and 100 Metrics API calls/day.
    - **Core:** $29, 100k units, 90 days, unlimited users, 3 queues.
    - **Pro:** $199, 3 years of data, HIPAA region, SOC 2 and ISO reports.
    - Overage is $8 per 100k units. A unit is a trace, an observation or a score.
    - Judge runs and experiments also consume units. Judge model spend is billed by the model
      provider, not by Langfuse.
12. **Self-hosting.**
    - All product features are MIT-licensed, including queues, judges, playground and
      experiments.
    - These need an EE license: project-level RBAC, protected labels, retention policies, audit
      log, server-side masking, SCIM.
    - The in-app Assistant is Cloud-only.
    - Needs 4 cores, 16 GiB RAM, Postgres, ClickHouse, Redis and S3; about $130/month or more.
      The v3→v4 upgrade is heavy.
    - **Running both is possible** with two span processors, but ingestion is doubled and
      prompts, scores and datasets never sync. An official script migrates self-host to Cloud.
      Xuan gets the same web UI on either.
13. **Xuan.**
    - She needs at least the **Member** role; Viewers cannot score.
    - An annotation queue cannot be edited after it is created.
    - Independent double-rating probably needs one queue per reviewer (uncertain).
14. **Tooling.**
    - A Langfuse MCP server exists (prompts and traces). The authenticated server has write
      tools on by default.
    - A Langfuse skill for coding agents exists.
    - Alerts can post to Slack, a webhook or GitHub Actions; Hobby allows 2.
    - `LANGFUSE_SAMPLE_RATE` is not implemented in the JS SDK; sample with an OpenTelemetry
      sampler.
    - Tags cannot be changed after ingestion.
    - Propagated metadata values must be strings of 200 characters or less.
15. **Ownership.** ClickHouse acquired Langfuse on 2026-01-16. The MIT license and Cloud are
    stated to continue unchanged.

## Open questions, round 1

Each question lists its options and the recommendation (➡️). None of them is answered yet.

**Q1 Hosting.**
- (a) Cloud only, on Core.
- (b) Cloud on Hobby.
- (c) Self-host.
- (d) Both.

➡️ (a) Cloud Core, US region. Self-hosting adds nothing Xuan needs, and running both doubles the
work while prompts, scores and datasets never sync.

**Q2 What gets traced.**
- (a) The eval app only.
- (b) (a) plus dev edge functions.
- (c) (b) plus prod: every AI call site above.

➡️ (c). Live judges, review queues and cost per athlete all need real traffic.

**Q3 Projects and environments.**
- (a) One project, with environments `production`, `development` and `eval`.
- (b) Separate prod and dev projects.

➡️ (a). Datasets, prompts, judges and queues belong to a project, so a prod failure can become
a dataset item and a prompt can be promoted from dev to prod in one place.

**Q4 Athlete data in prod traces.** This covers the Context block (profile, workouts, meals,
macros, memories) and meal photos.
- (a) Send everything, with 90-day retention and Langfuse added to the subprocessors in
  `docs/privacy`.
- (b) Send everything except photos.
- (c) Mask identifying fields.

➡️ (a). Also confirm that nutrition data is not PHI for us.

**Q5 The eval app's role.**
- (a) The eval app stays the runner and Langfuse becomes the record and UI.
  - Scenarios become dataset items and Runs become experiment runs.
  - The Simulated athlete, `vana-eval` and the data diff stay.
  - Tickets 09–11 are dropped in favour of Langfuse comparison.
- (b) Build both systems in full.
- (c) Retire the eval app.

➡️ (a). Langfuse's simulation guide has the same shape as ours but no simulator.

**Q6 Prompt management.**
- (a) Move every prompt into Langfuse, fetched at runtime in prod, with a copy in code as
  fallback.
- (b) Dev and eval only.
- (c) Record the prompt version in metadata only.

➡️ (a). The fetch cost is small and the copy in code covers outages. The tradeoff: when the
fallback serves, that generation loses its prompt link.

**Q7 Where cost truth lives.**
- (a) The budget, Wallet and Call log stay in code as the enforcement. We send the exact Gateway
  cost into Langfuse for analysis.
- (b) Langfuse estimates cost from custom prices.
- (c) Langfuse replaces the Call log.

➡️ (a). Budget enforcement must not depend on a third party.

**Q8 Flutter.**
- (a) No direct Langfuse link. Server traces carry the user and use the conversation as the
  session.
  - Add a new thumbs up/down on each Vana reply: the app calls `vana-action`, which posts a
    Langfuse score.
  - `saveFeedback` also becomes a score.
- (b) Same, with no thumbs UI.
- (c) The app posts scores directly with the public key.

➡️ (a). The thumbs UI is a product decision for Lee.

**Q9 Xuan's jobs in Langfuse** (multi-select).
- (a) Review queues.
- (b) Edit and promote prompts.
- (c) Start Custom Experiments.
- (d) Dashboards only.

➡️ (a) + (b) + (c), with the Member role.

## Later rounds (blocked on round 1)

- **The Judge and Mark versus Langfuse's binary judge-per-failure-mode pattern.**
  - Whether our Judge posts scores through the API or becomes managed evaluators.
  - How a conversation-level judgement is represented.
  - The glossary clash: our CONTEXT says avoid "score", but Langfuse's primitive is the Score.
- **Live LLM-as-judge on sampled prod traffic.** Which failure modes, what sampling rate, which
  judge model (through the Gateway's OpenAI-compatible endpoint), and the monthly cost ceiling.
- **Error-analysis loop.** Queue design (a flagged queue plus a random-sample queue), who codes
  failures, and where the failure taxonomy lives.
- **Datasets.** Seeding from existing Scenarios, prod-trace-to-dataset flow, reference-based
  versus reference-free datasets, and whether experiments gate CI.
- **Runtime.** A Deno and Sentry OpenTelemetry coexistence canary; whether the edge functions
  move to AI SDK 7; flush and latency impact on streaming chat.
- **Trace shape for a Vana Turn.** Mapping trace, generation, tool and step, plus where
  `onTrace` fits. Also whether to trace embeddings, background extraction and the changelog
  script.
- **Dashboards and alerts.** Cost per athlete, feature, model and prompt version; spend and
  error alerts to Slack.
- **Langfuse MCP server and coding-agent skill.** Read-only or write access, and for whom.
- **Secrets.** Where keys live: `secrets/langfuse.env`, Supabase function secrets for dev and
  prod, and Vercel env for the eval app.
- **Sequencing.** Where this sits relative to the testing-wave fixes and eval-v2 ticket 08's
  uncommitted work. The eval-v2 spec's "Langfuse optional later" clause needs rewriting.
