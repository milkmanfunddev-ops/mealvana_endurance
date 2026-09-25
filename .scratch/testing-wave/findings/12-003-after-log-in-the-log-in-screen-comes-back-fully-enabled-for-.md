# 12-003 · After Log In, the Log In screen comes back fully enabled for about a second before the tabs shell

- kind: bug
- status: triaged
- ticket: 12
- run: w4-20260924T0417Z
- screen: Log In
- decision: 

**Steps.**
1. Fresh install, welcome screen, I already have an account, Log in with email.
2. Enter the admin's address and password, tap Log In.
3. Screenshot once a second.

**Expected.**
Logging in… holds until the app moves to the tabs shell (or the paywall).

**Actual.**
At about 1 s and 2 s the screen shows Logging in… with a spinner; at about 3 s the Log In screen is back with the button enabled and no spinner; at about 4 s the tabs shell is up. The console shows `popping /welcome` then `going to /main` once, so the trip was not lost as on 2026-09-16, but for about a second the athlete sees the form again and could tap Log In a second time.

**Evidence.**
- runs/12/04a-login-logging-in.png, runs/12/04b-login-screen-back-before-shell.png, runs/12/04c-timeline-with-whats-new-sheet.png
- runs/12/console.log (GoRouter lines after the login)

**Decision quote.**
> 

**Triage.**
Fix ticket 53 (Lee, 2026-09-25). Closed by the retest after it merges.
