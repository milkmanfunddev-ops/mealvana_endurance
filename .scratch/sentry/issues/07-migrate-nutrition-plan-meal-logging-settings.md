# 07: Migrate: nutrition plan, meal logging, settings

**What to build:** Every catch block in the nutrition-plan feature, meal logging, and settings is classified and moved to `Report`: a swallowed failure becomes a Fault, an expected-but-bad condition a Degraded, a best-effort branch a Note with its area set, and a try/catch that hides a real bug is removed so the error propagates. Direct Sentry SDK calls in these directories route through `Report`. Every baseline entry for these directories is deleted from the guard's allow-list; any catch left deliberately silent gets a reasoned entry instead. The ticket's closing comment lists every site and its classification so review can overrule one.

**Blocked by:** 01 Report service exists; 04 Source guard with a baseline

**Status:** done (2026-10-06, wave 3; parts merged on `sentry`)

- [x] No baseline entry remains for the nutrition-plan feature or the other directories in scope; the guard test is green
- [x] No `print`, `debugPrint`, logger-only or empty catch remains in scope; each is a `Report` call, a rethrow, or a reasoned allow-list entry
- [x] No direct Sentry SDK import remains in scope
- [x] The ticket records each site's classification (Fault / Degraded / Note / removed / reasoned)
- [x] Existing tests in scope still pass; where a catch becomes a Fault on a tested path, the test asserts the report through `NoopReport` or the transport, not console output

## Sites (part A: `lib/features/nutrition_plan/**`, `lib/features/settings/**`)

Baseline lines deleted from `test/shared/source_guard/allow_list.md`: 61 (56 unreportedCatch, 4 printInCatch, 1 sentryImport). One `## reasoned` entry added. Legacy `DebugLogger.error/warning`, `appLogger.warning`, `_logger.warning` and `sentry.reportDatabaseError` calls inside catch blocks of the touched files were converted in the same pass (marked "legacy" below); `DebugLogger.info` calls were left for ticket 10. Areas: `nutrition_plan` by default; `training_peaks`, `garmin`, `coach_mode`, `push`, `sync`, `auth`, `settings` where the site is really about that.

### nutrition_plan / application
- `brick_macro_service.dart:182` — Removed (reporting) — `on FunctionException` rethrows as `BrickMacroGenerationException`; the legacy `DebugLogger.error` became `info` narrative, the controller owns the report (legacy)
- `brick_macro_service.dart:187` — Removed (reporting) — generic catch rethrows wrapped; `info` narrative only (legacy)
- `brick_macro_service.dart:979` — Note — `_toDoubleOrNull`: the `(value as num)` cast could never succeed after the `double`/`int`/`String` checks, so the try/catch was dead; replaced by a Note that the payload shape drifted
- `brick_macro_service.dart:1015` — Degraded — `_toDouble` fell back to 0 for an unreadable field (legacy `DebugLogger.error`)
- `macro_generation_service.dart:602` — Degraded — unknown activity type from the edge function, expected type used (legacy `DebugLogger.warning`)
- `macro_generation_service.dart:615` — Degraded — `SocketException`, offline fallback used (legacy)
- `macro_generation_service.dart:624` — Degraded — `TimeoutException`, offline fallback used (legacy)
- `macro_generation_service.dart:641` — Degraded — message-sniffed network failure, offline fallback used; the non-network branch still rethrows (legacy)
- `macro_generation_service.dart:1065` — Degraded — `_toDouble` fell back to 0 (legacy)
- `macro_generation_service.dart:1085` — Note — `_toDoubleOrNull` dead try/catch replaced, as in brick
- `client_plan/client_food_pool_service.dart:203` — Fault — Supabase fallback fetch of template foods failed, pool empty (legacy `_logger.warning`)
- `client_plan/client_food_pool_service.dart:293` — Note — category string was neither JSON nor a Postgres literal; treated as empty (asserted in `client_food_pool_category_parse_test.dart`)
- `client_plan/client_plan_service.dart:287` — Fault — electrolyte/water pairing pass threw; items returned unpaired (legacy)
- `client_plan/client_plan_service.dart:338` — Fault — template-based before selection threw; greedy used (legacy)
- `client_plan/client_plan_service.dart:466` — Fault — during rule solver threw; greedy used (legacy)
- `client_plan/client_plan_service.dart:583` — Fault — pinned personal formula lookup threw; fell through (legacy)
- `client_plan/client_plan_service.dart:730` — Fault — pin backfill could not load essential foods; backfill skipped (legacy)
- `client_plan/client_plan_service.dart:872` — Fault — greedy solver threw; phase left empty (legacy)
- `client_plan/client_plan_service.dart:1002` — Degraded — template `foods` JSON unreadable; template skipped
- `client_plan/client_plan_service.dart:1121` — Note — template JSON list unreadable; treated as empty

### nutrition_plan / data + domain
- `data/nutrition_plan_repository.dart:60` — Degraded — stored plan JSON unreadable; empty map returned (the mapper fails from there; this is the only place that knows why)
- `data/nutrition_plan_repository.dart:78` — Note — plan not cached because it has no activityId (guard bail, legacy `DebugLogger.warning`)
- `data/nutrition_plan_repository.dart:97` — Fault — caching the plan on the activity row failed (legacy `DebugLogger.error` + `sentry.reportDatabaseError`)
- `data/nutrition_plan_repository.dart:134` — Fault — reading an activity's plan failed, null returned (legacy)
- `data/nutrition_plan_repository.dart:165` — Fault — clearing an activity's plan failed, false returned (legacy)
- `data/nutrition_plan_repository.dart:188` — Fault — reading the latest cached plan failed (legacy)
- `data/nutrition_plan_repository.dart:222` — Removed (reporting) — `updatePlanRunDateTimeForActivity` rethrows; `info` narrative only, caller owns it (the legacy `reportDatabaseError` double-reported)
- `data/nutrition_plan_repository.dart:268`, `:317` — Degraded — one stored plan did not parse and was left out of the list (legacy `DebugLogger.warning`)
- `data/nutrition_plan_repository.dart:281`, `:330` — Fault — listing plans failed, empty list returned (legacy)
- `data/nutrition_plan_repository.dart` constructor — `SentryReporter sentry` replaced by `Report report`; provider wires `reportProvider`
- `data/template_foods_repository.dart:150` — Note — template food `categories` unreadable; excluded from the swap list (with foodId)
- `data/template_foods_repository.dart:187` — Note — drink `drinkPoolPhases` unreadable; excluded from the pool
- `data/transparency_feedback_store.dart:46` — Degraded — stored votes unreadable; reset to empty
- `domain/nutrition_target_overrides.dart:173` — Degraded — saved overrides unreadable; algorithm defaults used. Static parser, so `SentryReport.global`
- `domain/solver_food.dart:229` — Note — JSON list unreadable; treated as empty. Static parser, so `SentryReport.global`

### nutrition_plan / presentation / providers
- `activity_detail_controller.dart:659` — Note — one detailed-macro-targets candidate key did not parse; next key tried
- `activity_detail_controller.dart:2441` — Fault — analytics `track` threw (was "silently fail analytics")
- `activity_detail_controller.dart:2846` — Fault — reading the swipe-hint flag failed; hint treated as shown
- `activity_detail_controller.dart:2861` — Fault — writing the swipe-hint flag failed
- `activity_detail_controller.dart:2890` — Fault (`training_peaks`) — TP completion-feedback push failed, non-blocking (legacy `DebugLogger.error`)
- `activity_detail_controller.dart:2920` — Fault (`training_peaks`) — TP plan write-back failed, non-blocking (legacy)
- `activity_detail_controller.dart` / `macro_targets_controller.dart` — the `_report` getter falls back to `SentryReport.global` when `ref.mounted` is false: the fire-and-forget TP pushes outlive the provider (seen in `fuel_log_reopen_and_save_regression_test.dart`)
- `cycling_input_controller.dart:327` — Fault — user preferences load failed; defaults kept (legacy)
- `cycling_input_controller.dart:755` — Degraded — current location unavailable
- `cycling_input_controller.dart:821` — Degraded — weather forecast fetch failed; defaults kept
- `running_input_controller.dart:289` — Degraded — zone pace unavailable; default kept (legacy)
- `running_input_controller.dart:320` — Fault — user preferences load failed (legacy)
- `running_input_controller.dart:691` — Degraded — current location unavailable
- `running_input_controller.dart:758` — Degraded — weather forecast fetch failed
- `swimming_input_controller.dart:231` — Fault — user preferences load failed (legacy)
- `swimming_input_controller.dart:273` — Degraded — zone pace unavailable (legacy)
- `swimming_input_controller.dart:628` — Degraded — current location unavailable
- `swimming_input_controller.dart:690` — Degraded — weather forecast fetch failed
- `macro_targets_controller.dart` import — sentryImport removed; `captureMessage` + `SentryLevel` routed through `Report`
- `macro_targets_controller.dart:624`, `:854`, `:1148`, `:1399` — Degraded — event-name lookup failed; formatted title used (legacy `DebugLogger.warning`)
- `macro_targets_controller.dart:752`, `:1003`, `:1283`, `:1550` — Removed (reporting) — generation catch blocks rethrow after analytics; `info` narrative, the screen owns the report (legacy `DebugLogger.error`)
- `macro_targets_controller.dart:1865` — Fault — no cached macro targets when creating the plan, null returned (guard bail, legacy; `LoggedFault`)
- `macro_targets_controller.dart` ~`:2095`, ~`:2112` — Removed — `DebugLogger.error` immediately before a `throw` deleted; the throw carries the message
- `macro_targets_controller.dart:2127` — Removed (reporting) — draft-activity update rethrows; `info` narrative (legacy)
- `macro_targets_controller.dart:2182` — Fault — `createNutritionPlan` ended in error, navigation blocked (legacy `appLogger.error` + `DebugLogger.error`)
- `macro_targets_controller.dart:2240` / `:2249` — Fault / Degraded — plan-generation anomaly: Fault with the operation error when there is one, Degraded (`LoggedFault`) for fallback-used / target-miss; same tags, extra and fingerprint as the old `captureMessage`. Its try/catch (the flagged `catch (error)` with `DebugLogger.warning`) is Removed: `Report` never throws
- `macro_targets_controller.dart:2422` — Degraded — coach remote-visibility check attempt failed; retried, then the method throws (legacy `appLogger.warning`; the guard missed it because of the capital L)
- `macro_targets_controller.dart:2619` — Fault (`training_peaks`) — TP write-back failed, non-blocking (legacy)
- `night_before_nudge_coordinator.dart:101` — Fault (`push`) — the whole sweep is swallowed by design; D9 says write it down (legacy `appLogger.warning` via `ref.read(appLoggerProvider)`)
- `swap_food_controller.dart:156` — Reasoned — `_isMounted`: the catch IS the mounted test (reading `state` on a disposed notifier throws). Allow-list `## reasoned` entry added
- `swap_food_controller.dart:350` — Note — template food `categories` unreadable; food shown without categories

### nutrition_plan / presentation / screens + widgets (screens stay UI-only: the catch reports and shows the snackbar it already showed)
- `activity_detail_screen.dart:148` — Fault — swipe-hint check failed; hint suppressed
- `activity_detail_screen.dart:174` — Fault — marking the swipe hint shown failed
- `activity_detail_screen.dart:1062` — Fault — pull-to-refresh failed (best effort)
- `adjust_macros_screen.dart:630` — Fault — `createNutritionPlan` threw past the controller (the controller reports failures it captures in state; an escape is unexpected)
- `fuel_log_screen.dart:327` — Degraded — stored fuel log unreadable; empty one started
- `swap_food_screen.dart:241` — Fault — saving a scanned custom food failed
- `swap_food_screen.dart:385` — Fault — swap/add confirm failed (printInCatch removed)
- `swap_food_screen.dart:485` — Fault — saving a catalog food failed
- `swap_food_screen.dart:590` — Fault — barcode import failed
- `swap_food_screen.dart:727` — Fault — saving an imported product failed
- `swap_food_screen.dart:1140` — Fault — deleting a user food failed (printInCatch removed)
- `swap_food_screen.dart:1183` — Fault — updating a user food failed (printInCatch removed)
- `widgets/activity_detail/nutrient_full_story_section.dart:130` — Fault — analytics `track` threw
- `widgets/adjust_macros/edit_macros_dialog_widget.dart:305` — Fault — saving edited macro targets failed. The old catch also caught the athlete's typos (`double.parse`); validation now runs first with `tryParse` and shows "Invalid input" without a report, so the catch wraps only the save

### settings
- `providers/settings_controller.dart:926` — Degraded (`auth`) — sign-out after account deletion failed; the account is already gone
- `screens/coach_connection_screen.dart:68` — Fault (`coach_mode`) — loading the athlete's coach connection failed
- `screens/coach_connection_screen.dart:111` — Fault (`coach_mode`) — connect-by-code threw (the service's own failure reasons are handled; this is the escape)
- `screens/coach_connection_screen.dart:193` — Fault (`coach_mode`) — disconnect threw
- `screens/connected_apps_screen.dart:748`, `:870` — Fault — analytics `track` threw (was "must never block onboarding")
- `screens/connected_apps_screen.dart:1537` — Fault (`push`) — manual push-subscription reset threw
- `screens/debug_screen.dart:81` — Fault (`sync`) — manual sync from the debug screen failed (two `debugPrint`s removed)
- `screens/food_preferences_screen.dart:195` — Degraded — user-foods sync failed; cached data used (legacy `DebugLogger.warning`)
- `screens/food_preferences_screen.dart:312` — Fault — loading food preferences failed (legacy)
- `screens/food_preferences_screen.dart:374` — Fault — saving food preferences failed (legacy)
- `screens/food_preferences_screen.dart:546` — Fault — loading product details failed (legacy)
- `screens/food_preferences_screen.dart:652` — Fault — saving a searched food failed (legacy)
- `screens/food_preferences_screen.dart:678` — Degraded (`sync`) — remote `user_foods` delete failed, local delete succeeded (legacy `DebugLogger.warning`)
- `screens/food_preferences_screen.dart:702` — Fault — deleting a user food failed (legacy)
- `screens/food_preferences_screen.dart:802` — Fault — saving a scanned custom food failed (the flagged site)
- `screens/food_preferences_screen.dart:848` — Fault — barcode scanning threw (legacy)
- `screens/food_preferences_screen.dart:1143` — Fault — updating a user food failed (legacy)
- `screens/food_settings_consolidated_screen.dart:87` — Fault — loading dietary preference + allergies failed
- `screens/nutrition_profile_screen.dart:160` — Fault — unit preference unavailable; imperial display kept
- `screens/nutrition_profile_screen.dart:182` — Degraded (`training_peaks`) — TP athlete weight unavailable; badge absent
- `screens/nutrition_profile_screen.dart:227` — Degraded (`garmin`) — Garmin body-comp auto-fill failed
- `screens/nutrition_profile_screen.dart:322` — Fault — saving the nutrition profile failed
- `screens/nutrition_targets_screen.dart:186` — Fault — unit preference unavailable; mL display kept
- `screens/nutrition_targets_screen.dart:481` — Fault — saving nutrition target overrides threw
- `screens/preferences_screen.dart:152` — Fault — saving preferences failed

Screens take the `Report` before their first `await` (a `late final` set in `initState`, or a local), because `ref` is unusable from a catch that runs after the widget unmounted (seen in `nutrition_profile_save_invalidation_test.dart`).

### Left for other tickets
- `DebugLogger.info` / `_logger.info` calls everywhere in scope: not reports; ticket 10.
- `DebugLogger.error` calls that are NOT inside a catch and immediately precede a `throw` in `brick_macro_service.dart` (~98, ~113) and `macro_generation_service.dart`: unchanged, the throw propagates; ticket 10 when it deletes the alias.
- `adjust_macros_screen.dart` `DebugLogger.error` at ~115 (no-data state) and `logger.error` at ~670 (null activityId): not catch blocks; ticket 10.
- The `notification-testing` skill named in CLAUDE.md is not present in this checkout (`.claude/skills/` has device-sweep, drive-device, qa-smoke, shorebird-patch only); the nudge coordinator change is reporting-only, no scheduling behaviour touched.


## Part B: meal_logging

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

### Tests

- `test/features/meal_logging/meal_logging_business_logic_test.dart`: `MealAiService` group
  injects `RecordingReport`; the StorageException test asserts one Fault in area
  `meal_logging`. The corrupted-items test swaps `SentryReport.global` for a
  `RecordingReport` (restored in tearDown) and asserts one Degraded.
- Run green: that file, `recipe_picker_eaten_at_test`, `edit_meal_log_guard_test`,
  `meal_log_slot_seam_test`, `test/features/daily_macros/`, and the guard test.
- `dart analyze` on the test file shows two `unused_local_variable` warnings at lines 1436
  and 1950; both pre-date this change.
