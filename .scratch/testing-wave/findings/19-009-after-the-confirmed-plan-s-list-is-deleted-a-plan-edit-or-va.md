# 19-009 · After the confirmed plan's list is deleted, a plan edit or Vana Add back should rebuild it (mp-244)

- kind: followup-test
- status: triaged
- ticket: 19
- run: w11-20260924T1647Z
- screen: Food (Shopping sub-tab)
- decision: 

**Steps.**
Start from the state this run left (be6abf2f confirmed, no list, mirror []):
1. Edit the plan (swap a meal or change servings) and open Shopping.
2. Ask Vana to add back an item, if that path exists without a list.
3. Shop with Kroger and Share with no plan list.
4. Cold relaunch and go offline: what the offline copy shows with an empty mirror.
Check shopping_lists, shopping_items and meal_plans.shopping by SQL after each.

**Expected.**
mp-244: "the list is rebuilt after every plan edit", so the first edit brings back one list for be6abf2f with the plan's rows, and the tab shows it instead of the archived draft's list (19-001).

**Actual.**


**Evidence.**
- runs/19/db-05-final.txt: the state left for this test.

**Decision quote.**
> 

**Triage.**

Picked for retest ticket 89 (Lee, 2026-09-25).
