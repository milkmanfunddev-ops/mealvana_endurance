# 02-013 · Signing up with an address that already has an account

- kind: followup-test
- status: closed
- ticket: 02
- run: w2-20260923T1442Z
- screen: Sign Up with Email
- decision: 

**Steps.**
1. With a live lee+e2e account, run onboarding again and Sign up with Email at the same address.

**Expected.**
The 'account exists' dialog, offering to log in; no second account and no overwrite of the first account's profile.

**Actual.**
Not run (look-around, ticket 02).

**Evidence.**
- runs/02/notes.md

**Decision quote.**
> 

**Triage.**

Picked for retest ticket 109 (Lee, 2026-09-25: every open follow-up test folded into the planned runs, cap of ten lifted for this pass).
Moved to retest ticket 124 when 109 was split (Lee, 2026-09-25).

Run by retest ticket 124 (run w37-20260926T0221Z, build 72d3723e): fail, carried by new bug Finding 124-002 (an already-confirmed address opens Verify your email for a code that is never sent; no second account, profile not overwritten).
