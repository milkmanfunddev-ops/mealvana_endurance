# Improvement backlog

Master list of proposed changes to Vana: her prompt, Context block, Tools, and models. Every
Improvement is recorded with the Run that motivated it and its status. This file is the loop.
Mark, improve, re-run, until a round passes.

## Recording conventions

One entry per Improvement, appended with the next free ID, counting from `IMP-001`. An entry
records four things.

**What.** The change proposed, concrete enough that someone could apply it without guessing.

**Why.** The defect or gap observed, in a sentence or two.

**Motivating Run.** The round and Scenario that produced the finding, for example
`runs/001/pre-run-breakfast-reframe`, or `pilot` before round 001.

**Status.** Exactly one word from the vocabulary below.

Status vocabulary, and nothing else:

- `pending`. Proposed, not yet applied. The status of every new entry.
- `applied`. The change is in, as one or more commits. Record the commit hashes in the entry.
- `reverted`. Was applied and then undone. Record the revert commit and the reason.
- `ticketed`. Too big for a direct tweak. Structural changes, meaning new Tools, model changes,
  subagents, and schema changes, become tickets instead. Link the ticket.

## Rules

Every applied tweak is a commit. Prompt, Context, and tool-parameter tweaks are applied directly
as small commits during a round, so undo is always `git revert`. No tweak exists only in a
running session; if it changed Vana's behavior, it is in the history.

An Improvement that raises a product question does not decide it. File the question in
`.scratch/ssot/review-queue.md` and leave the Improvement `pending` until the ruling comes back.

After each round closes, triage the `pending` entries: apply the direct ones, ticket the
structural ones, or drop an entry with a sentence saying why.

## Backlog

| ID | What | Why | Motivating Run | Status |
|----|------|-----|----------------|--------|
| IMP-001 | Allergy filtering must apply every entry on the profile's allergy list, not only the one the prompt names. Concretely: when suggesting saved or searched meals, exclude any meal containing any listed allergen (peanuts AND tree nuts here), and say the exclusion. | The pilot asked for peanut-free vegetarian dinners; Vana cited "your vegetarian preferences and peanut allergy" and then suggested the athlete's saved Quinoa, mixed veg & walnuts — tree nuts are on the same allergy list. She read the field and applied one entry of it. | runs/pilot/s07-veg-dinners-after-long-runs | pending |
| IMP-002 | When rememberFact saves a correction, the visible reply must say so in one clause ("noted — walnuts are off your list for good"), so the athlete knows the correction outlives the conversation. | The pilot's tree-nut correction was saved (rememberFact verified server-side) but the reply never acknowledged it; the athlete cannot know Vana remembered. | runs/pilot/s07-veg-dinners-after-long-runs | pending |
| IMP-003 | A pick that emerges from meal suggestions should surface as a tappable meal card with a Log action (the designed interaction), not stay in prose with "log it when you're ready". | The pilot's pick (tofu bowl) and the log both happened through plain text; no chip, card, or button appeared in any reply, leaving the interactivity dimension unexercised. | runs/pilot/s07-veg-dinners-after-long-runs | pending |
| IMP-004 | Openers should lead with one thing only this athlete told her (mp-007/008), not a briefing of plan targets and log deltas. Draft from the Voodoo Doll's episodes/memories, with the day's numbers as seasoning at most. | The pilot's opener was a data read-out (835 g carbs, 393 g over, 9 servings left) — accurate and specific, but the kind of line a dashboard would generate; nothing in it came from something the athlete said. | runs/pilot/s07-veg-dinners-after-long-runs | pending |
