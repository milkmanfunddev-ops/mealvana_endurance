# 113-004 · A manual log with no macros shows 0 kcal, 0C, 0P, 0F on the timeline although every value is unknown (null)

- kind: bug
- status: open
- ticket: 113
- run: w40-20260926T1051Z
- screen: Timeline (Meals); Build a Meal
- decision: 

**Steps.**
1. Follow-up 25-002 ("a name but no macros at all"). Log a Meal → Manual → name "W40-113 No macros", every number empty → Save (10:58:01Z).
2. Timeline → Meals.
3. Also: Build a Meal after entering barcode 4006381333931 (an Open Food Facts product with no nutrition data).

**Expected.**
The row saves with calories, carbs, protein and fat null (it does), and the app shows them as unknown ("—" or no figure), not 0 (null ≠ 0; fix 41 kept missing sodium null for the same reason).

**Actual.**
The row is saved with all four null (db-after-manual.txt), and the timeline shows "0 kcal · 0C · 0P · 0F". Build a Meal shows the no-data product as "0 kcal C 0g P 0g F 0g" in the total, although the scanner's own Log Food page shows "—" for the same product.

**Evidence.**
- runs/113/27-after-back-half-entry.png (timeline row "0 kcal · 0C · 0P · 0F")
- runs/113/db-after-manual.txt (row eb8c7ab8, all macros null)
- runs/113/12-enter-notfound-result.png (Log Food shows "—")
- runs/113/33-build-after-barcode.png (Build a Meal total 0 kcal for the same product)

**Decision quote.**
> 

**Triage.**
