# 124-003 · Cancel, back or quitting after the right reset code leaves the phone signed in without the password

- kind: bug
- status: triaged
- ticket: 124
- run: w37-20260926T0221Z
- screen: Set New Password
- decision: 

**Steps.**
1. Sign out. Log In > Log in with email > Forgot Password? > account A > Send Reset Code; enter the right code: Set New Password opens.
2. Run 1: tap Cancel (02:38:20Z); run 2: the back arrow, then Back twice to Log In (02:40:32Z); run 3: terminate the app on Set New Password (02:42:01Z).
3. Each time, terminate and relaunch the app and check auth.sessions.

**Expected.**
Leaving a reset without setting a password leaves the phone signed out on Log In, the old password still works, and no recovery session stays usable (32-006).

**Actual.**
All three runs: the app shows Log In (runs 1 and 2), but a relaunch opens the onboarding paywall
signed in as A (the iOS notification prompt first, then the paywall with its ⋯ menu), with no
password typed. The recovery session stays in auth.sessions (efd424ee 02:38:08Z, 18cbc8dd
02:40:19Z, 66c82c28 02:41:56Z). So the emailed reset code alone signs the phone in. The old password
still worked (script grant 200 at 02:39:03Z). RevenueCat logged in at the code step.

**Evidence.**
- runs/124/37-after-cancel-set-new-password.png
- runs/124/39-relaunch-after-cancel-signed-in.png
- runs/124/40-after-back-arrow-set-new-password.png
- runs/124/42-relaunch-after-back-arrow.png
- runs/124/43-relaunch-from-set-new-password.png
- runs/124/db-sessions-A-2-after-cancel.txt
- runs/124/db-sessions-A-3-after-back.txt
- runs/124/db-sessions-A-4-after-relaunch.txt

**Decision quote.**
> 

**Triage.**

Fix ticket 139, Sign-in, sign-up, sign-out, delete, admin (Lee, 2026-09-26). Ruling: a recovery session is signed out on cancel, back or quit before the new password is saved (139). Closed by the retest after it merges. Record: `triage-20260926.md`.
