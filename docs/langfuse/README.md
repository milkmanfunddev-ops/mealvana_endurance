# Langfuse in Mealvana Eval

Lee chose Langfuse on 2026-09-30. This folder holds what we know about it and what adopting it
means for eval-v2, the eval system in `../mealvana_eval` that judges Vana. Terms follow
`../mealvana_eval/CONTEXT.md`, and eval-v2's spec and decisions are in `../mealvana_eval/.scratch/eval-v2/`.

| File | What it holds |
| --- | --- |
| [research.md](research.md) | Langfuse itself: features, how each part of eval-v2 maps onto it, pricing, model access, billing. Every fact is cited. |
| [alternatives-and-costs.md](alternatives-and-costs.md) | The field around it (Braintrust, LangSmith, Phoenix, Opik, promptfoo, Anthropic, OpenAI, Bedrock and others), what the Judge costs per Eval round, and whether a Claude subscription can pay for it. |

Both notes were researched on 2026-09-29, and prices and features drift. Both recommended keeping
what we built; Lee decided otherwise, and the notes are left as written, with the decision at the
top of each.

## What Langfuse can and can't do for us

These points come from [research.md](research.md), which cites the sources.

**What it gives us:**
- A second place to read Runs: a session per Run, a trace per turn, and the steps and tool calls
  inside each, with tokens and cost.
- Scores on a Run, with dashboards over time.
- Annotation queues, so Lee and Xuan can Mark Runs by hand. Score analytics then compares those
  marks with the Judge's.
- Dataset runs, which can be compared side by side in its UI.

**What stays ours whatever we choose:**
- The Run engine, the Simulated athlete, the throwaway Eval athlete copies and the data diff.
  Langfuse has no user simulator. Its own multi-turn example runs the simulation in the caller's
  code, as ours does.
- The Judge and the Mark. Langfuse's managed judge scores one observation at a time. Trace-level
  evaluators are deprecated and stop on 2026-11-16, and nothing scores a whole multi-turn
  conversation. The weighted Mark and robotic cap stay in code.
- The Rubric and its versions, Tool expectations, per-Run overrides and the Improvements backlog.
  None of these has a place in Langfuse.
- Supabase stays the source of truth.

**What doesn't change:**
- **The Judge's tokens are most of the bill.** An Eval round costs about $8 on Opus 5.5, about 90%
  of it the Judge ([alternatives-and-costs.md](alternatives-and-costs.md), section 7).
  Langfuse's fee comes on top.
- **Subscriptions can't pay for it.** A Claude or Claude Code subscription can't power Langfuse's
  judge or playground. Anthropic requires API keys for third-party tools. Langfuse can call models
  through our Vercel AI Gateway key.

## The two ways in

Effort figures are the research agent's estimates.

**Lean, about 1 to 2 days.** Keep the engine as it is. When a Run finishes, the Next.js app sends
it to Langfuse:
1. The Run's stored turns, as a session with a trace per turn and a generation per step, backdated
   to when they happened.
2. The Judge's dimension marks, the Mark and the robotic cap as scores.
3. The Tool expectation results.

The Run page links to the Langfuse session. Nothing changes in this repo (`vana-eval`, Vana, the Deno functions), and it
comes out as easily as it goes in.

**Heavy, about 1 to 2 weeks.** Everything in the lean option, plus:
- Scenarios mirrored as Langfuse dataset items, and Eval rounds run as Langfuse experiments with our
  engine as the task.
- Vana's Deno function sending its own traces. That path is unproven on Supabase Edge (Langfuse
  discussion #6150 is still open) and needs a backend deploy.
- Langfuse's views in place of our Run list and comparison screens.

The Judge and everything else listed above still stay ours. This also means two copies of every
Scenario.

## Dates that matter

On 2026-11-16 Langfuse Cloud:
- removes the legacy batch ingestion API, which JS SDK v3 and older use;
- stops running trace-level LLM-as-a-judge evaluators.

Anything we build should use the OpenTelemetry-based JS SDK (v4 or later, ideally v5) and should
not rely on trace-level evaluators.

## Decisions for Lee

1. **Lean or heavy.** The research points to lean. Heavy mostly buys screens we already have.
2. **Plan.**
   - **Hobby** is free: 50k units a month, 2 users, 30-day retention, and a hard cap with no
     overage.
   - **Core** is $29 a month: 100k units and 90-day retention.
   - We'd use an estimated 20k to 95k units a month. Every trace, step and score counts as a unit.
3. **Region.** Langfuse Cloud has EU, US and Japan data regions. We'd pick one.
4. **What athlete data may leave Supabase.** Traces carry the Eval athlete's profile, logs and
   memories as Vana saw them. Imported athletes come from dev users; a prod import would be
   anonymized first. Langfuse would become a second vendor holding this data.
5. **Human Marks.** Is Xuan marking Runs in annotation queues part of the goal? That is the one
   thing Langfuse adds that we don't have and wouldn't otherwise build.
6. **Where it sits in the ticket order.** Ticket 08 (overrides, model pickers, "run again") is
   built but not committed or deployed. Tickets 09 to 11 (batch Runs and Eval rounds, Scenario and
   Rubric editors, comparing Runs and Improvements) overlap with the heavy option. They are
   unaffected by the lean one.

## Next step

Run `/grill-with-docs` on the Langfuse integration, starting from the decisions above, then
`/to-spec`. The spec should say which ticket or tickets it adds or changes. Until then eval-v2's
spec still lists Langfuse as out of scope ("optional later").
