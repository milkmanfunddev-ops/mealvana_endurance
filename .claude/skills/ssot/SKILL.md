---
name: ssot
description: "The decision record and its page: apply the sign-offs, rejections and rewrites Lee and Xuan left on the cards, reseed the page, or settle the review queue. `/ssot` or `/ssot queue [<section>]`."
disable-model-invocation: true
model: opus
---

The decision record and its page: `docs/ssot/decisions/README.md` has the format, the file
locations, the sync commands and the rules. Read it first. The record holds approved decisions
only, in five section files; on the page Lee and Xuan can approve, reject or rewrite each card (Lee, 2026-09-26).
This skill holds the prologue and epilogue every -lee skill shares (`prologue.md`,
`epilogue.md` beside this file) and the locator those skills use for Matt's skills
(`matt.mjs`). Nothing here runs without a typed command.

## `/ssot` (no argument)

Run `prologue.md` (it applies the page's sign-offs and puts rejections and rewrites to Lee), then
`epilogue.md` (pictures and reseed). End with the report and `Next: press Finish on the page, or
type done` so Lee or Xuan can act on the cards. A Finish notification or `done` runs the prologue
again from step 2.

## `/ssot queue [<section>]`

Settle `.scratch/ssot/review-queue.md`, or one section of it when a section is named. First
check each item against the code: if it is built as described, record it; if the code does
something else, record what it actually does. For whatever is left, decide from the code, the
docs, Lee's approved cards and Xuan's spec. Mark the ruling `decided by Claude (Lee's
delegation)` (Lee, 2026-09-26). Only a call that is hard to reverse or that costs money (prices,
prod data, deploys) goes to Lee, with AskUserQuestion. Write each result the way
`/grill-with-docs-lee` step 5 does, then tick the item. Code that still has to change goes under
"Decided, needs building". Work that only Lee or Xuan can do goes to
`docs/ssot/decisions/open-tasks.md`.
Then run `epilogue.md`.

## For the -lee skills

Each -lee skill locates Matt's skill of the same name with
`node .claude/skills/ssot/matt.mjs <name>`, reads the file it prints, and follows it with the
SSOT steps around it. A non-zero exit is a stop: report the path it looked for and end the turn.
Never quote or copy Matt's text into a project file.
