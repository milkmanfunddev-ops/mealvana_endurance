# SSOT epilogue

Every -lee skill and `/ssot` ends with this, unchanged. It puts the record on the page. Same
conventions as `prologue.md` (`SYNC`, `URL`, `RECORD`, README first). `<feature>` below is each
section file whose cards changed in this run (`mealplanning`, `paywall`, `shopping-list`,
`ai-cost`, `misc`), and `<file>` is `docs/ssot/decisions/<feature>.md`.

## 0. Drawn pictures, only when asked

A drawn diagram is made only when Lee asks for one on a card (README, Drawn pictures):
`SYNC draw <spec.json> docs/ssot/decisions/images/<feature>/<id>.svg`, then
`SYNC attach-svg <file> <id> <svg>`.

## 0b. Capture the cards that name a screen

```
SYNC pictures <feature> <file>
```

Every card with a screen and no picture gets one: the golden or design frame `screens.json`
names for that screen, else a capture from the booted simulator (README, Captured pictures). Read
the `attached` and `skipped` lists it prints; a skip names why (no booted simulator, a screen
with no drive, a drive that found nothing). `SYNC capture --check` says what to fix when every
capture skips. A screen the registry does not know is added to `_page/screens.json` with its
drive, then the command is run again. The png files, their sidecars and the registry are
committed with the run.

## 0c. Refresh the stale pictures

```
SYNC stale <file>
```

Every picture in use with its age and `stale` (the screen's code changed after it was taken;
README, Captured pictures). When any is stale and a simulator is booted:

```
SYNC refresh <feature> <file>
```

Read `refreshed` (a retake in place, or cards moved from a golden to the capture) and `skipped`
(no drive, or a drive that failed). A retake rewrites the png and its sidecar, so step 2 uploads
it again and deletes the asset it replaced. Nothing stale is left silent: a skip is reported.

## 1. Prepare the page documents

All five files together, so the page keeps its order:

```
SYNC prepare RECORD --assets docs/ssot/decisions/_page/assets.json \
  --glossary CONTEXT.md --out <scratch dir>/out
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

It prints `{path, id, replaced}`; when `replaced` is not empty, delete that asset from the
artifact (`action: "delete_asset"` with `URL` and `asset_id`), so a refreshed picture leaves
no old one behind. An entry that is `unreferenced` names an asset no card uses any more: delete
it the same way, then `SYNC asset docs/ssot/decisions/_page/assets.json <path> --drop`. An
entry that is `file missing` is reported, not uploaded. If anything was uploaded, run step 1
again so the documents carry the new asset ids. The assets map is committed with the run.

## 3. Reseed

`write_db` `batch` on `URL` with each array in `<scratch dir>/out/_batches.json` as `writes`
(the entries already carry `op`, `collection`, `doc_id`, `file_path`, 50 per batch). Any id in
the `decisions` collection that no record file holds any more is removed with `delete`. The
template is redeployed only when its design changes (README).

## 4. Report

End the turn with a `Clear:` line and exactly one `Next:` line. `Clear:` says whether Lee can
`/clear` now (yes when everything is committed and reseeded; otherwise no, with the one thing
still open). `Next:` names the command and says in one clause what it does. When the next
command is `/grill-with-docs-lee`, `/to-spec-lee`, `/to-tickets-lee` or `/implement-lee`, the
line ends with `(on Fable: /model fable first)`.

```
Record: N decisions · Waiting on Lee: N in the review queue
Page: URL
Clear: yes, all committed and on the page
Next: /<command> (what it does, in one clause)
```
