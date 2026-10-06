# 08: Migrate: integrations and coach mode

**What to build:** Every catch block in the integrations feature (Garmin, TrainingPeaks, FinalSurge, VDOT, sync coordinator) and coach mode, including every `kDebugMode`-guarded print around token refresh and event sync is classified and moved to `Report`: a swallowed failure becomes a Fault, an expected-but-bad condition a Degraded, a best-effort branch a Note with its area set, and a try/catch that hides a real bug is removed so the error propagates. Direct Sentry SDK calls in these directories route through `Report`. Every baseline entry for these directories is deleted from the guard's allow-list; any catch left deliberately silent gets a reasoned entry instead. The ticket's closing comment lists every site and its classification so review can overrule one.

**Blocked by:** 01 Report service exists; 04 Source guard with a baseline

**Status:** done (2026-10-06, wave 3; parts merged on `sentry`)

- [x] No baseline entry remains for the integrations feature (Garmin or the other directories in scope; the guard test is green
- [x] No `print`, `debugPrint`, logger-only or empty catch remains in scope; each is a `Report` call, a rethrow, or a reasoned allow-list entry
- [x] No direct Sentry SDK import remains in scope
- [x] The ticket records each site's classification (Fault / Degraded / Note / removed / reasoned)
- [x] Existing tests in scope still pass; where a catch becomes a Fault on a tested path, the test asserts the report through `NoopReport` or the transport, not console output

## Sites

Part A: `lib/features/integrations/application/**` (ticket 08a, 2026-10-06). Areas: `garmin`,
`training_peaks`, `final_surge`, `vdot`, `runna`; the sync coordinator uses `sync` (Notes promote to
warnings, rule D9 — intended). Report reaches plain classes by constructor injection
(`Report? report`, falling back to `SentryReport.global`), the coordinator via `ref.read(reportProvider)`;
`integrations_providers.dart` / `tp_writeback_providers.dart` pass `ref.read(reportProvider)` in.
Every `kDebugMode` print in the OAuth, sync, write-back and coordinator files is gone: progress lines are
`report.debug`, skipped branches are Notes; OAuth callback / raw-URL / code / token prints were dropped
outright (never log a code). Transformer parser dumps (`TP TRANSFORM DEBUG` etc.) were left alone: not a
catch, not token/sync.

Counts: 21 Fault, 27 Degraded, 18 Note, 3 Reasoned, 0 Removed; 2 Sentry imports routed through Report;
94 baseline lines deleted (63 unreportedCatch, 29 printInCatch, 2 sentryImport).

### garmin_oauth_service.dart
- `lib/features/integrations/application/garmin_oauth_service.dart:203` — Fault — garmin_user_mappings delete failed on disconnect; an orphaned server mapping keeps routing pushes (local deactivation still runs)
- `lib/features/integrations/application/garmin_oauth_service.dart:364` — Degraded — body-comp fetch failed; profile continues without weight/body-fat
- non-catch: body-comp non-200 → Note; mapping upsert skipped in onboarding → Note; no active integration → Note; flow progress → debug

### training_peaks_oauth_service.dart
- `lib/features/integrations/application/training_peaks_oauth_service.dart:250` — Degraded — refresh token rejected by TP; integration parked in `error` until reconnect
- `lib/features/integrations/application/training_peaks_oauth_service.dart:303` — Degraded — force-refresh rejected; same handling
- `lib/features/integrations/application/training_peaks_oauth_service.dart:343` — Degraded — deauthorize failed (token may already be dead); local disconnect continues

### vdot_oauth_service.dart
- `lib/features/integrations/application/vdot_oauth_service.dart:183` — Note — malformed percent-encoding in a callback param, raw text kept (key only; the value may be the code). `_parseCallbackParams` became an instance method to reach `_r`

### training_peaks_sync_service.dart
- `lib/features/integrations/application/training_peaks_sync_service.dart:135` — Note — token expired before workout sync; the cause was already Degraded in `_refreshToken`
- `lib/features/integrations/application/training_peaks_sync_service.dart:152` — Degraded — zone fetch failed; sync runs with default zones
- `lib/features/integrations/application/training_peaks_sync_service.dart:166` — Degraded — metrics fetch failed (A1: 401/403 expected); sync continues
- `lib/features/integrations/application/training_peaks_sync_service.dart:331` — Degraded — token expired mid workout sync although pre-flight passed
- `lib/features/integrations/application/training_peaks_sync_service.dart:346` — Fault — workout sync failed (auto-downgrades for network)
- `lib/features/integrations/application/training_peaks_sync_service.dart:395` — Note — token expired before date-range sync
- `lib/features/integrations/application/training_peaks_sync_service.dart:409` — Degraded — zone fetch failed (date-range)
- `lib/features/integrations/application/training_peaks_sync_service.dart:539` — Degraded — token expired mid date-range sync
- `lib/features/integrations/application/training_peaks_sync_service.dart:553` — Fault — date-range sync failed
- `lib/features/integrations/application/training_peaks_sync_service.dart:595` — Note — token expired before event sync
- `lib/features/integrations/application/training_peaks_sync_service.dart:636` — Degraded — token expired mid event sync
- `lib/features/integrations/application/training_peaks_sync_service.dart:644` — Fault — event sync failed
- `lib/features/integrations/application/training_peaks_sync_service.dart:672` — Note — token expired before next-event sync
- `lib/features/integrations/application/training_peaks_sync_service.dart:704` — Degraded — token expired mid next-event sync
- `lib/features/integrations/application/training_peaks_sync_service.dart:712` — Fault — next-event sync failed
- `lib/features/integrations/application/training_peaks_sync_service.dart:741` — Fault — `syncEvents` threw past its own handling inside `syncAll`
- `lib/features/integrations/application/training_peaks_sync_service.dart:824` — Note — athlete-metrics cache malformed; refetching
- `lib/features/integrations/application/training_peaks_sync_service.dart:944` — Degraded — refresh token rejected (block rethrows TokenExpired; this is where the status code is). Also Degraded before the throw on the no-refresh-token path
- non-catch: payload duplicates deduped → Note; local duplicates removed → Note; per-item Inserted/Updated/Revived/Soft-deleted prints dropped in favour of one summary `debug` with counts

### final_surge_sync_service.dart
- `lib/features/integrations/application/final_surge_sync_service.dart:140` — Note — token expired mid-request; refreshed and retried (upcoming chunk)
- `lib/features/integrations/application/final_surge_sync_service.dart:165` — Note — same, date-range chunk
- `lib/features/integrations/application/final_surge_sync_service.dart:208` — Note — date-range endpoint 404 on this tenant; falling back to UpcomingWorkouts (non-404 rethrows, unchanged)
- `lib/features/integrations/application/final_surge_sync_service.dart:263` — Degraded — structured-workout fetch failed; workout syncs without its distribution
- `lib/features/integrations/application/final_surge_sync_service.dart:411` — Degraded — token refresh failed (requiresReauth in extra)
- `lib/features/integrations/application/final_surge_sync_service.dart:430` — Degraded — network failure; status untouched so the user can retry
- `lib/features/integrations/application/final_surge_sync_service.dart:439` — Fault — sync failed
- `lib/features/integrations/application/final_surge_sync_service.dart:550` — Note — token expired mid-request (date-range sync); refreshed and retried
- `lib/features/integrations/application/final_surge_sync_service.dart:593` — Degraded — structured-workout fetch failed (date-range sync)
- `lib/features/integrations/application/final_surge_sync_service.dart:710` — Degraded — token refresh failed (date-range sync)
- `lib/features/integrations/application/final_surge_sync_service.dart:728` — Degraded — network failure (date-range sync)
- `lib/features/integrations/application/final_surge_sync_service.dart:736` — Fault — date-range sync failed
- non-catch: duplicates → Notes; per-item prints dropped for one summary `debug`

### vdot_sync_service.dart
- `lib/features/integrations/application/vdot_sync_service.dart:183` — Degraded — token refresh failed
- `lib/features/integrations/application/vdot_sync_service.dart:201` — Degraded — network failure
- `lib/features/integrations/application/vdot_sync_service.dart:209` — Fault — sync failed
- `lib/features/integrations/application/vdot_sync_service.dart:251` — Note — token expired mid-chunk; refreshed and retried

### runna_sync_service.dart
- `lib/features/integrations/application/runna_sync_service.dart:250` — Degraded — feed unreachable (network); status untouched
- `lib/features/integrations/application/runna_sync_service.dart:259` — Degraded — feed answered but not with a calendar (revoked URL / 4xx / 5xx); integration marked error
- `lib/features/integrations/application/runna_sync_service.dart:275` — Fault — sync failed

### tp_writeback_service.dart (Sentry import removed; `_logError` + `Sentry.captureException` gone)
- `lib/features/integrations/application/tp_writeback_service.dart:82` — Fault — ledger row open failed; push refused (TP-5), nothing else would say so
- `lib/features/integrations/application/tp_writeback_service.dart:107` — Fault — ledger row close failed; row left as `attempt`
- `lib/features/integrations/application/tp_writeback_service.dart:184` — Fault — pushPlanToWorkout failed (fire-and-forget)
- `lib/features/integrations/application/tp_writeback_service.dart:290` — Degraded on the retry branch (fresh token still refused: the account, not the token); Notes on the first-401 and force-refresh-failed branches
- `lib/features/integrations/application/tp_writeback_service.dart:331` — Reasoned — delegates to `handleApiException`, which reports every status through Report; the guard only sees the block text
- `lib/features/integrations/application/tp_writeback_service.dart:370` — Fault — pushCompletionFeedback failed
- `lib/features/integrations/application/tp_writeback_service.dart:437` — Note — feedback push 401; refresh-and-retry, or abandoned after refresh
- `lib/features/integrations/application/tp_writeback_service.dart:455` — Reasoned — same as 331 (feedback push)
- `lib/features/integrations/application/tp_writeback_service.dart:514` — Note — plan removal 401; refresh-and-retry
- `lib/features/integrations/application/tp_writeback_service.dart:545` — Reasoned — same as 331 (plan removal)
- `lib/features/integrations/application/tp_writeback_service.dart:547` — Fault — removePlanFromWorkout failed
- `lib/features/integrations/application/tp_writeback_service.dart:594` — Degraded — per-workout strip failed on disconnect (athlete may have revoked access); loop continues
- `lib/features/integrations/application/tp_writeback_service.dart:621` — Fault — server ledger purge on disconnect failed
- `lib/features/integrations/application/tp_writeback_service.dart:630` — Fault — handleDisconnect failed
- `lib/features/integrations/application/tp_writeback_service.dart:703` — Note — premium status unreadable (informational only, A1)
- `handleApiException`: 403 → Degraded (TP refused the push; block armed), 404 → Note (workout gone; tracking removed), else → Degraded (was `Sentry.captureException`)
- non-catch: no ledger client → Note (push refused, TP-5); no valid token → Note; in-flight / hash-unchanged skips → debug

### integration_sync_coordinator.dart (area `sync`; `AppLogger` dropped)
- `lib/features/integrations/application/integration_sync_coordinator.dart:94` — Note — dead-man check could not be wired; skipped (best-effort by contract)
- `lib/features/integrations/application/integration_sync_coordinator.dart:115` — Degraded — integrations row sync failed; continuing with local data (was `_logger.warning`)
- `lib/features/integrations/application/integration_sync_coordinator.dart:205` — Note — connect-training controller unavailable; manual-sync dedup skipped
- `lib/features/integrations/application/integration_sync_coordinator.dart:326` — Fault — post-sync provider event import failed (the 2026-09-13 discard bug) (was `_logger.warning`)
- `lib/features/integrations/application/integration_sync_coordinator.dart:365` — Fault — post-sync dirty-activity upload threw (was `_logger.warning`); a `success == false` result is a Note (uploadDirtyRecords swallows exceptions into the result)
- `lib/features/integrations/application/integration_sync_coordinator.dart:381` — Fault — a sync service threw past its result object (was `_logger.error`)
- non-catch: unknown provider → Degraded(LoggedFault); "sync reported failure, cooldown armed" → Note (the service already reported the cause); skips → debug

### raw_retention_dead_man_check.dart (Sentry import removed; `SentryReporter` + `AppLogger` params replaced by `Report? report`)
- `lib/features/integrations/application/raw_retention_dead_man_check.dart:82` — Note — audit read failed (table absent / RLS / offline); must never false-alarm a pre-migration DB. Area `integrations` so it is not promoted
- stale sweep: `captureMessage(warning)` → `degraded(LoggedFault('raw_retention_sweep_stale'))`, same tags/extra/fingerprint

### synced_workout_analytics.dart
- `lib/features/integrations/application/synced_workout_analytics.dart:31` — Fault — analytics tracker threw for a synced workout (was `catch (_) {}`); `Report? report` param, callers pass `_r`

### transformers (const constructors gained `{Report? report}`)
- `lib/features/integrations/application/vdot_transformer.dart:196` — Note — V.O2 eventDate unparseable; workout dropped
- `lib/features/integrations/application/training_peaks_transformer.dart:883` — Degraded — structure JSON unparseable; distribution dropped (DI-26: null, never a guess)
- `lib/features/integrations/application/final_surge_transformer.dart:1549` — Degraded — structured workout unparseable; distribution dropped

### Tests
- `test/features/integrations/raw_retention_dead_man_check_test.dart` rewritten on `RecordingReport` (Degraded on stale/never, Note on a failing read, throttle)
- `test/features/integrations/integration_sync_coordinator_test.dart`: `reportProvider` overridden with `RecordingReport`; two new tests (reported failure → sync Note, throwing service → sync Fault + cooldown)
- Guard green; `flutter test test/features/integrations/` 420 green; `dart analyze lib/features/integrations` clean (pre-existing infos only)

### Left for others
- `final_surge_oauth_service.dart` (19 prints, none in a catch), `change_detection_service.dart` (3), `provider_event_import_service.dart` (1): no guard findings; prints untouched
- Transformer debug dumps (`TP/FS TRANSFORM DEBUG`, duration/distance/pace/intensity): untouched, not catch sites
- Part B: `integrations/{data,domain,presentation}` and `coach_mode`


## Part B: integrations data/domain/presentation + coach_mode

## Sites

### Baseline sites (74)

`lib/features/integrations/data/integrations_repository.dart`
- :489 — Degraded — best-effort push of migrated rows failed; rows stay dirty and retry (area `sync`)
- :501 — Fault — the user-id migration itself (a Drift write) failed and was swallowed; returns 0 (area `sync`)
- :684 — Note — stored athlete-zones JSON would not decode; the raw string is uploaded in its place

`lib/features/integrations/data/training_peaks_api_client.dart`
- :373 — Degraded — one day's event fetch failed and that day is skipped; was a kDebugMode print (area `training_peaks`)

`lib/features/integrations/data/vdot_api_client.dart`
- :68 — Reasoned — `_extractErrorMessage` reads the body as JSON only to pick out a message; a non-JSON body (HTML error page) is an expected input and the raw text is the fallback output

`lib/features/integrations/domain/athlete_zones.dart`
- :127 — Degraded — a stored zones blob that no longer parses is dropped; static parser, so via `SentryReport.global` (area `training_peaks`)

`lib/features/integrations/domain/integration.dart`
- :126 — Removed — the try/catch only guarded `int.parse`; replaced with `int.tryParse`, same null result, nothing can throw

`lib/features/integrations/domain/http_retry_client.dart` (`withRetry`, optional `Report? report` param)
- :96 — Degraded — SocketException: each retry is a `report.breadcrumb`, the give-up a Degraded before the NetworkException (area = provider)
- :108 — Degraded — TimeoutException, same shape
- :120 — Degraded — RateLimitException, same shape, rethrow after the Degraded
- :135 — Degraded — ServerException 5xx, same shape, rethrow after the Degraded

`lib/features/integrations/presentation/providers/integrations_providers.dart`
- :439 — Degraded — Garmin body-comp lookup failed; consumers would otherwise read it as "no data" (area `garmin`)

`lib/features/integrations/presentation/providers/connect_training_controller.dart`
(`Report get _report` falls back to `SentryReport.global` when the auto-dispose ref is gone; the
15 `_reportFailureToSentry` calls became `_report.integrationFailure(provider, phase, e, st)`, a
private extension that is a Fault tagged `provider`/`phase` with the provider as area)
- :307 — Note — `userIdProvider` timed out; falls back to the auth id (area `integrations`)
- old :530 — Removed — the `catch (_)` inside `_reportFailureToSentry`; the helper is gone, Report never throws
- :526 — Degraded — `_trackSafely`: the one catch that replaces the eight analytics `catch (_) {}` below
- :612 — Fault — connect failed (prints removed); state + snackbar unchanged
- :675 — Fault — disconnect failed
- :698 — Fault — hide workouts on soft-disconnect failed
- :712 — Fault — hide Garmin wellness rows failed
- :723 — Fault — clear integration autofill (hide path) failed
- :738 — Fault — macro-window invalidation failed
- :776 — Fault — purge workouts failed
- :793 — Fault — purge Garmin wellness + users mirror failed
- :812 — Fault — purge provider_raw_payloads failed
- :831 — Fault — clear integration autofill (purge path) failed
- :975 — Fault — Garmin backfill invoke threw; transient 502/rate-limit branch is a Degraded with retry scheduled, anything else a Fault (prints removed)
- :1185 — Fault — upload of synced VDOT activities threw (print removed; area `sync`)
- :1246 — Fault — VDOT import failed
- :1341 — Note — Runna feed URL rejected before any network call (user input; shown inline) (area `runna`)
- :1363 — Fault — Runna connect failed (print removed)
- :1482 — Fault — upload of synced Runna activities threw (print removed; area `sync`)
- :1530 — Fault — Runna import failed
- :1697 — Fault — upload of synced FS/TP activities threw (print removed; area `sync`)
- :1770 — Fault — FS/TP import failed
- :1876 — Degraded — TP write-back cleanup skipped on disconnect; disconnect proceeds (area `training_peaks`)
- :1959 — Fault — post-import provider invalidation failed (print removed)
- old :1976, :1990, :2003, :2015, :2032, :2044, :2063, :2080 — Removed — eight `catch (_) {}` around analytics calls collapsed into `_trackSafely` (one Degraded naming the event)

`lib/features/coach_mode/data/coach_repository.dart`
- :2154 — Degraded — coach name lookup failed; the relationship is returned without a name

`lib/features/coach_mode/presentation/providers/athlete_detail_controller.dart`
- :192 — Fault — athlete detail load failed; placeholder state with error
- :341 — Fault — coach message send failed
- :376 — Fault — coach message delete failed

`lib/features/coach_mode/presentation/providers/coach_activity_detail_controller.dart`
- :85 — Degraded — analytics track threw; UI unaffected
- :212 — Fault — coach delete of an athlete activity failed and returned `false` silently
- :364 — Fault — coach nutrition-plan update failed; state error kept (remote-ack write, behaviour unchanged)
- :567 — Degraded — stored fuel log unreadable; not shown

`lib/features/coach_mode/presentation/providers/coach_chat_controller.dart`
- :275 — Fault — chat send failed; message kept pending/failed as before
- :383 — Fault — chat retry failed; same

`lib/features/coach_mode/presentation/providers/coach_dashboard_controller.dart`
- :95 — Fault — dashboard load failed
- :164 — Fault — accept athlete request failed (remote-ack kept)
- :204 — Fault — decline athlete request failed
- :241 — Fault — archive athlete failed

`lib/features/coach_mode/presentation/providers/coach_directory_controller.dart`
- :51 — Fault — coach directory load failed
- :92 — Fault — coach connection request failed

`lib/features/coach_mode/presentation/providers/coach_reports_controller.dart`
- :683 — Degraded — `_parseJson`: stored nutrition JSON unreadable; treated as absent
- :839 — Degraded — `_extractActualCalories`: stored fuel log unreadable; calories omitted

`lib/features/coach_mode/presentation/providers/invite_athlete_controller.dart`
- :28 — Fault — invite athlete failed; `AsyncError` kept

`lib/features/coach_mode/presentation/providers/my_coaches_controller.dart`
- :69 — Fault — my-coaches load failed
- :140 — Fault — accept coach request failed
- :179 — Fault — decline coach request failed

`lib/features/coach_mode/presentation/widgets/portal_athlete_detail_panel.dart`
- :444 — Fault — carb-loading plan create failed (snackbar kept)
- :612 — Fault — carb-loading plan delete failed
- :845 — Fault — coach delete of athlete activity failed

`lib/features/coach_mode/presentation/widgets/portal_sidebar.dart`
- :360 — Degraded — active pairing-code lookup failed; dialog shows none
- :418 — Fault — pairing-code generation failed

`lib/features/coach_mode/presentation/widgets/portal_nutrition_targets_form.dart`
- :270 — Fault — nutrition targets save failed
- :323 — Fault — nutrition targets reset failed

`lib/features/coach_mode/presentation/widgets/portal_athlete_profile_form.dart`
- :156 — Fault — athlete profile save failed

`lib/features/coach_mode/presentation/widgets/activity_coach_feedback_widget.dart`
- :138 — Fault — activity comment send failed

Tally of the 74: Fault 45 · Degraded 15 · Note 3 · Removed 10 · Reasoned 1.

### Legacy alias conversions in the same files (not baseline lines; brief § Getting a Report)

`lib/features/integrations/data/integrations_repository.dart` — constructor takes `Report? report`
in place of `SentryReporter sentry`; the paired `_sentry.reportNetworkError` calls are gone.
- :103 — Fault — syncFromRemote failed (area `sync`)
- :128 — Degraded — remote `users` row check failed; upload deferred (was `_logger.warning` with no error object)
- :207 — Fault — uploadDirtyRecords failed (area `sync`)
- :337 — Degraded — remote delete failed; local row already removed
- :548 — Degraded — immediate upsert failed; row stays dirty (area `sync`)

`lib/features/coach_mode/data/coach_repository.dart` — constructor takes `Report? report` in place
of `SentryReporter sentry`; provider wires `ref.read(reportProvider)`. 39 Fault / 5 Degraded /
6 Note, one per former `_logger.error` / `_logger.warning`:
- Fault :207 :244 :286 :319 :377 :439 :496 :526 :607 :665 :723 :781 :854 :876 :908 :970 :1039
  :1106 :1177 :1250 :1339 :1388 :1451 :1515 :1543 :1577 :1602 :1655 :1839 :1969 :1980 :2050
  :2090 :2169 :2211 :2274 :2307 :2426 :2436 — each a `_logger.error` + rethrow/return site; message kept
- Degraded :564 :636 :694 :752 :1645 — "Immediate upload failed; record stays dirty for retry"
- Note :1473 :1508 :1959 :2010 :2024 :2035 — branch warnings with no error object (invalid code format, user not found, duplicate relationship, code not found / used / expired)

`lib/features/coach_mode/presentation/providers/coach_dashboard_controller.dart`
- :126 — Fault — background sync failed (was `logger.error`)

`lib/features/coach_mode/presentation/providers/my_coaches_controller.dart`
- :98 — Fault — background sync failed (was `logger.error`)

`lib/features/coach_mode/presentation/providers/coach_reports_controller.dart` (`_logger` getter
replaced by `_report`)
- :283 — Degraded — some athlete syncs failed; overview uses local data (`catchError`)
- :388 — Degraded — athlete overview failed to load; shown without numbers
- :416 — Degraded — athlete sync failed; report uses local data (`catchError`)
- :509 — Degraded — stored fuel log unreadable; actuals omitted

### Tests
- `test/new_sync/coach_repository_sync_test.dart` — `MockSentryReporter` replaced by `RecordingReport`
- `test/features/integrations/connect_identity_seam_test.dart` — `sentry:` arg dropped from the real `IntegrationsRepository`
- `test/features/coach_mode/presentation/coach_dashboard_controller_test.dart` — accept-request remote failure now also asserts one `coach_mode` Fault through `RecordingReport`
- `test/features/coach_mode/presentation/my_coaches_controller_test.dart` — load-throws test asserts one `coach_mode` Fault
- `test/features/coach_mode/presentation/coach_chat_controller_test.dart` — send-failure test asserts one `coach_mode` Fault

### Left for other tickets
- `lib/features/coach_mode/data/coach_messaging_repository.dart` still uses `_logger.warning` + `_sentry.reportNetworkError` (reported via legacy alias, not a guard finding; untouched here) — ticket 10.
- `integrations_providers.dart` keeps its `sentry_reporter.dart` import for `rawRetentionDeadManCheck` (application layer, part A).
- kDebugMode prints outside catch blocks in `connect_training_controller.dart` are untouched (not guard findings).
