# 38: The swap path keeps quantity apart from the portion text; MealItemsEditor is archived

**Status:** fixed (wave 4, 779431cb) awaiting retest
**Labels:** fix, round:develop-2026-10, area:meal-logging
**Branch:** `develop-next` (fix-wave worktree)
**Blocked by:** nothing.
**Next:** `/testing-wave develop-2026-10` (fix wave 4)
**Model:** opus

**What to build:** Ticket 24 (commit `8e2352a6`, 02-005) gave `MealComponent` a `quantity` (default 1) and a `portionLabel` getter (`meal_component.dart:52-57`), and the Edit Item dialog saves the portion as typed with `quantity: qty` (`meal_component_editor.dart:334`). Two paths still fold the quantity into the portion text (Lee, 2026-10-08, wave 2 question l). Line numbers from code at `4e77cf43`.

1. **The swap path, duplicated in two screens.** `meal_review_screen.dart:82-115` (qty at `:94`, label `:95-100`, `portion: '$qtyLabel $unit'` at `:105`, `* qty` at `:101, :107`) and `edit_meal_log_screen.dart:504-538` (qty `:517`, `portion` `:528`, `* qty` `:524, :530`) both build `MealComponent(portion: '$qtyLabel $unit', calories: caloriesPerServing * qty, …)` with no `quantity:`. Pull the mapping into one domain helper beside `meal_relog.dart` (`swappedComponent(food, qty)`), which writes `portion: '1 ${food.servingUnit ?? 'serving'}'` (the per-serving base, as the AI would write it), the eaten macros (× qty, ticket 24's rule: macros hold what was eaten), and `quantity: qty`. Both screens call it. The row then reads "2 × 1 serving · …" through `portionLabel`, and reopening shows Quantity 2 over the base.
2. **`MealItemsEditor` has no production caller.** `grep -rn MealItemsEditor lib` finds only its file and a doc-comment mention in `meal_component_editor.dart:11`; only `test/features/meal_logging/meal_items_editor_scaling_test.dart` constructs it. Per Lee's orphan rule (08-010: move to `_archived`, never delete), move `lib/features/meal_logging/presentation/widgets/meal_items_editor.dart` to `lib/features/meal_logging/presentation/widgets/_archived/` and its test to `test/features/meal_logging/_archived/` (excluded from the suite as the other `_archived` tests are; check `docs/test/README.md` for how `_archived` is skipped, and mirror it). Fix the doc comment at `meal_component_editor.dart:11` and `portion_quantity.dart:5-8`, which describe the folding. `replaceLeadingQuantity` in `portion_quantity.dart` keeps its other callers (`food_display_utils.dart`, nutrition-plan screens): leave it.
3. **`MealAnalysisItem` is untouched**: with `MealItemsEditor` archived, nothing folds a quantity into an analysis item, and fresh analysis items are quantity 1 by construction (`edit_meal_log_screen.dart:333`).

**Findings:** none (wave 2 question l; follow-on of 02-005).

**Decisions:**
- One helper for the swap mapping; the two screens stop carrying their own copies.
- Archive, not fix, for a widget no screen mounts (Lee's 08-010 ruling on orphans).

**Touches:** lib/features/meal_logging/presentation/screens/meal_review_screen.dart, lib/features/meal_logging/presentation/screens/edit_meal_log_screen.dart, lib/features/meal_logging/domain/meal_swap.dart (new helper), lib/features/meal_logging/presentation/widgets/meal_items_editor.dart (moved to `_archived/`), lib/features/meal_logging/presentation/widgets/meal_component_editor.dart (doc comment only), lib/features/meal_logging/domain/portion_quantity.dart (doc comment only), test/features/meal_logging/meal_items_editor_scaling_test.dart (moved to `_archived/`), test/features/meal_logging/meal_swap_test.dart (new). 8 files. No generated files.

**Overlaps:** none in wave 4 (24 is merged; 31 is a retest ticket).

No edge-function or schema change. Nothing to deploy.

**Fix notes (wave 4, 779431cb).** The archive paths follow the repo's convention rather than the paths in item 2: the widget went to `lib/features/_archived/meal_logging/presentation/widgets/meal_items_editor.dart` and its test to `_archived/test/features/meal_logging/meal_items_editor_scaling_test.dart`. A `*_test.dart` under `test/**/_archived/` would still be collected by `flutter test` (CI runs it with no path argument), while `lib/features/_archived/**` and `_archived/**` are the two trees `analysis_options.yaml` excludes and `docs/test/README.md` names as archived. Stale comments that still name `MealItemsEditor` remain in `test/seeded_tests/events_meal_logging_content_test.dart:557-605` (outside this ticket's Touches).

- [x] Unit (`meal_swap_test.dart`): a food with `servingUnit: 'cup'`, 150 kcal per serving, swapped at qty 2 → `portion == '1 cup'`, `quantity == 2`, `calories == 300`, `portionLabel == '2 × 1 cup'`; at qty 1 → `portionLabel == '1 cup'`; a food with no `servingUnit` → `'1 serving'`.
- [x] Both screens use the helper (a grep in the test's comment is not a test: a widget test on the Review screen's swap sheet asserting the row text "2 × 1 cup" is the seam; `test/smoke_tests/food_smoke_test.dart` renders the swap screen and shows how to pump it).
- [x] The archived test is not collected by `flutter test` (confirm with `flutter test test/features/meal_logging`).
- [x] `flutter analyze` clean on touched files.
- [ ] Retest on a simulator (ticket 31, next test wave): swap an item to quantity 2, reopen it, Quantity shows 2 over the base.

Next: /testing-wave develop-2026-10 (fix wave 4)
