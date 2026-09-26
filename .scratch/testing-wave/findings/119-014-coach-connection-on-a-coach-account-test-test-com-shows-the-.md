# 119-014 · Coach Connection on a coach account (test@test.com) shows the athlete's Enter Coach Code form: enter the account's own coach code

- kind: followup-test
- status: triaged
- ticket: 119
- run: w36-20260926T0031Z
- screen: Coach Connection
- decision: 

**Steps.**
1. On test@test.com (a coach, owner of DEVCOACH30), open Settings > Coach Connection.
2. Enter the account's own coach code and tap Connect (on a throwaway coach account if the write is not wanted on test@test.com).

**Expected.**
A coach cannot pair with itself; the error says so.

**Actual.**
Not run. The screen shows the athlete's "Connect with Your Coach / Enter Coach Code" form to the coach account, with no pending-request list.

**Evidence.**
- runs/119/26-coach-connection.png: the form on test@test.com

**Decision quote.**
> 

**Triage.**

Folded into the retest of its screen after the 2026-09-26 fix tickets (Lee, 2026-09-26: every follow-up test goes into the retests). Record: `triage-20260926.md`.
