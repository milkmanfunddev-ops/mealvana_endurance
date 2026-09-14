# SSOT prologue

Every -lee skill and `/ssot` runs this first, unchanged. It catches the decision record up with
what the ratifiers have already ruled on the page, and says what still waits. Format, file
locations and the rules of the record: `docs/ssot/decisions/README.md`. Read it once per session.

Paths below are relative to the repo root. `<feature>` is the feature slug (`mealplanning`).
`SYNC` means `node docs/ssot/decisions/_page/sync.mjs`. `URL` is the `Artifact:` line in the README.

## 1. Arm the watch

Call the Artifact tool with `action: "watch"` and `URL`, then `action: "status"`. Connected means
the Finish button on the page reaches this session as an artifact-changed notification. Not
connected means the ratifier types `done` in the terminal instead; say so in the report.

## 2. Read what is queued

`read_db` on `URL`, collection `verdicts`, `db_op: "query"`, `where [["applied", "==", false]]`,
`limit 200`, `out_dir` in the scratchpad. Build one `verdicts.json` from the files:
`{"sentAt": null, "verdicts": {"<doc id>": <document>, ...}}`. No documents: skip to step 6.

## 3. Sort the verdicts

```
SYNC triage <verdicts.json> --out <scratch dir>
```

`clear.json` is applied in step 4. `words.json` waits for step 5; each verdict in it carries
`pile`, which says why it is there. `other` is only reported. The README's Sync module section
says what goes where.

## 4. Apply the clear-cut verdicts now

For each feature that has verdicts in `clear.json` (decision ids carry the feature prefix):

```
SYNC apply <clear.json> .scratch/<feature>/decisions.md docs/ssot/decisions/<feature>.md
```

Read the `applied` and `refused` lists it prints. A refusal is reported, never retried blind.
Then `write_db` `update` on each applied `verdicts/<id>` with `{"applied": true}` (batch, 50 per
call).

## 5. Synthesise the verdicts with words, then wait for yes

Nothing in `words.json` touches a file until the ratifier agrees in the terminal. For each verdict,
say in a few lines what you think they meant, sorted into the README's piles (a rewrite, new
decisions, open questions, glossary terms). End the turn with the list and the question. On yes,
write:

- rewrites: `SYNC apply <rewrites.json> <proposals.md> <ssot.md>` marks each card `amended`
  with `**Original.**` and `**Lee said.**` filled in; then replace its `**Decision.**` with the
  rewrite they agreed to. Never run `apply` on `words.json` itself: a question-shaped rejection
  in it would enter the record as a rejection;
- new decisions: a new section with the id from `SYNC next-id <proposals.md> <ssot.md>`,
  status `proposed`;
- open questions: a section with `kind: question`, `status: open`, `linked: <id>`;
- terms: `SYNC terms <words.json> CONTEXT.md`.

Then `update` each of those `verdicts/<id>` with `{"applied": true}`. A verdict they said no to
stays unapplied and is named in the report.

## 6. Make the spec cite the record

If this run changed `docs/ssot/decisions/<feature>.md`, or `.scratch/<feature>/spec.md` cites no
decision id yet, bring the spec's Implementation Decisions and Testing Decisions sections in line
with the record. `SYNC cite .scratch/<feature>/spec.md .scratch/<feature>/decisions.md
docs/ssot/decisions/<feature>.md` reads both sections and says what each paragraph cites:

- a paragraph in `rejected` names an id that was rejected or withdrawn (`gone`): remove the
  paragraph, or only the clause that stated that id when the paragraph also cites ids that stand;
- a cited id that is approved stays, and the paragraph says what the record's **Decision** says;
  an approved decision that was amended on the page keeps its id and the paragraph is rewritten
  to the amended text (`SYNC export docs/ssot/decisions/<feature>.md` gives the text);
- a paragraph that states an approved decision without citing it gets the id in parentheses at
  the end, `(mp-042)`;
- `pending` ids are left as they are; `unknown` ids are a mistake to fix; `uncited` paragraphs
  with no decision behind them stay as they are and are listed in the report as backfill
  candidates; `unstated` ids (decisions that answered a question but appear nowhere in the spec)
  are listed in the report for the next `/to-spec-lee`.

Run `cite` again: `rejected` and `unknown` must be empty. Change nothing else in the spec.

## 7. Report

Four lines, no more:

```
Applied: N (a approved, w withdrawn, r rejected, m amended)
Waiting for yes: N   (only if step 5 has unanswered syntheses)
Pending on the page: N proposed, N open questions   <- SYNC pending / grep "status: open"
Page: URL
```

Then continue with the skill that called this prologue.
