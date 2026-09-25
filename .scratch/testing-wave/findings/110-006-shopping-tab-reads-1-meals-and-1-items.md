# 110-006 · Shopping tab reads 1 meals and 1 items

- kind: bug
- status: open
- ticket: 110
- run: w30-20260925T2103Z
- screen: Food (Shopping sub-tab)
- decision: 

**Steps.**
1. Open Food > Shopping on test@test.com's confirmed plan (one meal).
2. Make a hand-made list and add one item.

**Expected.**
"1 meal", "1 item" (16-004 fixed the same plural on the Review plan sheet).

**Actual.**
"Totals for 4 servings · 1 meals" under the plan's list, and "1 items" on a list with one row.

**Evidence.**
- runs/110/06-shopping-5s.png — 1 meals.
- runs/110/51-after-add-figs.png — 1 items.

**Decision quote.**
> 

**Triage.**

