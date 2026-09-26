# 32-005 · Verify your email: quit the app on the code screen and come back

- kind: followup-test
- status: closed
- ticket: 32
- run: w9-20260924T1447Z
- screen: Verify your email
- decision: 

**Steps.**
1. Sign up with email on dev and stop on Verify your email without entering the code.
2. Terminate the app and launch it again.
3. Try: Log In with the same address and password; Sign up again with the same address; enter the emailed code if the app offers a way back to the code screen.

**Expected.**
The athlete can finish verifying (the app returns to the code screen, or Log In says the email is
not confirmed and offers to resend). Onboarding answers are not lost. Nothing lands the account in
the app unconfirmed.

**Actual.**
Not run (look-around, ticket 32).

**Evidence.**
- runs/32/06-after-create-account-retry.png

**Decision quote.**
> 

**Triage.**

Picked for retest ticket 109 (Lee, 2026-09-25: every open follow-up test folded into the planned runs, cap of ten lifted for this pass).
Moved to retest ticket 124 when 109 was split (Lee, 2026-09-25).

Run by retest ticket 124 (run w37-20260926T0221Z, build 72d3723e): fail, carried by new bug Finding 124-001 (after quitting on the code screen, Log In says "check your credentials" for the unconfirmed email and offers no way back to the code).
