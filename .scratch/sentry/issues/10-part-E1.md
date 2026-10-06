# Ticket 10, part E1: activities, calendar, race_checklist, content, sync tests

## Converted (33 files)

Lib (11), areas `activities`, `calendar`, `race_checklist`, `content`:
- `activities/data/activities_repository.dart`: dropped `logger:` / `sentry:`; keeps the wave 3
  `Report? report` (falls back to `SentryReport.global`). All 10 `_sentry.reportNetworkError` calls
  were deleted, not converted: each sat directly after a `_report.fault/degraded` on the same error
  object, so it was already a double report.
- `activities/data/activity_mapper.dart`: `ActivityMapper({Report? report})`; the repository passes its own.
- `activities/application/activity_deduplication_service.dart`: `ActivityDeduplicationService({Report? report})`.
  Optional on purpose: tests outside this part build it with no args once they drop `logger:`.
- `activities/application/activities_service.dart`: positional `Report` replaces the `AppLogger`.
- `activities/presentation/providers/brick_actions_controller.dart`, `presentation/widgets/calendar_section.dart`:
  read `reportProvider`. (Activity detail UI not touched.)
- `calendar/application/calendar_service.dart` (positional `Report`), `calendar/presentation/providers/calendar_controller.dart`.
- `race_checklist/data/checklist_repository.dart` (positional `Report`), `race_checklist/presentation/providers/checklist_controller.dart`.
- `content/data/content_repository.dart`: 4 `DebugLogger.error` calls became `_report.fault(e, stackTrace, area: 'content')`;
  the constructor takes an optional `Report? report`, which the provider fills from `reportProvider`.

No new double reports. Controllers that fault on an error the repository already faulted and
rethrew are left as they were; Report dedupes by error identity.

Tests (22): `test/features/activities/**` (8), `test/features/calendar/calendar_service_test.dart`,
`test/features/race_checklist/checklist_repository_crud_test.dart`, `test/new_sync/**` (12).
Mocks became `RecordingReport`. Rewritten assertions:
- `food_repository_sync_test`: the sync failure is asserted as `report.faults.single`
  (message `Failed to sync foods from remote`). The info and debug lines are asserted on `report.calls`.
- `app_startup_version_check_test`: the "Version check passed" info is asserted on `report.calls`.
  The `containerWithDb` containers now override `reportProvider`.

## Identity calls deleted
None. There were no `setUserContext` / `clearUserContext` calls in scope.

## Domain decoders moved
None. There were no domain decoders in scope.

## Leftovers
- **`test/new_sync` targets constructors owned by other parts.** These tests were written against
  the brief's target shape (`report:` in place of `logger:` / `sentry:`), so `dart analyze` fails
  on them until those parts merge: `CarbLoadingRepository`, `EventsRepository`, `CoachRepository`
  (drop `logger:`), `FoodPreferencesRepository`, `UserFoodsRepository` (drop `sentry:`),
  `FoodRepository(report:)`, `VersionCheckService` (drop `logger:`), `DirtyRecordBackupService(report:)`.
  `FeedbackRepository` is positional. The test assumes `FeedbackRepository(database, report, supabase)`,
  meaning the logger slot becomes `Report` and the sentry slot is gone. Check that against whatever
  the feedback part did.
- **Outside-scope tests that still pass `logger:` / `sentry:` to `ActivitiesRepository` /
  `ActivityDeduplicationService`.** Their owners need to drop those args:
  `test/features/integrations/connect_identity_seam_test.dart`,
  `test/features/integrations/disconnect_soft_hide_state_machine_test.dart`,
  `test/features/nutrition_plan/pre_workout_hydration_check_persistence_test.dart`.
- **Grep false positives.** These match the scope grep but never touch the legacy `sentry` / `logger`
  fields: `AppExternalDeps(...)` in `test/new_sync/app_startup_version_check_test.dart`, which now
  passes `report:`, and the analytics-only `_MockAppExternalDeps` in
  `test/features/activities/presentation/widgets/activity_card_test.dart`.
- `lib/features/content/application/content_service.dart` already used `SentryReport.global`
  before this part and was not touched.
