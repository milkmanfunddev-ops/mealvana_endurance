# 32-006 · Set New Password: Cancel or back after the reset code is accepted

- kind: followup-test
- status: triaged
- ticket: 32
- run: w9-20260924T1447Z
- screen: Set New Password
- decision: 

**Steps.**
1. Forgot password, enter the right reset code; Set New Password opens (the app now holds a recovery session).
2. Tap Cancel (and, in a second run, the back arrow, and in a third, terminate and relaunch the app).
3. See where the router sends the app and whether it is signed in; check `auth.sessions`.

**Expected.**
Cancelling a reset leaves the device signed out on Log In, the old password still works, and no
recovery session stays usable on the device.

**Actual.**
Not run (look-around, ticket 32). The right code does open a signed-in recovery session
(`auth.sessions` row at 14:54:43Z), which is what makes this path worth checking.

**Evidence.**
- runs/32/19-after-reset-code.png
- runs/32/db-auth-user-after-reset.txt

**Decision quote.**
> 

**Triage.**

Picked for retest ticket 109 (Lee, 2026-09-25: every open follow-up test folded into the planned runs, cap of ten lifted for this pass).
