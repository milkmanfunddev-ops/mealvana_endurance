# 08 part B: sites (integrations data/domain/presentation + coach_mode)

Part B of ticket 08. Part A (`lib/features/integrations/application/**`) appends to
`08-migrate-integrations-and-coach-mode.md`; this file holds part B so the two do not
collide. Line numbers are as of the part B commit.

**Status:** done

Baseline lines deleted from `test/shared/source_guard/allow_list.md`: 82 (74 sites; 7
`printInCatch` lines in `connect_training_controller.dart` and 1 in
`training_peaks_api_client.dart` shared a catch with an `unreportedCatch` line). One
`## reasoned` entry added (vdot_api_client). Guard test green.

Area choice: `sync` for the integrations repository's remote read/write pipeline (so
the Notes there are D9-promoted), the provider's own name (`garmin`, `training_peaks`,
`runna`, `vdot`, `final_surge`) where the file or branch is provider-specific,
`integrations` otherwise, `coach_mode` for everything under coach_mode.

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
