# 120-015 · Sign out offline, then log back in as the same account while still offline

- kind: followup-test
- status: triaged
- ticket: 120
- run: w39-20260926T1013Z
- screen: Log In
- decision: 

**Steps.**
1. Signed in, offline, a Manual log, sign out offline.
2. Still offline, Log In as the same account.

**Expected.**
A clear offline message on Log In; the kept unsynced rows are still there once online sign-in succeeds.

**Actual.**


**Evidence.**
- runs/120/27-signout-offline-line.png

**Decision quote.**
> 

**Triage.**

Folded into the retest of its screen after the 2026-09-26 fix tickets (Lee, 2026-09-26: every follow-up test goes into the retests). Record: `triage-20260926.md`.
