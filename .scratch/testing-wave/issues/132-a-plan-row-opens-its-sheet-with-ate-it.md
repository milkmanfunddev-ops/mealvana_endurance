# 132: A Plan tab row opens its sheet, with Ate it

**Status:** in-progress (wave 33, 2026-09-25)
**Blocked by:** 130 (both change `plan_tab.dart`).
**Next:** `/implement-lee testing-wave`
**Model:** opus

**What to build:** Build mp-239's row sheet and Ate it (88-017, ssot-conflict). Today a Plan tab row opens the meal's detail page (`plan_tab.dart:112` pushes `/food/meals/<id>`), the row's ⋮ offers only Swap and Remove, and nothing in the app logs a meal from the plan: `MealPlanController.logFromPlan` and the `log_from_plan` RPC exist but have no caller in presentation.

mp-239 details 2-4: tapping a row opens a sheet with a servings stepper, Swap, Remove and Ate it; swipe right removes with Undo, swipe left swaps; "Ate it" waits for the server, hides when no servings are left, writes a meal log with source plan and takes one serving off. Reuse the chat's meal sheet (`meal_sheet.dart`, `showMealSheet`) rather than a second sheet.

Lee's ruling (2026-09-25): **the sheet keeps a Recipe link** (the meal name or a Recipe button) that opens the meal detail with Start cooking, since the row tap no longer does. Check the swipes against details 2 while there; build what is missing.

**Findings:** 88-017.

**Decisions:** mp-239 (quoted in 88-017).

**Touches:** lib/features/meal_planning/presentation/screens/plan_tab.dart, lib/features/meal_planning/presentation/widgets/plan_list.dart, lib/features/meal_planning/presentation/widgets/plan_tile.dart, lib/features/meal_planning/presentation/widgets/meal_sheet.dart, lib/features/meal_planning/presentation/screens/vana_chat_screen.dart (showMealSheet call sites :966, :1082), lib/features/meal_planning/presentation/widgets/plan_bar.dart (showMealSheet call site :268), lib/features/meal_planning/presentation/screens/previous_plan_screen.dart (uses PlanList), lib/features/meal_planning/application/meal_plan_controller.dart, lib/features/meal_planning/data/meal_plan_repository.dart, lib/features/content/domain/content_keys.dart, assets/config/content_defaults.json

- [ ] Seam test through the real `MealPlanController`: Ate it waits for the server ack, writes a meal log with source plan and the plan meal's id, and drops one serving; a failed ack changes nothing and says so; at zero servings Ate it is hidden.
- [ ] Widget tests: a row tap opens the sheet (not the detail); the Recipe link opens the detail; the earlier plan view's rows behave as its own rules say (check `previous_plan_screen.dart` before changing `PlanList`).
- [ ] No hardcoded strings; `flutter analyze` clean on touched files.

Next: /implement-lee testing-wave
