# 125-007 · Log In errors are a two-second snackbar at the bottom, not a message under the form

- kind: idea
- status: triaged
- ticket: 125
- run: w37-20260926T0221Z
- screen: Log In
- decision: 

**Steps.**
A wrong password, a deleted account and no network all show the same snackbar at the bottom, "Login failed. Please check your credentials.", for about two seconds. The wrong password stays in the field. Idea: show the message under the form and keep it until the next edit, and say which it is (wrong email or password vs no connection). 06-008 expected "an error under the form".

**Expected.**


**Actual.**


**Evidence.**
- runs/125/31-B-wrong-password-1.png
- runs/125/31-B-wrong-password-2.png
- runs/125/60-A-deleted-login-1.png

**Decision quote.**
> 

**Triage.**

Fix ticket 139, Sign-in, sign-up, sign-out, delete, admin (Lee, 2026-09-26). Ruling: Log In errors stay under the form until the next edit, and say whether it's a wrong email or password, or no connection (139). Closed by the retest after it merges. Record: `triage-20260926.md`.
