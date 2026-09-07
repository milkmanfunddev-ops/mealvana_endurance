# Deploy runbook — `<bundle name>` (`<date>`)

> Copy this file to `../ops/docs/deploys/<YYYY-MM>-<bundle>.md`, fill it in, and add a row to §10 of
> [`supabase-deploy-playbook.md`](supabase-deploy-playbook.md). The playbook holds the rules; this
> file holds the **state** of one bundle and the dated rulings that shaped it. Keep the status header
> honest — the coding agent reads it first.

## Status header (update on every step; newest ruling wins)

- **Current step:** P<n> — <one line>
- **Next gate:** <what has to be true before the next step>
- **Blocked on:** <nothing | human step | external>
- **Last verified:** <date> by <who> — <how>
- **Standing orders specific to this bundle** (rules the playbook does not already carry):
  1. …

## What ships

| Asset | Change | Where it lives |
|---|---|---|
| Schema | <migration files; additive or breaking?> | `supabase/migrations/…` |
| Edge functions | <functions + `_shared` blast radius; any rename / FROZEN?> | `supabase/functions/…` |
| Flutter build | <branch, release version, Drift `schemaVersion` before → after> | `lib/…` |
| Client gates | <any version field the client branches on; floor or exact?> | `lib/…` |

## `app_config` plan (playbook §7)

| key | before | step 1 target | step 2 target / date |
|---|---|---|---|
| `latest_schema_version` / `current_schema_version` | | | — |
| `min_supported_schema_version` | | unchanged | <N> on <date, adoption-driven> |
| `min_app_version` | | unchanged | |

Read the real values before writing anything here.

## Dev half

| # | Step | How it went |
|---|---|---|
| 0 | Local proof (vectors / unit) | |
| 1 | Schema → dev | |
| 2 | Local fn ↔ dev DB (optional) | |
| 3 | Version-gate decision (§6) | |
| 4 | Functions → dev | |
| 5 | Verify on dev (sim / dev TestFlight) | |
| 6 | Land branch → trunk | |

## Prod half (playbook §8)

| # | Step | Command / where | Gate | Done |
|---|---|---|---|---|
| P1 | Schema → prod | | | |
| P2 | Functions → prod | | | |
| P3 | Integration tests — locally | | | |
| P4 | Merge → `release/*` | | | |
| P5 | TestFlight hand smoke | | | |
| P6 | Release notes + submit | | downloadable | |
| P7 | `app_config` step 1 | | | |
| P8 | Athlete comms | | | |
| P9 | Cleanup / `app_config` step 2 | | | |

## Rulings ledger (dated, newest first)

- ▶ <who> <date>: <ruling> — <source: transcript / Slack / card>

## Open decisions / gaps

1. …

## Sources

- …
