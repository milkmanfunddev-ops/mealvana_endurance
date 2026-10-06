# 05: Migrate: startup, auth, shared services

**What to build:** Every catch block in the app-startup feature, the auth feature, and shared services other than sync and database (including the deferred-step runner, session check, plan initialisation, the auth edge repository, post-sign-in sync, the RevenueCat init catch) is classified and moved to `Report`: a swallowed failure becomes a Fault, an expected-but-bad condition a Degraded, a best-effort branch a Note with its area set, and a try/catch that hides a real bug is removed so the error propagates. Direct Sentry SDK calls in these directories route through `Report`. Every baseline entry for these directories is deleted from the guard's allow-list; any catch left deliberately silent gets a reasoned entry instead. The ticket's closing comment lists every site and its classification so review can overrule one.

**Blocked by:** 01 Report service exists; 04 Source guard with a baseline

**Status:** done

- [x] No baseline entry remains for the app-startup feature or the other directories in scope; the guard test is green
- [x] No `print`, `debugPrint`, logger-only or empty catch remains in scope; each is a `Report` call, a rethrow, or a reasoned allow-list entry
- [x] No direct Sentry SDK import remains in scope
- [x] The ticket records each site's classification (Fault / Degraded / Note / removed / reasoned)
- [x] Existing tests in scope still pass; where a catch becomes a Fault on a tested path, the test asserts the report through `NoopReport` or the transport, not console output

## Sites

Line numbers are as committed. Areas: `startup` for the startup feature (Notes promote to warnings, rule D9), `auth` for the auth feature, otherwise the component name. Legacy aliases (`_sentry.report*`, `_logger.error/warning` in a catch, `sentry.addBreadcrumb`) in every file touched were converted to `Report` in the same pass; `_logger.info` calls stay.

### lib/features/app_startup
- app_startup_provider.dart:249 — Fault — startup build threw; rethrown into the AsyncNotifier error state
- app_startup_provider.dart:324 — Fault — onboarding snapshot restore failed; startup continues as a fresh install
- app_startup_provider.dart (not catches) — four `_logger.warning` branches (force upgrade, resync required, resync deferred, snapshot skipped/restored) are Notes; "Schema resync failed" is Degraded; two `sentry.addBreadcrumb` are `Report.breadcrumb`
- app_startup_service.dart:73 — Degraded | Note — profile read before the health check: a null-check error is Degraded (recovery follows), anything else is a Note instead of being read as "fresh install"
- app_startup_service.dart:134 — Fault — null-value fix failed; database deleted and recreated
- app_startup_service.dart:198 — Degraded — dirty records could not be uploaded before corruption recovery
- app_startup_service.dart:232 — Fault — database initialization failed
- app_startup_service.dart:247 — Fault — recovery after that failed; rethrown
- app_startup_service.dart:276 — Fault — a deferred step failed (`step` tag); the chain continues
- app_startup_service.dart:370 — Fault — the deferred chain itself failed
- app_startup_service.dart:458 — Note — local profile lookup failed; analytics identifies with the device id
- app_startup_service.dart:487 — Fault — analytics initialization failed (retry allowed)
- app_startup_service.dart:521 — Fault — RevenueCat initialization failed (`component: revenuecat`)
- app_startup_service.dart:544 — Fault — coach status sync failed
- app_startup_service.dart:567 — Degraded — identity set failed (ticket 02, unchanged)
- app_startup_service.dart:607 — Fault — session check failed (a missing profile is null, not a throw, so this is never the fresh-install case)
- app_startup_service.dart:634 — Fault — plan initialization failed
- app_startup_service.dart:663 — Fault — fallback food load failed (network downgrades itself)
- app_startup_service.dart:756 — Fault — dirty-record recovery handler failed (one call replaces logger.error + reportCriticalError)
- app_startup_service.dart:805 — Fault — a repository's backup upload failed; the loop continues
- app_startup_service.dart (not catches) — "corruption detected" and "backup could not be recovered" are Degraded; "context not mounted" and "dialog dismissed" are Notes
- force_upgrade_screen.dart:193 — Degraded — store launch threw on a screen the user cannot leave; snackbar still shown

### lib/features/auth
- auth_service.dart:164 — Fault — user creation failed; rethrown
- auth_service.dart:203 — Note — remote user update failed after the local id repair; sync catches up
- auth_service.dart:216 — Fault — get current user failed; returns null
- auth_service.dart:420 — Fault — food preference save failed; user-facing exception thrown
- auth_service.dart:455 — Fault — getFoodPreferences failed; returns null
- auth_service.dart:471 — Fault — getFoodPreferenceLevels failed; returns {}
- auth_service.dart:506 — Degraded — removeFoodPreferencesBySource failed; returns 0
- auth_service.dart:524 — Fault — getFoodPreferenceSources failed; returns {}
- auth_service.dart:546, 563, 582 — Fault — liked / disliked / willing-to-try reads failed; return [] (were reportDatabaseError)
- auth_service.dart:654 — Degraded — app_version reconcile failed; never costs a launch
- auth_service.dart (not catches) — `setUserContext` is `Report.setUser(effectiveUserId)`; two breadcrumbs are `Report.breadcrumb`
- auth_repository_edge.dart:76 — Note | Fault — create-user 409 (user exists) is a Note and handled as success; anything else is a Fault
- auth_repository_edge.dart:125, 157, 188, 335, 397 — Fault — fetch by device id / food preferences / update / upsert profile / delete failed; each returns its failure value
- auth_repository_edge.dart (not catches) — upsert "returned failure" is Degraded, "HTTP error" is Fault (were logger.warning / logger.error)
- user_repository.dart:81 — Fault — syncFromRemote failed; SyncResult.failed
- user_repository.dart:139 — Fault — uploadDirtyRecords failed; UploadResult.failed
- user_repository.dart:166, 183, 206, 269, 356, 372, 391, 709, 1005 — Fault — local reads/writes failed; rethrown (were reportDatabaseError / reportNetworkError + rethrow)
- user_repository.dart:240 — Fault — immediate upload failed; record marked dirty for retry
- user_repository.dart:325 — Fault — auth-provider upload failed; record stays dirty
- user_repository.dart:515 — Note — food preference reconcile failed; throttle stamp cleared so the next read retries (the fetch reports itself)
- user_repository.dart:572 — Fault — user_foods fetch failed
- user_repository.dart:603 — Note — old user's food preferences unreadable during reset; not transferred
- user_repository.dart:677 — Fault — reset-anonymous upsert failed; record stays dirty
- user_repository.dart:754 — Fault — remote profile fetch failed; returns null
- user_repository.dart:848 — Fault — food preferences fetch failed; returns {}
- user_repository.dart:877 — Fault — createUserInSupabase failed; local save fallback
- user_repository.dart (not catches) — eleven `sentry.addBreadcrumb` are `Report.breadcrumb`; `DebugLogger.warning` (server returned empty prefs, keeping local) is a Note. Constructor takes `Report? report`; provider passes `reportProvider`
- email_login_screen.dart:79 — Note — coach check failed after email login; routes to /main
- post_onboarding_auth_screen.dart:442 — Note — coach check failed after sign-in; routes to /main
- post_onboarding_auth_screen.dart:670 — Fault — post-onboarding upload threw
- post_onboarding_auth_screen.dart (not catches) — "upload incomplete" and "save failed" are Degraded; "sync did not complete" is a Note; the static helper takes `Report` instead of `AppLogger`
- verify_email_screen.dart:99, 138 — Note — the athlete typed a wrong code; the message is shown to them, the Note is the trail
- verify_email_screen.dart:112 — Fault — OTP verification threw something other than a bad code

### lib/shared
- controllers/food_search_controller.dart:134 — Reasoned — the catch is the mounted test (reading `state` after dispose throws)
- controllers/food_search_controller.dart:324, 399, 451 — Degraded — Open Food Facts / catalog / nutrition-product search failed; surface shows an error state
- data/syncable_repository.dart:95 — Note (`sync`) — stored last-sync timestamp unparseable; treated as never synced
- services/analytics/analytics_tracker.dart:66 — Degraded — SharedPreferences unavailable; gating skipped
- services/analytics/analytics_tracker.dart:93, 166, 188, 215, 232, 249, 274, 337 — Fault — Mixpanel init / identify / reset / track / timeEvent / flush / markInternal / super properties failed (fan-out zone guard stops recursion)
- services/analytics/analytics_tracker.dart:301 — Note — PackageInfo unavailable; app_version super property 'unknown'
- services/analytics/internal_user_service.dart:145, 179, 202 — Note — secure storage write/write/read failed; flag session-only or unknown
- services/device_info_service.dart:67 — Degraded (`startup`) — device info unavailable; per-launch fallback id splits analytics identity
- services/privacy/privacy_links.dart:42 — Degraded — launchUrl threw; snackbar shown
- services/privacy/privacy_region_service.dart:124 — Fault — region lookup failed (offline/timeout downgrade themselves; a malformed body stays a Fault); device fallback used
- services/schema_recovery_service.dart:93 — Note — schema exception caught; recovery entered (the handler then reports Degraded, or Fault when the circuit breaker is tripped)
- services/schema_recovery_service.dart:156 — Fault — operation failed even after recovery; rethrown
- services/version_check_service.dart:169 — Fault — version check failed; cached result used
- services/version_check_service.dart:233 — Degraded — a repository's dirty upload threw during resync; recorded in the backup too
- services/version_check_service.dart:335 — Fault — schema resync failed
- services/version_check_service.dart:382 — Degraded — anonymous-data check failed; resync deferred defensively
- services/version_check_service.dart (not catches) — "some dirty records failed to upload" is Degraded; "deferring resync to protect anonymous data" is a Note
- services/launch_trail.dart:75, 100, 119 — Reasoned — LaunchTrail is the tape the D9 trail is written to; a recorder that reports into what it records recurses. Lee ruled it stays as is
- services/report/report.dart:285, 317, 343, 391, 481, 524, 547 — Reasoned — Report cannot report into itself; each entry in the allow-list names the sink
- utils/celebration_haptics.dart:35 — Note — haptics unavailable
- widgets/location_search_field.dart:107 — Degraded — location search failed; empty results shown
- widgets/root_app_widget.dart:295 — Note (`push`) — activity lookup for a notification deep link failed; navigates with the bare id
- widgets/tabs_screen.dart:84 — Degraded — TP writeback notice failed; retries next launch
- core/app_router.dart — Removed — the `sentry_flutter` import is gone; `SentryNavigatorObserver` is built by `appNavigatorObservers()` in `core/bootstrap/bootstrap.dart`

### Allow-list
40 baseline lines deleted; 11 reasoned entries added (food_search_controller 1, launch_trail 3, report.dart 7). Guard test green.

### Tests
- `test/features/app_startup/app_startup_service_test.dart`: local `_RecordingReport` replaced by the shared fake; `reportProvider` overridden in every container; Faults asserted for the session-check and fallback-foods paths, Notes for the unmounted-context recovery path (the fixture now writes real JSON so that path is actually reached).
- `test/new_sync/app_startup_version_check_test.dart`: the two `mockLogger.warning` verifications are Note assertions.
- User-repository tests (`user_repository_food_preferences`, `sweat_profile_controller`, `user_repository_settings`, `registration_flow`): `sentry:` mock replaced by `report: RecordingReport()`.

### Left for other tickets
- `auth_migration_service.dart`, `oauth_service.dart`, `email_auth_service.dart`: every catch reports through a legacy alias (`sentry.report*`, `_logger.error`), so the guard is green on them; ticket 10 retires the aliases and converts these callers. `supabase_auth_service.dart` only rethrows.
- `AppExternalDeps.sentry` / `sentryReporterProvider` are still constructed (tests and the files above); ticket 10.
