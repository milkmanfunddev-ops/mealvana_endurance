# Judging board

`index.html` is the visual artifact the vana-judging spec promised: a live page that shows a
round while it runs. It is published as a claude.ai artifact and reads the artifact's own data
store, so the Examiner reports progress by writing documents, and every open view updates.

The published page: see the `Board:` line at the bottom of this file. Republish from this
file with the Artifact tool against that URL after editing it; the data store survives
republishes.

## What the Examiner writes, and when

All writes go through the `ArtifactData` tool against the board's URL. Field names are the
`round.json` sidecar's (`eval/README.md`, "JSON sidecar convention") plus a few live fields.
Timestamps are ISO 8601 with a timezone. Marks are 0/25/50/75/100; dimension keys are the
Rubric's names in kebab-case:

`dietitian-judgment`, `task-success`, `concision-restraint`, `interactivity`,
`tool-use-data-ops`, `memory-personalization`, `reliability`, `opener`,
`instruction-following`, `recovery-boundaries`.

### `rounds/<round>` — once when a round opens, once when it closes

```json
{ "round": "001", "status": "open", "started_at": "…", "corpus": ["<scenario-slug>", "…"] }
```

`corpus` is the README's corpus index in order; it fixes the rows on the board before any Run
lands. On close, `update` with `"status": "closed"`, `"date"`, `"average_mark"`, `"passed"`.
The pilot Run is reported as round `"pilot"`.

### `runs/<round>-<scenario>` — at every phase change of a Run

Append `-rerun` to the id for a confirmatory re-run; never overwrite the original.

```json
{ "round": "001", "scenario": "<slug>", "account": "<account slug>", "rerun": false,
  "status": "talking", "started_at": "…", "turns": 0 }
```

`status` walks `talking` → `capturing` → `marking` → `marked`. When marked, `update` with
`dimensions` (all ten), `weighted_mark`, `robotic_cap_applied`, `verdict`, `improvements`
(IDs), `turns`, `finished_at`. Write the same object into the round's `round.json`.

### `live/current` — the heartbeat, `set` every turn or so

```json
{ "round": "001", "scenario": "<slug>", "account": "<account>", "phase": "talking",
  "turn": 4, "note": "one line on what is happening", "updated_at": "…",
  "log": [ { "t": "…", "text": "turn 4: athlete mentions taper" } ] }
```

Keep `log` to the last 60 lines. Set `phase` to `idle` when the round is done. The board shows
the Examiner as idle after five minutes without a heartbeat.

### `improvements/<IMP-id>` — whenever `improvements.md` changes

```json
{ "id": "IMP-001", "what": "…", "why": "…", "motivating_run": "runs/001/<slug>",
  "status": "pending", "commits": ["<hash>"] }
```

`status` uses the vocabulary in `improvements.md`. The markdown file is the record; this
document mirrors it.

## Verifying

The board falls back to a labelled example round when the store is empty or unreachable. Real
documents replace the example the moment one arrives.

Board: https://claude.ai/artifact/7eNL3g3r3xbiMVSKcmhNSb (private to Lee until shared)
