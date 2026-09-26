# 02-015 · Delete account while offline

- kind: followup-test
- status: closed
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
Moved to retest ticket 125 when 109 was split (Lee, 2026-09-25).

Run by retest ticket 125 (run w37-20260926T0221Z, build 72d3723e): fail, carried by open bug Finding 121-007 (offline delete signs out and wipes the phone while the server rows stay), with a paywall frame on the way (125-001).
