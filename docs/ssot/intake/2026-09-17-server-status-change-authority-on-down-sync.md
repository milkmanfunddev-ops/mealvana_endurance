type: ruling-request
bundle: daily-macros-dashboard / data-integrations (activities down-sync merge)

## Why this matters
"Deletion stays deleted" is a ratified chain, but its inverse — a status change made
SERVER-side reaching a device that already holds the row — has no rule and no pinned test.
Two live observations sit on opposite sides of the same seam, and neither can be called a
bug until the contract says which store wins. App-side scope waits on this ruling
(`ops/data/bug-reports/2026-08-20-server-tombstone-not-applied-to-known-local-rows.md`).

## The question
For an activity row the device already has, which store's `status` wins on down-sync, and
does the answer differ for `status = 'deleted'` (a tombstone) versus any other status
(`planned` → `skipped` → `completed`)?

## Evidence (both from dev, 2026)
- **Server → device does not arrive (2026-08-20).** Four activities were PATCHed to
  `status='deleted'` server-side as the signed-in user. The device kept them `planned` and
  kept rendering them through app kill + relaunch, pull-to-refresh, and ~5 min foreground.
  Static reading since: `syncFromRemote` pulls `deleted_at.is.null,status.eq.deleted` and
  replaces rows with no pending local edit, but `ensureSynced` skips the pull entirely when
  the last sync was under 1 h old (`_isStale`, timestamp in SharedPreferences) — so this may
  be cadence, not merge policy. **Not yet re-tested** (the re-test is blocked on a dev-write
  permission, ops side).
- **Device → server holds a status the server never got (2026-09-17).** On the dev sim,
  activity `854f429c-de87-42f1-9f6c-bb66ecb6eb57` ("Fuel Writeback Smoke Run") renders with a
  **Skipped** chip while the server row reads `status = 'planned'`, `deleted_at = null`. Local
  status is authoritative on screen and has not been pushed up (or was overwritten server-side).

## Options
1. **Server wins on `status` for any row with no pending local edit** (the down-merge applies
   remote status). Makes deletion propagate; costs the "local wins on status" convenience that
   `_mergeProviderUpdate` relies on today (it hardcodes `status: existing.status`).
2. **Local wins on `status` except for the tombstone value** — `deleted` propagates down,
   everything else stays device-authoritative until the device pushes.
3. **Local always wins; server-side status edits are unsupported** — then the 2026-08-20 report
   closes as works-as-designed, and admin/support tooling must never PATCH `status` directly.

## What it gates
- Whether the pull cadence needs a relaunch-triggered sync (option 1/2) or not (option 3).
- A pinned test for the tombstone inverse, which the ratified deletion chain currently lacks.
- Support/admin runbooks: today a server-side `status='deleted'` may silently not reach devices.

## Suggested spec home
`spec/daily-macros/platform-resolution.md` (the tombstone/skip family), as a post-ratification
addition on down-sync status authority, plus a vector or seam test pinning the chosen rule.
