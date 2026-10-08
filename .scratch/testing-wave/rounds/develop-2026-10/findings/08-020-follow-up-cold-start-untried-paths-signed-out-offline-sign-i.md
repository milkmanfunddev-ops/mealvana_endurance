# 08-020 · Follow-up: cold start untried paths (signed out offline, sign-in offline, kill during sync)

- kind: followup-test
- status: closed
- ticket: 08
- run: w1-20261007T1105Z
- screen: none (startup)
- decision: 

**Steps.**
1. Cold start signed out with no network; try to sign in offline; kill the app during the first sync after sign-in and relaunch. This run covered signed-in offline cold start (Timeline rendered from the local DB). Recurs from 29-003.

**Expected.**
Each shows a clear state and no crash; nothing local is lost.

**Actual.**


**Evidence.**
- runs/08/b14-offline-timeline.png signed-in offline cold start for comparison

**Decision quote.**
> 

**Triage.**
retest ticket 32 (retest: startup, tabs, deep links), wave 3 (Lee: all 27 followups into four retest tickets)

**Closed (wave 3, 2026-10-08).** retest passed in ticket 32 (runs/32/notes.md)
