---
name: grill-with-docs-lee
description: "Matt's grill-with-docs with the decision record around it: the waiting questions first, one at a time, then his grill; every ruling Lee gives is written straight into the record as an approved decision. `/grill-with-docs-lee <feature> [<id>]`."
disable-model-invocation: true
---

The decision record and its rules: `docs/ssot/decisions/README.md`. Read it once per session.
`SYNC` means `node docs/ssot/decisions/_page/sync.mjs`; `<feature>` is the slug in the argument;
`<id>`, if given, is the review-queue item to start with. `RECORD` is the five record files
(`prologue.md`), `QUEUE` is `.scratch/ssot/review-queue.md`.

## 1. Catch up

Run `.claude/skills/ssot/prologue.md`.

## 2. Find Matt's skill

```
node .claude/skills/ssot/matt.mjs grill-with-docs
```

Read the file it prints and follow it. A non-zero exit is a stop: report the path it looked for
and end the turn. His text stays in his file.

## 3. Load what is ruled

- `SYNC export RECORD`: every approved decision. These are settled; the grill cites them and
  asks about none of them unless Lee wants to change one.
- `QUEUE`: the unchecked items for this feature's section.
- `CONTEXT.md` and `docs/adr/`, as Matt's skill expects. Xuan's spec answers are adopted, never
  asked again.

## 4. Waiting questions first, one at a time

Put each unchecked `QUEUE` item for the section to Lee with AskUserQuestion, one question per
call, the recommended answer first (Lee, 2026-09-25). Give the two or three lines of context
that matter before the options. Facts are looked up, never asked. `skip` or `later` leaves it
unchecked. When the queue is done, continue with Matt's grill from the frontier his skill
computes, asking Lee's decisions the same way.

## 5. Write each ruling as it lands

A ruling is approved the moment Lee gives it. Write it into the record right away, in the
README's format and rules ("What makes a card"):

- it changes an existing card: rewrite that card in place so it states the new truth, add
  `> <today> changed by Lee: <one clause>`; newest ruling wins;
- it is new and belongs to an existing card's decision: fold it into that card;
- it is new and broad enough to stand alone: a new card in the right section file and
  subsection, id from `SYNC next-id RECORD`, `> <today> approved by Lee`;
- it is implementation detail, a test seam or a work plan: it goes in the spec or the tickets,
  never the record.

Tick the `QUEUE` item it answered (`- [x] … → mp-NNN`). A ruling that cannot be stated yet
stays in `QUEUE` as a question in Lee's words. Glossary terms and ADRs are written during the
grill by the skills Matt's file names.

## 6. On `done`

Run `.claude/skills/ssot/epilogue.md`. Its report gains one line ahead of the others:

```
Ruled: N (<ids written or changed>) · Still waiting: N
Next: /to-spec-lee <feature>
```
