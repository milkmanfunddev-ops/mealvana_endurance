# 50-014 · Follow-up: Connected Apps untried paths (Turn Off Sharing, Runna, TP sheet Cancel, reconnect with a future workout, Delete synced data on a disposable account)

- kind: followup-test
- status: closed
- ticket: 50
- run: w5-20261008T1720Z
- screen: Connected Apps
- decision: 

**Steps.**
1. TrainingPeaks write-back sheet → Turn Off Sharing, then the "Write fuel plan to TrainingPeaks" toggle back on.
2. Runna Connect (calendar URL) and Cancel.
3. TrainingPeaks sheet's X (cancel) mid sign-in: is it an `error_reported` like V.O2's Cancel (50-007)?
4. Disconnect → reconnect with a planned TP workout inside the next 45 days: does that one come back (50-006)?
5. "Delete synced data" on a disposable account with its own TP/FS link (never on test@test.com).

**Expected.**
Card, Timeline and `integrations` row agree after each path; a Cancel is not an error.

**Actual.**
Not run.

**Evidence.**
- runs/50/n11-after-allow.png the write-back sheet
- runs/50/n01-tp-disconnect-dialog.png the Delete synced data option

**Decision quote.**
> 

**Triage.**
- closed · retest passed or ran in wave 7 (ticket 69 checks 10+13 ran it; 69-009 and 69-011 carry the rest) · lead, 2026-10-09
