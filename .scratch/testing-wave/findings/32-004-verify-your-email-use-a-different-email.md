# 32-004 · Verify your email: Use a different email

- kind: followup-test
- status: open
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
