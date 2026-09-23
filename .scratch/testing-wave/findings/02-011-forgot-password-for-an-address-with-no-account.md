# 02-011 · Forgot password for an address with no account

- kind: followup-test
- status: open
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
