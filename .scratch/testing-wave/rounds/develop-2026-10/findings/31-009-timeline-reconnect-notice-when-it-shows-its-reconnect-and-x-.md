# 31-009 · Timeline Reconnect notice: when it shows, its Reconnect and X, and why it was gone after a relaunch with two integrations still needing a reconnect

- kind: followup-test
- status: triaged
- ticket: 31
- run: w3-20261008T1256Z
- screen: Timeline
- decision: retest ticket 49 (meal logging), wave 5

**Steps.**
1. Sign in on an account with a dead TrainingPeaks / V.O2 token: the notice showed right after sign-in (12:58:06Z).
2. Relaunch without touching it (12:59:09Z): it was gone, both integrations still requires_reauth.
3. Try: tap Reconnect (should open Settings > Connected Apps), tap X, relaunch after each, two providers at once (which one is named), offline launch.

**Expected.**
The notice follows a written rule (once per session, until dismissed, per provider) and the rule holds across relaunches.

**Actual.**


**Evidence.**
- runs/31/03-after-notif-prompt.png — notice after sign-in
- runs/31/04-relaunch-no-tp-sheet.png — no notice after relaunch

**Decision quote.**
> 

**Triage.**

