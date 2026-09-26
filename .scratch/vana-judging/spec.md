# Spec: Vana judging system (AI-as-judge evals)

Status: ready-for-agent
Feature: vana-judging
Grilled: 2026-09-26 (`/grill-with-docs`, rounds 1–3, all questions answered)
Glossary: the terms below are defined in `CONTEXT.md` under "Judging Vana" — Scenario, Run,
Examiner, Mark, Rubric, Improvement, Eval round. Use them, not synonyms.

## Problem Statement

Lee has no trustworthy way to answer "is Vana good yet?" The previous eval system produced raw
traces for human annotation, which stalled: nothing scored Vana, nothing said what to improve
next, and there was no defined finish line. Lee wants to judge Vana the way a dietitian-reviewer
would — by actually talking to her in the app — and to keep improving her (prompts, context,
tools, eventually subagents) until she demonstrably scores above 90.

## Solution

An Examiner (a Claude session) signs into the real app as a test athlete, holds real
conversations with Vana following saved Scenarios, and Marks each Run against a written Rubric
owned by Lee. Every Run's verdict feeds a master Improvement backlog; improvements get applied as
small undoable commits and the corpus is re-judged. The project iterates until an Eval round —
one Run of every Scenario — averages ≥ 90 with no single Mark below 80. A future visual artifact
(rendered by Claude, separate effort) reads the structured round data this system produces.

## User Stories

1. As Lee, I want a written Rubric with weighted dimensions and anchors, so that every Examiner
   session judges Vana the same way and Marks are comparable across rounds.
2. As Lee, I want the Rubric to penalize robotic, state-machine behavior with a hard cap, so that
   Vana can never score well while failing to feel like a dietitian in a real conversation.
3. As Lee, I want a saved corpus of Scenarios in the repo, so that every round judges the same
   conversations and score changes mean Vana changed.
4. As Lee, I want the old eval system discarded, so that there is one judging system, not two
   half-ones.
5. As Lee, I want the 22 existing scenarios salvaged into the new format, so that the product
   thinking already baked into them is not lost.
6. As Lee, I want the Examiner to talk to Vana inside the real app, so that what is judged is
   what athletes actually experience.
7. As Lee, I want the web build as the primary judging surface, so that rounds are fast and every
   judgment has screenshot evidence.
8. As Lee, I want the simulator kept available for spot-checks, so that UI-native findings
   (keyboards, sheet gestures, moments) can still be verified.
9. As the Examiner, I want each Scenario to pin its account, persona, goal, opening turn and
   required beats, so that I improvise realistically without drifting off the thing being tested.
10. As the Examiner, I want the full Transcript of each Run captured from the server's stored
    messages, so that my judgment is based on the exact conversation, not my memory of it.
11. As the Examiner, I want written dimension anchors, so that marking a Run is a comparison
    against descriptions, not a vibe.
12. As Lee, I want one Run per Scenario per round, so that rounds stay fast and cheap, with a
    single confirmatory re-run only when a Mark moves more than ~10 points without explanation.
13. As Lee, I want every Run's verdict to record observed defects and suggested Improvements, so
    that judging feeds the improvement backlog automatically.
14. As Lee, I want one master Improvement backlog, so that every proposed change to Vana is
    recorded with the Run that motivated it and its applied/reverted status.
15. As Lee, I want full freedom to tweak prompts, context and tools while a round is running, so
    that iteration is fast — with the only rule that every tweak is undoable (a commit).
16. As Lee, I want product questions an Improvement raises routed to the SSOT review queue, so
    that nothing product-level gets decided silently inside the eval loop.
17. As Lee, I want one persona per account, so that Memories and Voodoo Doll state never bleed
    between Scenarios.
18. As Lee, I want the first test account verified for Pro and wallet budget before judging, so
    that the Gate never refuses the Examiner mid-round.
19. As Lee, I want new persona accounts spawned as the corpus grows, so that Scenarios can
    exercise different athlete situations (dense, sparse, vegetarian, offseason).
20. As Lee, I want a pilot Run shown to me before round 001 is official, so that the Rubric's
    anchors get calibrated against my eye before twenty-odd judgments bake in.
21. As Lee, I want each round recorded twice — human-readable prose and a structured JSON sidecar
    — so that the future visual artifact renders from data without re-parsing prose.
22. As the future artifact builder (Claude), I want per-Run dimension marks, verdicts and
    Improvement links in JSON, so that the visual representation is a rendering problem, not an
    extraction problem.
23. As Lee, I want the round protocol written down (README), so that any agent can run a round
    the same way months from now.
24. As Lee, I want the deterministic guardrail tests kept green, so that rate limiting, budgets
    and turn ceilings are proven by code, not re-judged by the Examiner every round.

## Implementation Decisions

- **Discard**: the trace harness under the server-side evals directory, the repo-root evals
  directory (corpus, load/dump/sample scripts, review app), and the dev `eval_traces` table
  (dropped by migration). The `onTrace` hook in the chat pipeline is **kept** — the deno test
  suite uses it. `guardrails.test.ts` is kept and its currently-red test (pantry-photo budget
  hold not released on rate-limit refusal) is fixed as its own commit.
- **New home**: everything lives under `/eval` at the repo root — the Rubric (already written and
  approved, including the robotic hard cap: a Run that reads as a state machine is capped at 50),
  the Scenario corpus as one markdown file per Scenario, per-round results as prose + JSON
  sidecar, the master Improvement backlog, and the persona-account map. Credentials never live in
  `/eval`; they go in the secrets directory.
- **Scenario format** (markdown, one file): account + persona, the goal the conversation must
  achieve, the pinned opening turn, required beats (things that must happen), and Examiner notes.
  The 22 scenarios are converted from the old JSON as they are first run; the old files are
  deleted only once all 22 are converted.
- **Judging surface**: the web build of the app on the dev backend (port 8080), driven by browser
  automation; screenshots captured as evidence. The iOS simulator is reserved for spot-checks and
  is subject to the standing simulator-cap and memory rules.
- **Conversation style**: hybrid — pinned opening turn and required beats, Examiner improvises
  the rest in character as a real athlete, never scripted staccato.
- **Transcript capture**: read from the server's persisted conversation/message tables after each
  Run (both sides, tool calls, metadata), not from streaming captures.
- **Marking**: ten dimensions, weights 20/15/10/10/10/10/10/5/5/5 (dietitian judgment, task
  success, concision & restraint, interactivity, tool use & data ops, memory & personalization,
  reliability, opener, instruction-following, recovery & boundaries), each marked 0/25/50/75/100
  against anchors in the Rubric. Robotic hard cap overrides the weighted sum.
- **Round protocol**: one Run per Scenario; a single confirmatory re-run only for an unexplained
  >10-point jump, recorded as a re-run. Pass = average ≥ 90 and no Run below 80.
- **Improvements**: master backlog file records what/why/motivating Run/status. Prompt, context
  and tool-parameter tweaks are applied directly as small commits (revert = undo). Structural
  changes (new Tools, model changes, subagents, schema) become tickets. Product questions go to
  the SSOT review queue.
- **Accounts**: one persona per account, starting with the existing test account (Pro granted
  via the subscription provider, wallet topped, data shaped to its persona); further persona
  accounts spawned as needed.
- **Pilot gate**: one Scenario run end-to-end, transcript + marked verdict reviewed by Lee,
  before round 001 counts.

## Testing Decisions

A good test here externalizes behavior: the guardrail fix is proven by the deterministic test
turning green (and staying green), and the judging system is proven by successfully producing one
real judged Run — not by unit-testing markdown.

- **Seam 1 (existing)**: the deno Vana test seam — the real chat pipeline handlers running
  against the shared fake-db support. The guardrails fix is a red test at this seam today; the
  deletion of the old harness must leave this suite green (proving nothing depended on it).
  Prior art: the ~40 existing Vana test files at this seam.
- **Seam 2 (new, product-level)**: the pilot Run — the real app on web, one full Scenario,
  transcript captured from the server, Mark and verdict written to the round files, reviewed by
  Lee. This verifies account setup, capture, marking and file plumbing end-to-end in the only
  way that matters: by doing the thing once.

## Out of Scope

- The visual artifact / dashboard (separate effort; this system only owes it clean JSON).
- Building the SSOT page from the Rubric (later, per Lee).
- Designing or adding subagents to Vana (the Improvement backlog will propose; separate specs).
- New Vana Tools the Rubric surfaces as gaps (e.g. shopping-list CRUD) — they become
  Improvements/tickets, not part of this build.
- Median-of-N runs, production sampling, or any judgment of the prod backend.
- Fixing anything the first rounds reveal about Vana herself beyond prompt/context tweaks — that
  is the loop's output, not this spec's deliverable.

## Further Notes

- Vocabulary is law: use Examiner (never "judge" — that is the image pipeline), Mark (never
  "score"/"rating" — those are the meal library's), Run (never "eval run").
- The Examining model should be pinned per the repo's model-split convention before round work.
- Round results are committed; nothing in `/eval` is gitignored — the corpus and round history
  are meant to be read months later.
