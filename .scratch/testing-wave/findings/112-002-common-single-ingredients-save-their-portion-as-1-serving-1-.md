# 112-002 · Common single ingredients save their portion as "1 serving" / "1.5 servings", losing the unit ("1 large")

- kind: bug
- status: triaged
- ticket: 112
- run: w34-20260925T2320Z
- screen: Log a Meal (Common) → quick log sheet
- decision: 

**Steps.**
1. Retest of follow-up 26-007. Log a Meal → Common, drag below Quick add to the single ingredients.
2. Tap "Egg" (tile: 1 large · 72 kcal). Log it at 1 serving (23:27:49Z), then again at 1.5 servings (23:27:55Z).
3. Read the two rows' `items`.

**Expected.**
The item's portion still says what was eaten: "1 large" and "1.5 large" (or "1.5 × 1 large"), as the Recent re-log path already does (`scaleComponentForRelog`).

**Actual.**
Rows 83f837b4 and f29ae721: totals and sodium scale correctly (72 → 108 kcal, 71 → 106.5 mg), but `portion` is "1 serving" and "1.5 servings". `_scale` in log_meal_screen.dart replaces the portion with a serving count, so the log and any later edit no longer say an egg is one large egg. Search results ("Eggs", efdbe6cf) save "1 serving" the same way.

**Evidence.**
- runs/112/24-common-ingredients.png
- runs/112/26-common-egg-1.5-sheet.png
- runs/112/db-run-rows.txt (rows 83f837b4, f29ae721, efdbe6cf)

**Decision quote.**
> 

**Triage.**

Fix ticket 135, Meal upload and quick logging (Lee, 2026-09-26). Closed by the retest after it merges. Record: `triage-20260926.md`.
