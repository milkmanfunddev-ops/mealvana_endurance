# Ticket 10, part B: onboarding and small features off the legacy aliases

Scope: `lib/features/{onboarding,weather,feedback,food_preferences,fuel_timeline,user_foods}`,
`test/features/{onboarding,weather,user_foods}`.

## Files converted: 13

lib (10):
- `feedback/data/feedback_repository.dart`: positional ctor is now `(database, supabase, report)`; provider passes `deps.report`.
- `food_preferences/data/food_preferences_repository.dart`: `required Report report` replaces `sentry`.
- `user_foods/data/user_foods_repository.dart`: `sentry` dropped; the wave-3 `Report? report` param kept.
- `weather/data/weather_repository.dart`, `weather/application/weather_service.dart`: `required Report report` replaces `logger`; `logger.api` became `info(area: 'api')`.
- `onboarding/data/onboarding_survey_repository.dart`: `required Report report` replaces `logger` + `sentry`.
- `onboarding/presentation/providers/onboarding_controller.dart`: every `DebugLogger` and `sentry` call now goes through `_report` (`ref.read(reportProvider)`).
- `onboarding/presentation/providers/onboarding_preview_providers.dart`, `onboarding_session_controller.dart`, `screens/welcome_screen.dart`: `deps.sentry` / `deps.logger` → `reportProvider` / `deps.report`.

tests (3): `onboarding_session_controller_test.dart`, `user_foods_repository_crud_test.dart`,
`weather_service_test.dart` now use `RecordingReport`. None of them asserted on logger/sentry calls,
so no assertions were rewritten. Three pre-existing analyzer findings in two of these files were
fixed so `dart analyze` is clean.

`fuel_timeline` had no legacy sites.

## Area
Area is the feature folder name throughout, with three exceptions that follow the mapping table:
`reportNetworkError` → `'network'`, `reportDatabaseError` → `'database'`, `logger.api` → `'api'`.

## Double reports collapsed (same error, one catch)
- `feedback_repository.saveSurveyResponse`: `logger.warning` + `reportNetworkError` → one `degraded`.
- `onboarding_survey_repository.saveSurveyFromDraft`: `logger.error` + `reportDatabaseError` → one `fault` (area `onboarding`, operation/table tags).
- `onboarding_controller.saveAllOnboardingData` failure: `DebugLogger.error` + `captureMessage` (info level, so before this it was only a Note) → one `fault` on `state.error` with the batch_save tags. This one is now a real event, which is what the "no silent failures" comment above it asked for.
- `onboarding_controller` sport/diet/allergy save errors: `DebugLogger.error('...${state.error}')` + a stack-trace debug line → one `fault(state.error, stackTrace: state.stackTrace)`.
- `_uploadUserProfileToSupabase` catch: `error` + `warning` → one `fault`.
- Messages that interpolated ids or errors (`$e`, `userId=$userId`, failed repo list) now carry those values in `extra` and keep a static message, so events group.

## Identity calls deleted
None in scope.

## Domain decoders moved
None in scope.

## Leftovers (outside part B's scope; they break after merge)
These callers of constructors changed here still pass the old arguments, and `test/new_sync/` is not in part B:
- `test/new_sync/food_preferences_repository_test.dart` (8 constructions): `sentry: mockSentry` → `report: RecordingReport()` (now required).
- `test/new_sync/user_foods_repository_test.dart` (8 constructions): drop `sentry: mockSentry` (pass `report:` if wanted).
- `test/new_sync/feedback_repository_sync_test.dart:74`: `FeedbackRepository(database, mockLogger, mockSupabase, mockSentry)` → `FeedbackRepository(database, mockSupabase, RecordingReport())`.

The scope grep still matches `mockAppExternalDeps()` (a shared test helper's name) and one
`AppExternalDeps(` construction in `onboarding_session_controller_test.dart`. Both are the surviving
class, not the legacy `sentry:` / `logger:` fields.
