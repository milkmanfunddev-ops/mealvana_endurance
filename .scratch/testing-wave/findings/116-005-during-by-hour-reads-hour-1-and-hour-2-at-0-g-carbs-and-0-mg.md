# 116-005 · DURING By Hour reads Hour 1 and Hour 2 at 0 g carbs and 0 mg sodium while the sip-throughout drink carries 67 g across both hours

- kind: bug
- status: open
- ticket: 116
- run: w32-20260925T2220Z
- screen: Activity detail (DURING, By Hour)
- decision: 

**Steps.**
1. test@test.com, Mon 21 Sep "12 mi Run", DURING > By Hour.
Follow-up 30-008 step 1.

**Expected.**
Each hour's line shows what the athlete takes in that hour, sip-throughout items spread across the hours (the stored plan carries 50.4 g/h and 595 mg/h).

**Actual.**
SIP THROUGHOUT lists 4.5 cups Sports Drink (67 g), 1 cup Water and 3 Electrolyte Capsules; UNASSIGNED holds 1 Energy Gel; then "Hour 1 0g carbs · 0mg sodium" and "Hour 2 0g carbs · 0mg sodium". The stored `byHourData` has the three sip items at hourIndex -1 and no hour assignments. The per-hour rows read as if nothing is taken in either hour, against a Summary of 92 g and 1,075 mg.

**Evidence.**
- runs/116/13-during-by-hour.png
- runs/116/14-12mi-by-hour-after.png
- runs/116/db-12mi-run-plan-0921.json (sections[during_run].byHourData)

**Decision quote.**
> 

**Triage.**

