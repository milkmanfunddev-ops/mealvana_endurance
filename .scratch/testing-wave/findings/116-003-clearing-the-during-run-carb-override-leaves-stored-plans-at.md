# 116-003 · Clearing the during-run carb override leaves stored plans at the old rate and drops the info icon, so 92 g reads below its band with no reason

- kind: bug
- status: triaged
- ticket: 116
- run: w32-20260925T2220Z
- screen: Activity detail (12 mi Run, fuelling plan)
- decision: 

**Steps.**
1. test@test.com, `nutrition_target_overrides` = {"during": {"carbRateGPerH": 50.4}}. Timeline, Mon 21 Sep, open "12 mi Run" (activity 933edc6f). DURING reads 92 g in pink with an info icon; the icon's sheet says "Your override: 50g/hr · Calculated target: 91g for this activity · Recommended range: 97–126g".
2. Settings > Nutrition Targets: clear During Run and During Bike carbs (both showed 50.4 from the legacy `during` key), Save Changes (22:31:59Z). DB: overrides = null.
3. Reopen 12 mi Run (22:32:25Z).
Retest of 30-003 with the override cleared, as the ticket's setup asks.

**Expected.**
Either the stored plan is re-planned without the override (63 g/h, 113 g, inside 97–126 g, as a fresh plan on a new account showed at 23:00Z), or the screen keeps saying why the stored target sits below the band.

**Actual.**
The stored plan is unchanged (`duringRun.carbRateGPerH` 50.4, `carbTotalG` 91), no activity was flagged `needs_nutrition_refresh`, and the screen still shows 92 g in pink left of the 97–126 band. The info icon is gone, so nothing on screen explains why the figure sits below the band. The athlete who removed the override sees a plan that contradicts both their settings and the band. (For contrast, a fresh 12 mi Run planned on a new account with no override, gut HIGH, stored 63 g/h and 113 g inside 97.2–126: runs/116/db-acct2-12mi-run-during.json.) Related open question mp-680 (how the band should read while an override is set); this Finding is about the override's removal.

**Evidence.**
- runs/116/11-12mi-run-override-during.png (before: 92 g with info icon)
- runs/116/12-during-carbs-info.png (the icon's sheet)
- runs/116/20-12mi-run-override-cleared.png (after clearing: 92 g, no icon)
- runs/116/db-overrides-0-before.json
- runs/116/db-overrides-1-after-clear.json
- runs/116/db-12mi-run-plan-0921.json (stored plan, read 22:28:41Z)
- runs/116/db-acct2-12mi-run-during.json (fresh plan without override)

**Decision quote.**
> 

**Triage.**

Fix ticket 137, Timeline and activities (Lee, 2026-09-26). Closed by the retest after it merges. Record: `triage-20260926.md`.
