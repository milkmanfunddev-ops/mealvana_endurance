# 125-002 · Log In while offline says Login failed. Please check your credentials., the same as a wrong password

- kind: bug
- status: triaged
- ticket: 125
- run: w37-20260926T0221Z
- screen: Log In
- decision: 

**Steps.**
1. Clear the app's data (clear-app.sh), then `netcut.sh on --relaunch` so the app starts with no network.
2. Welcome → I already have an account → Log in with email; an existing paid account's address and its right password → Log In.

**Expected.**
07-007 step 1: a plain offline message ("You're offline" or similar), nothing half signed in.

**Actual.**
02:37:16Z: the snackbar "Login failed. Please check your credentials." for about 2 s, still on Log In. That is the same text a wrong password or a deleted account gets (02:39:58Z, 02:43:12Z), so an athlete with no signal is told their password is wrong. Console: `AuthRetryableFetchException(message: ClientException with SocketException: Connection failed (OS Error: Network is unreachable, errno = 51)` from `EmailAuthService.signInWithEmail` (email_auth_service.dart:755). Nothing was half signed in: the right password online at 02:40:15Z opened the app.

**Evidence.**
- runs/125/41-B-real-offline-login-1.png
- runs/125/47-B-wiped-wrong-password.png
- runs/125/console-redacted.log (21:37:17 local)
- runs/125/notes.md

**Decision quote.**
> 

**Triage.**

Fix ticket 139, Sign-in, sign-up, sign-out, delete, admin (Lee, 2026-09-26). Ruling: Log In errors stay under the form until the next edit, and say whether it's a wrong email or password, or no connection (139). Closed by the retest after it merges. Record: `triage-20260926.md`.
