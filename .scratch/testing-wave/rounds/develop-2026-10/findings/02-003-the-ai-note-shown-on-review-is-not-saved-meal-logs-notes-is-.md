# 02-003 · The AI note shown on Review is not saved: meal_logs.notes is null

- kind: bug
- status: triaged
- ticket: 02
- run: w1-20261007T1103Z
- screen: Review & Log
- decision: 

**Steps.**
1. Describe "two scrambled eggs, a slice of whole wheat toast with butter, a banana", Analyze.
2. On Review & Log, read the AI note under the totals ("Scrambled eggs cooked with a small amount of butter or oil; … Confidence is medium as no exact weights or brands were specified.").
3. Log this meal (Breakfast); read the stored row.

**Expected.**
The note the athlete was shown is kept with the meal (`meal_logs.notes`), or the screen does not imply it belongs to the meal.

**Actual.**
`meal_logs.notes` is NULL for row 40600e48-f359-48f6-b59f-d49a5c473bee. `MealReviewScreen._logMeal()` never passes `_result.notes` to `logFromComponents`. Same as mealplanning 23-002, still true on develop-next at ce1a1527.

**Evidence.**
- runs/02/10-review-scrolled.png — the AI note on Review
- runs/02/db-after.txt — notes null on the logged row
- runs/02/notes.md — Review items and note recorded
- Old Finding: mealplanning-2026-09 23-002 (the AI's note shown on Review is dropped at save)

**Decision quote.**
> 

**Triage.**
fix ticket: the AI note is saved to meal_logs.notes (meal-logging ticket with 02-005)
