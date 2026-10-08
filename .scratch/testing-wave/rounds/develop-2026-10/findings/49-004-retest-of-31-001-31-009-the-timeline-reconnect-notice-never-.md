# 49-004 · Retest of 31-001 / 31-009: the Timeline reconnect notice never showed (no provider went to requires_reauth), so its words, Reconnect, X and relaunch went unchecked

- kind: followup-test
- status: open
- ticket: 49
- run: w5-20261008T1719Z
- screen: Timeline
- decision: 

**Steps.**
1. Needs an account whose integration moves to `requires_reauth` during a sync on the device (run 31 had it: TrainingPeaks `invalid_grant` and V.O2 `TokenRefreshException` at sign-in). On this run test@test.com's TrainingPeaks and Final Surge synced `success` at 17:22Z and V.O2 was already inactive, so nothing triggered it.
2. With the notice up: read its text and button (31-001: words, not `connections.reconnect_notice`); tap Reconnect (expect Connected Apps); on a second trigger tap X; relaunch after each and note whether it returns (code map: dismissal is in memory, a prefs flag `reconnect_notice_shown.<provider>` stops it returning until a `success`).
3. A run account with a deliberately dead token is the reliable start state (written by that run, never on another run's account).

**Expected.**
The notice reads as words; Reconnect opens Connected Apps; X hides it; the relaunch rule matches a written rule.

**Actual.**
Not shown at 17:22:18Z (sign-in), 17:25:24Z (relaunch) or on any later Timeline visit. Integrations at 17:22Z: vdot inactive/requires_reauth (unchanged since 13:26Z), training_peaks success 17:22:10Z, final_surge success 17:22:09Z, garmin success.

**Evidence.**
- runs/49/04-timeline.png — Timeline after sign-in, no notice
- runs/49/08-timeline-after-relaunch.png — after relaunch, no notice
- runs/49/db-integrations-1722.txt — integration states at sign-in
- runs/49/05-connected-apps.png — Connected Apps, V.O2 shows Connect

**Decision quote.**
> 

**Triage.**
