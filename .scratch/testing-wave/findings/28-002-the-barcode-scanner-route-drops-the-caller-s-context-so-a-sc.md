# 28-002 · The barcode-scanner route drops the caller's context, so a scan from meal logging goes to the plan's food page

- kind: bug
- status: triaged
- ticket: 28
- run: w15-20260924T2040Z
- screen: Scan to Add Food (from Log — Sep 23 and from Build a Meal → Add food)
- decision: 

**Steps.**
1. Log — Sep 23 → barcode icon. Back.
2. Build a Meal → + Add food → barcode icon.
3. Read the console's analytics lines.

**Expected.**
`log_meal_screen._onBarcodeScan` pushes `barcode-scanner` with `extra: {'category': 'add_food', 'context': 'meal_log_discover'}` and Build a meal pushes `context: 'build_meal_add_food'`. The scanner's `_isMealLogContext` depends on that value: in a meal-log context a successful scan pops the `Food` back so the caller opens `LogScannedFoodScreen` (servings + slot) and logs it.

**Actual.**
The console logs `barcode_scanner_opened {category: add_food, context: null}` for all three opens, from both screens. The `/barcode-scanner` GoRoute in `lib/shared/core/app_router.dart` (around line 919) builds `BarcodeScannerScreen(category:, foodToSwapId:, foodToSwapName:)` and never passes `extra['context']`. So `_isMealLogContext` is always false. By the code, a successful scan from meal logging would therefore go to the nutrition plan's `FoodDetailScreen` (`addFromScan`, with the Before/During/After Run category picker) and pop a rebuilt `Food` only after the athlete saves there; the barcode_scanner_screen comment says the picker is exactly what the meal-log context is meant to skip. The scan itself cannot run on a simulator, so what the athlete sees after a successful scan is unconfirmed; 28-003 asks the device run to check it.

The Patrol flow `integration_test/flows/barcode_scanner_entry_flow_test.dart` only checks the screen opens and pops, so it would not catch this.

**Evidence.**
- runs/28/console-redacted.log (three `barcode_scanner_opened {category: add_food, context: null}` lines)
- runs/28/14-scanner-second-open.png (opened from Log — Sep 23)
- runs/28/19-build-scanner.png (opened from Build a Meal → Add food)

**Decision quote.**
> 

**Triage.**
Fix ticket 44 (Lee, 2026-09-25). Closed by the retest after it merges.
