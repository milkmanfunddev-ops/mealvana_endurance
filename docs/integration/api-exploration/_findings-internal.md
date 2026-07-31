# Internal Findings — Integration Code Defects (NOT part of the API reference)

> This file is intentionally prefixed `_` and is **not** part of the vendor API reference portal.
> It preserves defects surfaced while documenting the integrations, so they aren't lost when the
> reference was reframed to be provider-facing. These are about *our* code, not the vendor APIs.
> Verified against `release/1.21.1` on 2026-07-21. None have been fixed.

## Security — needs action

| # | Finding | Evidence |
|---|---|---|
| S1 | **Garmin webhooks accept unauthenticated requests.** `validateGarminRequest` returns *valid* when the `garmin-client-id` header is **absent** (a wrong header is rejected; no header is accepted). `garmin-push`/`garmin-ping` run with `verify_jwt = false`, so this is the only auth. | `supabase/functions/_shared/garmin/auth.ts:33-37`, `supabase/config.toml:316-320` |
| S2 | **SSRF via Garmin ping.** `fetchGarminCallback` fetches a URL taken from the request body with no host allowlist. Combined with S1, an unauthenticated caller can make the server fetch arbitrary URLs and ingest the response. | `supabase/functions/garmin-ping/index.ts:127` + ~9 more sites |
| S3 | **Final Surge client id *and secret* committed to git.** Both files are tracked and not gitignored, so the secret is in history. Rotating at the vendor is the only step that closes it. | `tool/final_surge_api_test.dart:23-24`, `test/manual_live/final_surge_api_test.dart:31` |
| S4 | **TrainingPeaks client secret committed to git** (sandbox credential). | `tool/tp_writeback_test.dart:21` |

The correct pattern already exists in-repo: `revenuecat-webhook` uses `verify_jwt = false` at the
gateway and validates a shared secret *inside* the function (`supabase/config.toml:331-333`). S1's
bypass appears deliberate (comment cites Garmin's Data Generator omitting the header), so tightening
it needs knowledge of real production traffic.

## Correctness

| # | Finding | Evidence |
|---|---|---|
| C1 | **Pace conversion inverted in a fallback path.** min/km → min/mile needs `×1.60934`; this branch multiplies by `kmToMiles` (0.621371), the reciprocal. A 5:00/km target becomes 3:06/mi instead of 8:03/mi. No test covers the branch. | `final_surge_transformer.dart:1331` vs correct path `:1252` |
| C2 | **TP write-back defaults ON in code, spec says OFF.** `tpWritebackEnabled` returns `?? true`; spec says "Default: OFF (opt-in to avoid surprising users)". | `preferences_service.dart:37` vs `docs/integration/tp_write/README.md:232` |
| C3 | **TP write-back `PUT` is a full-object replace** — omitted fields are nulled. GET→mutate→PUT, but nothing verifies the GET returns every PUT-preservable field. | `training_peaks`/writeback path |
| C4 | **Garmin `calendar_date` derivation inconsistent** — body composition computes it in UTC without applying the offset; epochs apply it correctly. | garmin health mapping |
| C5 | **TP `PercentOfThresholdHr/Speed` missing from the intensity switch** — classified against FTP thresholds, the wrong scale. | training_peaks intensity classification |
| C6 | **TP zone cache never expires.** 24h cache keys off `integration.updatedAt`, which token refresh bumps hourly. | training_peaks athlete/zones |

## Stale / dead

| # | Finding | Evidence |
|---|---|---|
| D1 | **`supabase/functions/sync-final-surge/index.ts` is dead code** — no caller, field names (`data.workouts`, `sport: 'RUNNING'`) don't match the real API. | |
| D2 | `docs/integration/vdot/README.md:107` states a `−7d/+14d` sync window; code is `−14d/+45d`. | `vdot_sync_service.dart:68-69` |
| D3 | `garmin-push/index.ts:10-15` header comment describes a "match-only" strategy the code no longer implements. | |
| D4 | `garmin-ping` duplicates record construction inline instead of sharing `mappers.ts`. | |
