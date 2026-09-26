# 111-001 · Kroger sign-in: Cancel on the kroger.com alert or X on the sheet shows 'Something went wrong' and leaves an OAuth session row

- kind: bug
- status: triaged
- ticket: 111
- run: w30-20260925T2103Z
- screen: Shop with Kroger
- decision: 

**Steps.**
1. Retest of follow-up 21-005. test@test.com, Food > Shopping > Shop with Kroger on the confirmed plan 666be167's list, not connected (production row removed first, 22-005).
2. Tap Connect Kroger (21:11:17Z); on "“Endurance Dev” Wants to Use “kroger.com” to Sign In" tap Cancel (21:11:33Z). Read the screen and `kroger_oauth_sessions`.
3. Tap Connect Kroger, Continue, wait for login-stage.kroger.com, close the sheet with its X (21:12:24Z). Read the same.

**Expected.**
Each time the screen stays disconnected with the Connect button back and a plain cancelled message (`authorization_cancelled`), no error in the console, no `kroger_connections` row and no leftover `kroger_oauth_sessions` row (21-005).

**Actual.**
Both times the snackbar reads "Something went wrong. Your draft is saved on this device; try again." (the `unexpected` code), though the shopper only cancelled. The console shows "SFAuthenticationSession was cancelled by user" at 21:11:33Z: `flutter_web_auth_2` throws a PlatformException (CANCELED) that `KrogerController._error` does not map (it knows only KrogerException, ClientException and AuthRetryableFetchException), so a cancel reads as an app fault. Each attempt also leaves its `kroger_oauth_sessions` row (558cd312 after the Cancel, 0c6e470f after the X, each expiring 10 min later); the next Connect deletes the old one, so they do not pile up, but they stay until then. No `kroger_connections` row was made (right). Connect stays usable.

**Evidence.**
- runs/111/17-connect-system-alert.png
- runs/111/18-after-alert-cancel.png
- runs/111/db-kroger-after-alert-cancel.txt
- runs/111/21-after-sheet-x.png
- runs/111/db-kroger-after-sheet-x.txt
- runs/111/31-21-007-after-x.png (same message after the double-tap sheet's X)
- runs/111/console-redacted.log (16:11:33 CDT "SFAuthenticationSession was cancelled by user")

**Decision quote.**
> 

**Triage.**

Fix ticket 133, Shopping lists and Kroger (Lee, 2026-09-26). Closed by the retest after it merges. Record: `triage-20260926.md`.
