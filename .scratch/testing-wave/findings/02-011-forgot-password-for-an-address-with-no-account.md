# 02-011 · Forgot password for an address with no account

- kind: followup-test
- status: closed
- ticket: 02
- run: w2-20260923T1442Z
- screen: Forgot Password
- decision: 

**Steps.**
1. Forgot Password with a lee+e2e address that was deleted. 2. Watch the screen and the Gmail inbox (dev sends at most 2 auth emails an hour).

**Expected.**
The screen does not reveal whether the address has an account, and no email arrives, or the decision says otherwise.

**Actual.**
Not run (look-around, ticket 02).

**Evidence.**
- runs/02/notes.md

**Decision quote.**
> 

**Triage.**

Picked for retest ticket 109 (Lee, 2026-09-25: every open follow-up test folded into the planned runs, cap of ten lifted for this pass).
Moved to retest ticket 124 when 109 was split (Lee, 2026-09-25).

Run by retest ticket 124 (run w37-20260926T0221Z, build 72d3723e): pass; an address with no account gets the same "Check your email for a reset code" screen, no auth user and no email.
