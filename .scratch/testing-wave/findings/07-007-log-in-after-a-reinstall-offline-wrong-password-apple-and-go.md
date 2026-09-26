# 07-007 · Log In after a reinstall: offline, wrong password, Apple and Google sign-in for a paid account, and a Lapsed account

- kind: followup-test
- status: closed
- ticket: 07
- run: w6-20260924T1118Z
- screen: Log In
- decision: 

**Steps.**
After a reinstall (uninstall, install the same build, launch):
1. Log in with email while offline.
2. Log in with a wrong password, then the right one.
3. A paid account that signed up with Apple or Google: sign in with that provider.
4. A Lapsed account (for example after the Test Store's 25-minute lapse): sign in; then ⋯ → Restore purchases.

**Expected.**
1: a plain offline message, nothing half signed in. 2: the error, then the app. 3: the app opens as for email. 4: the full-screen paywall with the ⋯ menu (mp-494, Manage shown since a subscription is on record); Restore says nothing was found and the Gate stays closed.

**Actual.**
Not run (look-around, ticket 07). Seen on the way: the Log In screen came back fully enabled for a frame after the tap before the timeline showed, as 12-003 describes.

**Evidence.**
- runs/07/09-after-login-frames.png

**Decision quote.**
> 

**Triage.**

Picked for retest ticket 109 (Lee, 2026-09-25: every open follow-up test folded into the planned runs, cap of ten lifted for this pass).
Moved to retest ticket 125 when 109 was split (Lee, 2026-09-25).

Run by retest ticket 125 (run w37-20260926T0221Z, build 72d3723e): fail, carried by new bug Findings 125-002 (offline Log In reads as a wrong password) and 125-003 (a cancelled Google sign-in says "Sign in failed"); wrong-then-right passes; Apple and Google sign-in themselves not run (follow-up 125-009).
