# 10: Contract: old services deleted

**What to build:** The logger, the debug logger, the in-memory debug log storage and the old Sentry reporter no longer exist as separate things, nor do any aliases on `Report`. The debug screen's log view reads from `Report`. The guard's allow-list has no baseline section left, only reasoned entries. The Sentry SDK is imported in exactly two places.

**Blocked by:** 02 One bootstrap; 03 Riverpod net; 05, 06, 07, 08, 09 Migrate batches

**Status:** done (2026-10-06, wave 4: seven Opus agents, parts A, B, C1, C2, D, E1, E2 merged on `sentry`, lead close-out `56d42891`)

- [x] `AppLogger`, `PrettyAppLogger`, `DebugLogger`, `DebugLogStorage`, `SentryReporter` and their providers are deleted; no alias method remains on `Report`
- [x] The debug screen still shows recent log lines, now sourced from `Report`
- [x] The guard allow-list has no baseline section; every remaining entry has a reason
- [x] Sentry SDK imports exist only in the service and the bootstrap
- [x] Full suite green; analyzer clean; no dead file references in docs


## Close-out (lead)

- Deleted: `lib/shared/services/logging_service.dart`, `lib/core/utils/debug_logger.dart`,
  `lib/shared/services/sentry/sentry_reporter.dart`; `AppExternalDeps` lost `sentry`/`logger`
  (keeps `analytics`, `supabaseClient`, `sharedPreferences`, `report`).
- `DebugLogStorage` moved to `lib/shared/services/report/report_log.dart` as `ReportLog`; the debug
  screen reads it through `Report`.
- Guard: legacy alias text no longer counts as a report; a domain decoder's `onIssue(` callback does.
  Allow-list `## baseline` section deleted; 23 reasoned entries remain.
- Domain decoders (Lee's ruling 2026-10-06) report through `DecodeIssue`
  (`lib/shared/domain/decode_issue.dart`), bound by the data layer via `report.decodeIssue(area)`.
- Docs rewritten: `docs/technical/sentry-integration.md`, `docs/technical/logging-service.md`.
  Historical docs under `docs/test/`, `docs/features/`, `docs/brick/notes.md`,
  `docs/technical/sync-simplification-roadmap.md` and `docs/_archived/` still name `AppLogger` /
  `SentryReporter` as history of past phases; left as written.
- Full suite: 5042 pass; only the pre-existing `ci_config_contract_test` red remains.


## Part A

## Files converted

- lib: 32 files in `lib/features/nutrition_plan` (10 application, 6 data, 2 domain, 8 providers,
  2 screens, 4 widgets), plus `lib/shared/database/daos/user_dao.dart`. 289 legacy calls rewritten.
- test: 6 files in `test/features/nutrition_plan`.

Injection used:
- Ref-holding services (`NutritionPlanService`, `LLMResponseParser`, `FoodDataTransformationService`,
  `FoodPreferenceResolver`, `ClientPlanService`, `ClientFoodPoolService`): `Report get _report =>
  ref.read(reportProvider)`.
- `FoodRepository`, `TemplatesRepository`: `AppLogger? logger` (defaulted to a no-op) is now
  `required Report report`; the providers pass `reportProvider`, including the second
  `foodRepositoryProvider` in `swap_food_controller.dart`.
- `TemplateFoodsRepository`: `logger` dropped; it keeps its wave 3 `Report? report`.
- `MacroRepositoryImpl`: new optional `Report? report` (falls back to `SentryReport.global`, the wave 3
  pattern) because tests outside this scope construct it; the provider passes `reportProvider`.
- `DraftActivityCleanupService`: new `required Report report`; provider and test updated.
- `MacroGenerationService`, `BrickMacroService`: already had `Report? report`; `DebugLogger` calls use
  it (`_r`).
- Notifiers (`BrickInputController`, `CyclingInputController`, `RunningInputController`,
  `SwimmingInputController`, `NewActivityCoordinator`): `_report` getter, `ref.mounted ?
  ref.read(reportProvider) : SentryReport.global`, the same shape `MacroTargetsController` uses.
- `ConsumerState` classes (`_NewActivityScreenState`, `_AdjustMacrosScreenState`,
  `_SwipeableFoodItemState`): `_report` getter guarded by `mounted`.
- `SentryReport.global` only where there is no injection point: `NutritionPlanMapper` (static),
  `PreWorkoutHydrationCheckService.answer` (static), `BrickNutritionSections` and
  `MacroTargetsWidget` (stateless, no ref), `UserDao` (Drift DAO).

Where a `DebugLogger.error('...: $e')` sat directly in a `catch (e)` block (19 sites), the Fault
carries the caught `e` (and the stack trace when the catch binds one) with the old text as `message`,
rather than a `LoggedFault` wrapping the text. That lets the expected-failure allow-list see the real
exception type.

### Identity calls deleted

None. No `setUserContext` / `clearUserContext` calls in scope.

### Domain decoders moved to `DecodeIssue`

- `domain/solver_food.dart`: `SolverFood.fromTemplateFoodEntry` and `SolverFood.fromUserFood` take
  `DecodeIssue onIssue = ignoreDecodeIssue`; `_parseJsonList` calls it. The caller
  `ClientFoodPoolService` passes `_report.decodeIssue('nutrition_plan')`. Severity changed from a
  Note to a Degraded, which is what the `decodeIssue` bridge emits. The fallback (empty list) is
  unchanged.
- `domain/nutrition_target_overrides.dart`: `NutritionTargetOverrides.fromJsonString` takes
  `{DecodeIssue onIssue = ignoreDecodeIssue}`. The only caller, `UserDao` (outside this part's
  folders), passes `SentryReport.global.decodeIssue('nutrition_plan')` because a Drift DAO has no
  injection point. Same Degraded, same null fallback as before.

### Could not convert / leftovers for the lead

1. `test/features/nutrition_plan/pre_workout_hydration_check_persistence_test.dart` now builds
   `ActivitiesRepository(..., report: RecordingReport(), ...)` with no `logger:`/`sentry:`. On this
   base those two params are still `required`, so the file has 2 analyzer errors until the part that
   owns `lib/features/activities` drops them (per the brief's "already has `Report? report`" rule).
2. Outside this scope, two tests still pass `logger:` to `FoodRepository` and must pass
   `report: RecordingReport()` instead: `test/new_sync/food_repository_sync_test.dart:77` and
   `test/features/carb_loading/g25_one_tap_log_test.dart:131`.
3. The scope grep still matches `AppExternalDeps` in 6 test files. These are the
   type itself, not the legacy fields: `mockAppExternalDeps()` (helper in
   `test/helpers/widget_test_harness.dart`), `MockAppExternalDeps` in the two fuel-log tests (the
   `logger` stub is gone; `reportProvider` is overridden with `RecordingReport`), and two
   `AppExternalDeps(...)` constructions with `sentry:`/`logger:` removed.
4. Mapped exactly per the brief, but flagged: several legacy `logger.warning` calls were narrative,
   and they are now Degraded events: "Create nutrition plan started" and "Coach remote activity plan
   visibility confirmed" (`macro_targets_controller.dart`), and "Coach create-plan tapped" and
   "Coach create-plan navigating to fresh activity detail route" (`adjust_macros_screen.dart`). The
   legacy alias already sent these as Degraded, so nothing changes in behaviour. They are candidates
   to move down to `info`.
5. `dart format` ran on the changed files, so some diffs include whitespace-only reflow.


## Part B

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

### Area
Area is the feature folder name throughout, with three exceptions that follow the mapping table:
`reportNetworkError` → `'network'`, `reportDatabaseError` → `'database'`, `logger.api` → `'api'`.

### Double reports collapsed (same error, one catch)
- `feedback_repository.saveSurveyResponse`: `logger.warning` + `reportNetworkError` → one `degraded`.
- `onboarding_survey_repository.saveSurveyFromDraft`: `logger.error` + `reportDatabaseError` → one `fault` (area `onboarding`, operation/table tags).
- `onboarding_controller.saveAllOnboardingData` failure: `DebugLogger.error` + `captureMessage` (info level, so before this it was only a Note) → one `fault` on `state.error` with the batch_save tags. This one is now a real event, which is what the "no silent failures" comment above it asked for.
- `onboarding_controller` sport/diet/allergy save errors: `DebugLogger.error('...${state.error}')` + a stack-trace debug line → one `fault(state.error, stackTrace: state.stackTrace)`.
- `_uploadUserProfileToSupabase` catch: `error` + `warning` → one `fault`.
- Messages that interpolated ids or errors (`$e`, `userId=$userId`, failed repo list) now carry those values in `extra` and keep a static message, so events group.

### Identity calls deleted
None in scope.

### Domain decoders moved
None in scope.

### Leftovers (outside part B's scope; they break after merge)
These callers of constructors changed here still pass the old arguments, and `test/new_sync/` is not in part B:
- `test/new_sync/food_preferences_repository_test.dart` (8 constructions): `sentry: mockSentry` → `report: RecordingReport()` (now required).
- `test/new_sync/user_foods_repository_test.dart` (8 constructions): drop `sentry: mockSentry` (pass `report:` if wanted).
- `test/new_sync/feedback_repository_sync_test.dart:74`: `FeedbackRepository(database, mockLogger, mockSupabase, mockSentry)` → `FeedbackRepository(database, mockSupabase, RecordingReport())`.

The scope grep still matches `mockAppExternalDeps()` (a shared test helper's name) and one
`AppExternalDeps(` construction in `onboarding_session_controller_test.dart`. Both are the surviving
class, not the legacy `sentry:` / `logger:` fields.


## Part C1

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

### Identity calls deleted

None in scope. `AppStartupService.setSentryUserContext` already calls `report.setUser/clearUser`
(left as is); `auth_listener_service` already calls `syncReportIdentity`. The
`mockSentry.setUserContext` stub in `app_startup_service_test.dart` went with the mock.

### Domain decoders moved

None in scope.

### Not converted, and why

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

### Cross-scope analyzer errors this part causes (fixed by the owning part or the lead)

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


## Part C2

## Converted

- 19 lib files, about 240 call sites, mapped per the wave 4 brief table.
  - auth (7): `auth_migration_service` (`SentryReporter sentry` became `Report report`;
    33 breadcrumbs, 3 database faults, 2 network degradeds), `auth_service`, `email_auth_service`,
    `oauth_service`, `password_recovery_controller`, `post_onboarding_auth_controller`,
    `post_onboarding_auth_screen`. The `_logger` getters (`appExternalDepsProvider.logger`) became
    `Report get _report => ref.read(reportProvider)`. `state.error` passed to `fault` gets a `!`
    because each one sits under `if (state.hasError)`.
  - integrations (7): `integrations_repository` (logger param dropped; uses its existing
    `Report? report`), `provider_raw_payloads_repository`, `provider_event_import_service`,
    `integrations_providers`, `athlete_zones`, `athlete_zones_provider`,
    `training_peaks_sync_service` (decoder wiring only).
  - settings (2): `settings_controller` (3 local `logger`s), `food_preferences_screen` (2
    `DebugLogger.info`s onto its existing `_report`). `debug_screen.dart` already had no legacy
    references.
  - events (3): `events_repository` (`logger` + `sentry` became `required Report report`),
    `events_service` (positional `AppLogger` dropped; it already had `report:`),
    `active_com_service`.
  - subscription: nothing left to convert.
- 10 test files: the 9 in scope plus `test/new_sync/events_repository_sync_test.dart`, which my
  `EventsRepository` signature change would otherwise have broken. Mocks became `RecordingReport()`,
  and `appLoggerProvider` overrides became `reportProvider` overrides. None of these tests asserted
  on logger or sentry calls, so no assertions changed.

### Changes beyond the mechanical mapping

- `events_repository`: four sites called `logger.warning(e)` and then
  `sentry.reportNetworkError(e)` on the same error. Each pair is now a single `degraded`
  (area `EVENTS_REPOSITORY`, the network method as a tag, the url folded into `extra`).
  `Report` dedupes by error identity, so a second call would have been dropped along with its tags.
- `provider_raw_payloads_repository`: its provider never passed a logger, so the
  `NoopAppLogger` default made a failed capture silent in prod (D9). The provider now passes
  `report:`, and the failure is a `degraded` that carries the caught error and stack.
- `integrations_providers`: dropped a `ref.watch(appExternalDepsProvider)` that only fed the logger.

### Identity calls deleted

None. No `setUserContext` or `clearUserContext` calls were in scope.

### Domain decoders moved

- `lib/features/integrations/domain/athlete_zones.dart`: `fromJsonString` takes
  `DecodeIssue onIssue = ignoreDecodeIssue`, and the Report import is gone. The string length that
  used to go in `extra` now goes in the message. Both callers pass
  `report.decodeIssue('training_peaks')`: `training_peaks_sync_service` (via `_r`) and
  `athlete_zones_provider` (via `ref.read(reportProvider)`).

### Left over

- The requested grep still matches `AppExternalDeps(` constructions and `mockAppExternalDeps()`
  helper calls in `test/features/{auth,settings,events,integrations}`. None of them pass
  `sentry:` or `logger:`. They match because the class name is in the pattern.
- `test/features/integrations/connect_identity_seam_test.dart` and
  `disconnect_soft_hide_state_machine_test.dart` still build `ActivitiesRepository(logger:, sentry:)`
  and `ActivityDeduplicationService(logger:)`. Those constructors belong to the activities part. Fix
  these lines when that part removes the params.
- Two warnings in changed test files were there before this part and are unrelated:
  `anonymous_account_upgrade_test.dart:217` (override_on_non_overriding_member) and
  `connect_identity_seam_test.dart:215` (unused local).
- Verification: `dart analyze` shows no errors in any changed file and no new warnings. No
  `flutter test`, per the brief.


## Part D

## Files converted (66)
- lib: 46 (meal_planning 21, formula_kit 9, coach_mode 8, ai_coach 4, personal_templates 3,
  recipes 1). That is 32 files off `AppLogger` / `SentryReporter` (219 call sites), plus the
  domain decoders and their callers below.
- test: 20 (meal_planning 7, formula_kit 5, coach_mode 4, ai_coach 1, personal_templates 1,
  recipes 1, `test/new_sync/coach_repository_sync_test.dart` 1).

Areas are the feature names (`meal_planning`, `formula_kit`, `ai_coach`, `coach_mode`,
`personal_templates`, `recipes`); the legacy `context:` string survives only inside
`LoggedFault(m, context: c)`. `_sentry.reportNetworkError` (coach messaging, personal templates)
became `degraded(e, area: 'network', tags: {method}, extra: {url})`. Repositories that already
had wave 3's `Report? report` + `_r` getter dropped their logger param and route through `_r`.
Unused `_context` constants were deleted.

### Calls that departed from the mapping table
- `coach_activity_detail_controller.dart`: two `logger.warning` calls that record successful
  loads ("loaded remote activity", "parsed nutrition plan") became `_report.info`, not
  `degraded`; the table would have raised a Sentry warning on every coach activity view.
- `ai_coach_chat_controller.dart`: the offline and out-of-AI-credits `logger.error` calls became
  `degraded`, not `fault`; both are expected conditions shown to the user. The remaining
  `_logger.error` calls are `fault`, as the prompt asked; the repository Faults and rethrows the
  same object, and Report dedupes it.

### Identity calls deleted
None. No `setUserContext` / `clearUserContext` calls were in scope.

### Domain decoders moved to `DecodeIssue`
The eight named files no longer import `Report`: `vana_part.dart`, `vana_stream_event.dart`,
`wire_record.dart`, `day_plan.dart`, `personal_formula.dart`, `ai_coach_ui_part.dart`,
`ai_coach_message.dart`, `personal_template.dart`. Each former report site calls
`onIssue(message, error:, stackTrace:)` with the same fallback. The old `extra` fields (kind,
slot, key/type, message id, template id, the line head) are now in the message text, because
`DecodeIssue` carries no extras.

`readRecordList` and `DayPlan.fromJson` sit under many nested factories. To keep nested failures
reported, `onIssue` is threaded through every meal-planning factory on a path to a report site:
`MealPlan`, `PlanMeal`, `AthleteContext`, `AthleteWeekContext`, `AthleteBudgetContext`,
`HomePayload`, `HomeDays`, `MealDetail`, `VanaMessage`, the nine Vana part factories that nest
lists, `VanaPart.listFromJson` and `VanaStreamEvent.fromJson`. Every parameter is optional and
defaults to `ignoreDecodeIssue`, so the tests and other callers compile unchanged.

Data-layer callers pass `report.decodeIssue(area)`:
- `vana_chat_repository.dart`: stream events, history parts; `messageFromRow` (static) takes
  `onIssue`.
- `vana_action_client.dart`: `VanaActionResult` carries `onIssue` for its typed accessors.
- `meal_plan_repository.dart`: `_assemble`; `_planMealFromEntry` is now an instance method.
- `personal_formulas_repository.dart`, `ai_coach_chat_repository.dart`,
  `personal_templates_repository.dart` (new `_fromEntry` helper).

Behaviour change: `personal_template.dart` used `fault`. Through `decodeIssue` its decode
failures are now `degraded`.

### Left over
- `grep` still matches `AppExternalDeps(` in three tests (`meal_planning/helpers/container.dart`,
  `formula_kit/formula_editor_analytics_test.dart`, `formula_kit/fork_conflict_metadata_test.dart`).
  These construct the class without the `sentry:` / `logger:` args, which is allowed.
- 14 `SentryReport.global` uses remain in scope, all outside the domain layer. They are wave 3's
  `_r` fallbacks (`_report ?? SentryReport.global`) and static data-layer helpers
  (`meal_plan_repository._decodeList/_decodeMap`, `user_memory_repository`). The brief did not
  ask for them to move.
- `test/new_sync/coach_repository_sync_test.dart` is outside part D's test scope. It was edited
  only because `CoachRepository` lost its `logger:` param. If another part also converted it,
  expect a trivial conflict.
- The rest of the repo still has compile errors where `deps.logger` / `deps.sentry` are now
  nullable. Those are other parts' files.


## Part E1

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

### Identity calls deleted
None. There were no `setUserContext` / `clearUserContext` calls in scope.

### Domain decoders moved
None. There were no domain decoders in scope.

### Leftovers
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


## Part E2

## Converted
- 22 lib files, 10 test files.
- 176 legacy call sites rewritten per the brief's mapping table (`_logger.*`, `logger.*`,
  `_sentry.reportNetworkError`, `DebugLogger.*`). Area is the feature name (`carb_loading`,
  `meal_logging`, `barcode_scanning`, `education`), not the old `context:` string.
- 9 `logger.warning` + `sentry.reportNetworkError` pairs on the same error became one
  `degraded` (method in `tags`, url in `extra`) instead of two events: 6 in
  `CarbLoadingRepository`, 2 in `MealLogRepository`, 1 in `SavedMealsRepository`.
- Injection: every repository/service in scope takes `required Report report` (positional in
  `CarbLoadingService` and `CatalogSearchService`, where the logger was positional). Providers
  pass `ref.watch/read(reportProvider)`. `OpenFoodFactsSearchService` and
  `ProductDetailService` had no logger and used static `DebugLogger`; they now take a Report too.
  `CarbLoadingUserFoodRepository` takes `report:` so it can feed the meal-type decoder.
- Controllers use `Report get _report => ref.read(reportProvider)`. `CarbLoadingController`'s
  background sync keeps a local read before the await, as the old code did with the logger.
  `AddFoodScreen` reads the Report once in `initState`, so logging after an await never touches
  a disposed `ref`.

### Domain decoders moved onto `DecodeIssue`
- `carb_loading/domain/meal_type.dart` `parseMealTypeIds(raw, {onIssue})`. Callers:
  `CarbLoadingFoodRepository`, `CarbLoadingUserFoodRepository`, `FoodImportService` pass
  `_report.decodeIssue('carb_loading')`. Severity changes from Fault to Degraded (that is what
  `decodeIssue` emits); the raw value goes into the message.
  `meal_type_parsing_test` now asserts one Degraded.
- `meal_logging/domain/meal_log.dart` and `saved_meal.dart`: `fromDriftEntry` /
  `fromSupabaseJson` take `{DecodeIssue onIssue = ignoreDecodeIssue}`, threaded through the
  private decode/coerce helpers. `MealLogRepository` and `SavedMealsRepository` pass
  `_report.decodeIssue('meal_logging')` at every call. The business-logic test no longer swaps
  `SentryReport.global`; it passes `onIssue: report.decodeIssue('meal_logging')`.
- `barcode_scanning/domain/api_food_product.dart`: the 12 `DebugLogger.debug` traces in
  `calculateForServing` were deleted, not moved. The domain stays pure, and they were
  step-by-step arithmetic narration with no reporting value.

### Judgement calls
- `SupabaseBarcodeService` on `ProductDetailException`: was `logger.error`, now
  `report.note`. `ProductDetailService` already reports the cause (Fault for HTTP or unexpected
  errors, Degraded for not-found), so a second Fault with a new object would double-count it.
- `DebugLogger.error(m, error: response.statusCode)` (two sites, OFF search and product
  detail): an int is not an error object. These now raise a `LoggedFault` whose message includes
  the status, with `status` in `extra`.
- Warnings that put `e.toString()` into `data` with no `error:` (education fetch, catalog
  search, carb day-detail sync) now pass `e` and the stack trace as the error itself.
- Removed a commented-out `_logger.debug` block in `CarbLoadingFoodSyncService`.

### Identity calls deleted
None; there were no `setUserContext` / `clearUserContext` calls in scope.

### Leftovers
- The scope grep still matches `mockAppExternalDeps()` in `edit_meal_log_guard_test`,
  `recipe_picker_eaten_at_test` and `macro_dashboard_screen_test`. That is the shared
  widget-harness override of `appExternalDepsProvider`, not a legacy logger/sentry surface.
- Out-of-scope tests broken by the new required `report:` on `CarbLoadingRepository` and
  `MealLogRepository`: `test/new_sync/carb_loading_repository_sync_test.dart` (8 constructions)
  and `test/features/home_shell/home_shell_calendar_seam_test.dart` (1). The parts that own them
  should replace `logger:`/`sentry:` with `report: RecordingReport()`.
- `g25_one_tap_log_test` now builds `FoodRepository(MockSupabaseClient(), db)` with no logger
  (the parameter is optional). If the nutrition_plan part makes `FoodRepository`'s Report
  required, this call needs `report:`.
- Wave-3 `SentryReport.global` fallbacks remain in `food_import_service.dart`,
  `food_selection_service.dart`, `meal_ai_service.dart` and `meal_log_providers.dart:103`.
  They are on the new surface and outside this part's grep.
- Analyzer issues that were already there in touched test files: unused locals `now` (~1376)
  and `raw` (~1885) in `meal_logging_business_logic_test.dart`, and the `_seedPlan` lint in
  `carb_loading_service_test.dart`. I did not fix them.
- No `flutter test` run, per the brief.
