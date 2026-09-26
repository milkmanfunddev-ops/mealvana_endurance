# SSOT prologue

Every -lee skill and `/ssot` runs this first, unchanged. Format, file locations and the rules of
the record: `docs/ssot/decisions/README.md`. Read it once per session.

Paths below are relative to the repo root. `SYNC` means `node docs/ssot/decisions/_page/sync.mjs`.
`URL` is the `Artifact:` line in the README. `RECORD` is the five files
`docs/ssot/decisions/{mealplanning,paywall,shopping-list,ai-cost,misc}.md`. `QUEUE` is
`.scratch/ssot/review-queue.md`.

The record holds approved decisions only (Lee, 2026-09-26). Each card on the page has Approve,
Reject and Rewrite, and an Ask thread that can draft a rewrite. Approve is a sign-off on a card
that is already approved (for example Xuan confirming it). Reject and Rewrite change the record
only after Lee agrees in the terminal.

## 1. Arm the watch

Call the Artifact tool with `action: "watch"` and `URL`, then `action: "status"`. Connected means
Finish on the page reaches this session as an artifact-changed notification. If it is not
connected, the ratifier types `done` in the terminal instead; say so in the report.

## 2. Read what is queued

Run `read_db` on `URL`: collection `verdicts`, `db_op: "query"`, `where [["applied", "==", false]]`,
`limit 200`, `out_dir` in the scratchpad. Build one `verdicts.json` from the files:
`{"sentAt": null, "verdicts": {"<doc id>": <document>, ...}}`. No documents: skip to step 5.

## 3. Sort them

```
SYNC triage <verdicts.json> --out <scratch dir>
```

`clear.json` holds approvals and withdrawals. `words.json` holds everything with words in it:
rejections, rewrites, accepted change cards and new terms.

## 4. Apply the approvals now, synthesise the rest

- **Approvals** are sign-offs. For each record file, apply `clear.json` with a throwaway
  proposals file. It holds only the header block (`Feature:`, `Feature name:`) and lives in the
  scratchpad:
  `SYNC apply <clear.json> <scratch>/empty-<feature>.md docs/ssot/decisions/<feature>.md`.
  Each run applies the ids in its own file and refuses the others as `unknown id`; that is
  expected. The card gains `> <date> approved by <name>` and stays approved.
- **A withdrawal** takes a card out of the record. Do not apply it. Put it to Lee like a
  rejection.
- **Rejections, rewrites and change cards** never apply straight away. For each one, say in a
  few lines what the person meant, and put it to Lee with AskUserQuestion: rewrite the card in
  place, fold it into another card, delete the card, or leave it. On his answer, edit the card as
  `/grill-with-docs-lee` step 5 does (newest ruling wins, one history line), or delete the card.
  The record never holds a rejected card, and git keeps what was removed. A reason that is really
  a question, and anything Lee parks, goes to `QUEUE`.
- **Terms**: `SYNC terms <words.json> CONTEXT.md` once Lee agrees.

Then `write_db` `update` on each handled `verdicts/<id>` with `{"applied": true}`. Batch the
updates, 50 per call.

## 5. Load what is ruled and what waits

`SYNC export RECORD` lists every decision with its id, section (`feature`) and subsection
(`category`). `QUEUE` lists what still waits on Lee.

## 6. Report

```
Applied: N sign-offs · Put to Lee: N · Record: N decisions · Waiting on Lee: N
```

Then continue with the skill that called this prologue.
