# Langfuse pivot: research report and open questions

Written 2026-09-30, at the start of a `/grill-with-docs` session. Lee is replacing the bespoke
eval and observability work with Langfuse and wants every Langfuse feature that fits: tracing,
cost breakdowns, prompt management, evals, experiments, and review by Xuan. The grilling
finished the same day; Lee's decisions are under "Decisions" at the end.

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
| `05-simulation-and-evaluators.md` | Whether Langfuse can run simulated conversations itself (no), the least code we own, the evaluator gallery, judges through the Gateway |
| `06-true-cost-and-vercel-hosting.md` | Getting the Gateway's exact charge onto a generation, and staying on Supabase Edge versus moving to Vercel |
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

## Corrections to the facts above

- Fact 5: through the Gateway the model name that reaches Langfuse is the upstream ID
  (`claude-haiku-4-5-20251001`), which does match Langfuse's built-in prices. Estimated cost
  equalled the Gateway's charge to 8 decimals in five probe calls (`06`, section A).
- Fact 5: a v4 dashboard widget can group cost by `userId` as a top-N table or bar.

## Decisions (Lee, 2026-09-30)

**Scope**
- The pivot is complete. The eval app's screens, Judge, Mark, Rubric and Scenario store go.
  Langfuse's vocabulary replaces the eval glossary (`CONTEXT.md`, "Judging Vana").
- Turn, Step and Conversation stay as app words: a Turn is a trace, a Step a generation, a
  Conversation a session.
- The Call log, Wallet and Monthly budget stay and keep enforcing spend. Langfuse shows cost.

**Hosting and plan**
- Langfuse Cloud, US region, Hobby. Stay on Hobby until a limit is actually hit; with one
  annotation queue allowed, delete each queue before making the next.
- A Docker Langfuse on Lee's Mac comes later, as a sandbox for trying features and heavy
  experiment batches. Deployed edge functions cannot reach it, so Cloud is where Xuan works and
  where dev and prod traces go.
- Vana stays on Supabase Edge. Prove tracing with one dev deploy; if the SDK fails there, send
  OTLP by hand.
- The orchestrator-with-subagents idea gets its own grilling after tracing exists, then a
  Langfuse experiment compares it with today's single Vana.

**Tracing**
- Dev first, then prod once dev is proven and the privacy documents name Langfuse. Prod sends
  everything, meal photos included.
- Trace every chat Turn, describe-meal, meal photo and the background calls. Leave embeddings out.
- Langfuse shows the Gateway's true charge on each generation.

**Prompts**
- All static prompt text and each call's model choice move to Langfuse. The Context block builder
  and tool definitions stay in code. Code carries a bundled copy for outages.
- Dev reads the `latest` label and prod reads `production`. Moving `production` is publishing;
  moving it back is the undo. No `staging` label and no gate.

**Evaluation**
- Start with Langfuse's ready-made user-signal evaluators to flag conversations for review.
- Two custom evaluators from day one: the dietitian evaluator and the robotic check. Others come
  from what review finds. Tool expectations become code checks.
- The dietitian evaluator is pass or fail, tuned to agree with Xuan's labels. Dr. Mitchell is
  out of scope.
- The 22 Scenarios in `eval/scenarios` carry over as the first dataset.
- Experiments on full Vana run through one endpoint: `../mealvana_eval` stripped to the Custom
  Experiment webhook on Vercel.
- Xuan has the Member role and does everything: review, corrections, prompts, starting runs.

**Models and spend**
- Never Opus. Evaluators start on Haiku 4.5 and move to Sonnet 5.5 only if agreement with Xuan
  is poor. Simulated athlete on Haiku 4.5. Vana chat stays on Haiku 4.5. Describe-meal and meal
  photo move from Sonnet 4.6 to Sonnet 5.5 after one experiment confirms quality.
- The Gateway's prepaid credits are the overall backstop. The evals key gets its own $20 monthly
  budget so evaluators and experiments cannot drain prod's balance.

**Athlete feedback**
- First: a conversation-signal evaluator (corrections, repeats, frustration) and a Score when a
  plan is confirmed or its Draft abandoned.
- Later, as its own ticket: thumbs down with a reason picker.
- Not doing: a signal for planned meals being logged later, or for swapping a meal Vana placed
  (the athlete ticks meals from the Meal picker; Vana rarely places them).
- Wiredash and shake-to-report stay for general bug reports.

**Tooling**
- The Langfuse skill, CLI and MCP server (read and write) are installed; keys in
  `secrets/langfuse.env`.

**Order of work**
1. Prove tracing on dev: one function, the trace arrives, its cost equals the Call log's.
2. Trace every call site on dev with user, session and true cost.
3. Move prompts into Langfuse.
4. Strip the eval repo to the Run endpoint; carry the Scenarios into a dataset.
5. Flag evaluators, dietitian evaluator, robotic check, first review queue with Xuan.
6. Privacy documents updated, then prod tracing on.
7. Later and separate: thumbs down UI, Docker sandbox, orchestrator comparison.

Langfuse work starts now, alongside the testing-wave fix tickets. The uncommitted eval-v2 ticket
08 work is discarded except the Run overrides, if the Run button's settings need them.
