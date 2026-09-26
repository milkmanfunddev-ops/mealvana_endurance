# 112-003 · Recent re-log at 2 servings writes "2/2 cup dry"; at 1.5 writes "6 oz cooked (115 g)"

- kind: bug
- status: triaged
- ticket: 112
- run: w34-20260925T2320Z
- screen: Log a Meal (Recent) → quick log sheet
- decision: 

**Steps.**
1. Log a Meal → Recent → "Oatmeal + raisins" (items "1/2 cup dry", "2 tbsp") → servings 2 → Log it (23:24:41Z).
2. Recent → "W14-25 Built bowl" (items "4 oz cooked (115 g)", "1.25 cup") → servings 1.5 → Log it (23:25:06Z).
3. Read the new rows' items.

**Expected.**
Portions scale readably: "1 cup dry" and "4 tbsp"; "6 oz cooked (172 g)" and "1.875 cup" (or "1.5 × …").

**Actual.**
Row 5543d340: "2/2 cup dry" (only the numerator was scaled) and "4 tbsp". Row 5c0c96f4: "6 oz cooked (115 g)" (the grams in brackets not scaled) and "1.875 cup". Totals scale exactly in both (408 kcal; 675 kcal, sodium 130.5). `scaleComponentForRelog` → `parseLeadingQuantity` reads only the first integer.

**Evidence.**
- runs/112/16-recent-oatmeal-2x-sheet.png
- runs/112/17-recent-builtbowl-1.5-sheet.png
- runs/112/db-run-rows.txt (rows 5543d340, 5c0c96f4)

**Decision quote.**
> 

**Triage.**

Fix ticket 135, Meal upload and quick logging (Lee, 2026-09-26). Closed by the retest after it merges. Record: `triage-20260926.md`.
