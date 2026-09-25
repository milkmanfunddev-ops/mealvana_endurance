# 20-007 · Keep the per-app network cut (netcut dylib) as a testing-wave script so offline runs never touch the host network

- kind: idea
- status: wontfix
- ticket: 20
- run: w10-20260924T1614Z
- screen: none
- decision: 

**Steps.**
1. Add the small interpose library this run built (`connect`/`connectx` fail with ENETUNREACH for non-loopback addresses while a flag file exists) to `scripts/testing-wave/`, with a wrapper: `netcut.sh build`, `netcut.sh launch <udid>` (adds `SIMCTL_CHILD_DYLD_INSERT_LIBRARIES`), `netcut.sh off|on`.
2. Point RUNBOOK step 5 at it for any offline step, and note its limit: the OS still reports Wi-Fi, so connectivity checks read online (20-006).

**Expected.**
Offline tickets (02-015, 04-004, 11-006, 14-009, 20) cut only their own app, with no sudo and no effect on the other simulator or the host. Setting `http_proxy`/`https_proxy` for the app does not work: Dart's HttpClient ignores them (tried in this run).

**Actual.**


**Evidence.**
- runs/20/notes.md — "Offline method": what was tried, how it was checked, and its limits.

**Decision quote.**
> 

**Triage.**

Won't fix (Lee, 2026-09-25): done already: netcut is a testing-wave script (IMPROVEMENTS #36).
