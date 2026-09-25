# 88-015 · Confirm plan offline does nothing visible: no message, the sheet just stays

- kind: bug
- status: triaged
- ticket: 88
- run: w29-20260925T1949Z
- screen: Review plan sheet
- decision: 

**Steps.**
1. Retest of 09-006 step 3. Draft 8ebeb6da (conversation `449da56d`), Review plan open. Netcut on (20:21:12Z). Tap Confirm plan.
2. Watch 1 s and 5 s; read the week's plans.

**Expected.**
09-006: offline Confirm says so and leaves the draft.

**Actual.**
The draft is left alone (right), but nothing tells the athlete: at 1 s and 5 s the sheet is exactly as before the tap, with no toast or line (the console logs a vana-action network error). Back online, a double tap on Confirm made one confirm_plan call (right).

**Evidence.**
- runs/88/96-09-006-offline-confirm-1s.png, runs/88/97-09-006-offline-confirm-5s.png
- runs/88/db-21-09-006-offline-confirm.txt: 8ebeb6da still draft.
- runs/88/edge-04-confirm.txt: a single confirm_plan at 15:21:43 local.

**Decision quote.**
> 

**Triage.**

Fix ticket 129 (Lee, 2026-09-25). Closed by the retest after it merges.
