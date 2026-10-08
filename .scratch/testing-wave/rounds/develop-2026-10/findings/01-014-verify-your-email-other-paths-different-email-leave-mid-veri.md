# 01-014 · Verify your email: other paths (different email, leave mid-verify, expired code, relaunch)

- kind: followup-test
- status: closed
- ticket: 01
- run: w1-20261007T1103Z
- screen: Verify your email
- decision: 

**Steps.**
1. Tap "Use a different email": does it go back to the form, and is the first address dropped from `auth.users.email_change`?
2. Close the screen (swipe down / back) before entering the code: what state is the app in (anonymous user with a pending `email_change`), and can the athlete get back to the code screen?
3. Terminate the app on the code screen and relaunch: where does it open, and does the old code still work?
4. Enter a code after it expires (1 hour) and check the message.
5. Enter the code with the network cut (`netcut.sh on`) and check the message and retry.

**Expected.**
Each path either finishes the signup or leaves the athlete a clear way back to it; no orphaned half-upgraded anonymous user with nowhere to type the code.

**Actual.**
Not run (look-around).

**Evidence.**
- runs/01/19-verify-email.png

**Decision quote.**
> 

**Triage.**
retest ticket 30 (retest: auth and account), wave 3 (Lee: all 27 followups into four retest tickets)

**Closed (wave 3, 2026-10-08).** run in ticket 30; what failed is re-filed as 30-007 and 30-008; part (e) expired code not seen live
