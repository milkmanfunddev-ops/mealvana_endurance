# 23-002 · The AI's note shown on Review & Log is dropped at save: meal_logs.notes stays null and Edit Meal never shows it

- kind: idea
- status: open
- ticket: 23
- run: w13-20260924T1903Z
- screen: Review & Log
- decision: 

**Steps.**
Idea: keep the AI's note with the logged meal (in meal_logs.notes or a separate field) and show it on Edit Meal, so the athlete can later see what the estimate assumed ("Butter estimated at 1 tsp").

**Expected.**
The note that Review & Log showed ("Standard breakfast-style lunch. Butter estimated at 1 tsp. Eggs cooked with a small amount of butter or oil included in calorie count.") is kept with the meal.

**Actual.**
Row 38c4f0ed-e7d2-453c-9b8e-a19614dbe522 has notes = null. Edit Meal for that meal shows name, type, time, items and total, and no note. The assumptions behind the numbers are lost once the athlete taps Log this meal. This may be intended: meal_logs.notes may be meant for the athlete's own note only.

**Evidence.**
- runs/23/10-review-bottom.png: the note on Review & Log.
- runs/23/db-meal-logs-after.txt: notes null.
- runs/23/14-edit-food.png: Edit Meal with no note.

**Triage.**
