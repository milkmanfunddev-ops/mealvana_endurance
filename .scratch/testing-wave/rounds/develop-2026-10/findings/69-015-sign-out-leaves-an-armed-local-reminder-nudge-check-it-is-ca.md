# 69-015 · Sign Out leaves an armed local reminder nudge: check it is cancelled

- kind: followup-test
- status: triaged
- ticket: 69
- run: w7-lead-20261008T2354Zw7-lead-20261008T2354Z
- screen: Settings (Sign Out)
- decision: 

**Steps.**
1. Signed in with an upcoming planned activity: open its reminder (run 69 saw `nudge ARMED id=be55a023… fireAt 2026-10-09 19:00` in the tape while signed in).
2. Settings → Sign Out → Sign out.
3. Read the pending local notifications (the tape, or `xcrun simctl` cannot list them: the app's Debug console) and let the fire time pass, or sign in as a different athlete on the same device before it fires.

**Expected.**
A sign-out cancels every local reminder armed for the signed-out athlete; no nudge fires on Welcome or for a different athlete. If one fires, its tap must not route into another athlete's activity.

**Actual.**
Filed by the wave lead from runs/69/notes.md check 14 ("whether Sign Out cancels it was not checked"). Touches notifications: the notification rule in CLAUDE.md applies to the retest.

**Evidence.**
- runs/69/notes.md check 14 note

**Decision quote.**
> 

**Triage.**
- triaged · retest ticket A (auth, startup, Welcome, Sign Out; with fix ticket 53), cut after fix wave 8 for test wave 9 · Lee, 2026-10-09
