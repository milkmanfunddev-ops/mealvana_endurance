# Ticket 06, run w6-20260924T1117Z: notes

Device: pool simulator wave-pool-1 (2C88D1D5-…), iOS 26.2, cloned from the dev simulator. The app
was uninstalled before the build.

## Setup (not app problems)
- The worktree had no `.env*` files. `.env` and `.env.dev.local` were copied from the main clone.
  `.env.prod.local` was created empty because pubspec bundles it. The prod file was not copied.
- The run drove the device with idb (taps from the accessibility tree, `idb ui text`) and
  `simctl io` (screenshots, screen recordings), as ticket 05 did. The mobile MCP was not tried.
- `idb ui text` dropped most of the email address on the first signup try ("lee+e"). The field was
  cleared and retyped in 8-character chunks. Known noise: an idb typing race, not the app.
- Locks: slot 11:17:27Z. Simulator claimed 11:18:57Z after a 49 s wait. Build lock 11:19:15Z →
  11:24:34Z (released at "Flutter run key commands"; "Xcode build done 140.1s"). Patrol builds
  under the lock: 11:38:50–11:42:54Z (226.0 s), 11:56:13–11:58:08Z (72.4 s), 12:00:26–12:01:54Z
  (69.0 s), each released at "Completed building". The simulator and slot were released at
  12:03:22Z, and `lock.mjs list` was empty after that.
- RevenueCat reads went through the RevenueCat MCP. The run's scratch curl helper answered
  `resource_missing` for every customer path because it loaded the key or project wrongly. A
  plain curl with the same key answered 200 at 11:43Z. So the REST API works; this is not a
  harness Finding. The one cost is that customer C was not read before the purchase (see
  revenuecat-C-before-purchase.txt).
- Edge logs were read from `GET /v1/projects/{ref}/analytics/endpoints/logs` (unified `logs`
  table), as ticket 05 did (05-006).

## What happened, in order (UTC)
- 11:24:29 app on the welcome screen. 11:25–11:26 onboarding with ticket 05's answers: Running,
  performance, pitfalls skipped, "I don't use training plan apps", female, defaults, gut high,
  sweat heavy, plan reveal, daily preview, Save My Plan.
- 11:26:56 account C signed up: lee+e2e-06-20260924T1126Z@… (stored lowercased), id
  d3d962e6-c7d4-4e11-b6ff-60ee59079540, confirmed at creation. It landed on the onboarding
  paywall. The row went into the credentials file at once.
- 11:27:26 before-checks: users 1 (onboarded), `user_entitlements` 0. The console showed
  `customer info fetched {active: false}`.
- 11:28:25 Monthly → Continue → Test Store sheet. 11:28:36 "Test valid purchase", screen recorded.
  RevenueCat: `pro` until 11:33:37.722Z, subscription `test_store`, `sandbox`, active,
  `will_renew`. Row: `active_until` 11:33:37.722, `period_type NORMAL`. They match. The webhook
  INITIAL_PURCHASE landed at 11:29:02Z, 25 s after the purchase (ticket 05 saw about 1 s).
  **Paid window: purchase 11:28:36Z; the 20-minute limit was 11:48:36Z.**
- After the purchase: the sheet closed, the paywall showed its spinner for about 1.4 s, then
  **Continue was enabled for about 0.8 s** before the timeline and the What's New sheet. This is
  05-004 again, with a shorter live window (05 saw 2.4 s). Known, 05-004; no new Finding. Evidence:
  18-purchase-to-app-frames.png, 18b-purchase-frames-5fps.png.
- 11:30:20 Settings → Sign Out → confirm. Welcome at once, no paywall frame
  (19-sign-out-frames-5fps.png). The dialog promises guest mode (06-003). RevenueCat and the row
  were unchanged.
- 11:31:12 I already have an account → Log in with email → Log In. Timeline, no paywall frame
  (20-sign-in-frames-5fps.png). One frame of the form with Log In enabled came first. Known, 12-003, so no new Finding.
  Console: no new `[RevenueCatService] logged in` line at sign-in. The SDK had kept C since
  before sign-out (line 477, `customer info updated {active: true}` on welcome, 03-002's issue),
  so this sign-in did not test a change of account (06-004).
- 11:31:40 `simctl terminate` (flutter run ended "Lost connection to device", as expected).
  11:31:52 `simctl launch`: splash, spinner, one black frame (06-006), timeline. No paywall frame.
  The router waited about 1.4 s for RevenueCat (06-001, which answers 05-007). The iOS
  notification prompt showed over the timeline on this second launch. On the first launch of the
  install it did not show. Known, 03-004 (it asks on every launch until answered). "Don't Allow"
  was tapped.
- 11:32:28 / 11:32:35 row and RevenueCat unchanged after sign-out, sign-in and relaunch:
  one subscription, same id, same period, no new customer. **All paid checks were done by
  11:32:35Z, 4 minutes after the purchase.**
- 11:33:37 period end. The row stayed at 11:33:37.722 until the RENEWAL webhook at 11:36:13Z moved
  it to 11:38:37.722. For 2.5 min the server's view had lapsed (06-002).
- 11:33:39 Settings → Subscription: "Subscribed, Renews on September 24, 2026", Manage
  subscription, Redeem code. It was right for a Test Store monthly (5-minute periods), so nothing
  was filed. Manage for Test Store is 05-008.
- 11:37:02 Settings → Delete Account → Delete. delete-user 200 at 11:37:03Z. Welcome. auth, users
  and entitlements rows are 0. RevenueCat keeps the customer and the renewing subscription, which
  is known, 02-004. Later webhooks for C answered "user … not in this project, ignoring event",
  200. That is correct handling, not a Finding. Credentials row set to `deleted`.

## Criteria against the run
- Sign out, sign in and terminate+relaunch each landed in the app with no paywall frame. RevenueCat
  and the Entitlement row were unchanged across all three (only the expected renewal moved them
  afterwards). All within 4 minutes of the purchase. No lapse happened during the checks.
- Account deleted in the app. The delete succeeded.
- The screen recordings were cut into 5 fps frame sheets and deleted (up to 27 MB each).

## Console lines and what they are
- console.log (flutter run, 11:19–11:31:40Z): Swift Package Manager and UIScene lifecycle
  warnings at build, which are toolchain noise. No error or exception lines.
- console-relaunch.log (`simctl launch --console-pty`) holds only native stdout:
  `Engine creation error: … CoreHaptics Code=-4815` (the simulator has no haptics engine;
  known noise) and a OneSignal "unable to fetch user with External ID nil" warning (no OneSignal
  login on dev; noise).
- console-relaunch-oslog.log (the Flutter lines after relaunch, from the simulator's unified log):
  `[RevenueCatService] logIn skipped: SDK not configured` twice before `configured`. This is startup
  ordering; the `logged in` line follows 50 ms after `configured`, with no visible effect. Noted,
  not a Finding. No error or exception lines.
- Token scan (`eyJ…`, `Bearer `, `sk_`, `sbp_`) over every log and txt file in runs/06: no hits.

## Look-around, per screen
Onboarding and Create Your Account were walked as in tickets 04 and 05 and are covered by their
Findings. Paywall, Test Store sheet: covered by 04-005, 05-004, 05-010. New this run:
- Settings (paid): Sign Out cancel and offline sign-out (06-007). Delete while subscribed is 02-004.
- Sign Out dialog: its copy (06-003).
- Welcome / Log In options / Email Log In: wrong password first (06-008), a change of account
  (06-004; see also 12-007). The Log In button live before navigation is 12-003.
- Timeline after a cold relaunch: offline (06-001), black frame (06-006).
- Subscription (paid): see above; nothing new.

## Patrol: integration_test/flows/paid_relogin_flow_test.dart
Written by this run (a build-time decision in the report), listed in `runner_exclusions.json` as
clean-install and in `integration_test/README.md`. `flutter analyze` is clean, and
`node --test test/scripts/patrol-targets.test.mjs` passes 11/11. It signs up
`lee+e2e-relogin-<millis>`, buys Monthly with a native tap on "Test valid purchase", signs out
and back in while pumping every 100 ms and failing if `paywall.screen` ever exists, reads the
Entitlement row as the account before and after, then deletes itself from Settings. Cold start
stays agent-only (Patrol runs inside the app's process).
- Run 1 (11:43Z) failed at step 30: `waitUntilVisible` on the tab bar under the What's New scrim.
  The purchase had opened the Gate (25-patrol-stuck-state.png). Patrol then hung until it was
  killed at 11:55Z, and the simulator shut down with it and was booted again.
- Run 2 (11:59Z) failed at step 37: the Welcome "Log in" tap came during the sign-out transition
  and was dropped.
- Both were flow bugs, fixed in the flow and not in the app. Each left a paid throwaway account.
  Each was deleted alone through `sweep-accounts.mjs`'s own delete path, filtered to its id,
  because a whole-dev sweep could have hit ticket 07's live account.
- Run 3 (12:02Z): **passed 1/1, 49 steps, 0 skipped, 1m 8s**. It deleted itself (delete-user
  200 at 12:02:59Z), and no relogin accounts are left (db-P-after-flow.txt).
