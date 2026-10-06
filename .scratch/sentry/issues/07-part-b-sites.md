# 07 part B: meal logging sites

Scope: `lib/features/meal_logging/**`, area `meal_logging`. 36 baseline lines deleted
from `test/shared/source_guard/allow_list.md` (4 printInCatch, 32 unreportedCatch). No
`sentryImport` existed in scope. Line numbers are post-migration.

`MealAiService` takes an optional `Report? report` (falls back to `SentryReport.global`);
`mealAiServiceProvider` injects `reportProvider`. The provider signature is unchanged, so no
codegen. `duringFuelTotalsForActivity` takes an optional `report` the same way.

## Sites

- lib/features/meal_logging/application/meal_ai_service.dart:173 — Fault — describe-meal threw something other than the typed exceptions; debugPrint removed, still wrapped as `MealAiException` for the UI
- lib/features/meal_logging/application/meal_ai_service.dart:223 — Fault — Storage upload of the meal photo failed; debugPrint removed, extra has extension and byte count
- lib/features/meal_logging/application/meal_ai_service.dart:280 — Fault — analyze-meal-photo threw something unexpected; debugPrint removed
- lib/features/meal_logging/application/meal_ai_service.dart:338 — Fault — edge function response body did not parse as `MealAnalysisResult`; debugPrint removed
- lib/features/meal_logging/application/meal_ai_service.dart:322 — Degraded (not a catch) — non-200 status from the edge function was only a debugPrint; now a `LoggedFault` Degraded with status and body
- lib/features/meal_logging/application/meal_ai_service.dart:360 — Degraded (not a catch) — `_mapFunctionException` debugPrint replaced; 402 (out of credits) is excluded as a business outcome
- lib/features/meal_logging/domain/meal_log.dart:349 — Degraded — `items` TEXT column did not decode; row shows empty items instead of taking the diary down, reported through `SentryReport.global` (static helper, no ref)
- lib/features/meal_logging/domain/saved_meal.dart:259 — Degraded — saved meal `items` column did not decode; same shape
- lib/features/meal_logging/domain/saved_meal.dart:276 — Degraded — saved meal `meal_types` column did not decode; same shape
- lib/features/meal_logging/presentation/providers/meal_log_providers.dart:101 — Degraded — activity `fuel_log_data` blob malformed; Daily Macros keeps rendering with zero during-fuel, activity id in extra
- lib/features/meal_logging/presentation/providers/meal_log_providers.dart:546 — Fault — signed URL for a meal photo failed; thumbnail falls back to null (network auto-downgrades)
- lib/features/meal_logging/presentation/screens/recipe_picker_screen.dart:81 — Fault — recipe sync/load failed; spinner cleared, list stays empty
- lib/features/meal_logging/presentation/screens/build_meal_screen.dart:664 — Fault — recipes failed to load for the Add Food sheet
- lib/features/meal_logging/presentation/screens/build_meal_screen.dart:706 — Fault — local food pool seed failed (search still works via catalog/OFF)
- lib/features/meal_logging/presentation/screens/build_meal_screen.dart:822 — Fault — barcode product detail lookup failed; snackbar kept
- lib/features/meal_logging/presentation/screens/build_meal_screen.dart:870 — Fault — OpenFoodFacts product detail lookup failed; snackbar kept
- lib/features/meal_logging/presentation/screens/describe_meal_screen.dart:100 — Note — out of AI credits, paywall shown (business outcome, user sees it)
- lib/features/meal_logging/presentation/screens/describe_meal_screen.dart:118 — Note — typed `MealAiException` surfaced to the user; the service already reported the cause, so the screen leaves a breadcrumb with the kind
- lib/features/meal_logging/presentation/screens/describe_meal_screen.dart:139 — Fault — unexpected exception escaped the service's typed mapping
- lib/features/meal_logging/presentation/screens/photo_capture_screen.dart:66 — Degraded — image picker refused (permission / no camera); user told
- lib/features/meal_logging/presentation/screens/photo_capture_screen.dart:134 — Note — out of AI credits, paywall shown
- lib/features/meal_logging/presentation/screens/photo_capture_screen.dart:152 — Note — typed `MealAiException` surfaced to the user; cause already reported by the service
- lib/features/meal_logging/presentation/screens/photo_capture_screen.dart:183 — Fault — unexpected exception escaped the service's typed mapping
- lib/features/meal_logging/presentation/screens/edit_meal_log_screen.dart:198 — Degraded — image picker refused on rescan; user told
- lib/features/meal_logging/presentation/screens/edit_meal_log_screen.dart:254 — Note — out of AI credits on rescan, paywall shown
- lib/features/meal_logging/presentation/screens/edit_meal_log_screen.dart:262 — Note — typed `MealAiException` on rescan surfaced to the user; cause already reported by the service
- lib/features/meal_logging/presentation/screens/edit_meal_log_screen.dart:278 — Fault — unexpected exception on rescan
- lib/features/meal_logging/presentation/screens/log_meal_screen.dart:193 — Removed + Fault — `_isToday` and `_screenTitle` both wrapped `DateTime.parse(widget.logDate)` in `catch (_)`; replaced with one `DateTime.tryParse` getter, and a bad route value is reported once in `initState` as a `LoggedFault` (two baseline catches gone, one Fault)
- lib/features/meal_logging/presentation/screens/log_meal_screen.dart:270 — Fault — `diary_closed` analytics threw in `dispose`; `Report` captured in `initState` alongside the tracker because `ref` is unsafe there
- lib/features/meal_logging/presentation/screens/log_meal_screen.dart:484 — Fault — recipes failed to load
- lib/features/meal_logging/presentation/screens/log_meal_screen.dart:533 — Fault — local food pool seed failed
- lib/features/meal_logging/presentation/screens/log_meal_screen.dart:690 — Fault — barcode product detail lookup failed (was `catch (e)` with `e` unused)
- lib/features/meal_logging/presentation/screens/log_meal_screen.dart:742 — Fault — OpenFoodFacts product detail lookup failed
- lib/features/meal_logging/presentation/screens/log_meal_screen.dart:1702 — Note — AI tab out of credits, paywall shown
- lib/features/meal_logging/presentation/screens/log_meal_screen.dart:1720 — Note — AI tab typed `MealAiException` surfaced to the user; cause already reported by the service
- lib/features/meal_logging/presentation/screens/log_meal_screen.dart:1740 — Fault — AI tab unexpected exception
- lib/features/meal_logging/presentation/screens/log_meal_screen.dart:1789 — Degraded — AI tab image picker refused; user told

Counts over the 36 baseline entries: Fault 20 (incl. the one that replaced the two removed
parse catches), Degraded 7, Note 9, Removed 2 (the pair above), Reasoned 0. Plus two
non-catch debugPrints in `meal_ai_service.dart` turned into Degraded.

## Tests

- `test/features/meal_logging/meal_logging_business_logic_test.dart`: `MealAiService` group
  injects `RecordingReport`; the StorageException test asserts one Fault in area
  `meal_logging`. The corrupted-items test swaps `SentryReport.global` for a
  `RecordingReport` (restored in tearDown) and asserts one Degraded.
- Run green: that file, `recipe_picker_eaten_at_test`, `edit_meal_log_guard_test`,
  `meal_log_slot_seam_test`, `test/features/daily_macros/`, and the guard test.
- `dart analyze` on the test file shows two `unused_local_variable` warnings at lines 1436
  and 1950; both pre-date this change.
