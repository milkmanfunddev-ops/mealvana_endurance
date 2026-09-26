# 112-004 · Scaled quick logs store float noise in meal_logs (protein_g 60.449999999999996, carbs_g 0.6000000000000001)

- kind: bug
- status: triaged
- ticket: 112
- run: w34-20260925T2320Z
- screen: Log a Meal (Recent, Common) → quick log sheet
- decision: 

**Steps.**
1. Recent → "W14-25 Built bowl" at 1.5 servings → Log it (row 5c0c96f4).
2. Common → "Egg" at 1.5 servings → Log it (row f29ae721).
3. Read the numeric columns and items.

**Expected.**
Stored macros are rounded like every other row (one decimal, e.g. 60.4 / 0.6), since the columns are shown and summed.

**Actual.**
5c0c96f4: `protein_g` "60.449999999999996", `fat_g` "6.8999999999999995", item fat_g 0.8999999999999999, protein_g 7.949999999999999. f29ae721: `carbs_g` "0.6000000000000001". The app shows rounded values, so nothing looks wrong on screen, but the server rows (and anything reading them: coach views, exports, Vana) carry the noise.

**Evidence.**
- runs/112/db-run-rows.txt (rows 5c0c96f4, f29ae721)

**Decision quote.**
> 

**Triage.**

Fix ticket 135, Meal upload and quick logging (Lee, 2026-09-26). Closed by the retest after it merges. Record: `triage-20260926.md`.
