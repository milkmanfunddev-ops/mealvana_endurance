# 26-006 · Log a Meal Recent: a Saved meals row, its trash icon, servings above 1 and a double tap on Log it

- kind: followup-test
- status: triaged
- ticket: 26
- run: w13-20260924T1904Z
- screen: Log a Meal (Recent)
- decision: 

**Steps.**
1. Tap the Saved meals row "Egg & Veggie Scramble" (saved-meal path, `logSavedMeal`, no servings stepper) and log it.
2. Re-log a Recent meal at 2 and at 1.5 servings.
3. Tap the red trash icon on a saved meal (on a throwaway saved meal made for the test, not an existing one).
4. Tap Log it twice quickly on one quick log sheet.
5. Pick a Recent row that was logged with Describe (the source has AI-made items) and re-log it.

**Expected.**
1: row with source saved, saved_meal_id set, the saved meal's items and totals, last_used bumped. 2: totals scale exactly (×2, ×1.5) and the item portion says so. 3: asks before deleting, or offers undo; the saved meal row gets is_deleted on the server. 4: one row, not two. 5: no AI call; totals equal the source.

**Actual.**


**Evidence.**
- runs/26/08-recent-after-food-tab.png

**Decision quote.**
> 

**Triage.**

Picked for retest ticket 91 (Lee, 2026-09-25: every open follow-up test folded into the planned runs, cap of ten lifted for this pass).
