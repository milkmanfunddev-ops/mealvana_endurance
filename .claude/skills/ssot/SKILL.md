---
name: ssot
description: "The decision record and its read-only page: reseed the page, or walk the review queue with Lee one question at a time. `/ssot` or `/ssot queue [<section>]`."
disable-model-invocation: true
model: opus
---

The decision record and its page: `docs/ssot/decisions/README.md` has the format, the file
locations, the sync commands and the rules. Read it first. The record holds approved decisions
only, in five section files; the page shows them read-only for Lee and Xuan (Lee, 2026-09-26).
This skill holds the prologue and epilogue every -lee skill shares (`prologue.md`,
`epilogue.md` beside this file) and the locator those skills use for Matt's skills
(`matt.mjs`). Nothing here runs without a typed command.

## `/ssot` (no argument)

Run `prologue.md`, then `epilogue.md` (pictures and reseed). End with the report and
`Next: /ssot queue` when the review queue has unchecked items.

## `/ssot queue [<section>]`

Walk `.scratch/ssot/review-queue.md` with Lee: every unchecked item (in that section only, when
one is named), one AskUserQuestion call per item, the recommended answer first, two or three
lines of context before the options. Write each answer as `/grill-with-docs-lee` step 5 does,
then tick the item. `skip` leaves it. An item marked obsolete is dropped unless Lee objects.
Then run `epilogue.md`.

## For the -lee skills

Each -lee skill locates Matt's skill of the same name with
`node .claude/skills/ssot/matt.mjs <name>`, reads the file it prints, and follows it with the
SSOT steps around it. A non-zero exit is a stop: report the path it looked for and end the turn.
Never quote or copy Matt's text into a project file.
