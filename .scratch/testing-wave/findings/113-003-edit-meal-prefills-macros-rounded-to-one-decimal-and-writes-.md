# 113-003 · Edit Meal prefills macros rounded to one decimal and writes them back on any save: protein 12.25 becomes 12.3 though it was not touched

- kind: bug
- status: triaged
- ticket: 113
- run: w40-20260926T1051Z
- screen: Edit Meal
- decision: 

**Steps.**
1. Retest of 27-002 on "W40-113 Decimal kcal" (logged with protein 12.25, row c3bc3639).
2. Timeline → ⋯ → Edit food. The Protein field reads "12.3". Change only Carbs 30.2 → 31, Back → Save (11:09:25Z).
3. Same on the old row a61f94fd (protein 12.25): Edit food, change only Calories, Save changes (11:21:09Z).
4. SELECT protein_g.

**Expected.**
Fields the athlete did not touch keep their saved values (12.25).

**Actual.**
protein_g is 12.3 on both rows after the save. Edit Meal shows each macro rounded to one decimal and saves the shown text back, so any edit silently rounds every other macro (two-decimal values from the Manual tab, scaled items, the float noise of 112-004). Small in grams, but it rewrites data the athlete never changed.

**Evidence.**
- runs/113/60-edit-meal-decimal.png (Protein "12.3" on open)
- runs/113/db-after-manual.txt (protein_g 12.25 as logged)
- runs/113/db-after-edit.txt (protein_g 12.3 after changing carbs only)
- runs/113/db-old-row-correct.txt (old row 12.25 → 12.3)

**Decision quote.**
> 

**Triage.**

Fix ticket 136, Build a Meal, saved meals, Manual and Edit (Lee, 2026-09-26). Closed by the retest after it merges. Record: `triage-20260926.md`.
