---
name: grill-with-docs-lee
description: "Matt's grill-with-docs with the decision record around it: the feature's open questions first, one at a time, then his grill; on `done` every ruling is a proposal on the page. `/grill-with-docs-lee <feature> [<question id>]`."
disable-model-invocation: true
---

The decision record, its page and the sync commands: `docs/ssot/decisions/README.md`. Read it
once per session. `SYNC` means `node docs/ssot/decisions/_page/sync.mjs`; `<feature>` is the
slug in the argument; `<question id>`, if given, is the open question to start with.

## 1. Catch up

Run `.claude/skills/ssot/prologue.md` in full. If its step 5 left syntheses waiting for yes,
stop there; the grill starts after the ratifier has answered.

## 2. Find Matt's skill

```
node .claude/skills/ssot/matt.mjs grill-with-docs
```

Read the file it prints and follow it. A non-zero exit is a stop: report the path it looked for
and end the turn. His text stays in his file.

## 3. Load what is already ruled

Before the first question, read:

- `SYNC export docs/ssot/decisions/<feature>.md`: every approved, rejected and withdrawn
  decision with its id. These are settled; the grill cites them and asks about none of them.
  A ruling that reverses one follows the README (a new proposal naming the id it reverses).
- `SYNC questions .scratch/<feature>/decisions.md docs/ssot/decisions/<feature>.md`: the open
  questions in file order, each with the ratifier's words, context, why and touches.
- `.scratch/<feature>/decisions.md`: what is already proposed. A pending proposal may come up in
  a round when the ratifier wants to challenge it; it is proposed only once.
- `CONTEXT.md` and `docs/adr/`, as Matt's skill expects.

## 4. Open questions first, one at a time

Print the open questions as a numbered list, id and title only, with the count, and invite a
different order in the same message. The order is the ratifier's: `<question id>` from the
command line first, then the list order unless they name another. Then walk them one per round:

- A round is one open question: its id, the question in their words, the two or three lines of
  context that matter, and a recommended answer in Matt's round format. Follow-up questions that
  the answer opens belong to the same open question and come in the next round, still one at a
  time, before the next open question.
- Facts are looked up (Matt's rule). Only the decision goes to the ratifier.
- `skip`, `later` or `park` leaves the question open and moves on. A question is settled only by
  a stated answer, and the next round opens by repeating that ruling in one sentence.

When every open question is settled or parked, continue with Matt's grill for the rest of the
plan, from the frontier his skill computes.

## 5. On `done`

The word `done` (or "that's enough", "stop here") ends the grill. Then, in this order:

1. **Extract the rulings.** Walk the transcript from the first round. Every ruling becomes one
   section in `.scratch/<feature>/decisions.md` in the README's file format: id from
   `SYNC next-id`, status `proposed`, `source: grill <today>`, the category of the question it
   answers or one reused from the record. **Question** is the question as asked; **Decision**
   is the ruling; **Why** is the ratifier's reason, or the recommendation's when they took it;
   **What else was considered** names the options the round offered; **What it touches** comes
   from the question's touches line and what the round found in the code.
2. **Link each answered question.** For each ruling that answers an open question:
   `SYNC answers <question id> <decision id> .scratch/<feature>/decisions.md docs/ssot/decisions/<feature>.md`.
   That marks the question `answered` with a dated history line and writes `linked:` on the
   decision. A ruling that answers no open question carries no `linked:`.
3. **Lose nothing.** A ruling you cannot state as a decision (they said something firm but the
   round did not reach a shape a card can hold) becomes a new section with `kind: question`,
   `status: open`, `linked:` to the decision or question it came from, and **Question** in
   their words. A parked question stays exactly as it was.
4. **Glossary and ADRs** were written during the grill by the skills Matt's file names. A
   changed `CONTEXT.md` means the epilogue reseeds `vocab`.

Then run `.claude/skills/ssot/epilogue.md`. Its report gains two lines ahead of `Pushed:`:

```
Closed: N open questions (<ids>)
Still open: N (<ids>)
Pushed: N proposals, N open questions, N images
Pending on the page: N proposed, N open questions
Page: URL
Next: /to-spec-lee <feature>
```
