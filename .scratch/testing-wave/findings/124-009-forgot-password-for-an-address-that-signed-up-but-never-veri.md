# 124-009 · Forgot Password for an address that signed up but never verified

- kind: followup-test
- status: triaged
- ticket: 124
- run: w37-20260926T0221Z
- screen: Forgot Password
- decision: 

**Steps.**
1. Sign up by email, stop on Verify your email, leave.
2. Log In > Forgot Password with that address; enter the reset code if one comes.

**Expected.**
Either a reset code that also confirms the address, or a message that points to finishing verification. Never a signed-in unconfirmed account.

**Actual.**
Not run (look-around, ticket 124).

**Evidence.**
- runs/124/28-forgot-password.png

**Decision quote.**
> 

**Triage.**

Folded into the retest of its screen after the 2026-09-26 fix tickets (Lee, 2026-09-26: every follow-up test goes into the retests). Record: `triage-20260926.md`.
