# 127: Plan edits reach the shopping list and the Review sheet

**Status:** done (wave 31, 2026-09-25)
**Blocked by:** none.
**Next:** `/implement-lee testing-wave`
**Model:** opus

**What to build:** Four fixes where a plan edit leaves something else stale, from wave 29.
1. **Servings and Remove rebuild the list (88-003, ssot-conflict mp-244).** mp-244: "the list is rebuilt after every plan edit". The stepper and Remove are local-first writes replayed through the `plan_set_servings` / `plan_remove_meal` RPCs, which touch `plan_meals` only; the list is built in TypeScript (`plan.ts refreshShopping` → `shopping.ts syncPlanList` → `ensurePlanList`), so the SQL RPCs cannot rebuild it. Every caller goes through `MealPlanController.setServings/removeMeal`. Keep the local-first write (offline-first rule) and, once `uploadDirtyRecords` has replayed the edits, run the rebuild for each plan it touched (`RebuildShoppingListAction`, or `vana-action`'s `set_servings` / `remove_meal`, which already end in `refreshShopping`). Check the upload result; never assume success. A confirmed plan's list must be right after the replay, not only at the next confirm.
2. **Review sheet and plan bar drop a removed meal at once (88-004).** `_ReviewSheet` renders the `widget.plan` it opened with; its `onServings` / `onRemove` (`vana_chat_screen.dart` ~1082-1092) and `_swapPicked`'s meal sheet call the plan controller without `_controller.applyDraftPlan(...)`, which the plan bar's own handlers do. The sheet reads the live plan, and the counts and bar update at once. Also find why reopening the conversation in the same session still showed 3 meals (unreplayed removal read back by `get_plan`?), and fix that too. Confirm then confirms exactly what the sheet shows.
3. **An edit-rebuilt list is confirmed like a Rebuild (89-004).** `refreshShopping` → `syncPlanList` → `ensurePlanList` never calls `markListConfirmedIfUnset`; only `rebuildShoppingList` does (`plan.ts:192`). A confirmed (or once-confirmed) plan's list gets `confirmed_at` on every path. Backfill existing lists of confirmed plans whose `confirmed_at` is null in migration `20260925172700_plan_lists_confirmed_at_backfill.sql`.
4. **Delete plan takes its list (88-019).** The dialog says "The meals and shopping list for this week go with it", but `writes.ts deletePlan` only flags the plan, and Previous lists keeps "Week of Sep 20 · From plan". Undo only clears the flag, so hide lists whose plan is deleted in `orderedRows` / `listLists` / `getList` (Undo then brings the list back with the plan), or delete the list and rebuild it on Undo. Either way the Shopping tab and Previous lists never show a deleted plan's list.

**Findings:** 88-003, 88-004, 89-004, 88-019.

**Decisions:** mp-244 (quoted in 88-003).

**Touches:** lib/features/meal_planning/application/meal_plan_controller.dart, lib/features/meal_planning/data/meal_plan_repository.dart, lib/features/meal_planning/presentation/widgets/review_sheet.dart, lib/features/meal_planning/presentation/screens/vana_chat_screen.dart, lib/features/meal_planning/application/vana_chat_controller.dart, supabase/functions/_shared/vana/plan.ts, supabase/functions/_shared/vana/shopping.ts, supabase/functions/_shared/vana/writes.ts, supabase/migrations/20260925172700_plan_lists_confirmed_at_backfill.sql

- [x] Seam test through the real `MealPlanController`: a servings change and a remove on a confirmed plan end with a rebuild request for that plan after the upload; a failed upload requests none and says so.
- [x] Widget test: Remove in the Review sheet drops the meal and the counts at once, and the plan bar shows the new count.
- [x] Deno tests: an edit on a confirmed plan leaves its list with `confirmed_at`; a deleted plan's list is absent from `listLists` and `getList`, and back after Undo.
- [x] `flutter analyze` clean on touched files; deno vana tests. Deploy (migration, then vana-action and the functions sharing `_shared/vana`): wave lead.

Next: /implement-lee testing-wave
