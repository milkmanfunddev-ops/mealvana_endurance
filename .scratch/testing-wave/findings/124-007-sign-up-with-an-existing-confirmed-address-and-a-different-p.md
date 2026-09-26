# 124-007 · Sign up with an existing confirmed address and a different password

- kind: followup-test
- status: triaged
- ticket: 124
- run: w37-20260926T0221Z
- screen: Sign Up with Email
- decision: 

**Steps.**
1. With a live confirmed account, run onboarding and Sign up with Email at its address but a different password.
2. Check auth.users (password unchanged: the old one still signs in) and the profile.

**Expected.**
The same answer as 124-002's fix gives for the right password; the first account's password and profile unchanged.

**Actual.**
Not run (look-around; 124-002 used the account's own password).

**Evidence.**
- runs/124/22-signup-existing-confirmed-B.png

**Decision quote.**
> 

**Triage.**

Folded into the retest of its screen after the 2026-09-26 fix tickets (Lee, 2026-09-26: every follow-up test goes into the retests). Record: `triage-20260926.md`.
