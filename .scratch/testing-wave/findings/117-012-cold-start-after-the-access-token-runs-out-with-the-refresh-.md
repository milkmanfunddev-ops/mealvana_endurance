# 117-012 · Cold start after the access token runs out with the refresh token revoked (29-003 expiry leg, not run)

- kind: followup-test
- status: triaged
- ticket: 117
- run: w40-20260926T1052Z
- screen: Welcome, Timeline, Food, Events, Learn
- decision: 

**Steps.**
1. On a run-made account, signed in and paid, terminate the app and revoke the session on the server (`POST /auth/v1/logout?scope=global` with a password-grant token for that account).
2. Wait until the app's access token has expired (1 h after its last sign-in or refresh), then cold start.
3. Visit every tab; read the console.

**Expected.**
The app fails its refresh and lands on Log In with no red screen and no unhandled exception (29-003 step 2).

**Actual.**


**Evidence.**
- runs/117/notes.md

**Decision quote.**
> 

**Triage.**

Folded into the retest of its screen after the 2026-09-26 fix tickets (Lee, 2026-09-26: every follow-up test goes into the retests). Record: `triage-20260926.md`.
