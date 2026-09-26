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

Empty. The pilot Run and round 001 fill it.

| ID | What | Why | Motivating Run | Status |
|----|------|-----|----------------|--------|
