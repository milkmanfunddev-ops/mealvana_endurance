# 02-015 · Delete account while offline

- kind: followup-test
- status: triaged
- ticket: 02
- run: w2-20260923T1442Z
- screen: Settings
- decision: 

**Steps.**
1. Signed in past the paywall. 2. Turn networking off. 3. Settings → Delete Account → Delete.

**Expected.**
The app refuses or queues with a message; it does not wipe local data and sign out while the server account survives.

**Actual.**
Not run (look-around, ticket 02).

**Evidence.**
- runs/02/notes.md

**Decision quote.**
> 

**Triage.**

Picked for retest ticket 109 (Lee, 2026-09-25: every open follow-up test folded into the planned runs, cap of ten lifted for this pass).
