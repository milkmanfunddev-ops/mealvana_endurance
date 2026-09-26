# 121-002 · A superseded signup code reads as "wrong or has expired" and does not point to the newest email

- kind: bug
- status: triaged
- ticket: 121
- run: w34-20260925T2320Z
- screen: Verify your email
- decision: 

**Steps.**
1. Sign up by email, reach Verify your email (code 1 mailed).
2. Resend code (code 2 mailed).
3. Type code 1.

**Expected.**
86-009 step 3: a message that sends the athlete to the newest code (for example, that only the latest email's code works).

**Actual.**
The six digits submit on their own and the screen reads "That code is wrong or has expired. Check the digits, or tap Resend for a new one." (`/auth/v1/verify` 403). Nothing says a newer code was already sent; the advice to tap Resend would send a third email. App build e3367d2c.

**Evidence.**
- runs/121/10-superseded-code-typed.png
- runs/121/edge-auth-requests-2320-2338.txt (`verify` 403 at 18:24:58 local)

**Decision quote.**
> 

**Triage.**

Fix ticket 139, Sign-in, sign-up, sign-out, delete, admin (Lee, 2026-09-26). Closed by the retest after it merges. Record: `triage-20260926.md`.
