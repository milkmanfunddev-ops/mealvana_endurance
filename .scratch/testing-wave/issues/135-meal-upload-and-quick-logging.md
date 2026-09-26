# 135: Meal upload and quick logging

**Status:** ready
**Blocked by:** none.
**Next:** `/implement-lee testing-wave`
**Model:** fable

**What to build:** Fixes from the 2026-09-26 triage for Log a Meal's quick log paths, one agent, as a list. Item 1 is the priority. Do it first and do not trade it away for the others.
1. **PRIORITY: a meal whose first upload fails gets retried (112-001).** Offline logs never reach the server, and neither does an online log whose first insert timed out. `meal_log_repository.dart:581` `_scheduleImmediateUpload` (and `_scheduleImmediateBulkUpload`, :620) only logs "stays dirty for retry". `SyncCoordinator.ensureSynced` then skips while `meal_logs` is under an hour fresh (`sync_coordinator.dart:201`), because `_uploadRetryOwed` (:87) is set only when the coordinator's own upload fails. Fix: a failed immediate upload marks `meal_logs` as owed a retry on the coordinator. That upload is retried when the network comes back (`ConnectivityChecker.onlineChanges`), on pull-to-refresh, on opening Log a Meal and on app resume. Keep it repository-level through `ensureSynced`, never a startup sync-all (CLAUDE.md offline-first). Check the `UploadResult` from `uploadDirtyRecords()`, because a `failed()` must keep the retry owed. The row shows at once and its upload state stays tracked.
2. **Common single ingredients keep their unit (112-002).** `_scale` in `log_meal_screen.dart:277` replaces the portion with "1 serving" / "1.5 servings". Scale the ingredient's own portion ("1 large" → "1.5 large") the way `scaleComponentForRelog` does. Search results that log as "1 serving" (Eggs) take the same path.
3. **Recent re-log scales portions readably (112-003).** `parseLeadingQuantity` (`portion_quantity.dart:16`) reads only the first integer. That gives "2/2 cup dry" and leaves "(115 g)" unscaled. Parse fractions, mixed numbers and decimals, and scale a bracketed gram amount too. When a portion cannot be parsed, fall back to "1.5 × <portion>".
4. **Scaled logs store rounded numbers (112-004).** `_scale` and `meal_relog.dart` multiply without rounding, so rows carry 60.449999999999996. Round macros to one decimal and sodium to a whole mg, on items and on the row totals, before the write. Keep null as null.
5. **A double tap on Log it logs once and opens nothing (112-006).** The second tap reaches the list under the sheet (`quick_log_confirm_sheet.dart:212`). Ignore taps after the first pop, and do not let the closing sheet pass a tap through to the tile below.
6. **A Recent row keeps the meal's per-serving numbers (112-012, Lee).** One serving always means the original amount. A re-log at 2 servings must not become Recent's new 1-serving base. `_dedupeRecent` in `meal_log_repository.dart` keys by lowercase name, so same-named meals with different items must both show. Store or derive the per-serving base (for example from the servings the log was made at; how is unverified) and use it in `_onRecentTap`'s preview and in `relogMeal`.
7. **A Recent re-log starts on the source log's slot (112-013, Lee).** `_onRecentTap` (`log_meal_screen.dart:750`) opens the sheet without `initialSlot`. Pass `log.slot`.
8. **Combos carry sodium (112-014, Lee).** `kQuickAssemblies` in `quick_assembly.dart` has per-item numbers but no sodium. Add `sodiumMg` to each item, taken from the matching single ingredient in `common_ingredients.dart` where one exists. Where none matches, leave it null (null ≠ 0).
9. **Common logs are tracked as `common` (112-025).** Combo and single-ingredient taps fall back to `source.wireValue` (`meal_log_providers.dart:489`). Only the search tap passes `logMethod: 'common'` (`log_meal_screen.dart:717`). Pass it on the combo and ingredient paths too (`log_meal_screen.dart:893`, `:939`).

**Findings:** 112-001, 112-002, 112-003, 112-004, 112-006, 112-012, 112-013, 112-014, 112-025.

**Decisions:** none on the page. Lee ruled in the terminal (triage-20260926.md: 112-012, 112-013, 112-014).

**Touches:** lib/features/meal_logging/data/meal_log_repository.dart, lib/shared/services/sync/sync_coordinator.dart, lib/shared/services/connectivity_checker.dart, lib/features/meal_logging/presentation/providers/meal_log_providers.dart, lib/features/meal_logging/presentation/screens/log_meal_screen.dart, lib/features/meal_logging/presentation/widgets/quick_log_confirm_sheet.dart, lib/features/meal_logging/domain/portion_quantity.dart, lib/features/meal_logging/domain/meal_relog.dart, lib/features/meal_logging/domain/quick_assembly.dart, lib/features/meal_logging/domain/common_ingredients.dart

The app-resume and Log-a-Meal-open hooks for item 1 are not mapped yet (unverified). Find where `recentMeals` and `mealLogsForDate` already call `_ensureSynced` and reuse that.

- [ ] Seam test through the real `MealLogController` and `SyncCoordinator`: an insert whose immediate upload fails is uploaded by the next `ensureSynced` while `meal_logs` is still fresh, and by the online event. A `UploadResult.failed()` keeps it owed.
- [ ] Unit tests: `parseLeadingQuantity` / relog scaling on "1/2 cup dry", "4 oz cooked (115 g)" and "1 large". Scaled totals are rounded and null stays null. Every quick assembly with a matching ingredient has sodium.
- [ ] Controller or widget tests: a Recent re-log of a 2-serving log previews and logs the per-serving base. Two same-named meals with different items both show. The sheet starts on the source slot. A double tap on Log it writes one row and opens no second sheet. Combo and ingredient logs track `method: common`.
- [ ] `flutter analyze` clean on touched files.

Next: /implement-lee testing-wave
