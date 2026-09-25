# 112-014 · Quick-add combos carry no sodium while the same single ingredients do, so any combo leaves the day's sodium unknown

- kind: idea
- status: open
- ticket: 112
- run: w34-20260925T2320Z
- screen: Log a Meal (Common)
- decision: 

**Steps.**
1. "Eggs + toast" (6ff23915) saves Eggs 2 large with no sodium_mg; the single "Egg" ingredient has 71 mg. With fix 41 the row's sodium is now null (correct), so one combo makes the day's sodium total unknown. Idea: fill sodium on the `kQuickAssemblies` items from the matching single ingredients.

**Expected.**
Triage decides.

**Actual.**


**Evidence.**
- runs/112/db-run-rows.txt (rows 6ff23915, 83f837b4)

**Decision quote.**
> 

**Triage.**
