# 02-012 · Enter Reset Code: wrong code, expired code and Resend

- kind: followup-test
- status: closed
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

Run by retest ticket 124 (run w37-20260926T0221Z, build 72d3723e): pass; wrong and superseded codes read "Invalid or expired code", Resend after 60 s sent a working code. A code over an hour old was not tried. Resend inside 60 s is new bug Finding 124-004.
