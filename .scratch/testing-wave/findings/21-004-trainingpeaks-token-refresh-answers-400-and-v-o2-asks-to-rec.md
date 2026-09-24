# 21-004 · TrainingPeaks token refresh answers 400 and V.O2 asks to reconnect on every login of the dev test account
- kind: bug
- status: open
- ticket: 21
- run: w17-20260924T2233Z
- screen: none
- decision: 

**Steps.**
1. Fresh app data, sign in as test@test.com (22:35 UTC). The app runs its integration sync after login.

**Expected.**
The integration sync either works or tells the athlete once, on screen, which integration needs reconnecting.

**Actual.**
The console shows, at 17:35:03-04 local (22:35 UTC): "Token refresh failed: TrainingPeaksApiException: Token refresh failed (status: 400)" twice, "Integration sync failed for training_peaks: Token expired. Please reconnect.", and "Integration sync failed for vdot: Please reconnect your V.O2 account". Nothing on screen said so; the TrainingPeaks sharing sheet opened as if TrainingPeaks were working. Not caused by this ticket's steps; filed because the runbook files every server error. Earlier Findings mention the TrainingPeaks sheet (12-008, 30-010) but not these failures.

**Evidence.**
- runs/21/console-redacted.log (lines with "Token refresh failed" and "Integration sync failed")
- runs/21/05-trainingpeaks-sheet.png

**Decision quote.**
> 

**Triage.**
