# 04-007 · Sign Up with Email rejects a mismatched confirm password and a weak password

- kind: followup-test
- status: closed
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

Picked for retest ticket 109 (Lee, 2026-09-25: every open follow-up test folded into the planned runs, cap of ten lifted for this pass).
Moved to retest ticket 124 when 109 was split (Lee, 2026-09-25).

Run by retest ticket 124 (run w37-20260926T0221Z, build 72d3723e): pass; mismatch, short password and no-@ address each show a field message and reach no server. An 8+ character weak password is follow-up 124-006.
