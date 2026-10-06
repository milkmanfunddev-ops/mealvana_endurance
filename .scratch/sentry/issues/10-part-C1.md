# Ticket 10, part C1: shared services, startup and test harness

Scope: `lib/shared/**` (minus `services/report/` and the legacy files), `lib/core/**`,
`lib/features/app_startup/**`, and the tests under `test/shared`, `test/helpers`,
`test/smoke_tests`, `test/db_flows`, `test/seeded_tests`, `test/qa_conformance`,
`test/features/{app_startup,responsive,home_shell,analytics}`.

## Converted (32 files changed, 2 deleted)

lib (20):
- `shared/services/location_service.dart`: `logger` field becomes `Report _report`, area `location`.
- `shared/services/dirty_record_backup_service.dart`: `required Report report`, area `sync`.
- `shared/services/version_check_service.dart`: logger param dropped; uses the wave-3 `Report? report`.
- `shared/services/food_management/`: `food_recommendation_service`, `nutrition_product_search_service`,
  `shared_food_search_service`, `user_food_crud_service` (logger and sentry become one `Report`;
  `reportNetworkError` becomes `degraded(area: 'network', tags: method, extra: url)`),
  `product_type_mapper` (`{AppLogger? logger}` becomes `{Report? report}`). Area `food_management`.
- `shared/services/sync/`: `sync_coordinator` plus six entity handlers and `duplicate_cleanup_service`:
  logger param dropped, narrative calls go to the existing `Report`. Area `sync`.
- `shared/services/auth/auth_listener_service.dart`: `_logger.error` + `reportCriticalError` on the
  same error merged into one `fault` (tags kept); `addBreadcrumb` becomes `breadcrumb`. Area `auth`.
- `shared/widgets/food_icon.dart`: `DebugLogger` becomes `SentryReport.global` (stateless widget,
  no ref). Two departures from the table, on purpose: "no image URL" is an ordinary render state
  and fired on every build, so it is now `debug`, not Degraded; an image load failure is one
  `degraded` with the error object and URL, not three `fault`s.
- `features/app_startup/application/app_startup_service.dart`, `app_startup_provider.dart`:
  `_logger` getter dropped, calls go to `_report`, area `startup`.

tests (12 changed, 2 deleted):
- `helpers/widget_test_harness.dart`: `MockSentryReporter`, `mockSentryReporter()`, `MockAppLogger`
  removed; `mockAppExternalDeps()` no longer passes sentry/logger.
- `helpers/fakes/recording_app_logger.dart`, `recording_sentry_reporter.dart`: DELETED (no
  references left anywhere in `test/`).
- `db_flows/{app_startup,carb_loading,food_management,nutrition_plan,settings,registration_flow}_test.dart`:
  `RecordingReport` via `reportProvider.overrideWithValue`. Two tests in `app_startup_test.dart`
  ("tracks operations in Sentry breadcrumbs", "logger records startup messages") only exercised
  the deleted fakes themselves and were removed.
- `features/app_startup/app_startup_service_test.dart`, `features/analytics/missing_analytics_events_regression_test.dart`,
  `features/responsive/responsive_smoke_test.dart`, `features/home_shell/home_shell_calendar_seam_test.dart`,
  `seeded_tests/meal_weather_ai_coach_content_test.dart`: logger/sentry mocks and stubs removed,
  `RecordingReport` where a Report is read.

## Identity calls deleted

None in scope. `AppStartupService.setSentryUserContext` already calls `report.setUser/clearUser`
(left as is); `auth_listener_service` already calls `syncReportIdentity`. The
`mockSentry.setUserContext` stub in `app_startup_service_test.dart` went with the mock.

## Domain decoders moved

None in scope.

## Not converted, and why

- `AppExternalDeps` / `appExternalDepsProvider` reads of the NON-legacy fields (`supabaseClient`,
  `analytics`) stay in `shared/providers/user_id_provider.dart`, `shared/core/app_router.dart`,
  `shared/widgets/root_app_widget.dart`, `shared/services/auth/auth_listener_service.dart`,
  `features/app_startup/application/*`, and the test overrides (harness, startup, responsive,
  analytics, smoke/seeded). The brief keeps the class (only its `sentry:`/`logger:` fields are
  legacy) and ~150 feature files outside this scope read it; switching lib reads to
  `supabaseClientProvider` would bypass every test that fakes Supabase through
  `appExternalDepsProvider`. Deleting `app_external_deps.dart` needs its own sweep.
- `lib/features/auth/application/{auth_migration_service,oauth_service,email_auth_service}.dart`
  are under `lib/features/auth/`, not `lib/shared/services/auth/`, so they belong to the
  features part.

## Cross-scope analyzer errors this part causes (fixed by the owning part or the lead)

- `test/features/home_shell/home_shell_calendar_seam_test.dart` already passes
  `MealLogRepository(report: RecordingReport())`; it analyzes clean once the meal_logging part
  gives the repository its `required Report report`.
- Uses of the removed harness mocks (`MockAppLogger`, `MockSentryReporter`, `mockSentryReporter()`):
  `features/auth/{anonymous_account_upgrade,oauth_second_provider_login}_test.dart`,
  `features/events/event_origin_d2c_test.dart`,
  `features/integrations/{connect_identity_seam,disconnect_soft_hide_state_machine,provider_event_import_service}_test.dart`,
  `features/macro_dashboard/macro_dashboard_screen_test.dart`.
- New constructor signatures: `test/new_sync/dirty_record_backup_service_test.dart` and
  `new_sync/edge_cases/network_failure_test.dart` need `DirtyRecordBackupService(report: RecordingReport())`;
  `new_sync/version_check_service_test.dart` drops `logger:` (it can pass `report:`).
