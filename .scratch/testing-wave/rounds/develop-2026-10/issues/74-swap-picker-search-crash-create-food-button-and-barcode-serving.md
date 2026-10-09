# 74: Swap picker search crash, Create Food button that never enables, barcode values per 100 g shown as one serving

**Status:** landed (wave 8, 2026-10-09, develop-next `4b146f27`); open until its retest passes in test wave 9 (retest tickets 85-87)
**Labels:** fix, round:develop-2026-10, area:meal-logging, area:nutrition-plan
**Branch:** `develop-next` (fix-wave worktree)
**Source:** Findings 68-006, 68-009, 68-011; TRIAGE.md rulings of 2026-10-09 ("one ticket, fix all three")
**Blocked by:** nothing. No file shared with 75, 76 or 77, or with 71-73.
**Next:** `/testing-wave develop-2026-10` (fix wave 8)
**Model:** opus

Line numbers are from code at `84615131`.

## Findings

- **68-006 · Swap picker (Add Food, from an Edit Meal swipe) turns into a red "Tried to modify a provider while the widget tree was building" screen on search.** Run 68 swiped the only item of meal f380f4c8 in Edit Meal, tapped "Search for food...", typed "rice"; the whole screen went red. Dev Sentry MEALVANA-ENDURANCE-DEV-BX (23:28:38Z, fatal, unhandled): `_SwapFoodScreenState.build` → `_seedSearchController` (`swap_food_screen.dart:128`) → `FoodSearchController.updateFoodPool` → `updateSearch` → `state=`. Evidence: `runs/68/10c-search-rice.png`, `runs/68/10b-swap-picker.png`, `runs/68/sentry-dev-bx-swap-food.txt`.
- **68-009 · Create Custom Food: "Create Food" stays disabled after the name is typed.** Run 68 filled the form top to bottom (name "tw68 rice cup", unit, macros) and tapped Create Food four times: dim, no row, no log line. Toggling the During Run box (a `setState`) lit the button and one tap created `user_foods` 4fe1717b. Evidence: `runs/68/10h-create-food-no-response.png`, `runs/68/10l-create-food-after-toggle.png`, `runs/68/db-user-foods-after-create.txt`.
- **68-011 · Barcode lookup shows Nutella's per-100 g values as "1 serving".** Enter 3017620422003 → cache hit in `nutrition_products` (origin open_food_facts). Log Food showed "Per serving: 1 servings", "For 1 serving" 539 kcal, 58 g C, 6 g P, 31 g F: Nutella's per-100 g label values. "McEnnedy Double burger" (12345670, an OFF hit) showed 277 kcal the same way. Evidence: `runs/68/12f-known-barcode-result.png`, `runs/68/edge-check12-barcode.txt`.

## Fix

**68-006: seed the search pool outside `build`.**

Why it crashes (from code): `build` calls `_seedSearchController(state)` on every data rebuild (`lib/features/nutrition_plan/presentation/screens/swap_food_screen.dart:765-771`). The screen also watches `foodSearchControllerProvider('swap_food')` (`:742-744`). Typing calls `updateSearch` (`:134-138`), the search state changes, `build` runs again, and the seed calls `updateFoodPool` (`lib/shared/controllers/food_search_controller.dart:222-241`). Since G28 (`dcd275ae`) `updateFoodPool` re-runs `updateSearch` when a query is active (`:236-240`), which writes `state` (`:265`) inside `build`. `setFilter` (`:143-149`) does the same once the filter changes. The other four seeders (Log Meal `log_meal_screen.dart:564-573`, Build a Meal `build_meal_screen.dart:746-753`, Food Preferences `food_preferences_screen.dart:124-142`, carb loading `carb_loading_food_selection_screen.dart:233-238`) seed from an async load, not from `build`; only Swap seeds during `build`.

1. In `swap_food_screen.dart`, take the `_seedSearchController(state)` call out of `build` (`:768-771`; the `data:` branch only returns `_buildContent`).
2. In `initState` (`:73-100`), `ref.listenManual(swapFoodControllerProvider(_params), (prev, next) { … })` without `fireImmediately` (a provider write inside `initState` trips the same assert). In the listener, seed only when `next` has data and its pool changed: `!identical(prev?.value?.allFoodsForSearch, next.value?.allFoodsForSearch) || !identical(prev?.value?.allUserFoods, next.value?.allUserFoods)`. A selection change or My Foods expand (also `SwapFoodState` copies) then does not re-run the search or reset `isCatalogExpanded`.
3. In the existing post-frame callback (`:87-97`), seed once from `ref.read(swapFoodControllerProvider(_params)).value` when it already has data (the provider can be warm from an earlier open). Keep `setFilter` inside `_seedSearchController` (`:119-127`): it runs out of `build` now.
4. Leave `FoodSearchController` unchanged: G28's re-filter is right for the async seeders.

**68-009: the button reads the name as it is typed.**

Why it stays dim (from code): every controller listener calls `_onFieldChanged` (`lib/shared/screens/food_detail_screen.dart:314-323`), which calls `setState` only the first time (`:326-332`, guarded by `_hasChanges`). A `TextEditingController` also notifies on a selection change, so the tap that focuses the empty name field (caret placed) is that first time: `_hasChanges` turns true with the name still empty, and no later keystroke rebuilds. The button reads `_isValid` at build (`:351-353`, `:755-760`). Any `setState` (the category checkbox, `CategorySelector` `:706-715`) re-reads it, which is what run 68 saw.

5. Wrap the bottom `KylePrimaryButton` (`:755-760`) in `ValueListenableBuilder<TextEditingValue>(valueListenable: _nameController, builder: …)`, with `onPressed: value.text.trim().isNotEmpty && _hasValidCategorySelection ? _handleSave : null`. Keep the `ValueKey('custom_food.create_button')`. `_handleSave`'s own name check (`:402-405`) stays. This covers every mode of the screen (create, scan, search, edit), since all share the button.

**68-011: the values match the serving the label names.**

How 539 kcal became "1 serving" (from code): `FoodMappingService.mapToFood` (`lib/features/barcode_scanning/application/food_mapping_service.dart:19-95`) uses `apiProduct.servingGrams ?? assumedServingGrams ?? 100.0` (`:38-40`) and `calculateForServing` (`lib/features/barcode_scanning/domain/api_food_product.dart:120-185`). With `serving_grams` null and no per-serving values, that is per-100 g × 1. The Food is labelled `servingAmount: 1.0, servingUnit: 'servings'` (`food_mapping_service.dart:53-60`), and `LogScannedFoodScreen._servingDescriptor` prefers amount + unit (`lib/features/meal_logging/presentation/screens/log_scanned_food_screen.dart:64-77`), so it prints "Per serving: 1 servings" and never shows `servingSize`. The cache path (`supabase/functions/_shared/food_sources/cache.ts:46-67`) returns `serving_grams` and `serving_size` but not `serving_quantity`; the client reads `serving_size` only as a label. So 539 kcal means, from code (unverified), that row 03017620422003 has `serving_grams` null and `calories_per_serving` null.

6. Before coding, read that row once, read-only (the main clone's `/Users/leemartin/development/mealvana_endurance/secrets/supabase_management_api.env`, Management API `database/query`): `select barcode, serving_size, serving_grams, calories_per_100g, calories_per_serving, nutrition_data_per, source from nutrition_products where barcode in ('03017620422003', '00000012345670');`. Write the answer into the fix notes. Items 7-9 hold either way.
7. In `food_mapping_service.dart`, one private basis helper used by both `mapToFood` (`:38-63`) and `_convertFoodItemToFood` (`:117-144`), in this order:
   - a. Grams known: `servingGrams` if > 0; else `servingQuantity` when `servingQuantityUnit` is null, `g` or `ml`; else grams parsed from `servingSize` (`(\d+(?:[.,]\d+)?)\s*(g|ml)\b`, case-insensitive; "15 g", "1 portion (37 g)"); else `assumedServingGrams`. Values are `calculateForServing(grams)` (which already prefers the per-serving values within 10 %). Label is `servingSize` if it gave or names the grams, else "`<grams> g`".
   - b. No grams, per-serving values present: values are the per-serving values as they are; label is `servingSize` (may be null).
   - c. Neither: per-100 g values; label "100 g". Never label per-100 g values with a declared serving's text.
   - `servingAmount: 1.0` and `servingUnit: 'servings'` stay (the plan and the carb-loading sheet count servings, `carb_loading_food_selection_controller.dart:711`); `servingSize` carries the label.
8. In `log_scanned_food_screen.dart:64-77`, when the unit is the generic `serving`/`servings`, use `servingSize` ("Per serving: 15 g", "Per serving: 100 g"); amount + unit stays for a real unit ("Per serving: 1 gel", `test/features/meal_logging/log_scanned_food_screen_test.dart:21-22`).
9. No server change: the client reads the fields the cache already returns. The mapper serves every `mapToFood` caller (`barcode_scanner_service.dart:99`, `log_meal_screen.dart:724, :779`, `build_meal_screen.dart:867, :915`, `swap_food_screen.dart:540`, `food_preferences_screen.dart:477`, `carb_loading_food_selection_controller.dart:711`, `shared_food_search_service.dart:105`). A product whose label names a serving now shows that serving's values everywhere, not 100 g's.

## Touches

lib/features/nutrition_plan/presentation/screens/swap_food_screen.dart
lib/shared/screens/food_detail_screen.dart
lib/features/barcode_scanning/application/food_mapping_service.dart
lib/features/meal_logging/presentation/screens/log_scanned_food_screen.dart
test/features/nutrition_plan/swap_food_search_seed_test.dart (new)
test/shared/screens/food_detail_create_button_test.dart (new)
test/features/barcode_scanning/food_mapping_serving_basis_test.dart (new)
test/features/meal_logging/log_scanned_food_screen_test.dart

8 files. `food_mapping_service.dart` holds a `@riverpod` provider, but no annotated signature changes, so no codegen. If one slips in, run unfiltered codegen.

## Tests

- [x] **68-006, widget test through the real controllers** (`swap_food_search_seed_test.dart`): pump `SwapFoodScreen` with the real `SwapFoodController` and `FoodSearchController`, seeded with a food pool shaped like the Drift rows (`allFoodsForSearch` with "Rice (1 cup cooked)", `allUserFoods` with one user food). Type "rice": no `FlutterError`, the rice row is listed. Then refresh the swap controller's foods (`SwapFoodController.refreshFoods`, `swap_food_controller.dart:590`, called from the screen at `:235, :297, :477, :712`) while the query is active: the results are re-filtered and nothing throws. Red before the fix (the same assert as DEV-BX).
- [x] **68-009, widget test** (`food_detail_create_button_test.dart`): `FoodDetailMode.createNew`. Tap the name field first (moves the caret), then enter text: the button is enabled and one tap pops a `FoodDetailResult`. Clearing the name disables it again. Red before the fix.
- [x] **68-011, seam test** (`food_mapping_serving_basis_test.dart`): feed `ApiFoodProduct.fromEdgeFunctionResponse` the cache shape from `cache.ts:46-67` (snake_case, as the server sends it), never a Food built by the mapper:
  - Nutella as stored (item 6's row; until it is read, `serving_size: "15 g"`, `serving_grams: null`, `calories_per_100g: 539`, `carbohydrates_per_100g: 57.5`, `calories_per_serving: null`): about 81 kcal, label "15 g".
  - The same row with `serving_size: null`: 539 kcal, label "100 g".
  - Per-serving values with no grams (USDA label shape, `calories_per_serving: 140`, `serving_grams: null`): 140 kcal, `servingSize` as sent.
  - `serving_grams: 37` with per-100 g only: 199 kcal (539 × 0.37, rounded).
  - Run the `existingFood` branch too (`getFoodByBarcode` answering a row).
- [x] `log_scanned_food_screen_test.dart`: add "Per serving: 15 g" for a `servings` Food with `servingSize: '15 g'` and "Per serving: 100 g" for the 100 g basis; the existing "1 gel" case still passes. "1 servings" appears nowhere.
- [x] #116: `grep -rl` under `test/` for `SwapFoodScreen`, `_seedSearchController`, `foodSearchControllerProvider`, `updateFoodPool`, `FoodDetailScreen`, `custom_food.create_button`, `FoodMappingService`, `mapToFood`, `calculateForServing`, `LogScannedFoodScreen`; run every file named. Known today: `test/smoke_tests/food_smoke_test.dart`, `test/smoke_tests/auth_misc_smoke_test.dart`, `test/shared/food_search_pool_race_test.dart`, `test/shared/controllers/food_search_barcode_query_test.dart`, `test/shared/screens/food_detail_screen_category_optional_test.dart`, `test/features/barcode_scanning/barcode_scanner_service_analytics_test.dart`, `test/features/barcode_scanning/api_food_product_scaling_test.dart`.
- [x] Async paths, written in the fix notes: (i) the swap controller's foods refresh twice at once: each completion runs the listener once and the second seed re-filters the same query; (ii) the screen is popped while `refreshFoods` is in flight: `listenManual` is closed with the element, so nothing seeds a disposed screen; (iii) the provider is warm when the screen opens: the post-frame seed covers it, and the listener does not fire for a value that did not change. No retry or timeout is added.
- [x] `flutter analyze` clean on the touched files.

## Deploy

None (client only).

## Retest

Next test wave, meal-logging retest ticket, on a simulator:
- **68-006:** Edit Meal → swipe an item right to left → the picker → search "rice": results show, no red screen, no new DEV-BX event. Pick one, set quantity 2, Save: Edit Meal shows the swap.
- **68-009:** picker → Create Custom Food → tap the name field, type a name: Create Food lights at the first letter, without touching a checkbox; one tap creates the `user_foods` row.
- **68-011:** Scan barcode → Enter → 3017620422003: Log Food reads "Per serving: <the row's serving, e.g. 15 g>" with that serving's kcal (about 81 for 15 g), or "Per serving: 100 g" with 539 if the row names no serving (fix notes, item 6). "1 servings" appears nowhere. 12345670 the same way.

## Fix notes

Code commit `ffbf0606b` on `testing-wave/develop-2026-10/74` (base `0e6aa1cf7`). No codegen: no annotated signature changed, no generated file touched.

**68-006 (swap picker search crash).** `swap_food_screen.dart`: `build`'s `data:` branch only returns `_buildContent`. `initState` adds `ref.listenManual(swapFoodControllerProvider(_params), …)` without `fireImmediately`; the listener seeds only when `next` has data and `allFoodsForSearch` or `allUserFoods` is a different list from `prev` (`identical`), so a selection change or My Foods toggle does not re-run the search. A post-frame callback seeds once from a warm provider. `setFilter` stays in `_seedSearchController`. `FoodSearchController` unchanged. The new widget test went red on the old screen with the DEV-BX assert ("Tried to modify a provider while the widget tree was building") before the fix.

**68-009 (Create Food never enables).** `food_detail_screen.dart`: the bottom `KylePrimaryButton` sits in a `ValueListenableBuilder<TextEditingValue>` on `_nameController`; `onPressed` is `name.text.trim().isNotEmpty && _hasValidCategorySelection ? _handleSave : null`. Key `custom_food.create_button` kept; `_handleSave`'s own name check kept. The now-unused `_isValid` getter is removed. The test (tap the name field, then type) went red on the old screen.

**68-011 (per-100 g shown as one serving).** `food_mapping_service.dart`: one private `_servingBasis` used by `mapToFood` and `_convertFoodItemToFood`, in the ticket's order: (a) grams from `serving_grams` > 0, else `serving_quantity` when its unit is null/g/ml, else grams parsed from `serving_size` (`(\d+(?:[.,]\d+)?)\s*(g|ml)\b`, case-insensitive), else `assumedServingGrams` (no caller passes it today); values `calculateForServing(grams)`; label `serving_size` when its grams match, else "N g". (b) no grams but per-serving values: those values as sent, label `serving_size` (may be null). (c) neither: per-100 g values, label "100 g". `servingAmount: 1.0` / `servingUnit: 'servings'` unchanged. `log_scanned_food_screen.dart`: for the generic `serving`/`servings` unit the descriptor prints `servingSize` ("Per serving: 15 g"); a real unit still prints amount + unit ("Per serving: 1 gel"); generic unit with no size shows no descriptor. The seam test went red (9 of 10) on the old mapper. No server change.

**Item 6 (read the Nutella row) not done.** The wave lead's rules for this pass say "No SQL on dev or prod", which outranks the ticket's read-only select. The test uses the ticket's stand-in row (`serving_size: "15 g"`, `serving_grams: null`, `calories_per_100g: 539`, `carbohydrates_per_100g: 57.5`, `calories_per_serving: null`). Items 7-9 hold either way; the retest will show which label the real row gives (15 g / about 81 kcal, or 100 g / 539 kcal). The lead or the retest agent can run the ticket's select.

**#77 async paths.**
- (i) Two `refreshFoods` at once: both `invalidateSelf` and await the same rebuild; each data emission with a new pool runs the listener once, and a second seed re-filters the same active query (idempotent). Covered by the "two refreshes at once" test.
- (ii) Screen popped while `refreshFoods` is in flight: the `listenManual` subscription closes with the element, so nothing seeds a disposed screen; the post-frame seed checks `mounted`.
- (iii) Provider warm when the screen opens: the post-frame seed covers it; the listener does not fire for a value that did not change. During a refresh the loading state carries the previous value, the pool is `identical`, so nothing seeds mid-build.
- No retry or timeout added. Create Food and the mapper add no async path.

**D9.** No new early return or swallowed error on a startup, sync, push or payment path. The listener's `value == null` return is the loading/error state, not a failure.

**Tests run (all pass).**
- `test/features/nutrition_plan/swap_food_search_seed_test.dart` (new): 3/3
- `test/shared/screens/food_detail_create_button_test.dart` (new): 2/2
- `test/features/barcode_scanning/food_mapping_serving_basis_test.dart` (new): 10/10
- `test/features/meal_logging/log_scanned_food_screen_test.dart`: 8/8 (3 added)
- #116 grep (`SwapFoodScreen`, `_seedSearchController`, `foodSearchControllerProvider`, `updateFoodPool`, `FoodDetailScreen`, `custom_food.create_button`, `FoodMappingService`, `mapToFood`, `calculateForServing`, `LogScannedFoodScreen`): `api_food_product_scaling_test.dart` 18/18, `barcode_scanner_service_analytics_test.dart` 2/2, `food_search_barcode_query_test.dart` 6/6, `food_search_pool_race_test.dart` 2/2, `food_detail_screen_category_optional_test.dart` 2/2, `smoke_tests/auth_misc_smoke_test.dart` 7/7 (1 skipped), `smoke_tests/food_smoke_test.dart` 1/1.
- `flutter analyze` on the 8 touched files: no issues.

## Questions for Lee

**Questions for Lee.** None.

**Lead, at the close (2026-10-09).** Item 6 read on dev (read-only): the Nutella row `03017620422003` (source open_food_facts) has `serving_size` null, `serving_grams` null, `serving_quantity` null, `nutrition_data_per` 100g, 539 kcal / 57.5 C / 6.3 P / 30.9 F per 100 g. With this fix Log Food shows those values for "100 g", not "1 serving" and not 81 kcal for 15 g; the retest judges on that.
