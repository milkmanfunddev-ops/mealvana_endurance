# 10 part A: nutrition plan off the legacy aliases

Scope: `lib/features/nutrition_plan/**`, `test/features/nutrition_plan/**`, plus one line in
`lib/shared/database/daos/user_dao.dart` (the data-layer caller of a domain decoder).

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

## Identity calls deleted

None. No `setUserContext` / `clearUserContext` calls in scope.

## Domain decoders moved to `DecodeIssue`

- `domain/solver_food.dart`: `SolverFood.fromTemplateFoodEntry` and `SolverFood.fromUserFood` take
  `DecodeIssue onIssue = ignoreDecodeIssue`; `_parseJsonList` calls it. The caller
  `ClientFoodPoolService` passes `_report.decodeIssue('nutrition_plan')`. Severity changed from a
  Note to a Degraded, which is what the `decodeIssue` bridge emits. The fallback (empty list) is
  unchanged.
- `domain/nutrition_target_overrides.dart`: `NutritionTargetOverrides.fromJsonString` takes
  `{DecodeIssue onIssue = ignoreDecodeIssue}`. The only caller, `UserDao` (outside this part's
  folders), passes `SentryReport.global.decodeIssue('nutrition_plan')` because a Drift DAO has no
  injection point. Same Degraded, same null fallback as before.

## Could not convert / leftovers for the lead

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
