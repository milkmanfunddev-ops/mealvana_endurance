# Video summary: "Langfuse Walkthrough – Full Demo of Agent Tracing, Evals, Experiments and Prompt Management"

- Channel: Langfuse. Presenter: Marc Klingen (co-founder).
- Published 2026-09-18, 14:56. https://www.youtube.com/watch?v=THfB4p2xCFY
- Timestamped outline: `video-transcript.md`.

## What it teaches, in one line
Langfuse sells a loop: **trace → evaluators surface the interesting traces → humans annotate →
annotated failures become datasets → experiments gate changes (in CI) → prompt changes ship by label
→ monitors confirm in prod → repeat.** Adopt it in that order; you don't need everything on day one.

## Features shown
| Area | What's demoed |
|---|---|
| Tracing | Step tree per trace: user input, retrieval (which docs entered context), tool calls, LLM calls, final answer; each with prompt, tokens, cost, latency. OTEL-native; Python/TS SDKs; 100+ integrations incl. Vercel AI SDK, LangGraph, Claude Code, Codex. |
| Setup shortcut | Install the **Langfuse skill** and ask your coding agent to add tracing. |
| Slicing | Traffic/cost/latency time series with click-to-zoom on spikes; `userId`; environments (prod/dev/staging); tags and metadata (model, feature, release). |
| Online evaluators | LLM-as-judge plus code-based. Three boolean "flag for review" judges: user pushback, out-of-scope, user cursing/complaining. Always-on: numeric relevance score and an intent classifier. Managed evaluator library; Langfuse publishes its own judge prompts. |
| Annotation queues | Two queues: auto-flagged items, and a regular random sample regardless of flags. Each item gets pass/fail plus a short note (error analysis). |
| Dashboards / alerts | Custom dashboards; metrics API. Alerts on metric thresholds go to Slack, a GitHub Action or a webhook (cost, time-to-first-token, negative feedback). |
| Datasets | Input plus expected output. Seeded from annotated queue items or "add trace to dataset". Demo keeps a QA set with references and a reference-free inputs-only set for one failure mode. |
| Experiments | Run a change against a dataset and compare side by side with the baseline. Three scores: correctness (LLM judge vs expected), keyword overlap (deterministic), behaviour match (answer / follow-up / out-of-scope / right tool). Run in CI as a release gate. |
| Prompt management | Versions with diffs; promote by moving a label, no redeploy; SDK caches prompts locally (no latency or availability hit); each trace links to its prompt version; open any trace in the playground. |
| In-app agent (Assistant) | Debugs a trace to the failing step; answers questions like "last 10 traces scoring <0.5, what do they share?"; suggests prompt edits. **Cloud only** (see 03-hosting-pricing.md). |
| Agent access | Skill, CLI (full REST API) and MCP server; docs available as markdown, llms.txt, and an MCP doc-search tool. |
| Data out | REST, metrics API, observations API, scheduled blob export. "No lock-in." |
| Hosting | Same codebase for OSS and Cloud; Docker Compose runs locally in about a minute; Helm and Terraform for production; Cloud is self-serve with a free tier. |

## Recommended workflow (as stated)
1. **Trace first.** Capture every step so you can tell bad retrieval from bad reasoning.
2. **Add monitoring** so interesting traces find you instead of you scrolling thousands.
3. **Human review** of a small, relevant sample: flagged items plus a regular random sample. Pass/fail and a note.
4. **Turn reviewed failures into datasets.** Decide what goes in through your own error analysis; start with one end-to-end set of app-specific failure modes.
5. **Experiments against the dataset** for every model, prompt, tool or harness change; wire them into CI as the regression gate.
6. **Ship prompt changes by label**, then watch prod traces and monitors. Repeat.

## Concrete tips that map to Mealvana / Vana
- **Boolean "flag" judges are cheap triage, not grades.** Pushback / out-of-scope / complaint judges fit Vana chat directly (e.g. the athlete corrects Vana's macros; the athlete asks medical questions). These fill an annotation queue for Lee and Xuan.
- **Keep a random-sample queue too**, so review isn't only what the judges already know to look for.
- **Mix scorer types in experiments.** One LLM judge for correctness, one deterministic check (e.g. the carb target number appears and matches the engine), and one behaviour classifier (answered / asked follow-up / deferred / called the right tool). This matches the rubric-plus-deterministic split in `eval/rubric.md`.
- **Two datasets are fine:** a reference QA set and a reference-free set aimed at one known failure mode.
- **Put `userId`, `environment`, a `release` tag and the prompt version on every trace.** That is what makes the dashboards and experiment comparisons worth having.
- **Prompt management gives Xuan a non-Git path** to edit Vana prompts, with version-to-trace linkage. It needs a decision on whether prompts move out of the edge-function source.
- **Try the public demo project** (langfuse.com/demo) before building anything.

## What the video does not cover
Pricing numbers, EE gating, data privacy, masking, rate limits, and v4 upgrade effort. All of those are in `03-hosting-pricing.md`.
