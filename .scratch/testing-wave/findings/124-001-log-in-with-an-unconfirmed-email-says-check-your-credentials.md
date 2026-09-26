# 124-001 · Log In with an unconfirmed email says 'check your credentials' and gives no way back to the code

- kind: bug
- status: triaged
- ticket: 124
- run: w37-20260926T0221Z
- screen: Log In with email
- decision: 

**Steps.**
1. Sign up by email on dev and stop on Verify your email without entering the code (02:27:26Z, account B).
2. Terminate the app and launch it again: it opens on Welcome (the code screen is not restored).
3. I already have an account > Log in with email > the same address and password > Log In (02:28:15Z).

**Expected.**
The athlete can finish verifying: Log In says the email is not confirmed yet and offers to send
a code (or opens the code screen), as 32-005 expects. The onboarding answers are still there.

**Actual.**
Snackbar "Login failed. Please check your credentials." The server's answer was different: the
console has `AuthApiException(message: Email not confirmed, statusCode: 400, code: email_not_confirmed)`.
Nothing on Log In leads back to the code. The only way found was to run onboarding again from
Build My Plan (every answer was gone: no sport ticked, first name empty) and Sign up with Email
at the same address, which sent a fresh code (02:30:15Z, same auth user 13f2e03f) that verified.
Nothing landed the account in the app unconfirmed. App build 72d3723e.

**Evidence.**
- runs/124/12-relaunch-after-verify-screen.png
- runs/124/15-login-unconfirmed-3s.png
- runs/124/17-onboarding-again-sports.png
- runs/124/console-redacted.log (email_not_confirmed)
- runs/124/notes.md

**Decision quote.**
> 

**Triage.**

Fix ticket 139, Sign-in, sign-up, sign-out, delete, admin (Lee, 2026-09-26). Closed by the retest after it merges. Record: `triage-20260926.md`.
