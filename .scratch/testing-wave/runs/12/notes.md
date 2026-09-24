# Ticket 12, run w4-20260924T0417Z: notes

## Setup
- Device: pool simulator wave-pool-2 (200D613D-…), iOS 26.2, claimed fresh (cloned, not reused).
  The dev app on it was uninstalled before the build, so the install was clean.
- Worktree `.env`, `.env.dev.local`, `.env.prod.local` copied from the main clone (gitignored, not
  committed). The Patrol run used a define file in the session scratchpad carrying the admin's
  address and password as `INTEGRATION_TEST_*`; it is outside the repo.
- `scripts/run_dev.sh` started from the Bash tool's background mode exited during the Xcode
  build with no error (`console-attempt1.log`). It was restarted detached with its stdin held
  open; that run (`console.log`) built in 93 s and launched.
- The mobile MCP's agent was not installed on this simulator, so the run tapped and typed with
  idb and took screenshots with `simctl io`.
- A first try at the login put the password in the email field (idb typed before focus moved).
  Those screenshots were deleted before anything was saved; no committed file holds the password
  (checked with a grep for it over the run folder).

## Timeline of the run (UTC)
- 04:17 records read (db-admin-before.txt, revenuecat-admin-before.json).
- 04:40:14 Log In tapped; tabs shell by about 04:40:18. No paywall.
- 04:41:14 app terminated and relaunched with `simctl launch`: splash, then the tabs shell. No
  paywall. The notification prompt showed over the shell (03-004, not filed again).
- 04:42:30 opening Ask Vana fired the opener (vana-chat 200, `vana.opener.general`).
- 04:43:08 one message sent; vana-chat 200, Vana answered (`vana.chat.general`).
- 04:43:44 records read again (db-admin-after.txt, revenuecat-admin-after.json): unchanged.
- Patrol `admin_bypass_flow_test.dart` as the admin: passed, 1/1, 53 s (patrol-admin-bypass.log).
  The flow signed in from the welcome screen (the reinstall dropped the session), saw the shell,
  and `/paywall` stayed on the shell. Its server leg did not run because the account holds Pro.

## Against expected.md
Everything matched expected.md. The account holds three `pro` Grants, so the Gate opened on the
subscription status and the server answered Vana; that is what mp-416 says for an account with a
Grant. The admin-only case the ticket is named for could not be seen: 12-001.

## Cost
Wave 4 `logging` 1/5 and 2/5 were spent by this ticket: the opener that opening Ask Vana fires on
its own, and the one message. Recorded as `logging` because the counter has no chat kind (12-004).
Gateway cost: $0.0214 + $0.0052.

## Console lines and what they are
- `Token refresh failed (status: 400) invalid_grant` (TrainingPeaks) and `Please reconnect your
  V.O2 account` (vdot): stale integrations on test@test.com, as in runs/03/notes.md; environment.
- `⚠️ No intensity distribution hints available` / `No distance data available`: macro engine
  defaults for the admin's planned sessions without distance; informational.
- `Engine creation error: Error Domain=com.apple.CoreHaptics Code=-4815` (console-relaunch.log):
  the simulator has no haptics engine; simulator noise.
- `OneSignalUserManagerImpl.startNewSession() is unable to fetch user with External ID nil`:
  OneSignal before login on relaunch; seen once, no effect on the Gate.
- Standalone relaunch (`simctl launch`) sends Dart prints to neither the pty nor the unified log,
  so the relaunch has no Dart console; the screenshots and edge logs cover it.

## Look-around
Screens visited: Welcome, Log In options, Log In (email), What's New sheet, TrainingPeaks sharing
sheet, Timeline, UI settings (testing tools, by accident), Vana companion.
- Welcome / Log In: login error paths are already 02-010 to 02-013; new: 12-003 (the form comes
  back before the shell), 12-006 (slow network for an Admin with no Pro), 12-007 (Admin signs out,
  a Lapsed athlete signs in).
- What's New and sharing sheets: 12-008.
- Timeline and Vana: 12-002 (testing-tools button over Ask Vana and Send), 12-009 (companion
  paths), 12-004 and 12-005 (ideas).
