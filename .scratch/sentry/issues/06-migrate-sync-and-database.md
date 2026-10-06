# 06: Migrate: sync and database

**What to build:** Every catch block in the sync coordinator, the data sync service, every entity sync handler, dirty-record upload, and the Drift database, schema manager and DAOs is classified and moved to `Report`: a swallowed failure becomes a Fault, an expected-but-bad condition a Degraded, a best-effort branch a Note with its area set, and a try/catch that hides a real bug is removed so the error propagates. Direct Sentry SDK calls in these directories route through `Report`. Every baseline entry for these directories is deleted from the guard's allow-list; any catch left deliberately silent gets a reasoned entry instead. The ticket's closing comment lists every site and its classification so review can overrule one.

**Blocked by:** 01 Report service exists; 04 Source guard with a baseline

**Status:** done

- [x] No baseline entry remains for the sync coordinator or the other directories in scope; the guard test is green
- [x] No `print`, `debugPrint`, logger-only or empty catch remains in scope; each is a `Report` call, a rethrow, or a reasoned allow-list entry
- [x] No direct Sentry SDK import remains in scope
- [x] The ticket records each site's classification (Fault / Degraded / Note / removed / reasoned)
- [x] Existing tests in scope still pass; where a catch becomes a Fault on a tested path, the test asserts the report through `NoopReport` or the transport, not console output

## Sites

Branch `sentry`, worktree commit of 2026-10-06. Guard-counted sites first, then
the legacy `_logger.error`-in-catch sites the brief folds in, then non-catch
prints and silent paths converted on the way. Area `sync` promotes Notes to
warning events (rule D9); area `database` does not.

### Guard-counted baseline sites (23 lines deleted)

- lib/shared/database/connection_native.dart (sentryImport) — Removed — `sentry_drift` import gone; the interceptor is built in `bootstrap.dart` and handed in through `AppDatabase.queryInterceptorFactory`, applied by `_openConnection`; native only, as before.
- lib/shared/services/sync/data_sync_service.dart (sentryImport) — Removed — `Sentry.captureException` replaced by `_report.fault`.
- lib/shared/services/sync/sync_coordinator.dart (sentryImport) — Removed — `_sentry.reportCriticalError` / `captureMessage` replaced by `_report.fault` / `note`.
- lib/shared/database/app_database.dart:838 — Fault — a PRAGMA table_info query failing during schema validation is not a schema mismatch; the error string still joins the DatabaseSchemaException.
- lib/shared/database/app_database.dart:1028 (`closeError`, was printInCatch too) — Degraded — the files are deleted regardless; an open handle on a deleted file is worth a warning. Print removed.
- lib/shared/database/app_database.dart (`isDatabaseHealthy`, `canExecuteQueries`) — Removed — dead duplicates of the DiagnosticDao methods; no caller in lib or test. Two baseline lines.
- lib/shared/database/daos/diagnostic_dao.dart:477 — Degraded — startup acts on the `false`; this records why the integrity check could not run.
- lib/shared/database/daos/diagnostic_dao.dart:497 — Degraded — same for the basic query probe.
- lib/shared/database/daos/foods_dao.dart:228 (`on FormatException`) — Note — legacy TEXT timestamps found; normalised and retried, a one-time repair path.
- lib/shared/database/daos/foods_dao.dart:385 — Degraded — a malformed remote `user_foods` row is skipped; the food id is in `extra`.
- lib/shared/database/daos/foods_dao.dart:523 — Note — categories looked like JSON but did not parse; comma split used instead.
- lib/shared/database/daos/foods_dao.dart:548 — Note — unknown category value dropped from the list.
- lib/shared/database/schema_manager.dart (4 sites) — Removed — `DatabaseSchemaManager` had no caller in lib or test (expected three tables from an early schema); file deleted.
- lib/shared/database/tables/user_profiles.dart:317 — Degraded — `users.food_preferences` JSON did not parse; row loads with empty preferences. Const converter, so `SentryReport.global`.
- lib/shared/services/sync/data_sync_service.dart:252 (`on TimeoutException`) — Degraded — a 30 s edge timeout is expected on slow links; client-side download takes over.
- lib/shared/services/sync/data_sync_service.dart:261 — Fault — any other edge function failure; `fault` downgrades network failures itself.
- lib/shared/services/sync/entity_sync/activity_sync_handler.dart:422 (`_encodeJsonIfNeeded`) — Degraded — remote JSON could not be re-encoded; stored NULL.
- lib/shared/services/sync/entity_sync/activity_sync_handler.dart:441 (`_decodeJsonIfNeeded`) — Note — local JSON column did not parse; raw string uploaded.

### Legacy `_logger.error` catches converted (same files, per the brief)

- lib/shared/services/sync/sync_coordinator.dart:233 (`ensureSynced`) — Fault — best-effort sync swallowed the error; tag `repo`.
- lib/shared/services/sync/sync_coordinator.dart:313 (`_repositoryFor`) — Degraded (was `_logger.warning`) — provider could not be built; dependency treated as a no-op.
- lib/shared/services/sync/sync_coordinator.dart:475 (`sync`) — Fault — legacy full sync swallowed into `false`; tag `trigger`.
- lib/shared/services/sync/sync_coordinator.dart:568 (per-repo upload failure, not a catch) — Degraded — `uploadDirtyRecords()` swallowed into `UploadResult.failed()`; rows stay dirty; `LoggedFault` carries the repo and the error string.
- lib/shared/services/sync/sync_coordinator.dart:583 (upload failure summary) — Note (promoted) — replaces `_sentry.captureMessage(warning)` and the duplicate `_logger.warning`; skipped repos ride in `data`. The per-skip `_logger.warning` became `_logger.info` since the summary records it.
- lib/shared/services/sync/sync_coordinator.dart:594 (`_uploadAllDirtyRecords`) — Fault — orchestration failure; every repo reported unsuccessful to the caller, unchanged.
- lib/shared/services/sync/sync_coordinator.dart:700 (force sync offline skip, not a catch) — info — offline is the user's situation; a structured log, not an event per pull-to-refresh.
- lib/shared/services/sync/sync_coordinator.dart:743 (`forceSyncRepository`) — Fault — best-effort; tag `repo`.
- lib/shared/services/sync/data_sync_service.dart:120 (`syncAllData`) — Fault — the one swallow for the whole download; replaces logger + direct Sentry call.
- lib/shared/services/sync/data_sync_service.dart:182 (`needsFullSync`) — Fault — DB read failed; full sync forced.
- lib/shared/services/sync/data_sync_service.dart:387 (`_syncDataFromEdgeFunction`) — breadcrumb + rethrow — the transaction rolled back; `_tryEdgeFunctionSync` owns the swallow and reports.
- lib/shared/services/sync/data_sync_service.dart:414 (`_clientSideDownload`) — breadcrumb + rethrow — `syncAllData` owns the swallow.
- lib/shared/services/sync/data_sync_service.dart:430, 448, 475, 499, 535 (`_download*`) — Fault each — per-entity swallow so the other entities still land; tag `entity`.
- lib/shared/services/sync/duplicate_cleanup_service.dart:96, 206, 324 — Fault each — cleanup failure returns 0 so sync continues; tag `table` where known.
- lib/shared/services/sync/entity_sync/activity_sync_handler.dart:271 (`upsertActivity`) — Fault — one bad row must not stop the download; `activityId` in `extra`.
- lib/shared/services/sync/entity_sync/activity_sync_handler.dart:352 (`syncAthleteActivities`) — Fault — coach view batch; count in `extra`.
- lib/shared/services/sync/entity_sync/carb_loading_sync_handler.dart:109, 186, 210 — Fault each — plan / day upsert and athlete batch.
- lib/shared/services/sync/entity_sync/coach_sync_handler.dart:95 (`syncCoachMessagesForActivity`) — breadcrumb + rethrow — the feedback screen owns the error.
- lib/shared/services/sync/entity_sync/coach_sync_handler.dart:189 (`syncAthleteData`) — breadcrumb + rethrow — caller owns it.
- lib/shared/services/sync/entity_sync/coach_sync_handler.dart:254, 323, 374, 424, 463 — Fault each — coach record, relationships, messages, athlete profiles, coach profiles; swallowed so other slices continue.
- lib/shared/services/sync/entity_sync/event_sync_handler.dart:108, 133 — Fault each — event upsert and athlete batch.
- lib/shared/services/sync/entity_sync/food_preference_sync_handler.dart:102 — Fault — swallowed; count in `extra`.
- lib/shared/services/sync/entity_sync/user_sync_handler.dart:118 (`syncUsers`) — breadcrumb + rethrow — rethrow is the FK guard; `syncAllData` reports. Breadcrumb names the FK consequence.
- lib/shared/services/sync/entity_sync/user_sync_handler.dart:178 (`saveRemoteUserProfile`) — breadcrumb + rethrow — caller owns it.
- lib/shared/services/sync/entity_sync/user_sync_handler.dart:209, 257 — Fault each — profile and food-preference upload swallowed so other uploads continue; rows stay dirty.

### Non-catch prints and silent paths in app_database.dart

- :852 (schema validation failed, before delete) — Note — the thrown DatabaseSchemaException carries the errors; the Note records the deletion. Replaces two `kDebugMode` prints.
- :871 (validation passed) — debug — replaces a print.
- :901 (integrations CHECK rebuild) — Note — replaces a print.
- :1002 (`handleSchemaError`, recovery already attempted) — Degraded — a second schema error in one session means the Drift schema itself is wrong and the bail was silent in release. Replaces four prints.
- :1016 (`handleSchemaError`, deleting database) — Note — replaces three prints.
- :1133 (`_openConnection`, no interceptor installed) — Note — a database opened before the bootstrap set the factory would silently lose every span.

### Left alone

- `deleteAndResync` catch (`throw Exception('Database recovery failed: $e')`) — already an escape; not a guard finding. Loses the original stack trace; a candidate for `Error.throwWithStackTrace` later.
- Non-catch `_logger.info` / `_logger.debug` / `_logger.warning` narrative in the handlers and coordinator — outside the ticket; ticket 10 retires the alias.
- `lib/shared/database/daos/food_preferences_dao.dart:164` `dead_null_aware_expression` — pre-existing analyzer warning, untouched.

### Tests

- `test/new_sync/sync_coordinator_v2_test.dart`: every container now overrides `reportProvider` with `RecordingReport`; the two "handles errors gracefully" tests assert the Fault (area, message, `repo` tag).
- `test/new_sync/data_sync_service_test.dart`: `DataSyncService` takes `report` instead of `logger`; the four log assertions became Fault assertions (STEP 0 failure, edge apply failure, per-entity failure, the documented all-fail hazard).

