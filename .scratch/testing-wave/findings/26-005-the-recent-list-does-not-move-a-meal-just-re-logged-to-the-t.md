# 26-005 · The Recent list does not move a meal just re-logged to the top until Log a Meal is reopened

- kind: bug
- status: closed
- ticket: 26
- run: w13-20260924T1904Z
- screen: Log a Meal (Recent)
- decision: 

**Steps.**
1. Log a Meal → Recent. Order: Patrol Build 1790210919365, Patrol Build 1790210521428, Rice cake and Almond butter, Oatmeal with Blueberries, ...
2. Tap "Rice cake and Almond butter" → Log it. "Meal logged!" shows (19:08:37Z).
3. Look at Recent again after a few seconds; later leave Log a Meal and open it again → Recent.

**Expected.**
Recent is newest first, so the meal just logged moves to the top right away.

**Actual.**
After the save and again about 6 s later, Recent still showed the old order with Rice cake third (11-recent-after-log.png). Only after leaving and reopening Log a Meal did the list read Cottage Cheese & Pineapple Bowl, Rolled oats and Raisins, Rice cake and Almond butter, Patrol Build... (21-recent-reopened.png). The save did land (row 00a120e5). Note from the code: `logRecipe` also does not invalidate `recentMealsProvider`, unlike `logFromComponents`.

**Evidence.**
- runs/26/08-recent-after-food-tab.png
- runs/26/11-recent-after-log.png
- runs/26/21-recent-reopened.png

**Decision quote.**
> 

**Triage.**
Fix ticket 54 (Lee, 2026-09-25). Closed by the retest after it merges.
Moved to retest ticket 112 when 91 was split (Lee, 2026-09-25).

Run by retest ticket 112 (run w34-20260925T2320Z, build e3367d2c): pass.
