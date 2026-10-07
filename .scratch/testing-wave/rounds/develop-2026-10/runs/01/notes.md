# Ticket 01 notes, run w1-20261007T1103Z

- App build: `ce1a1527` (ROUND/app-build.json), installed on wave-pool-1
  (4AD8A3B6-0E7C-4CE3-A372-BE8FE4C34D2B) as com.milkman.mealvanaendurance.dev. App data cleared by the lead.
- Slot claimed 11:03Z.
- Pass A user 8fbd939d-ca32-49aa-aabc-de17cafc0383 (anonymous at Build My Plan 11:06:36Z, email linked 11:09:45Z, confirmed 11:11:02Z, deleted in app 11:12:53Z).
- Pass B user 6c8552d2-63da-4fec-be3f-641914f92c3e (same address, anonymous 11:13:19Z, confirmed 11:17:30Z, deleted in app 11:18:25Z).
- 11:19Z UK pass: AppleLocale set to en_GB, app terminated and relaunched.
- Pass C user ef00796d-8211-43b4-b4f2-3495812032e0 (address ...T112011Z, anonymous 11:19:54Z, confirmed 11:33:26Z, deleted in app 11:35:01Z). AppleLocale set back to en_US at 11:35:20Z.

## Run log
- 11:03Z slot claimed. 11:04Z app launched; `simctl launch` and the mobile MCP's first call both left SpringBoard in front (runbook #50); relaunched twice.
- Welcome opened with three stacked "Launch trail (dev)" dialogs (one per launch/resume); three Dismiss taps needed. Same again after the pass C relaunch. Filed 01-011.
- No consent screen in the US passes (A, B), as expected.
- Pass A: anonymous user at Build My Plan, email linked as an `email_change`; code mail 1 s after submit; wrong code refused (message wrong, 01-002); real code accepted; Timeline; Cancel kept the account; Delete removed everything (footprint empty); RevenueCat 404 before and after (02-005 does not recur: no customer is created on develop-next for these users).
- Pass B: same address, new id 6c8552d2 (pass A id 8fbd939d gone, nothing carried over: onboarding fields empty, plan reveal had no name). Resend sent nothing (01-003). Deleted cleanly.
- Pass C (en_GB): no consent screen; stored region `geo` US/AL wins over the locale (01-007). iOS notification permission prompt appeared at this relaunch (01-010). Signed up at a third address, Privacy shows analytics ON (implied grant, standard regime). Deleted cleanly. Locale reset to en_US.
- 11:26Z-11:33Z: a mobile MCP `type_keys` call timed out (RPC deadline) though the text landed, and the next tap took ~7 min to return. Known noise: MCP helper stall, not the app. The Impeller "Could not acquire current drawable" line at 06:31 local falls in that stall. Known noise: simulator rendering while the MCP helper hung.
- `scripts/edge_logs.sh` returned "(no rows in window)" for every query, even 24 h unfiltered, although three delete-user calls ran. Filed 01-013. Deletes were checked by SQL and `footprint` instead.
- `sweep-accounts.mjs list` at the end: 0 lee+e2e-* accounts on dev.

## Console (known noise)
- Plugin "uses deprecated application lifecycle events" lines (AppLinksIosPlugin, FlutterWebAuth2Plugin, FLTGoogleSignInPlugin): framework notices at startup, not errors.
- UIKit `focusItemsInRect` lines: OS debug noise, not the app's own output (dropped from the redacted log anyway).
- Every other error/warning line is in a Finding: EmailVerificationRequiredException and InvalidVerificationCodeException (01-005), DashboardTargetsAnomaly (01-006), SlowOperation deferred.notifications (01-010).

## Leftover accounts
None. All three users (8fbd939d, 6c8552d2, ef00796d) were deleted through the app; `CRED` rows set to `deleted`.
