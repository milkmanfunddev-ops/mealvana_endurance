# 29-001 · Three of the four meals in the confirmed plan show no kcal or macros: 31 active library meals have null nutrition and the plan picked three

- kind: bug
- status: closed
- ticket: 29
- run: w16-20260924T2100Z
- screen: Food > Plan
- decision: 

**Steps.**
1. Cold start the dev app (data cleared), log in as test@test.com.
2. Open Food; it lands on Plan with the confirmed plan be6abf2f (Sep 20 – Sep 26 · 4 meals).
3. Read each meal card; then `SELECT` plan_meals for be6abf2f and meal_library for their ids.

**Expected.**
Every meal in a confirmed plan carries its kcal and C/P/F chips, as the first card does, so the athlete can see what the week's dinners give. A meal with no nutrition should not be picked for a plan, or the card should say the numbers are missing (`null` is not `0`).

**Actual.**
Only "Wholewheat pasta, mixed veg & avocado" (AD-014) shows 520 kcal · 75g C · 15g P · 18g F. The other three dinners, "Farro, chickpea & roasted cauliflower bowl with tahini" (AD-103), "Spelt, lentil & raw pepper-carrot bowl with balsamic" (AD-108) and "Farro, white bean & roasted beet bowl with pesto" (AD-113), show only the Dinner tag and ×1, no numbers and no word that they are missing. The screen matches the data: plan_meals has kcal, carbs_g, protein_g and fat_g null for those three rows, and so does meal_library for AD-103, AD-108 and AD-113 (all Greenletes "plant-based bowl formula" assemblies). 31 of the 1,922 active library meals have null kcal, and Vana's plan picked three of them for this week's four dinners. The Meals tab shows the same three under Recents with no numbers either. Run 16's db extracts had the same null rows but filed nothing. Whatever sums the plan's day or week totals would count these three as nothing.

**Evidence.**
- runs/29/07-food-tab.png (Plan tab, first card with chips, three without)
- runs/29/db-plan-be6abf2f-meals.txt (plan_meals: kcal/macros null on positions 1-3)
- runs/29/db-meal-library-ad.txt (meal_library AD-014/103/108/113; 31 of 1,922 active meals with null kcal)
- runs/29/08-food-meals.png (Recents cards for the same meals)

**Decision quote.**
> 

**Triage.**

Fix ticket 61 (Lee, 2026-09-25). Closed by the retest after it merges.

Closed by retest ticket 88 (run w29-20260925T1949Z, build e3367d2c): pass, evidence in runs/88/verdicts.md.
