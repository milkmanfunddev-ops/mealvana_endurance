# 48-003 · Logging in from Verify's hint lands back on the Sign Up form, not the app

- kind: bug
- status: closed
- ticket: 48
- run: w5-20261008T1718Z
- screen: Log In
- decision: 

**Steps.**
1. Account A exists and is signed out. Welcome → Build My Plan (new anonymous session 656d8eb7-2238-43f5-bf42-747103670f5a) →
   onboarding → Save My Plan → Sign up with Email with a new address B → Create Account (17:37:00Z) → Verify your email.
2. Tap the hint's "Log in" (17:37:09Z): Log In opens with B prefilled.
3. Change the address to A's, type A's password, Log In (17:43:23Z).

**Expected.**
A successful log in takes the athlete into the app (Timeline), as it does from Welcome → I already have an account.

**Actual.**
- Log in succeeds (`email_sign_in_success {user_id: 1c31d98e…}`, `auth_flow_completed`), but the screen pops back to
  "Sign Up with Email" with address B and both password fields still filled, and a Create Account button.
- Back from there goes to "Create Your Account" (Continue with Apple / Google / Sign up with Email / Continue without signing in),
  while signed in as A.
- Only a relaunch (17:44:00Z) reached the Timeline as A.
An athlete who follows the hint ("This address may already have an account") and logs in is left on a sign-up form; tapping
Create Account there would try to link B onto an already-signed-in account. Also, the anonymous user 656d8eb7 stays behind with B
pending in `email_change` (db-48-after-hint-login.txt): the upgrade-path leftover 30-007 (a) already describes.
Retest of 30-013 (the hint's Log in): the hint itself works; what follows the log in does not.

**Evidence.**
- runs/48/48-46-verify-B.png
- runs/48/48-47-hint-login.png (Log In with B prefilled)
- runs/48/48-54-after-login-A.png (Sign Up with Email after a successful log in)
- runs/48/48-56-back-from-signup-after-login.png (Create Your Account while signed in)
- runs/48/48-57-relaunch-after-login.png (Timeline after relaunch)
- runs/48/console-redacted.log (12:43:2x local: email_sign_in_success)
- runs/48/db-48-after-hint-login.txt

**Decision quote.**
> 

**Triage.**
- closed · retest passed or ran in wave 7 (ticket 67 check 5) · lead, 2026-10-09
