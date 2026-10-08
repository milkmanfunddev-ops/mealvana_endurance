# 30-007 · Relaunching on Verify your email drops the pending signup: Welcome, onboarding answers gone, no way back to the code without a new one

- kind: bug
- status: triaged
- ticket: 30
- run: w3-20261008T1255Z
- screen: Verify your email
- decision: fix ticket 42 (pending signup survives a relaunch; 429 is a wait)

**Steps.**
1. Account B, anonymous session 1ffc8851-e02f-4203-b5b9-973400f65528 (upgrade path). Sign up with email, Create Account;
   Verify your email open, code sent 13:13:27Z (757482).
2. (b) Try to leave without the code: an edge swipe does nothing; the screen has no close or back button.
3. (c) Terminate the app on that screen and relaunch (13:13:58Z).
4. Build My Plan, walk onboarding again, Sign up with email again with the same address (13:16:23Z), type the code from
   step 1.

**Expected.**
01-014 (b)/(c): an athlete who closes or loses the code screen can get back to it, and the code already in their inbox
still works; their answers are kept.

**Actual.**
- (b) The only ways off the screen are "Use a different email" and the hint's Log in; a swipe is ignored. Not a bug on its
  own, recorded for 01-014.
- (c) Relaunch opens Welcome. The pending address stays on the auth user (`email_change` set, db-30b4c-after-relaunch.txt),
  but nothing in the app leads back to the code. Build My Plan reuses the anonymous session but starts onboarding
  empty (sports unselected; every answer re-entered). Getting back to the code means re-sending, which supersedes the
  code in the inbox: 757482 was then refused ("wrong code", shown as the raw key, 30-001).
- (a) "Use a different email" (13:12:47Z) goes back to the form with the address and both passwords still filled; the
  first address stays pending in `email_change` until another is submitted, and is replaced then
  (db-30b4a-after-different-email.txt, db-30b4a-after-second-address-retry.txt). An athlete who walks away there leaves
  their first address pending on the anonymous user. Upgrade path only (`discardSignup` runs only for `OtpType.signup`);
  Lee ruled that path is going away.
- (d) With the network cut, typing the code shows `auth.verify_email.error_generic` (raw key; default "Could not verify
  that code. Please try again."), not a connection message; after `netcut off`, Verify accepted the same code. Fine apart
  from the text.
- (e) Expired code: first B code sent 13:12:10Z; the run ended before 14:12Z: not seen live.
Retest of 01-014.

**Evidence.**
- runs/30/30b4-05-after-edge-swipe.png
- runs/30/30b4-06-relaunch-from-code-screen.png
- runs/30/30b4-07-build-again.png
- runs/30/30b4-08-old-code-after-relaunch.png
- runs/30/30b4-09-code-offline.png
- runs/30/30b4-02-after-different-email.png
- runs/30/db-30b4c-after-relaunch.txt
- runs/30/db-30b4a-after-different-email.txt
- runs/30/db-30b4a-after-second-address-retry.txt

**Decision quote.**
> 

**Triage.**
