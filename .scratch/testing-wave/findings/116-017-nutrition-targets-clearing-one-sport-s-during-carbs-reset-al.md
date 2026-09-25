# 116-017 · Nutrition Targets: clearing one sport's during carbs, Reset All to Defaults, and whether saved overrides re-plan future stored sessions

- kind: followup-test
- status: open
- ticket: 116
- run: w32-20260925T2220Z
- screen: Nutrition Targets (Settings)
- decision: 

**Steps.**
1. With a during override on run and bike, clear only During Run carbs and Save: check the bike value survives and the run value is gone in `users.nutrition_target_overrides`.
2. Reset All to Defaults: check the DB holds null and every field reads Auto.
3. Change the during-run carbs, then open a FUTURE session that already has a stored plan: check whether it is re-planned, and what its DURING line and info icon say.
Look-around from this run: the screen shows a legacy `during` override in both Run and Bike fields, and saving writes `duringRun`/`duringCycling` instead (restoring 50.4 g/h on test@test.com left `{"duringRun":{"carbRateGPerH":50.4},"duringCycling":{"carbRateGPerH":50.4}}` where `{"during":{"carbRateGPerH":50.4}}` was).

**Expected.**
Each save writes exactly what the fields show, and stored plans follow the athlete's current setting or say they do not.

**Actual.**


**Evidence.**
- runs/116/db-overrides-0-before.json
- runs/116/db-overrides-2-after-restore.json
- runs/116/17-nutrition-targets-before.png

**Decision quote.**
> 

**Triage.**

