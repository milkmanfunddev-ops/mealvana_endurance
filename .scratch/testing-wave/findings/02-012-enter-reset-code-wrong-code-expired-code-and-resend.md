# 02-012 · Enter Reset Code: wrong code, expired code and Resend

- kind: followup-test
- status: triaged
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

Picked for retest ticket 109 (Lee, 2026-09-25: every open follow-up test folded into the planned runs, cap of ten lifted for this pass).
Moved to retest ticket 124 when 109 was split (Lee, 2026-09-25).
