# 112-006 · A double tap on Log it logs once, then opens the sheet of the tile under the button

- kind: bug
- status: triaged
- ticket: 112
- run: w34-20260925T2320Z
- screen: Log a Meal (Common) → quick log sheet
- decision: 

**Steps.**
1. Retest of follow-up 26-006 step 4. Common → "Banana + peanut butter" → double tap Log it (23:26:35Z).
2. Look at the screen; read meal_logs.

**Expected.**
One row and the sheet closes; the second tap does nothing.

**Actual.**
One row (3d90eedf), as expected. But the second tap passed through to the list and opened a new quick log sheet for "Cottage cheese + fruit", the tile under the button. An athlete who taps twice sees a different meal's sheet and may log it too.

**Evidence.**
- runs/112/22-double-tap-after.png
- runs/112/db-run-rows.txt (row 3d90eedf, no second row)

**Decision quote.**
> 

**Triage.**

Fix ticket 135, Meal upload and quick logging (Lee, 2026-09-26). Closed by the retest after it merges. Record: `triage-20260926.md`.
