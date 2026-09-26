# 120-011 · Log In: several wrong passwords in a row, what does the app say when Supabase rate-limits?

- kind: followup-test
- status: triaged
- ticket: 120
- run: w39-20260926T1013Z
- screen: Log In
- decision: 

**Steps.**
Log In with a wrong password five or more times in a row, fast.

**Expected.**
Each attempt answers; when Supabase rate-limits, the message says to wait, not "check your credentials", and the form stays usable.

**Actual.**


**Evidence.**
- runs/120/04-wrong-password-message.png (one wrong password: "Login failed. Please check your credentials.")

**Decision quote.**
> 

**Triage.**

Folded into the retest of its screen after the 2026-09-26 fix tickets (Lee, 2026-09-26: every follow-up test goes into the retests). Record: `triage-20260926.md`.
