# 118-010 · Connected Apps: Reconnect on TrainingPeaks and V.O2 opens the sign-in sheet, and a finished reconnect clears the Reconnect state

- kind: followup-test
- status: triaged
- ticket: 118
- run: w36-20260926T0031Z
- screen: Settings → Connected Apps
- decision: 

**Steps.**
1. test@test.com with TrainingPeaks and V.O2 at requires_reauth.
2. Tap Reconnect on each; cancel the sheet once, then finish it once (sandbox login).
3. Tap Sync Now on a working connection twice fast.

**Expected.**
Cancel leaves Reconnect; a finished reconnect shows Sync Now and the row goes to success; a double Sync Now runs one sync.

**Actual.**
Not run (look-around, ticket 118).

**Evidence.**
- runs/118/41-connected-apps.png

**Decision quote.**
> 

**Triage.**

Folded into the retest of its screen after the 2026-09-26 fix tickets (Lee, 2026-09-26: every follow-up test goes into the retests). Record: `triage-20260926.md`.
