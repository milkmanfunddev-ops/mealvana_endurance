# 118-009 · Onboarding: back from the signup screen and from the code screen keeps the answers, and Use a different email keeps them too

- kind: followup-test
- status: triaged
- ticket: 118
- run: w36-20260926T0031Z
- screen: Onboarding; Sign Up with Email; Verify your email
- decision: 

**Steps.**
1. Walk onboarding with non-default answers to Create Your Account.
2. Back from Sign Up with Email, then from Verify your email (Use a different email); go forward again.
3. Kill the app mid-onboarding and relaunch.

**Expected.**
Answers kept each way (or, after a kill, a clear restart); the saved profile carries them.

**Actual.**
Not run (look-around, ticket 118).

**Evidence.**
- runs/118/21-signup.png

**Decision quote.**
> 

**Triage.**

Folded into the retest of its screen after the 2026-09-26 fix tickets (Lee, 2026-09-26: every follow-up test goes into the retests). Record: `triage-20260926.md`.
