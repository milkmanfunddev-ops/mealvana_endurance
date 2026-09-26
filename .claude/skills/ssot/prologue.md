# SSOT prologue

Every -lee skill and `/ssot` runs this first, unchanged. Format, file locations and the rules of
the record: `docs/ssot/decisions/README.md`. Read it once per session.

Paths below are relative to the repo root. `SYNC` means `node docs/ssot/decisions/_page/sync.mjs`.
`URL` is the `Artifact:` line in the README. `RECORD` is the five files
`docs/ssot/decisions/{mealplanning,paywall,shopping-list,ai-cost,misc}.md`. `QUEUE` is
`.scratch/ssot/review-queue.md`.

The record holds approved decisions only (Lee, 2026-09-26). The page is read-only: there are no
verdicts to read or apply, and nothing on the page waits for a ruling.

## 1. Load what is ruled

`SYNC export RECORD` gives every decision with its id, section (`feature`) and subsection
(`category`). These are settled. A skill cites them and asks about none of them unless Lee
wants to change one.

## 2. Load what waits

Read `QUEUE`: the unchecked items are the questions still waiting on Lee, grouped by section.
The calling skill decides whether any of them belong to its work.

## 3. Report

Two lines, no more:

```
Record: N decisions (N meal planning, N paywall, N shopping list, N cost cutting, N misc)
Waiting on Lee: N in the review queue
```

Then continue with the skill that called this prologue.
