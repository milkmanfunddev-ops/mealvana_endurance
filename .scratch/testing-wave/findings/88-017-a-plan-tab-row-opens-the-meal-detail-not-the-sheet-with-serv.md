# 88-017 · A Plan tab row opens the meal detail, not the sheet with servings and Ate it; nothing in the app logs a meal from the plan

- kind: ssot-conflict
- status: triaged
- ticket: 88
- run: w29-20260925T1949Z
- screen: Food > Plan
- decision: mp-239

**Steps.**
1. Retest of 03-006 (by hand; no Patrol). Food > Plan with confirmed 8ebeb6da. Tap the Wholewheat pasta row (20:22:53Z); tap its ⋮.
2. Timeline > + Add Food: look for the plan's meals.

**Expected.**
mp-239: tapping a row opens a sheet with a servings stepper, Swap, Remove and Ate it; Ate it waits for the server, writes a meal log with source plan and takes a serving off.

**Actual.**
The row opens the meal's detail page (photo, review, ingredients, directions, Start cooking); the row's ⋮ offers only Swap and Remove. There is no servings stepper and no Ate it anywhere on the Plan tab, and Log a Meal has no plan source (Recent, Common, Recipes, Describe, Manual). In `lib/`, `MealPlanController.logFromPlan` has no caller in presentation. So the 03-006 leg (Ate it -> meal_logs row with plan_meal_id) can't be reached. mp-239 is marked amended; the amendment only drops the row icon.

**Evidence.**
- runs/88/103-03-006-tile-sheet.png: the detail page a row opens.
- runs/88/71-plan-meal-more-menu.png: ⋮ with Swap and Remove.
- runs/88/104-03-006-add-food.png: Log a Meal sources.

**Decision quote.**
> The Plan tab shows a message from Vana, then every plan meal as one row with its name, meal type and servings, and two buttons: Add meal and New meal plan. Tapping a row opens a sheet to change servings, swap, remove or mark it eaten; swiping right removes it with Undo, and swiping left swaps it. A swap keeps the row's identity, so changing servings afterwards changes the right one. Ate it waits for the server, logs the meal and takes one serving off, and nothing reminds the athlete to log each day. Example: a dinner row shows 2 servings; the athlete taps Ate it, the meal is logged from the plan and the row shows 1; after the last serving, Ate it no longer shows.

**Triage.**

Fix ticket 132 (Lee, 2026-09-25): build to mp-239 as approved, plus a Recipe link in the sheet. Closed by the retest after it merges.
