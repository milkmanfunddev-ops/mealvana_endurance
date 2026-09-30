# Langfuse Walkthrough: Full Demo of Agent Tracing, Evals, Experiments and Prompt Management

- Channel: Langfuse (presenter: Marc Klingen, co-founder)
- URL: https://www.youtube.com/watch?v=THfB4p2xCFY
- Published: 2026-09-18 · Length: 14:56

This file is a timestamped outline in my own words, not a verbatim copy of the video's speech.
To read the exact wording, pull the auto-captions locally:

```
uvx yt-dlp --skip-download --write-auto-subs --sub-lang en --sub-format vtt -o yt "https://www.youtube.com/watch?v=THfB4p2xCFY"
```

## Outline

- **00:00 Why Langfuse.** Getting an agent demo working is easy. Keeping it reliable for real users is hard, because regressions show up as customer complaints days later. Langfuse aims to cover the whole AI engineering loop: tracing, LLM-as-judge and code evaluators, human annotation, datasets and experiments, prompt management, dashboards and alerts.
- **01:19 The demo agent.** Langfuse's own docs chatbot. It answers the question "how do sessions work?", using retrieval tools before replying. It is traced into a public demo project.
- **01:57 Trace view.** One trace shows the user question, the retrieval steps (which docs entered the context), tool calls, LLM calls and the final answer. Each step shows its prompt, tokens, cost and latency. A wrong answer can have different causes: bad retrieval, no retrieval, or the model going wrong after good retrieval. The full trace is what lets you tell them apart. The in-app agent can investigate a trace and point at the failing step.
- **03:04 Getting data in.** Tracing is OpenTelemetry-native: point existing OTEL exporters at Langfuse, or use the Python/TS SDKs or one of 100+ integrations (LangGraph, the Vercel AI SDK, Codex, Claude Code). The quickest setup is installing the Langfuse skill and asking a coding agent to add tracing.
- **03:42 Handling volume.** A time-series view of traffic, cost, latency and volume; click a spike to zoom into that window. Pass a user ID to group by end user. Use environments, tags and metadata to split prod/dev/staging or slice by model, feature or release. Queries stay fast because the backend is ClickHouse.
- **04:48 Monitoring with evaluators.** Evaluators surface the traces worth a human look and track quality, cost and latency over time. Types: LLM-as-judge where judgment is needed, code-based where cheap deterministic checks do.
  - The demo runs three boolean judges that flag a conversation for review: the user pushes back on the assistant, the question is out of scope, the user curses or complains.
  - Always-on checks: a numeric relevance score and an intent classifier (conceptual / implementation / self-hosting / pricing) that shows which topics are popular.
  - There is a managed evaluator library, and Langfuse publishes the judge prompts it uses itself.
- **06:20 Human annotation.** Two annotation queues: one fed by the automated flags, one a general sample reviewed on a schedule whether or not anything fired. For each item: a pass/fail call and a short note on what went wrong. This is error analysis, grouping failure modes. Early on most of the value is people reading real conversations; evaluators make sure the few traces they read are the relevant ones.
- **07:11 Dashboards and alerts.** Scores, volume, cost and latency, sliced freely, plus a metrics API for outside analytics tools. Monitors take a metric and a threshold and notify Slack, a GitHub Action or a webhook (e.g. rising cost, slower time to first token, a spike in negative user feedback).
- **07:47 Datasets.** Rows are an input plus an expected output. Seed the first dataset from annotated queue items, or add any trace from the trace view. The demo keeps two: a general QA set with expected outputs, and a reference-free inputs-only set for one product-specific failure mode. Your own error analysis decides what goes in; an end-to-end set covering app-specific failure modes is a good start.
- **08:59 Experiments.** Run a change (new model, prompt tweak, tool definition, harness config) against a dataset and compare it side by side with the baseline. The demo scores three dimensions:
  - correctness against the expected answer (LLM judge)
  - keyword overlap, a deterministic check that product names appear
  - behaviour match: answered, asked a follow-up, deferred as out of scope, or called the right tool

  The dataset becomes the team's own benchmark and release gate, run in CI: a regression suite for AI apps.
- **10:05 Prompt management.** Prompts are versioned with diffs. Moving a deployment label promotes a version with no app redeploy, so PMs and domain experts can iterate outside release cycles and outside Git. The SDKs cache prompts locally like feature flags, adding no latency or availability risk. Every trace links to the prompt version that produced it. Any real trace opens in the playground, and the in-app agent can suggest prompt improvements from production usage.
- **11:14 The loop.** Change the agent, test on a dataset, release, watch production traces, let monitors report whether it worked, repeat.
- **11:29 Agent access.** Most workflows can be driven by agents: the in-app one (e.g. "pull the last 10 traces scoring below 0.5 and tell me what they share") or your own coding agent. There are three ways in, all on the same API: the Langfuse skill (a playbook), a CLI wrapping the full REST API, and an MCP server. The docs are also exposed as markdown, as llms.txt, and as an MCP doc-search tool.
- **12:37 Self-hosting.** The public repo is the same codebase Cloud runs. Docker Compose gets a local instance running in about a minute; Helm charts and Terraform templates handle production on any cloud. Langfuse claims the largest OSS community in this space.
- **13:15 Cloud.** Fully managed and self-serve, with a free tier and paid tiers. Sign up, pick a data region, go.
- **13:33 Data platform.** OTEL goes in. Coming out: the REST API, a metrics API (aggregates), an observations API (raw rows) and scheduled blob exports (e.g. to a data lake). No proprietary formats, no lock-in.
- **14:01 Adoption order.** Start with tracing, add monitoring so interesting traces find you, then turn reviewed failures into datasets and experiments to hill-climb against.
- **14:22 Getting started.** Explore the public demo project at langfuse.com/demo, install the Langfuse skill and let an agent add tracing, or run Docker Compose locally.
