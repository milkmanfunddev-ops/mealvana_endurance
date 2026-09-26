# 112-007 · Build a meal's "Also save as a favorite" saves the favorite with no totals; its quick log sheet then says 0 kcal

- kind: bug
- status: triaged
- ticket: 112
- run: w34-20260925T2320Z
- screen: Build a Meal; Log a Meal (Recent → Saved meals)
- decision: 

**Steps.**
1. Build a meal → + Add food → Manual: "E2E 112 throwaway", 1 piece, 100 kcal, 10 g carbs → Add to meal.
2. Meal name "E2E 112 throwaway", tick "Also save as a favorite", Log meal (23:45:28Z).
3. Read saved_meals; open Log a Meal → Recent → tap the new Saved row.

**Expected.**
The saved meal carries the meal's totals (100 kcal, 10 g carbs) like the other favorites, and its row and sheet show them.

**Actual.**
saved_meals 85c22213 has `calories`, `carbs_g`, `protein_g`, `fat_g`, `sodium_mg` all null; only `items` holds the 100 kcal. The Saved row shows no numbers at all, and the quick log sheet previews "0 kcal · C 0g P 0g F 0g" (the sheet maps null to 0). Logging it anyway wrote 100 kcal (c2a54ff4), so the sheet's preview contradicts what gets saved. `DraftMealController.save` builds a temporary MealLog without totals and hands it to `saveLogAsFavorite`.

**Evidence.**
- runs/112/73-recent-saved-with-throwaway.png
- runs/112/74-throwaway-saved-sheet.png
- runs/112/db-run-rows.txt (saved_meals 85c22213, meal_logs c2a54ff4)

**Decision quote.**
> 

**Triage.**

Fix ticket 136, Build a Meal, saved meals, Manual and Edit (Lee, 2026-09-26). Closed by the retest after it merges. Record: `triage-20260926.md`.
