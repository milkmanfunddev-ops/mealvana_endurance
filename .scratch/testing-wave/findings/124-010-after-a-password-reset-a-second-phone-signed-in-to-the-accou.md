# 124-010 · After a password reset, a second phone signed in to the account: what it shows at its next token refresh

- kind: followup-test
- status: triaged
- ticket: 124
- run: w37-20260926T0221Z
- screen: Set New Password
- decision: 

**Steps.**
1. Sign one account in on two simulators.
2. Reset the password on one.
3. On the other, wait for the next token refresh (or relaunch) and watch what it shows.

**Expected.**
The second phone is signed out cleanly, lands on Log In with a message, and keeps no unsynced data silently.

**Actual.**
Not run. 32-003's server side passes (124 verdicts: every other session gone, the old refresh token refused), but the app on the other phone was not watched.

**Evidence.**
- runs/124/db-sessions-A-5-after-reset.txt

**Decision quote.**
> 

**Triage.**

Folded into the retest of its screen after the 2026-09-26 fix tickets (Lee, 2026-09-26: every follow-up test goes into the retests). Record: `triage-20260926.md`.
