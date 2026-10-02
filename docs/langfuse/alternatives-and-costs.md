# Eval and observability tools in 2026: what's out there, what it costs, and what we should do

> **Decision, 2026-09-30:** Lee chose Langfuse, against this note's "keep what we built". The
> note stays as researched. Its judge-cost findings (section 7) still apply: Langfuse doesn't
> change what the Judge's tokens cost. See [README.md](README.md).

Researched 2026-09-29 against vendor pricing pages, vendor docs, GitHub (`gh api`, stars as of that
day), Anthropic's docs, Consumer Terms and Help Center, AWS docs and pricing, OpenAI's docs and
deprecations page, and Vercel's AI Gateway docs and live `/v1/models`. Prices and features were
fetched live that day and will drift. Judge cost figures also use the 8 most recent Opus-judged
Runs in the dev `eval.runs` table (read-only query, same day).

Scope: tools that could replace or sit beside the eval-v2 system described in `../mealvana_eval/CONTEXT.md` and
`../mealvana_eval/.scratch/eval-v2/spec.md`, and the cheapest way to pay for the Judge. Langfuse, AgentCore
Evaluations and Vercel's offerings are covered in their own notes; this one summarizes and links
them rather than redoing them:
[research.md](research.md), [agentcore-evaluations.md](../../../mealvana_eval/docs/research/agentcore-evaluations.md),
[vercel-ai-evals.md](../../../mealvana_eval/docs/research/vercel-ai-evals.md).

Facts carry a link. Lines marked **Judgement** are mine.

## Summary

- **The Judge's tokens are almost the whole bill, not platforms.** In our last 8 Opus-judged Runs
  the Judge cost $0.07 to $0.65 each (mean $0.34). Vana cost about $0.01 to $0.02 and the Simulated
  athlete about $0.02. That puts an Eval round of 25 Runs at about **$8 on Opus 5.5**. Every
  platform below still bills judge tokens at model rates on top of its own fee.
- **Cheapest levers, in order (Judgement):** Sonnet 5/5.5 as Judge (half of Opus 5.5's price, about
  $4 a round), Batch (another 50% off, about $2 a round on Sonnet, but no structured output through
  the Gateway's AI SDK batch path), then Haiku 4.5. Prompt caching barely helps, because each
  Run's trace is different.
  [Claude pricing](https://platform.claude.com/docs/en/about-claude/pricing),
  [Gateway batch](https://vercel.com/docs/ai-gateway/models-and-providers/batch-processing)
- **Vercel AI Gateway adds no markup** on tokens, including BYOK, and has its own 50%-off batch
  API (beta). [Gateway pricing](https://vercel.com/docs/ai-gateway/pricing). Moving the Judge to
  Anthropic's API directly saves nothing on price.
- **Running the Judge on a Claude subscription (`claude -p` on Lee's own machine) is documented
  and currently draws from subscription limits.** Anthropic paused its plan to move `claude -p`
  onto a separate credit on 2026-06-15 and says it will give notice before any change.
  [Help Center](https://support.claude.com/en/articles/15036540-use-the-claude-agent-sdk-with-your-claude-plan).
  Putting Lee's subscription token into the Vercel app, or letting Xuan's clicks spend it, is
  where the terms get murky. Details in section 5.
- **Hosted platforms that judge a whole multi-turn conversation natively:** Braintrust (trace-scope
  scorers with `{{thread}}`), LangSmith (OpenEvals multi-turn simulation), Opik (thread metrics),
  Arize (session-level evals), MLflow 3.10+ (session judges and a conversation simulator),
  DeepEval (conversational metrics and simulator). Langfuse still doesn't, as of today.
- **Free tiers that fit two people:** Opik Cloud (25k spans, 10 users, 60 days), Arize AX Free (25k
  spans, unlimited users), Braintrust Starter (1 GB, 10k scores, unlimited users, 14 days),
  Logfire (10M records, 1 admin plus 2 read-only guests), Langfuse Hobby (50k units, 2 users).
  Open source with no fee: promptfoo, DeepEval, Inspect, Phoenix, Opik, Langfuse, MLflow.
- **Things that went away or changed in 2026:** OpenAI is shutting down its Evals platform and
  graders on 2026-11-30 and points users to promptfoo, which OpenAI acquired in March.
  Helicone joined Mintlify and is in maintenance mode. ClickHouse acquired Langfuse.
- **Anthropic has no hosted agent-eval product.** The Console's old Evaluate tab was for
  single-prompt tests, and its docs page now redirects to general eval guidance. The useful
  Anthropic material is guidance (Jan 2026 "Demystifying evals for AI agents"), which describes
  roughly the design we already built.
- **Recommendation (Judgement):** keep what we built. Make the Judge model a cheaper default for
  routine rounds (Sonnet), keep Opus for rounds that decide things, and optionally batch full
  Eval rounds. Revisit a hosted tool only for human-vs-Judge agreement or if our trace UI becomes a
  burden. If we do, Braintrust Starter or Opik Free are the free options that Mark whole
  conversations.

## 1. What we already have, in one paragraph

A Next.js app on Vercel runs scripted or simulated Scenarios against Vana through `vana-eval`,
stores the full trace in Supabase, checks Tool expectations in code, and has one Judge call
(Opus 5.5 via the Gateway) Mark the whole Run against a versioned, weighted Rubric. Code computes
the Mark and the robotic cap. See `../mealvana_eval/CONTEXT.md` and `../mealvana_eval/.scratch/eval-v2/spec.md`. **Judgement:** this
is the shape Anthropic's own guidance recommends: code graders where possible, one model grader
with a structured rubric, a second LLM to play the user, and reading transcripts.
[Demystifying evals](https://www.anthropic.com/engineering/demystifying-evals-for-ai-agents)

## 2. Popular alternatives to Langfuse

Langfuse, for reference ([our note](research.md)): MIT core; Hobby is free (50k units, 2 users,
30 days) and Core is $29/mo. Its managed judge scores one observation, and trace-level evaluators
are deprecated from 2026-11-16, so it can't Mark a whole Run natively. ClickHouse acquired it in
January 2026, and it stays open source.
[ClickHouse blog](https://clickhouse.com/blog/clickhouse-acquires-langfuse-open-source-llm-observability).
It has 35.2k GitHub stars.

### Braintrust (hosted, closed source)

- **Pricing:** Starter $0/mo: 1 GB processed data (+$4/GB), 10k scores (+$2.50/1k), 14-day
  retention, unlimited users, $10/mo model credits. Pro $249/mo: 5 GB, 50k scores, 30 days.
  Enterprise is custom. [pricing](https://www.braintrust.dev/pricing)
- **Whole-conversation judging: yes.** Trace-scope scorers run "once per trace", and LLM judges
  can use `{{thread}}` populated from the trace. Code scorers get `trace.getThread()` and
  `trace.getSpans()`. [score online](https://www.braintrust.dev/docs/observe/score-online),
  [multi-turn scoring](https://www.braintrust.dev/blog/multi-turn-scoring)
- **Ingestion:** OpenTelemetry exporter or span processor, plus a Vercel AI SDK integration and a
  Vercel Marketplace listing.
  [OTel](https://braintrust.dev/docs/integrations/sdk-integrations/opentelemetry/send-traces-and-logs.md),
  [Vercel](https://braintrust.dev/docs/integrations/sdk-integrations/vercel.md),
  [marketplace](https://vercel.com/marketplace/braintrust)
- **Simulated users:** we found no built-in simulator in the docs index.
  [llms.txt](https://braintrust.dev/docs/llms.txt)
- **Self-host:** Enterprise only (hybrid data plane).
  [self-hosting](https://www.braintrust.dev/docs/admin/self-hosting)
- **Popularity:** its `autoevals` library has 1.0k stars. The platform itself is closed.
- **Judgement:** the best hosted fit for Marking whole Runs, and the free tier probably covers
  us. Scores are capped at 10k/mo, and we'd use about 15 per Run. It's still a second home for
  athlete-derived data.

### LangSmith (LangChain; hosted, closed source)

- **Pricing:** Developer $0: 1 seat, 5k base traces/mo, then pay as you go. Plus is $39/seat/mo
  with 10k base traces. Base traces keep 14 days. Enterprise adds self-hosting.
  [pricing](https://www.langchain.com/pricing)
- **Multi-turn:** OpenEvals' `run_multiturn_simulation` with `create_llm_simulated_user`, and
  trajectory evaluators run on the final message list.
  [multi-turn simulation](https://docs.langchain.com/langsmith/multi-turn-simulation),
  [openevals](https://github.com/langchain-ai/openevals) (1.2k stars)
- **Ingestion:** AI SDK v7 via `LangSmithTelemetry()`, v5/v6 via `wrapAISDK()`.
  [Vercel AI SDK](https://docs.langchain.com/langsmith/trace-with-vercel-ai-sdk)
- **Judgement:** the free tier is one seat, so Xuan would need Plus ($39/mo). It isn't free
  for us.

### Arize Phoenix (open source) and Arize AX (hosted)

- **Phoenix:** Elastic License 2.0 (source-available, not OSI), 11.7k stars, self-hosted for free.
  [LICENSE](https://github.com/Arize-ai/phoenix/blob/main/LICENSE),
  [self-hosting](https://arize.com/docs/phoenix/self-hosting)
- **AX:** Free is 25k spans/mo, 1 GB, 15 days, unlimited users. Pro is $50/mo for 50k spans and
  10 GB. [pricing](https://arize.com/pricing/)
- **Whole conversation: yes, as a recipe.** Group turns by `session_id`, build one transcript,
  run session-scoped judges, and log results back onto the session.
  [Phoenix session-level eval](https://arize.com/docs/phoenix/cookbook/evaluation/session-level-evaluation),
  [AX session evals](https://arize.com/docs/ax/evaluate/session-level-evaluations)
- **Judgement:** that recipe is what our Judge already does. The gain is a viewer.

### Weights & Biases Weave

- **Pricing:** Free has 1 GB/mo ingestion. Pro starts at $60/mo for 1.5 GB, then $0.10/MB.
  [pricing](https://wandb.ai/site/pricing/)
- Python and TypeScript SDKs, OTel ingestion, LLM judges and custom scorers.
  [docs](https://docs.wandb.ai/weave/). Apache-2.0 SDK with 1.1k stars. We found no
  conversation-level judge or simulator on the overview page.
- **Judgement:** full traces with tool I/O would use up 1 GB quickly, and the $0.10/MB overage
  is steep.

### Helicone

- Free Hobby tier: 10k requests/mo, 7 days, 1 seat. Pro is $79/mo.
  [pricing](https://www.helicone.ai/pricing)
- **It joined Mintlify in March 2026 and is in maintenance mode:** "security updates, new
  models, bug & performance fixes all keep shipping", with no new features.
  [announcement](https://www.helicone.ai/blog/joining-mintlify)
- **Judgement:** skip it. It's a proxy and logger, not a whole-conversation judge, and it's winding down.

### Opik (Comet)

- **Pricing:** Free Cloud is 25k spans/mo, up to 10 team members, 60 days. Pro is $19/mo for
  100k spans, then $5/100k. Open source is free with no limits.
  [pricing](https://www.comet.com/site/pricing/)
- **Whole conversation: yes.** Traces grouped by `thread_id`, with conversational metrics
  (heuristic and LLM judge) and `evaluate_threads`. They also work on conversations sourced
  outside Opik. [conversation metrics](https://www.comet.com/docs/opik/evaluation/metrics/conversation_threads_metrics)
- **Simulated users:** `SimulatedUser` and `run_simulation`, documented in Python only.
  [multi-turn agents](https://www.comet.com/docs/opik/evaluation/advanced/evaluate_multi_turn_agents)
- Apache-2.0, 22.3k stars.
- **Judgement:** the most generous free tier for two people, at $19 if we outgrow it. Still a
  duplicate of our UI.

### promptfoo (now OpenAI)

- MIT, 25.6k stars, a Node CLI and library. Community is free: all eval features, local or
  self-hosted, and 10k red-team probes/mo. Enterprise is custom.
  [pricing](https://www.promptfoo.dev/pricing/)
- OpenAI announced the acquisition on 2026-03-09. Promptfoo says it "will remain open source"
  and "continue to support a diverse range of providers".
  [OpenAI](https://openai.com/index/openai-to-acquire-promptfoo/),
  [promptfoo blog](https://www.promptfoo.dev/blog/promptfoo-joining-openai/)
- **Multi-turn:** a simulated-user provider with `instructions` and `maxTurns` (default 10). It
  stops on `###STOP###` and runs `llm-rubric` assertions over the conversation. Targets can be an
  HTTP endpoint, and a Vercel AI Gateway provider exists.
  [simulated user](https://www.promptfoo.dev/docs/providers/simulated-user/),
  [HTTP provider](https://www.promptfoo.dev/docs/providers/http/),
  [Vercel provider](https://www.promptfoo.dev/docs/providers/vercel/)
- **Judgement:** the closest free, TypeScript-native, CLI-shaped equivalent of our runner. It has
  no data-diff, Eval athletes, or Mark arithmetic. It would suit a CI smoke test more than it
  would replace our app.

### DeepEval and Confident AI

- DeepEval: Apache-2.0, 18.5k stars, Python. `ConversationalTestCase` works with conversational
  metrics such as `ConversationalGEval`, and there's a `ConversationSimulator`. Anthropic models
  can be judges.
  [multi-turn](https://deepeval.com/docs/evaluation-multiturn-test-cases),
  [simulator](https://deepeval.com/docs/conversation-simulator),
  [Anthropic](https://deepeval.com/integrations/models/anthropic)
- Confident AI (hosted): Free is 2 seats, 1 project, 5 test runs/week, 1 GB-month. Starter
  is $200/mo. [pricing](https://www.confident-ai.com/pricing)
- **Judgement:** a Python library next to a TypeScript app, and 5 test runs a week is too few.

### Inspect AI (UK AI Security Institute)

- MIT, 2.9k stars, Python only. Tasks, datasets, solvers (including a ReAct agent), scorers
  (including model-graded), Anthropic models, and the Inspect View log viewer.
  [docs](https://inspect.aisi.org.uk/)
- **Judgement:** built for benchmark-style capability and safety evals, and it's Python. Not our
  shape.

### OpenAI Evals framework (the open-source repo)

- `openai/evals`: MIT, 19.5k stars, last commit 2026-04-14. It's the old benchmark registry, not
  the platform. [repo](https://github.com/openai/evals). See section 4 for the platform.

### Laminar

- Apache-2.0, 3.3k stars. Tracing (Vercel AI SDK and Claude Agent SDK among 15+ integrations),
  "Signals" failure clustering, evals, self-hosting via Docker or Helm. Users named include
  Browser Use and All Hands. [site](https://laminar.sh/)
- Free is 1 GB, 7 days, 1 seat, 1 project. Starter is $30/mo for 3 GB, 30 days, unlimited seats.
  [pricing](https://laminar.sh/pricing)
- **Judgement:** the free tier has 1 seat. Its strength is finding failures in production
  traffic, which we don't have.

### Logfire (Pydantic)

- OTel-native. Evals via pydantic-evals. [docs](https://pydantic.dev/docs/logfire/).
  The SDK is MIT (4.5k stars). Self-hosting is on Enterprise only.
- Free: 10M records/mo, 1 admin plus 2 read-only guests, 30 days. Team is $49/mo.
  [pricing](https://pydantic.dev/pricing)
- **Judgement:** a generous general OTel store, but Python-first for evals.

### Also popular in 2026

- **MLflow** (Apache-2.0, 28.2k stars). 3.10 added a conversation simulator (goals and personas)
  and session-level judges (`ConversationCompleteness`, `UserFrustration`,
  `KnowledgeRetention`). The simulator is documented in Python.
  [multi-turn](https://mlflow.org/docs/latest/genai/eval-monitor/running-evaluation/multi-turn/),
  [simulation](https://mlflow.org/docs/latest/genai/eval-monitor/running-evaluation/conversation-simulation/)
- **LangWatch Scenario** (Apache-2.0, 1.0k stars) is a simulated-user testing library.
  [repo](https://github.com/langwatch/scenario)
- Others with real adoption: Ragas (15.9k), Evidently (7.9k), OpenLLMetry (7.5k), Agenta (4.8k),
  per `gh api` today.

## 3. Anthropic (first-party)

- **Console Evaluate tab (2024):** generate test cases, compare prompt versions side by side,
  and have "subject matter experts grade response quality on a 5-point scale". It's
  single-prompt. [blog, 2024-07-09](https://claude.com/blog/evaluate-prompts). The old docs URL
  `test-and-evaluate/eval-tool` now serves "Define success criteria and build evaluations"
  (checked today). That page covers code, LLM (Likert, binary, ordinal) and human grading
  through the normal Messages API at normal rates, and advises "use a different model to
  evaluate than the model used to generate". [develop tests](https://platform.claude.com/docs/en/test-and-evaluate/develop-tests)
- **Agent eval guidance:** "Demystifying evals for AI agents" (2026-01-09) says to start with 20
  to 50 tasks from real failures. It covers code, model and human graders, calibrating the LLM
  judge against humans, giving it an "Unknown" way out, a second LLM to simulate the user, and
  pass@k / pass^k. It names Harbor, Braintrust, LangSmith, Langfuse and Arize.
  [article](https://www.anthropic.com/engineering/demystifying-evals-for-ai-agents)
- **Claude Agent SDK / `claude -p`:** an agent loop with `--output-format json --json-schema`
  for structured output and `total_cost_usd` in the result. It isn't an eval product.
  [headless](https://code.claude.com/docs/en/headless)
- **What's free:** the guidance and the Console UI. Every model call is billed at API rates.
  **Judgement:** we found no hosted Anthropic tool that Marks multi-turn agent Runs.

## 4. OpenAI

- **The Evals platform and graders are being shut down.** Deprecation was announced 2026-06-03.
  Evals go read-only on 2026-10-31, and the dashboard and API shut down on 2026-11-30. "Graders
  documented for eval workflows are part of this transition." The migration path OpenAI
  suggests is promptfoo. [deprecations](https://developers.openai.com/api/docs/deprecations),
  [evals guide](https://developers.openai.com/api/docs/guides/evals),
  [graders](https://developers.openai.com/api/docs/guides/graders),
  [migration cookbook](https://developers.openai.com/cookbook/examples/evaluation/moving-from-openai-evals-to-promptfoo)
- **Trace grading:** graders over traces in Logs > Traces, "from SDK-based apps", meaning OpenAI
  Agents SDK traces. [trace grading](https://developers.openai.com/api/docs/guides/trace-grading),
  [agent evals](https://developers.openai.com/api/docs/guides/agent-evals). Vana doesn't emit
  those.
- **Non-OpenAI outputs:** the agent-evals page mentions "evaluation against external models" via
  Evals, the product being shut down.
- **Free usage:** a data-sharing program gave up to 1M (tiers 1 to 2: 250k) free tokens/day on
  large models, in exchange for sharing inputs and outputs with OpenAI.
  [Help Center](https://help.openai.com/en/articles/10306912-sharing-feedback-evaluation-and-fine-tuning-data-and-api-inputs-and-outputs-with-openai)
  (returned 403 to our fetch, so this is from search snippets and its model list may be stale).
  **Judgement:** sharing athlete-derived conversations with OpenAI for training is a
  non-starter, so this doesn't apply to us.
- **Judgement:** nothing to adopt. A GPT model through the Gateway can be a second Judge
  without any OpenAI eval product.

## 5. AWS Bedrock

- **Bedrock Model Evaluation (LLM-as-a-judge):** built-in metrics or custom metrics, with scores
  plus explanations. **Bring your own inference responses:** "you can evaluate a non-Amazon
  Bedrock model by providing your own inference response data", and Bedrock "skips the model
  invoke step". [judge](https://docs.aws.amazon.com/bedrock/latest/userguide/evaluation-judge.html)
- **But the record is single-turn:** JSONL `{prompt, referenceResponse?, category?,
  modelResponses:[{response, modelIdentifier}]}`, one response per prompt, one
  `modelIdentifier` per job, up to 1,000 prompts per job.
  [dataset format](https://docs.aws.amazon.com/bedrock/latest/userguide/model-evaluation-prompt-datasets-judge.html).
  A whole Run would have to be stuffed into `prompt`/`response` strings.
- **Judge models:** for custom metrics, the newest Claude models listed are Opus 4.8 and Sonnet
  4.6. There's no Opus 5.x (same page).
- **Pricing:** "the tokens that the judge model uses are charged based on the on-demand standard
  tier prices". Algorithmic scores are free, and human evaluation is $0.21 per task.
  [Bedrock pricing](https://aws.amazon.com/bedrock/pricing/)
- **AgentCore Evaluations** ([our note](../../../mealvana_eval/docs/research/agentcore-evaluations.md)): session, trace and tool-call
  levels, a simulated-user dataset runner, and an on-demand `Evaluate` API that takes spans
  inline. Conversations from outside AWS are possible if converted to OTel GenAI spans.
  Pricing: built-in evaluators cost $0.0024/1k input and $0.012/1k output tokens (batch $0.0018
  and $0.009). Custom evaluators cost "$1.50 per 1,000 evaluations (model usage billed
  separately)". [AgentCore pricing](https://aws.amazon.com/bedrock/agentcore/pricing/)
- **Bedrock Agent evaluation:** the old `awslabs/agent-evaluation` framework (375 stars, last push
  2025-12-15) has been overtaken by AgentCore Evaluations.
  [repo](https://github.com/awslabs/agent-evaluation)
- **Judgement:** AgentCore's platform fee is tiny (25 custom evaluations cost about $0.04), but
  judge tokens still cost model rates. It adds an AWS account, IAM, CloudWatch and span
  conversion for a Judge we already have. Not worth it for cost.

## 6. Paying for the Judge: subscriptions, Batch, caching, the Gateway

### 6a. Using a Claude subscription (`claude -p` as the Judge)

What the sources say:

- **Claude Code's docs document scripted use with a subscription.** `claude -p` runs
  non-interactively. `claude setup-token` makes a one-year OAuth token "for CI pipelines,
  scripts, or other environments where interactive browser login isn't available". Subscription
  OAuth is the default credential for Pro, Max, Team and Enterprise users. `--bare` mode "never
  reads OAuth credentials", so it needs an API key.
  [authentication](https://code.claude.com/docs/en/authentication),
  [headless](https://code.claude.com/docs/en/headless)
- **It currently counts against subscription limits.** Help Center, updated 2026-06-16: "For
  now, nothing has changed: Claude Agent SDK, `claude -p`, and third-party app usage still draw
  from your subscription's usage limits." The planned move to a separate monthly credit ($20 Pro,
  $100 Max 5x, $200 Max 20x, at API rates) was paused on 2026-06-15. Anthropic is "working to
  update the plan … we'll share it before anything takes effect". The paused text said the credit
  was "sized for individual experimentation and automation", and that "teams running shared
  production automation should use Claude Platform with an API key".
  [Help Center](https://support.claude.com/en/articles/15036540-use-the-claude-agent-sdk-with-your-claude-plan)
- **Limits:** "Advertised usage limits for Pro and Max plans assume ordinary, individual usage of
  Claude Code and the Agent SDK." [legal](https://code.claude.com/docs/en/legal-and-compliance).
  Max plans reset every five hours and have a weekly limit. Max 5x is $100/mo and Max 20x is
  $200/mo. [Max plan](https://support.claude.com/en/articles/11049741-what-is-the-max-plan)
- **The restrictions are about third parties and intermediation.** "OAuth authentication is
  intended exclusively for purchasers of … subscription plans and is designed to support
  ordinary use of Claude Code and other native Anthropic applications." "Developers building
  products or services … including those using the Agent SDK, should use API key
  authentication." Anthropic doesn't permit third-party developers "to route requests through
  Free, Pro, or Max plan credentials on behalf of their users", and developers "may not collect,
  store, or intermediate Claude.ai credentials or session tokens".
  [legal](https://code.claude.com/docs/en/legal-and-compliance). The Agent SDK overview repeats
  that third parties may not offer claude.ai login or rate limits "unless previously approved".
  [Agent SDK](https://code.claude.com/docs/en/agent-sdk/overview)
- **Consumer Terms (effective 2025-10-08):** users may not access the Services "through
  automated or non-human means, whether through a bot, script, or otherwise", "Except when you
  are accessing our Services via an Anthropic API Key or where we otherwise explicitly permit
  it". [Consumer Terms](https://www.anthropic.com/legal/consumer-terms)

What's plain, and what isn't:

- **Plain:** Lee running `claude -p` himself, on his own machine, signed in with his own plan, is
  a documented use that draws on his plan today. Anthropic's Help Center says so in as many words.
- **Plain:** a third party (Langfuse, Braintrust, a hosted app) can't use Lee's subscription as
  its judge. Those tools need API keys.
- **Unclear:** whether the Consumer Terms' "explicitly permit it" exception covers an unattended
  loop Marking dozens of Runs. No source says "automated eval pipelines on Pro/Max are
  permitted", and none forbids it. The Claude Code docs that document `claude -p` and
  setup-token for "scripts" are the nearest thing to explicit permission.
- **Unclear, and the part to avoid (Judgement):** putting Lee's `CLAUDE_CODE_OAUTH_TOKEN` into
  Vercel so the hosted app Marks Runs, especially Runs Xuan starts. That looks like storing a
  session token inside a service and spending one person's plan on another's requests, which the
  legal page targets.
- **Unstable:** Anthropic has already tried once to move `claude -p` off plan limits and says an
  update is coming. Anything built on this can lose its economics with a notice period.

**Judgement, practical shape if Lee wants it:** a local "Judge worker" script on Lee's Mac polls
Supabase for Runs awaiting a Mark. It calls `claude -p --model opus --output-format json
--json-schema <judge schema>` with the bundle on stdin (not `--bare`, which forces an API key),
then writes the Judge output back. The app would keep the Gateway Judge as the default and fallback.
That's worth it only if Lee already pays for Max for his own coding and has spare weekly
headroom. Buying Max to save about $100/mo of Judge tokens (section 7) is a wash. It also adds a
laptop-must-be-on dependency and a policy risk.

### 6b. Anthropic API cost levers

- **Opus 5.5:** $4/MTok input, $20/MTok output, cache hits $0.20. **Sonnet 5 / 5.5:** $2 / $10
  (Sonnet 5's $2/$10 promo became the standard price, and the planned rise to $3/$15 was
  cancelled). **Haiku 4.5:** $1 / $5. [pricing](https://platform.claude.com/docs/en/about-claude/pricing)
- **Batch API:** 50% off input and output. "Most batches finish in less than 1 hour", with a
  24-hour cap. It stacks with caching.
  [pricing](https://platform.claude.com/docs/en/about-claude/pricing),
  [batch processing](https://platform.claude.com/docs/en/build-with-claude/batch-processing)
- **Prompt caching:** writes cost 1.25x (5 min) or 2x (1 h), and reads 0.1x (0.05x on Opus 5.5).
  **Judgement:** only the Rubric and instructions (a few thousand tokens) repeat across Judge
  calls, and the 30k to 80k trace is unique per Run. Caching saves roughly 5%.

### 6c. Vercel AI Gateway

- "No markup and no platform fee on tokens", the same with BYOK. There's a monthly free credit
  on a free tier limited to a subset of models, and buying credits ends the free credit.
  Payment processing fees may apply. [pricing](https://vercel.com/docs/ai-gateway/pricing),
  [FAQ](https://vercel.com/docs/ai-gateway/faq). Live `/v1/models` today shows
  `anthropic/claude-opus-5.5` at $4/$20 and `claude-sonnet-5.5` at $2/$10, the same as Anthropic.
- **Batch (beta):** 50% off for Anthropic and OpenAI models, via AI SDK
  `experimental_startTextBatch` (needs `ai` ≥ 7.0.71), up to 1,000 requests and 4.5 MB per start
  request, 24-hour window. The AI SDK batch path does **not** support tool calls or structured
  output, and doesn't support ZDR. The native Anthropic Message batches endpoint through the
  Gateway is separate. [batch](https://vercel.com/docs/ai-gateway/models-and-providers/batch-processing)
- **Judgement:** a batched Judge would return JSON as text for us to parse and validate, which
  our malformed-output rejection already handles. The request limit is 4.5 MB, and 25 × 80k-token
  traces is about 8 MB of text, so one round would need about two batches. Our app is also on
  AI SDK 6, and batching needs 7.

## 7. Where the money goes, and Judge cost per Eval round

Observed (dev `eval.runs`, 8 Opus 5.5-judged Runs on 2026-09-29): the Judge cost $0.073, 0.242,
0.247, 0.273, 0.309, 0.418, 0.463 and 0.654 per Run (mean **$0.335**). Vana's cost was about
$0.007 to $0.021 and the Simulated athlete's about $0.011 to $0.024. **The Judge is about 90% of
every Run's cost.**

Estimate (**Judgement** on sizes): 25 Runs, 30k to 80k Judge input tokens, 3k to 6k output tokens
(ten reasons plus the structure). Prices from [Claude pricing](https://platform.claude.com/docs/en/about-claude/pricing),
the same through the Gateway.

| Judge | Per Run | Per Eval round (25) | Per month at 13 to 22 rounds* |
| --- | --- | --- | --- |
| Opus 5.5, standard (today) | $0.18 to $0.44 (observed mean $0.34) | $4.50 to $11 (observed ≈ $8.40) | ≈ $110 to $185 |
| Opus 5.5, Batch | $0.09 to $0.22 | $2.25 to $5.50 | ≈ $55 to $92 |
| Sonnet 5 / 5.5, standard | $0.09 to $0.22 | $2.25 to $5.50 | ≈ $55 to $92 |
| Sonnet 5 / 5.5, Batch | $0.045 to $0.11 | $1.10 to $2.75 | ≈ $27 to $46 |
| Haiku 4.5, standard | $0.045 to $0.11 | $1.10 to $2.75 | ≈ $27 to $46 |
| `claude -p` on an existing Max plan | $0 marginal (uses plan limits) | $0 marginal | $0 marginal, with the caveats in 6a |

\* 3 to 5 rounds a week, as estimated in [research.md](research.md). The monthly column uses the
observed Opus mean for the first row and scales the others by price.

Platform fees on top, for comparison: Langfuse Hobby $0 or Core $29, Braintrust Starter $0,
Opik Free $0 or Pro $19, Arize AX Free $0 or Pro $50, LangSmith Plus $78 for two seats, Laminar
Starter $30, Logfire Team $49. None of these removes the Judge's token cost. Braintrust Starter's
$10/mo model credit would cover about one Opus round.

## 8. Comparison table

| Tool | Open source? | Free tier | Paid entry | Whole-conversation judging | Simulated users | Fit for us (Judgement) |
| --- | --- | --- | --- | --- | --- | --- |
| **Ours (eval-v2)** | ours | n/a | Judge tokens only | Yes, one Judge per Run, Rubric, code Mark | Yes | Already fits. Cost is the Judge model. |
| Langfuse | MIT core (+ee) | Hobby: 50k units, 2 users, 30 d | Core $29/mo | No (trace evals deprecated; single observation) | Cookbook with OpenEvals | Low. [Our note](research.md). |
| Braintrust | No (SDKs MIT) | Starter: 1 GB, 10k scores, unlimited users, 14 d | Pro $249/mo | **Yes** (trace scope, `{{thread}}`) | Not built in | Best hosted fit if we ever buy. Free tier likely enough. |
| LangSmith | No (SDK MIT) | 1 seat, 5k traces | Plus $39/seat/mo | Yes (trajectory evaluators) | **Yes** (OpenEvals) | Needs 2 paid seats. |
| Arize Phoenix / AX | Phoenix ELv2 | AX: 25k spans, unlimited users, 15 d | AX Pro $50/mo | Yes (session-level recipe) | No | Viewer only. We already do the recipe. |
| W&B Weave | SDK Apache-2.0 | 1 GB/mo | $60/mo | Custom scorers only | No | Traces too big for its pricing. |
| Helicone | Apache-2.0 | 10k req, 7 d, 1 seat | $79/mo | No | No | Skip (maintenance mode). |
| Opik | Apache-2.0 | 25k spans, 10 users, 60 d | $19/mo | **Yes** (thread metrics) | Yes (Python) | Best free hosted tier for two people. |
| promptfoo | MIT (OpenAI-owned) | All eval features, local | Enterprise custom | Yes (`llm-rubric` on conversation) | **Yes** | Good for a CI smoke test, not a replacement. |
| DeepEval / Confident AI | Apache-2.0 / hosted | 2 seats, 5 test runs/wk | $200/mo | Yes (conversational metrics) | Yes (Python) | Python, and the free tier is too small. |
| Inspect AI | MIT | Free | n/a | Via custom scorer | Via solver | Benchmark-shaped, Python. |
| OpenAI Evals platform | No | n/a | Token rates | Trace grading (Agents SDK) | No | Shutting down 2026-11-30. |
| Laminar | Apache-2.0 | 1 GB, 7 d, 1 seat | $30/mo | Evals plus Signals | No | For production failure mining, not us. |
| Logfire | SDK MIT | 10M records, 1 admin + 2 guests | $49/mo | pydantic-evals (Python) | No | Python-first. |
| MLflow | Apache-2.0 | Free (self-host) | n/a | **Yes** (session judges) | **Yes** (Python) | Needs a server, and it's Python. |
| Bedrock Model Evaluation | No | Token rates only | Token rates | No (single prompt/response) | No | Poor fit. No Opus 5.x judge. |
| AgentCore Evaluations | No | $200 new-AWS credit | $1.50/1k custom evals + tokens | **Yes** (session level) | **Yes** | Cheap fee, heavy setup. [Our note](../../../mealvana_eval/docs/research/agentcore-evaluations.md). |
| Anthropic Console Evaluate | No | Free UI | API rates | No (single prompt) | No | Not for agents. |
| Vercel AI Gateway (evaluate/Jev, batch) | No | Monthly free credit (subset of models) | No markup | Jev has no rationale | No | Keep as transport. Batch is a lever. [Our note](../../../mealvana_eval/docs/research/vercel-ai-evals.md). |

## 9. Recommendation for Lee (Judgement)

1. **Keep what we built.** No tool above Marks a whole Run against a weighted, versioned Rubric
   with a code-computed Mark, Tool expectations at the failing step, a data diff, and throwaway
   Eval athletes. The ones that judge whole conversations (Braintrust, Opik, AgentCore, MLflow)
   would still need our bundle and our arithmetic. Their fees are small, but none makes the
   Judge cheaper.
2. **Cut the Judge bill with the model, not a platform.** Make Sonnet 5.5 the default Judge for
   routine rounds and ad hoc Runs, which halves the cost (about $8 to about $4 a round). Keep
   Opus 5.5 for rounds that decide whether an Improvement ships. Before switching, re-Mark 5 to
   10 existing Runs with both and compare dimension marks. The pass bar at 90/80 is sensitive to
   Judge drift, and the Rubric anchors exist for exactly this.
3. **Batch Eval rounds if the wait is fine.** Another 50% off, via the Gateway batch API (AI SDK
   7, JSON-as-text) or Anthropic's API directly. Keep single Runs synchronous so the Run page
   still Marks live. This is the most code of the three.
4. **`claude -p` on Lee's Max plan: only as a personal side path.** It's allowed for Lee's own
   scripted use today and draws from his plan. Don't put his token into Vercel or spend it on
   Xuan's Runs. Expect the rules to change. It's worth doing only if he already has Max with
   headroom.
5. **Skip:** OpenAI Evals (shutting down), Helicone (maintenance), Bedrock Model Evaluation
   (single-turn), LangSmith (paid seats), and AgentCore for cost reasons.
6. **Revisit a hosted tool only when** we want Xuan's human Marks next to the Judge with an
   agreement number, or our trace UI becomes a burden. Then try Braintrust Starter or Opik Free,
   forwarding stored Runs from Next.js as in the lean option in [research.md](research.md). Both
   Mark whole conversations for free, which Langfuse doesn't.
