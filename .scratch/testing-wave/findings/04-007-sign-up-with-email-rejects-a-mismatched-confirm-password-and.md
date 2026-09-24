# 04-007 · Sign Up with Email rejects a mismatched confirm password and a weak password

- kind: followup-test
- status: open
- ticket: 04
- run: w4-20260924T0418Z
- screen: Sign Up with Email
- decision: 

**Steps.**
1. On Sign Up with Email, enter a confirm password that differs from the password.
2. Then a too-short password. 3. Then an address with no `@`.

**Expected.**
A clear message on the field for each, no account created, no auth call for the first two.

**Actual.**
Not run (look-around, ticket 04).

**Evidence.**
- runs/04/12-signup-email.png

**Decision quote.**
> 

**Triage.**

