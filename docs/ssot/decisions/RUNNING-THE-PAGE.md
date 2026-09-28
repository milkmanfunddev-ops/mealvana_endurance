# Running the decisions page

Step-by-step for an agent (Claude Code) that has to open, reseed, or republish the decisions
page. Written 2026-09-26 for Xuan's agent. Every path is relative to the repo root. Nothing
here needs Lee's laptop.

This file lives in `decisions/` because that folder is app-owned and outside the QA mirror's
sync; a file at `docs/ssot/` root would be overwritten by the next sync.

## 1. What the page is

- The page is a claude.ai artifact. Its template is `docs/ssot/decisions/_page/index.html`.
- Its content is not in the HTML. The cards, glossary terms and reference documents live in the
  artifact's own database (collections `decisions`, `vocab`, `refs`, `tickets`); verdicts that
  people give on the page land in `verdicts`; Ask threads in `chats`.
- The source of truth for the cards is the five markdown files
  `docs/ssot/decisions/{mealplanning,paywall,shopping-list,ai-cost,misc}.md`. The database is
  a rendering of them. "Reseed" means: turn the five files into documents and write them into
  the database.
- Pictures are uploaded once as artifact assets. `_page/assets.json` maps each repo image path
  to the asset id it was uploaded as, keyed to Lee's artifact.

Lee's artifact: https://claude.ai/code/artifact/2b18d770-da55-443e-8740-483a422db8ac

The page declares these runtime capabilities and needs all four:

```json
{"artifact": {}, "assets": {}, "db": {}, "sample": {}}
```

Because it declares `db`, the artifact is organization-internal: only signed-in members of the
claude.ai organization that owns it can open it, and only people the owner has shared it with
as Editor can write to its database or republish it.

## 2. Before anything else: can this agent reach the artifact?

Prerequisites:

1. A clone of this repo on branch `mealplanning`, at the repo root.
2. Node 20 or newer (`node --version`). The sync module has no dependencies.
3. Claude Code with the artifact tools enabled: `Artifact` and `ArtifactData` (older builds
   spell the same calls differently; the table in section 7 maps them).
4. The Claude Code session signed in to the same claude.ai organization as Lee.

Check the tooling once:

```
node --test docs/ssot/decisions/_page/sync.test.mjs
```

All cases must pass. Then check access with the `Artifact` tool:

```
Artifact  action: "read"  url: "https://claude.ai/code/artifact/2b18d770-da55-443e-8740-483a422db8ac"
```

Read the header of the result.

- It says **writer**: you can reseed and republish Lee's page. Follow sections 3 to 6 against
  Lee's URL.
- It returns a summary but not "writer": you can read, not write. Ask Lee to share the
  artifact with you as **Editor** from the page's Share menu, then read again.
- It errors or says the artifact cannot be opened: you are outside Lee's organization, or it is
  not shared with you at all. Either Lee shares it, or you publish your own copy (section 8).

## 3. Only reading and ratifying (no agent needed)

Open the URL in a browser. Pick your name in the header once. On each card use Approve, Reject
or Rewrite, or open the Ask thread. Press **Finish** when done. Finish writes your verdicts to
the `verdicts` collection; nothing changes in the repo until Lee's terminal applies them
(section 4). That is the whole loop for a ratifier.

## 4. Applying verdicts and reseeding with the skill

From the repo root in Claude Code, type:

```
/ssot
```

That skill is in the repo at `.claude/skills/ssot/` (`SKILL.md`, `prologue.md`,
`epilogue.md`). It reads the queued verdicts, applies sign-offs to the five files, puts
rejections and rewrites to the person in the terminal one at a time, draws or captures missing
pictures, reseeds the page, and ends with a `Next:` line. It pins itself to the Opus model.

Rejections and rewrites change the record only when Lee agrees. If you are not Lee, stop at
that question and send him the list instead of answering for him.

If `/ssot` is not offered (skills not loaded), run the steps in sections 5 and 6 by hand.

## 5. Reseeding by hand, exactly

`SYNC` below means `node docs/ssot/decisions/_page/sync.mjs`. `URL` is the artifact URL from
section 1 (or your own from section 8). `<scratch>` is any temp directory.

### 5.1 Prepare the documents

```
SYNC prepare docs/ssot/decisions/mealplanning.md docs/ssot/decisions/paywall.md \
  docs/ssot/decisions/shopping-list.md docs/ssot/decisions/ai-cost.md docs/ssot/decisions/misc.md \
  --assets docs/ssot/decisions/_page/assets.json --glossary CONTEXT.md --out <scratch>/out
```

It prints something like `178 documents in 4 batches; 12 distinct images (0 to upload)` and
writes one JSON file per document plus `_batches.json`, `_images.json`, `_features.json` into
`<scratch>/out`. Always pass all five files together so the page keeps its order.

### 5.2 Upload pictures that are new or changed

```
SYNC images docs/ssot/decisions/_page/assets.json <scratch>/out/_images.json
```

It prints a JSON list. For every entry whose `why` is `new` or `changed`:

```
Artifact  action: "publish"  url: URL  asset: true  file_path: "<the entry's path>"
```

The result gives an asset `id`. Record it:

```
SYNC asset docs/ssot/decisions/_page/assets.json <path> <asset id>
```

It prints `{path, id, replaced}`. When `replaced` is not empty, delete that old asset:

```
Artifact  action: "delete"  url: URL  path: "<replaced id>"
```

An entry whose `why` is `unreferenced` is an asset no card uses any more; delete it the same
way, then `SYNC asset docs/ssot/decisions/_page/assets.json <path> --drop`. An entry whose `why`
is `file missing` is reported and left alone. If anything was uploaded, run 5.1 again so the
documents carry the new ids. Commit `assets.json` with the run.

Empty list, or every entry `unreferenced`: nothing to upload; carry on.

### 5.3 Write the documents

`<scratch>/out/_batches.json` is an array of arrays. Each inner array is at most 50 write
entries of the form `{"op":"set","collection":"decisions","doc_id":"mp-001","file_path":"…"}`.
For each inner array, one call:

```
ArtifactData  action: "batch"  url: URL  writes: <that inner array, verbatim>
```

The entries already carry `op`, `collection`, `doc_id` and `file_path`; pass them through.

### 5.4 Remove cards the files no longer hold

```
SYNC export docs/ssot/decisions/mealplanning.md docs/ssot/decisions/paywall.md \
  docs/ssot/decisions/shopping-list.md docs/ssot/decisions/ai-cost.md docs/ssot/decisions/misc.md
```

gives every current id. Then:

```
ArtifactData  action: "list"  url: URL  collection: "decisions"  query: {"limit": 1000}
```

Any id in the database that the export does not hold:

```
ArtifactData  action: "delete"  url: URL  collection: "decisions"  doc_id: "<id>"
```

### 5.5 Reference documents

Two documents in `refs` are built from repo files. Rebuild both whenever those files change:

```
SYNC reference docs/ssot/decisions/open-tasks.md --id open-tasks --title "Open tasks" --out <scratch>/open-tasks.json
SYNC reference docs/revenuecat-spec-for-lee.md --id revenuecat-spec --title "RevenueCat spec (Xuan)" --out <scratch>/revenuecat-spec.json
```

Each prints one write entry; put both in one call:

```
ArtifactData  action: "batch"  url: URL  writes: [<entry 1>, <entry 2>]
```

### 5.6 Check

```
ArtifactData  action: "list"  url: URL  collection: "decisions"  query: {"limit": 5}
```

returns cards. Reload the page in the browser; the cards show. Done. Nothing in the repo
changed except `assets.json` if pictures were uploaded; commit that.

## 6. Republishing the template

Only when `_page/index.html` itself changed (design or behaviour), never for content:

```
Artifact  action: "read"  url: URL          (required first: a publish to an unread artifact is refused)
Artifact  action: "publish"  url: URL  file_path: "docs/ssot/decisions/_page/index.html"
```

Leave `capabilities` out: a republish keeps the stored declaration. The database and the
assets survive a republish.

## 7. Tool spellings

Claude Code builds differ in how they name the same calls. Both columns do the same thing.

| Newer builds (this file) | Older builds and the skill files |
|---|---|
| `ArtifactData action: "batch"` | `Artifact action: "write_db" db_op: "batch"` |
| `ArtifactData action: "query"` / `"list"` / `"get"` | `Artifact action: "read_db" db_op: "query"` … |
| `ArtifactData action: "update"` / `"delete"` | `Artifact action: "write_db" db_op: "update"` … |
| `Artifact action: "publish" asset: true file_path: …` | `Artifact action: "upload_asset"` |
| `Artifact action: "delete" url path: <asset id>` | `Artifact action: "delete_asset" asset_id: …` |
| `ArtifactComments` (watch a page) | `Artifact action: "watch"` then `"status"` |

If a tool is only listed by name, load it first with ToolSearch, for example
`select:ArtifactData`.

## 8. Publishing your own copy

Use this only when Lee has not shared his artifact with you. Your copy has its own database
and its own asset ids, so it needs its own asset map; never write another artifact's ids into
the committed `assets.json`.

1. Copy the map and empty it: `echo '{}' > <scratch>/assets-mine.json`.
2. Publish the template as a new artifact:

   ```
   Artifact  action: "publish"  file_path: "docs/ssot/decisions/_page/index.html"
             icon: "checklist"  title: "Mealvana Decisions"
             capabilities: {"artifact": {}, "assets": {}, "db": {}, "sample": {}}
   ```

   The result gives your URL. Use it as `URL` from here on.
3. Run section 5 with `--assets <scratch>/assets-mine.json` in 5.1 and 5.2. Every picture in
   use (about 12) comes back as `new`; upload each and record it in your map. Run 5.1 again,
   then 5.3, 5.5 and 5.6.
4. Keep `assets-mine.json` somewhere outside the repo, or commit it under a different name.
   Do not overwrite `docs/ssot/decisions/_page/assets.json`.

Verdicts given on your copy land in your copy's `verdicts` collection. Lee's terminal only reads
his artifact, so send him your verdicts as text, or run section 4 yourself and send him the
rejections and rewrites to rule on.

## 9. When it goes wrong

- **The page opens but shows no cards.** The database is empty or unreachable for you: either
  you are outside the owner's organization (section 2), or nothing has been seeded (section 5).
- **A write is refused or "not found" on write.** You are not an Editor on this artifact.
  Section 2, or section 8.
- **A publish is refused as unread.** Run `Artifact action: "read"` on the URL first, then
  publish again with `url`.
- **`prepare` fails.** Check `node --version` is 20 or newer and that all five files were
  passed. `node --test docs/ssot/decisions/_page/sync.test.mjs` must be green.
- **Finish on the page does not reach the terminal.** Type `done` in the `/ssot` session; the
  prologue re-reads the `verdicts` collection.
- **A picture shows as missing on a card.** Its asset id is not in the map you passed to
  `prepare`; upload it (5.2) and prepare again.

## 10. Never

- Hand-edit the five decision files to record a ruling. Approved decisions are written only by
  a skill after Lee said yes in the terminal (README, "How a decision gets in").
- Edit or delete documents in `verdicts` by hand.
- Commit a different artifact's asset ids into `_page/assets.json`.
- Touch anything under `docs/ssot/` outside `decisions/`; it is mirrored from the QA repo.
