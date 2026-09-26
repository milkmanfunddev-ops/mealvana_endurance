# 121-015 · Verify your email: kill the app on it, and a code older than an hour

- kind: followup-test
- status: triaged
- ticket: 121
- run: w34-20260925T2320Z
- screen: Verify your email
- decision: 

**Steps.**
1. Sign up, reach Verify your email, kill the app, relaunch.
2. Enter a code whose email is more than 1 h old (mailer_otp_exp 3600 on dev).
3. Tap Resend twice across the 60 s server limit after 121-001's fix.

**Expected.**
1: the app brings the athlete back to the code step (or a clear way to it), not a signed-in half account. 2: the expired message. 3: no 429 message.

**Actual.**
Not run (look-around, ticket 121).

**Evidence.**
- runs/121/07-verify-B.png

**Decision quote.**
> 

**Triage.**

Folded into the retest of its screen after the 2026-09-26 fix tickets (Lee, 2026-09-26: every follow-up test goes into the retests). Record: `triage-20260926.md`.
