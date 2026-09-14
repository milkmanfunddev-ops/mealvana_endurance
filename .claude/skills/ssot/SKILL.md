---
name: ssot
description: "Open the decisions page, apply the ratifiers' verdicts, and backfill a feature's history into proposals. `/ssot` or `/ssot backfill <feature>`."
disable-model-invocation: true
---

The decision record and its page: `docs/ssot/decisions/README.md` has the format, the file
locations, the sync commands and the rules. Read it first. This skill holds the prologue and
epilogue every -lee skill shares (`prologue.md`, `epilogue.md` beside this file) and the locator
those skills use for Matt's skills (`matt.mjs`). Nothing here runs without a typed command.

## `/ssot` (no argument)

1. Run `prologue.md` in full: arm the watch, read queued verdicts, apply the clear-cut ones,
   synthesise the ones with words and wait for yes, keep the spec honest, report.
2. If step 5 of the prologue left syntheses waiting, stop there and wait for the ratifier's yes.
3. Otherwise end the turn with the report and this line, so the ratifier can rule on the page:

   ```
   Next: press Finish on the page, or type done
   ```

   An artifact-changed notification and the word `done` both mean the same thing: run the
   prologue again from step 2. The page's Finish republishes a `verdicts.json` file; the
   database is still the source, read it, never the file.
4. When nothing is queued and nothing waits for yes, run `epilogue.md` (it reseeds only what
   changed) and end with `Next: /grill-with-docs-lee <feature>` when the feature has open
   questions, else `Next: /to-spec-lee <feature>`.

## `/ssot backfill <feature>`

Turn what the repo already records about the feature into proposals for the page. Run the prologue
first, then:

1. Read the record and the proposals for the feature, so nothing already ruled or already
   proposed is proposed again. Note the categories in use (`sync.mjs export` shows them); reuse
   one before inventing one.
2. Read the feature's material: `.scratch/<feature>/spec.md` (Implementation and Testing
   Decisions first), every ticket in `.scratch/<feature>/issues/`, anything in
   `.scratch/<feature>/archive/`, `docs/adr/`, and the docs folders the CLAUDE.md docs map names
   for the feature. Commit messages on the feature's files count as sources too.
3. One card per product question. Each card has the README's parts: Question, Context, Decision
   (a clause list when several small rulings answer one question), Why, What else was considered,
   What it touches, and a `source:` line naming where it came from. A screen decision names its
   screen and references an existing capture by repo path if one fits; otherwise `image: none`
   (ticket 08 captures it). A card with no screen says `screen: none (algorithm/data)` and
   gets a drawn picture in the epilogue's step 0. Numbers go in Details. Write every card through `unslop`.
4. Ids come from `sync.mjs next-id .scratch/<feature>/decisions.md docs/ssot/decisions/<feature>.md`,
   one at a time as you write. Status `proposed`. A ruling you cannot state as a decision becomes
   an open question in the source's words (`kind: question`, `status: open`), never a dropped
   fact. If `.scratch/<feature>/decisions.md` does not exist, create it with the README's header
   block (`Feature:`, `Feature name:`, `Last extracted: <current commit>`).
5. Run `epilogue.md`; its step 0 draws a picture for every screenless card the backfill wrote
   and for any older one still without. The `Next:` line is `Next: approve N decisions on the page, then
   /grill-with-docs-lee <feature>`.

## For the -lee skills

Each -lee skill locates Matt's skill of the same name with
`node .claude/skills/ssot/matt.mjs <name>`, reads the file it prints, and follows it with the
SSOT steps around it. A non-zero exit is a stop: report the path it looked for and end the turn.
Never quote or copy Matt's text into a project file.
