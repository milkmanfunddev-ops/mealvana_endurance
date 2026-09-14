---
name: to-spec-lee
description: "Matt's to-spec with the decision record around it: the spec is written from the conversation, and its test seams and decisions go to the page as Spec cards instead of being confirmed in the terminal. `/to-spec-lee <feature>`."
disable-model-invocation: true
---

The decision record, its page and the sync commands: `docs/ssot/decisions/README.md`. Read it
once per session. `SYNC` means `node docs/ssot/decisions/_page/sync.mjs`; `<feature>` is the
slug in the argument; `PROPOSALS` is `.scratch/<feature>/decisions.md`, `RECORD` is
`docs/ssot/decisions/<feature>.md`, `SPEC` is `.scratch/<feature>/spec.md`.

## 1. Catch up

Run `.claude/skills/ssot/prologue.md` in full. If its step 5 left syntheses waiting for yes,
stop there; the spec is written after the ratifier has answered.

## 2. Find Matt's skill

```
node .claude/skills/ssot/matt.mjs to-spec
```

Read the file it prints and follow it. A non-zero exit is a stop: report the path it looked for
and end the turn. His text stays in his file. His skill synthesises the conversation and never
interviews; that holds here too. The one place it checks with the user in the terminal (the test
seams) is replaced by step 4: the seams go to the page.

## 3. Load what is already ruled

Before writing a line of the spec, read:

- `SYNC linked PROPOSALS RECORD`: the decisions that answered an open question, most recently
  the rulings a grill extracted. These come first: every one of them is stated in the spec's
  Implementation or Testing Decisions with its id. An entry marked `stale` (rejected or withdrawn
  after it answered) is not stated; it goes in the report as a question whose answer no longer
  stands, for the ratifier to reopen or re-ask. The tooling has no reopen path yet.
- `SYNC export RECORD`: everything approved, rejected and withdrawn. An approved decision the
  spec relies on is cited by id, never re-proposed. A rejected one is not in the spec at all.
- `PROPOSALS`: what is already proposed and not yet ruled. A pending proposal the spec relies on
  is cited by its id too; nothing is proposed twice.
- `CONTEXT.md` and `docs/adr/`, as Matt's skill expects.

## 4. Seams and decisions become Spec cards

Write the spec to `SPEC` in Matt's template, `ready-for-agent`, and at the same time write the
cards. If `SPEC` already exists, revise it in place: a paragraph that cites an approved id keeps
its words as long as they still say what the record's **Decision** says; everything else is
rewritten from the conversation.

Every paragraph in Implementation Decisions and Testing Decisions, and every test seam Matt's
step 2 sketches, is one of three things:

- it states an approved or already-proposed decision: cite the id at the end of the paragraph,
  `(mp-042)`, and write no card;
- it states something new: write a card in `PROPOSALS` and cite its id the same way. A seam is
  a card too, its **Decision** naming the seam and its **Why** saying why that level and no
  lower one;
- it states no decision (prior art, a description of what makes a good test): leave it
  uncited.

Each new card is written the way `/ssot backfill` step 3 and 4 write one (README parts, id from
`SYNC next-id` one at a time, `unslop`), with three things fixed here: `category: Spec`,
`source: spec <feature> <today>`, and a **Context** that opens with the spec's problem statement
in its words and then says where in the spec the decision sits. **Question** is the question the
paragraph answers. `SYNC cite SPEC PROPOSALS RECORD` then shows `unknown: []` and
`unstated: []`, with every decision paragraph cited; fix anything it lists before pushing.

## 5. Push and hand over

Run `.claude/skills/ssot/epilogue.md`. Its `Next:` line for this skill is the "approve N
decisions" form, so the epilogue sends the push. End the turn with the report and:

```
Next: approve N decisions on the page, then /to-tickets-lee <feature>
```

Finish on the page (an artifact-changed notification) and the word `done` in the terminal mean
the same thing: run the prologue again from its step 2. Its step 6 is what brings the spec in
line with the verdicts (rejected paragraphs gone, amended text taken over, ids cited); when
`SYNC cite SPEC PROPOSALS RECORD` still lists a `rejected` paragraph, the spec is not done.
Then run the epilogue again (it reseeds only what changed) and end the turn the same way.

The skill ends when `cite` shows `pendingSpec: []`: no Spec card is proposed or amended. Other
pending ids the spec cites do not hold it. The last line is then:

```
Next: /to-tickets-lee <feature>
```

`/to-tickets-lee` refuses while a Spec card is pending, so the "approve N" line is the gate.
