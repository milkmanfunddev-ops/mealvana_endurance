# SSOT epilogue

Every -lee skill and `/ssot` ends with this, unchanged. It puts what the run produced on the page
and tells the ratifier what waits on them. Same conventions as `prologue.md` (`SYNC`, `URL`,
`<feature>`, README first).

## 1. Prepare the page documents

For every feature whose record, proposals, glossary or tickets changed in this run:

```
SYNC prepare docs/ssot/decisions/<feature>.md .scratch/<feature>/decisions.md \
  --assets docs/ssot/decisions/_page/assets.json \
  --tickets <feature>=.scratch/<feature>/issues --out <scratch dir>/out
```

## 2. Upload new images once

```
SYNC images docs/ssot/decisions/_page/assets.json <scratch dir>/out/_images.json
```

For each entry that is `new` or `changed`: Artifact `action: "upload_asset"` with `URL` and the
file path, then record the id it returns:

```
SYNC asset docs/ssot/decisions/_page/assets.json <path> <asset id>
```

An entry that is `file missing` is reported, not uploaded. If anything was uploaded, run step 1
again so the documents carry the new asset ids. The assets map is committed with the run.

## 3. Reseed

`write_db` `batch` on `URL` with each array in `<scratch dir>/out/_batches.json` as `writes`
(the entries already carry `op`, `collection`, `doc_id`, `file_path`). Ids that were folded or
deleted from the proposals are removed with `delete` on `decisions/<id>`. If `CONTEXT.md`'s
glossary changed, reseed the `vocab` collection the same way (README, Vocabulary).

The database holds at most 5,000 documents across every collection (decisions, verdicts, chats,
tickets, vocab); a backfill that would pass it stops and says so. A skill never publishes the
page itself; the template is redeployed only when its design changes (README).

## 4. Tell the ratifier

Count what waits: `SYNC pending .scratch/<feature>/decisions.md` and the open questions in it.
When the calling skill cannot go on until they rule (its `Next:` line is the "approve N
decisions" form), send one phone push with Claude Code's PushNotification tool (a harness tool,
not a repo one), under 200 characters, leading with the count: `N decisions wait for you on the
SSOT page`. A run that merely leaves cards pending sends nothing; the report carries the count.
The tool skips the push when they are at the terminal; that is fine.

Report, then end the turn with exactly one `Next:` line:

```
Pushed: N proposals, N open questions, N images
Pending on the page: N proposed, N open questions
Page: URL
Next: /<command>
```

or, when the next step cannot start until they rule:

```
Next: approve N decisions on the page, then /<command>
```
