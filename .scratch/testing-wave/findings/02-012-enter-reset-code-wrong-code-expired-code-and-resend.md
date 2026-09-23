# 02-012 · Enter Reset Code: wrong code, expired code and Resend

- kind: followup-test
- status: open
- ticket: 02
- run: w2-20260923T1442Z
- screen: Enter Reset Code
- decision: 

**Steps.**
1. Request a reset code. 2. Enter a wrong six-digit code. 3. Tap Resend (mind dev's 2 emails/hour limit). 4. Enter the first, superseded code.

**Expected.**
Wrong and superseded codes are refused with a clear message; Resend delivers a new code that works.

**Actual.**
Not run (look-around, ticket 02).

**Evidence.**
- runs/02/notes.md

**Decision quote.**
> 

**Triage.**
