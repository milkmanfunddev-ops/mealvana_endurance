# 02-010 · Signing in with a deleted account's old password gives a clear error

- kind: followup-test
- status: closed
- ticket: 02
- run: w2-20260923T1442Z
- screen: Log In
- decision: 

**Steps.**
1. Delete an account. 2. Welcome → I already have an account → Log in with email, the deleted address and its old password.

**Expected.**
A plain 'wrong email or password' style message, no crash, no half-signed-in state.

**Actual.**
Not run (look-around, ticket 02).

**Evidence.**
- runs/02/notes.md

**Decision quote.**
> 

**Triage.**

Picked for retest ticket 109 (Lee, 2026-09-25: every open follow-up test folded into the planned runs, cap of ten lifted for this pass).
Moved to retest ticket 125 when 109 was split (Lee, 2026-09-25).

Run by retest ticket 125 (run w37-20260926T0221Z, build 72d3723e): pass; a deleted account's old password gives "Login failed. Please check your credentials." and stays on Log In (same text as a wrong password: idea 125-007).
