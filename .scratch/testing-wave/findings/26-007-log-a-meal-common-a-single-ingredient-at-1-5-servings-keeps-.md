# 26-007 · Log a Meal Common: a single ingredient at 1.5 servings keeps its portion and sodium

- kind: followup-test
- status: triaged
- ticket: 26
- run: w13-20260924T1904Z
- screen: Log a Meal (Common)
- decision: 

**Steps.**
1. Log a Meal → Common, scroll below Quick add to the single ingredients (slow drag).
2. Log "Egg" (1 large, 72 kcal, 0.4 C, 6.3 P, 5.0 F, 71 mg Na) at 1 serving, then at 1.5 servings.
3. Log a Quick add combo twice in a row, and one with a meal type set.
4. Search "egg" in the top search bar and log from the results.

**Expected.**
Rows equal the ingredient scaled by servings. The item's portion still says what a serving is: reading the code, `_scale` replaces "1 large" with "1 serving"/"1.5 servings", so the saved row may lose the unit; check it. Sodium scales (71 → 106.5).

**Actual.**


**Evidence.**
- runs/26/12-common-tab.png

**Decision quote.**
> 

**Triage.**

Picked for retest ticket 91 (Lee, 2026-09-25: every open follow-up test folded into the planned runs, cap of ten lifted for this pass).
