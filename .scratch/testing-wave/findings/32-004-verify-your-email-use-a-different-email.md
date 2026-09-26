# 32-004 · Verify your email: Use a different email

- kind: followup-test
- status: closed
- ticket: 32
- run: w9-20260924T1447Z
- screen: Verify your email
- decision: 

**Steps.**
1. Sign up with email on dev; on Verify your email tap "Use a different email".
2. Sign up again with a second address, verify it.
3. Check `auth.users` for both addresses, and try the first address's code afterwards.

**Expected.**
The first, unconfirmed account does not block or leak into the second; onboarding answers land on
the second account only; the first address can sign up again later (or its unconfirmed row is
cleaned up).

**Actual.**
Not run (look-around, ticket 32).

**Evidence.**
- runs/32/06-after-create-account-retry.png

**Decision quote.**
> 

**Triage.**

Picked for retest ticket 109 (Lee, 2026-09-25: every open follow-up test folded into the planned runs, cap of ten lifted for this pass).
Moved to retest ticket 124 when 109 was split (Lee, 2026-09-25).

Run by retest ticket 124 (run w37-20260926T0221Z, build 72d3723e): pass; the first address stayed unconfirmed, the onboarding answers landed only on the second account.
