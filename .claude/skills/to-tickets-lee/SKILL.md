---
name: to-tickets-lee
description: "Matt's to-tickets with the decision record around it: refuses while a Spec card is pending, puts the breakdown on the page as one card per ticket with blockers and touches, and writes the ticket files only once every card is approved. `/to-tickets-lee <feature>`."
disable-model-invocation: true
---

The decision record, its page and the sync commands: `docs/ssot/decisions/README.md`. Read it
once per session. `SYNC` means `node docs/ssot/decisions/_page/sync.mjs`; `<feature>` is the
slug in the argument; `PROPOSALS` is `.scratch/<feature>/decisions.md`, `RECORD` is
`docs/ssot/decisions/<feature>.md`, `SPEC` is `.scratch/<feature>/spec.md`, `ISSUES` is
`.scratch/<feature>/issues/`.

## 1. Catch up

Run `.claude/skills/ssot/prologue.md` in full. If its step 5 left syntheses waiting for yes,
stop there; the breakdown is cut after the ratifier has answered.

## 2. The gate: no ticket from an unapproved spec

```
SYNC pending PROPOSALS Spec
```

A `count` above zero is a stop. Report it and end the turn with nothing else written:

```
N Spec decisions still wait on the page: <ids>
Page: URL
Next: approve N decisions on the page, then /to-tickets-lee <feature>
```

When `count` is zero, go on. The spec may still cite pending ids of other categories. They do
not hold the breakdown; each ticket that depends on one names it, so the implementing agent sees it.

## 3. Find Matt's skill

```
node .claude/skills/ssot/matt.mjs to-tickets
```

Read the file it prints and follow it. A non-zero exit is a stop: report the path it looked for
and end the turn. His text stays in his file. Gathering context, exploring the code and drafting
the vertical slices with their blocking edges run as he writes them, from `SPEC` and the
conversation. Two of his steps change here: where he presents the breakdown in the terminal and
asks whether the granularity and the edges are right, step 5 below puts it on the page; where he
publishes the tickets to the tracker, step 7 below writes them from the approved cards.

## 4. Load what is ruled

Before drafting a slice, read `SYNC export RECORD` and `PROPOSALS`, and `SYNC cite SPEC
PROPOSALS RECORD` for the ids the spec's decision paragraphs cite. Every slice comes from
approved decisions and the spec; a rejected decision never becomes ticket work. Note the tickets
already in `ISSUES` (if any): new numbers continue after the highest existing one, and a slice
that repeats a done ticket is not a slice.

## 5. The breakdown goes to the page

Instead of presenting a numbered list in the terminal, write one card per ticket in `PROPOSALS`,
the way `/ssot backfill` step 3 and 4 write one (README parts, id from `SYNC next-id` one at a
time, `unslop`), with these fixed:

- `category: Tickets`, `source: tickets <feature> <today>`;
- `ticket: NN`, the number the file will get;
- `blocked: NN, NN` for the blockers Matt's step 3 gave it, omitted when none;
- `depends: <id>, <id>`, the decision ids the ticket relies on (approved ones from the record,
  pending ones from `PROPOSALS`); every ticket names at least the ids behind its slice;
- title `Ticket NN: <title>`;
- **Context** opens with the spec's problem statement in its words, then says where this slice
  sits in the breakdown (which of how many, what comes before and after);
- **Question** is "Is this the right slice, with the right blockers?" in the ticket's terms;
- **Decision** is what the ticket delivers: the end-to-end behaviour from the user's side. The
  page adds a "Blocked by" line under it from the `blocked:` meta, so the prose need not repeat
  the numbers;
- **Why** says why this cut and this size (fits one context window, demoable on its own);
- **What else was considered** names the merge or split that was not taken;
- **What it touches** is a comma-separated list of the repo paths (files or directories) the
  ticket will change. This line is what turns overlaps into edges, so it names real paths, not
  areas;
- **Details** holds the acceptance criteria, one `- [ ]` line each.

Then:

```
SYNC ticket-plan <feature> PROPOSALS RECORD
```

It lists every ticket card with `declared` blockers, `overlaps` (an earlier ticket sharing a
touch, and on what) and `blockedBy`, the union. Where an overlap added an edge the draft did not
have, either write that number into the card's `blocked:` line so the page shows it, or change
the touches if the overlap is not real. `forward` names any declared blocker that is not a
lower number; renumber until it is empty, since `publish-tickets` refuses while it is not.

## 6. Push and wait

Run `.claude/skills/ssot/epilogue.md`. Its `Next:` line for this skill is the "approve N
decisions" form, so the epilogue sends the push. End the turn with the report and:

```
Next: approve N tickets on the page, then /to-tickets-lee <feature>
```

Finish on the page (an artifact-changed notification) and the word `done` in the terminal mean
the same thing: run the prologue again from its step 2. A rejected ticket card means the cut
was wrong. Re-cut that part of the breakdown as new cards with new ids; the numbers may move,
and a card whose blockers changed gets a new card too, while the ratifier withdraws the old one
on the page. Push again and wait again. An amended card is re-proposed with the rewrite. The
skill writes nothing to `ISSUES` while `SYNC ticket-plan` lists a pending id.

## 7. Write the files

When every ticket card is approved (`ticket-plan` shows `pending: []`):

```
SYNC publish-tickets <feature> PROPOSALS RECORD ISSUES --next "/implement-lee <feature>"
```

It writes one file per approved card in the shape the README's Tickets paragraph describes,
and refuses everything (`refused`, with `why` per id) while a card is pending, a declared
blocker is not a lower number, or a card depends on an id that was rejected or withdrawn since
it was written. A number that already has a file is `skipped`, so a second run writes nothing
over the first. Report the three lists. A refusal for a dropped `depends` id means that ticket
was cut on a decision that no longer stands: re-cut it as a new card and go back to step 6.

Then run the epilogue once more so the Work page lists the new tickets (its `prepare --tickets`
step seeds `ISSUES`). End the turn:

```
Written: N tickets to ISSUES
Next: /implement-lee <feature>
```
