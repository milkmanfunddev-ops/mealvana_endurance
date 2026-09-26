# 113-009 · meal_saved_as_favorite analytics from Build a Meal carries an empty log_id

- kind: bug
- status: triaged
- ticket: 113
- run: w40-20260926T1051Z
- screen: Build a Meal
- decision: 

**Steps.**
1. Follow-up 25-003 ("Also save as a favorite"). Build a meal "W40-113 Built bowl" (4 items), tick Also save as a favorite, Log meal (11:06:12Z).
2. Read the console's [ANALYTICS] lines.

**Expected.**
`meal_saved_as_favorite` names the meal log it came from (the new row d51be206), as it does when saving a favorite from a logged meal.

**Actual.**
`meal_saved_as_favorite {log_id: , custom_name: false}`: the id is empty, because `DraftMealController.save` builds a throwaway `MealLog(id: '')` to call `saveLogAsFavorite`. Also still true in this run (re-checked, not re-filed): 112-007, the favorite saved_meals row 85f10c75 has calories and every macro null although it has 4 items; and the log row's saved_meal_id stays null (the log is not linked to the favorite it made).

**Evidence.**
- runs/113/console-redacted.log (meal_logged and meal_saved_as_favorite at 06:06:12-13 local)
- runs/113/db-after-build.txt (log d51be206 saved_meal_id null; saved_meals 85f10c75 totals null)

**Decision quote.**
> 

**Triage.**

Fix ticket 136, Build a Meal, saved meals, Manual and Edit (Lee, 2026-09-26). Closed by the retest after it merges. Record: `triage-20260926.md`.
