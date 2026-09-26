# 121-014 · Sign Up with Email: returning via Use a different email keeps the old address and password

- kind: followup-test
- status: triaged
- ticket: 121
- run: w34-20260925T2320Z
- screen: Sign up (Sign Up with Email)
- decision: 

**Steps.**
1. From Verify your email tap Use a different email: the form still holds the first address and its password in both fields.
2. Change only the address and Create Account.
3. Also: a mismatched Confirm Password, a weak password, and the abandoned unconfirmed address from 121-003 signed up again.

**Expected.**
2: the second account uses the kept password knowingly (or the fields are cleared). 3: clear field errors; the abandoned address can sign up again and gets a fresh code.

**Actual.**
Not run (look-around, ticket 121).

**Evidence.**
- runs/121/06-after-use-different-email.png

**Decision quote.**
> 

**Triage.**

Folded into the retest of its screen after the 2026-09-26 fix tickets (Lee, 2026-09-26: every follow-up test goes into the retests). Record: `triage-20260926.md`.
