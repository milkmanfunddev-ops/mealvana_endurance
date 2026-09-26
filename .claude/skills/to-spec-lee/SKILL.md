---
name: to-spec-lee
description: "Matt's to-spec with the decision record around it: the spec cites the approved decisions it builds on, and any new product decision in it is put to Lee in the terminal and written to the record. `/to-spec-lee <feature>`."
disable-model-invocation: true
---

The decision record and its rules: `docs/ssot/decisions/README.md`. Read it once per session.
`SYNC` means `node docs/ssot/decisions/_page/sync.mjs`; `<feature>` is the slug in the argument;
`RECORD` is the five record files (`prologue.md`), `SPEC` is `.scratch/<feature>/spec.md`,
`QUEUE` is `.scratch/ssot/review-queue.md`.

## 1. Catch up

Run `.claude/skills/ssot/prologue.md`.

## 2. Find Matt's skill

```
node .claude/skills/ssot/matt.mjs to-spec
```

Read the file it prints and follow it. A non-zero exit is a stop: report the path it looked for
and end the turn. His text stays in his file. His skill synthesises the conversation and never
interviews, and his check of the test seams happens in the terminal as he writes it.

## 3. Build on what is ruled

Before writing a line of the spec, read `SYNC export RECORD`. A paragraph in Implementation or
Testing Decisions that states an approved decision cites its id at the end, `(mp-042)`. Test
seams, ship order and implementation choices stay in the spec and never become cards (Lee,
2026-09-26: the record holds product decisions only).

## 4. New product decisions

If the conversation settled a product decision the record does not hold yet (what the athlete
sees or pays, what Vana does, what the app will and will not do), and Lee already said it in
this conversation, write it into the record now as the README's "How a decision gets in"
describes: the right section file and subsection, id from `SYNC next-id RECORD`, the README's
parts kept short, `> <today> approved by Lee`, then cite it in the spec. If it is not settled,
put it to Lee with AskUserQuestion, one question at a time with the recommended answer first,
and write it once he answers. A question he parks goes to `QUEUE`.

## 5. Hand over

Run `.claude/skills/ssot/epilogue.md`, then end with:

```
Next: /to-tickets-lee <feature>
```
