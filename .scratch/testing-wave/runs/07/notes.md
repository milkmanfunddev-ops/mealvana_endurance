# Ticket 07, run w6-20260924T1118Z: notes

Device: pool simulator wave-pool-2 (BFD4CE4C-…), cloned from the dev simulator, iOS 26.2. The app
was uninstalled before the build.

## Setup (not app problems)
- `.env` and `.env.dev.local` copied from the main clone; an empty `.env.prod.local` written
  (pubspec lists it as an asset). All gitignored.
- Slot claimed 11:18:03Z. The first simulator claim (11:18:19Z) threw `EEXIST` on the claims lock
  while ticket 06 was cloning its device (07-005); a shell loop waited for the lock and the claim
  went through at 11:20:50Z.
- Build lock: waited 11:20:56Z-11:24:58Z (ticket 06 building). `run_dev.sh` started 11:25:00Z;
  "Xcode build done. 149.6s"; "Flutter run key commands" at 11:28:47Z; lock released 11:28:52Z.
- Driven with idb (describe-all, tap, text in 6-character chunks) and `simctl io` screenshots.
  The mobile MCP was not used.
- Tools: RevenueCat v2 API with the secret key, the RevenueCat MCP for customer events, SQL through
  the Management API `database/query`, edge logs through `analytics/endpoints/logs` on the unified
  `logs` table (the way 05-006 describes; `function_logs` as a table name fails there).

## What happened, in order (UTC)
- 11:28:47 app on the welcome screen. 11:29-11:30 onboarding with ticket 05's answers: Running,
  performance, pitfalls skipped, "I don't use training plan apps", female, metric, gut high, sweat
  heavy, plan reveal (no edit), daily preview, Save My Plan. Personal info was empty.
- 11:31:03 account C signed up: lee+e2e-07-20260924T1130Z@… (stored lowercased), id
  6f9ea9ac-e299-494a-9adb-bd63bd48d1b7, confirmed at creation. Row added to the credentials file.
  The paywall's first frame is its opening clip (`paywall.clip`, "Mealvana Endurance in use…"),
  then the plans: by design, not a Finding.
- 11:31:37 before-checks: users 1 (onboarded), `user_entitlements` 0; RevenueCat customer, no
  active entitlement, no subscription, no purchase. As expected.md says.
- 11:31:55 Monthly → Continue → Test Store sheet (`mealvana_pro_monthly`, $9.95, 1 month) → "Test
  valid purchase". The What's New sheet over the timeline.
- 11:32:09 RevenueCat: `pro` active to 11:36:56.226Z; one subscription `subTst4076cb8f…`,
  `test_store`, `sandbox`, active, will_renew. Row: `active_until 11:36:56.226`, `NORMAL`. Equal.
  Webhook INITIAL_PURCHASE at 11:31:57Z.
- 11:32:32 flutter run stopped (killed; the app went with it). `simctl uninstall`, then
  `simctl install` of the same `build/ios/iphonesimulator/Runner.app`: 1 s in all. No rebuild.
- 11:32:38 `simctl launch --console-pty`: the debug build started on its own (no flutter tool
  needed on a simulator). `--console-pty` caught only two native lines (console-reinstall.log), so
  a `simctl spawn … log stream` for process Runner was started (device-reinstall.log); it holds the
  Flutter `print` lines from 11:33Z on. From here the evidence is that log, not flutter run.
- 11:32:50 welcome screen (the reinstall is signed out). I already have an account → Log in with
  email → C's address and password → 11:33:23 Log In.
- 11:33:24-26 the SDK went `active: false` (anonymous install) then `active: true, expires_at
  11:36:56` after `logIn`; router `going to /main`. No paywall frame (09-after-login-frames.png).
  The Restore branch was not needed (07-001). The What's New sheet showed again (07-009).
- 11:33:43 RevenueCat after the sign-in: the same single subscription (same id, same `starts_at`),
  purchases empty. The row unchanged. No second INITIAL_PURCHASE. Criterion 3 passes on its
  first branch.
- 11:34:26 terminate + cold relaunch: no paywall frame (11-cold-relaunch-frames.png). The
  notification prompt came up at launch (known, 03-004); Don't Allow.
- 11:34:55 Settings → Subscription: "Subscribed", "Renews on September 24, 2026.", Manage
  subscription, Redeem code (07-008).
- 11:36:56 the first period ended. 11:37:45, 11:38:16 and 11:38:37 reads: no renewal, row still
  11:36:56, and at 11:38:37 no active entitlement in RevenueCat (07-003). The customer events API
  returned an empty list for C throughout (the webhook logs stand in for it).
- 11:38:47 Home + resume: the open Subscription screen stayed, no refetch.
- 11:39:00 terminate + cold relaunch: the saved copy said `active: true` with `expires_at 11:36:56`
  (07-002), then the fetch returned 11:41:56. The RENEWAL `event_at` is 11:39:04.351, the second of
  that fetch (07-003). Still one subscription, same id and start.
- 11:39:59 Settings → Delete Account → Delete (one confirm): welcome screen. delete-user 200;
  `auth.users`, `users`, `user_entitlements` 0 for C. RevenueCat keeps the customer and the
  subscription stays `will_renew` (known: 02-004, 02-005). Credentials row set to `deleted`.
- 11:41:51-11:43:21 waited for the build lock (ticket 06), then Patrol (below). "Completed
  building … (242.0s)" at 11:47:45Z; lock released 11:47:48Z. Test passed 11:48:44Z.
- 11:49:02 simulator released, slot released. `lock.mjs list` shows only ticket 06's slot.

## Timing against the 20-minute paid window
Purchase 11:31:55Z. Reinstall done 11:32:33Z (38 s after), sign-in 11:33:24Z, RevenueCat
compared 11:33:43Z, delete 11:39:59Z (8 min after purchase). No lapse inside the window.

## Criteria against the run
- Criterion 1: slot, build lock (twice) taken and released; console.log (flutter run, to 11:32Z)
  and device-reinstall.log (after the reinstall) saved; look-around below; nothing fixed.
- Criterion 2: own account, credentials row, Test Store Monthly bought at the start, deleted in the
  app at the end with no error.
- Criterion 3: after uninstall and reinstall, sign-in opened the app on its own; RevenueCat shows
  one subscription and no second purchase. "Restore opens it" could not arise with the Test Store
  (07-001); the Restore item itself was exercised by the Patrol flow on a new account (nothing to
  restore, as it should).

## Console lines and what they are
- console.log (flutter run, 11:25-11:32Z): Swift Package Manager and UIScene warnings at build,
  toolchain noise. No error or exception lines after launch.
- device-reinstall.log is the whole unified log for process Runner, so it is mostly system noise:
  Accessibility notifications, `UIFocus` "focusItemsInRect" lines, CoreHaptics
  `hapticpatternlibrary.plist` missing (simulator has no haptics), `nw_connection` endpoint lines,
  Metal compiler warnings, `app_launch_measurement`, locationd. All simulator/OS noise.
- RevenueCat SDK: `Using a Test Store API key` (expected on dev), `appUserID passed to logIn is the
  same as the one already cached` (a repeat logIn at cold launch; no effect seen), `credits`
  packages with "unknown duration" (one-time packs), and the `founding` offering with no packages
  (07-004).
- `console-reinstall.log` (from `--console-pty`): "Unable to create restoration in progress marker
  file" and "Engine creation error: … CoreHaptics Code=-4815": simulator noise.
- Token scan (`eyJ…`, `Bearer `, `sk_`, `sbp_`) over every log and extract in this folder: nothing found, so the logs are committed whole.

## Look-around, per screen
Onboarding, Create Your Account, Sign Up with Email and the onboarding paywall were walked the same
way as tickets 04 and 05; their other paths are already Findings (02-0xx, 04-002..007, 05-010) and
were not written again. New or different this run:
- Log In after a reinstall: offline, wrong password, Apple/Google, Lapsed account (07-007). The
  fully enabled Log In frame after the tap is 12-003.
- Timeline after a reinstall: What's New again (07-009); cold relaunch (no paywall frame, as 05-007
  hoped); the notification prompt (03-004).
- Settings: Delete Account for a paid account (one confirm; subscription keeps renewing, 02-004).
  Delete offline is 02-015.
- Subscription screen: plan, price, time (07-008). Redeem code there is 11-010.
- Paywall ⋯ → Restore purchases on a new account: now a Patrol flow (below), closing the gap
  04-003 listed. Restore for a Lapsed account is 05-008; with a real receipt, 07-006.

## Patrol
`integration_test/flows/restore_purchases_flow_test.dart` written and run once: a new
`lee+e2e-restore-<millis>` account on the paywall taps ⋯ → Restore purchases, sees "No active
subscription was found…", stays on the paywall, has no `user_entitlements` row (read as itself),
the menu still has no Manage subscription, then deletes itself from the menu. Passed 1/1, 36 steps,
0 skipped, 58 s (patrol-restore.log); its account 6ddbbc07-… signed up 11:48:30Z and was deleted
11:48:38Z (edge-logs-patrol.txt). Excluded from the M1 runner as clean-install, listed in the
integration_test README. It cannot uninstall and reinstall itself, so the ticket's own scenario
stays agent-only.
