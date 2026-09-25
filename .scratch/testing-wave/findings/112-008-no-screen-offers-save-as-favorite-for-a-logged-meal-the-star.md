# 112-008 · No screen offers "save as favorite" for a logged meal: the star row (MealLogRow) is not mounted anywhere

- kind: bug
- status: open
- ticket: 112
- run: w34-20260925T2320Z
- screen: Timeline
- decision: 

**Steps.**
1. Timeline → a logged meal's ⋯ (Greek yogurt + honey, 23:43:44Z).
2. Edit food → look for a favorite action.
3. Code: grep for `TodayLogSection` / `MealLogRow` use.

**Expected.**
The one-tap star ("item 23") on a logged meal saves it as a favorite, as the wave-34 prompt and 26-006 assumed.

**Actual.**
⋯ offers only Edit food and Remove; Edit Meal has no favorite action. `MealLogRow` (the star, meal_log_row.dart:128-161) is used only by `TodayLogSection`, and nothing mounts `TodayLogSection`. The only way left to make a favorite is Build a meal's "Also save as a favorite" before logging. An athlete cannot favorite a meal after eating it. Product question for triage: was the star dropped on purpose?

**Evidence.**
- runs/112/62-timeline-row-menu.png
- runs/112/63-edit-food.png

**Decision quote.**
> 

**Triage.**
