# 10 part E2: carb loading, meal logging, barcode scanning, education

Scope: `lib/features/{carb_loading,meal_logging,barcode_scanning,education}` and
`test/features/{carb_loading,meal_logging,barcode_scanning,education,macro_dashboard}`.

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

## Domain decoders moved onto `DecodeIssue`
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

## Judgement calls
- `SupabaseBarcodeService` on `ProductDetailException`: was `logger.error`, now
  `report.note`. `ProductDetailService` already reports the cause (Fault for HTTP or unexpected
  errors, Degraded for not-found), so a second Fault with a new object would double-count it.
- `DebugLogger.error(m, error: response.statusCode)` (two sites, OFF search and product
  detail): an int is not an error object. These now raise a `LoggedFault` whose message includes
  the status, with `status` in `extra`.
- Warnings that put `e.toString()` into `data` with no `error:` (education fetch, catalog
  search, carb day-detail sync) now pass `e` and the stack trace as the error itself.
- Removed a commented-out `_logger.debug` block in `CarbLoadingFoodSyncService`.

## Identity calls deleted
None; there were no `setUserContext` / `clearUserContext` calls in scope.

## Leftovers
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
