# 116-007 · The first open of the 12 mi Run's fuelling screen rewrote activities.updated_at with the plan unchanged; later opens wrote nothing

- kind: followup-test
- status: open
- ticket: 116
- run: w32-20260925T2220Z
- screen: Activity detail (fuelling plan)
- decision: 

**Steps.**
1. Note `activities.updated_at` and `nutrition_plan_data.updatedAt` of a session with a stored plan that has not been opened on this install.
2. Open it and do nothing; SELECT again after 30 s. Then tap the low-carb info icon, dismiss the sheet, tap By Hour, SELECT after each.
Seen in this run: test@test.com's 12 mi Run (933edc6f) moved from 2026-09-21 15:33:27 to 2026-09-25 17:28:29 (local-naive; 22:28:29Z), about 28 s after the first open at 22:28:01Z, between the info-icon tap and the By Hour tap. `detailedMacroTargets.duringRun` was identical before and after. Opens at 22:29:44Z (no taps), 22:30:22Z (By Hour) and 22:30:40Z (info sheet and dismiss) wrote nothing, so the first write was not reproduced. No console line names it.

**Expected.**
Opening and reading the fuelling screen writes nothing; if it writes on a first open (a migration, a pin decision), the write is intended and named.

**Actual.**


**Evidence.**
- runs/116/db-12mi-run-during-before.json (updated_at before)
- runs/116/db-12mi-run-plan-0921.json (after, updatedAt 17:28:29)
- runs/116/notes.md (Activity fuelling section)

**Decision quote.**
> 

**Triage.**

