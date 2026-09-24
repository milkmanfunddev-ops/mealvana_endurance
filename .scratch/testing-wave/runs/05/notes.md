# Ticket 05, run w5-20260924T0839Z: notes

Device: pool simulator wave-pool-1 (ED953004-…), iOS 26.2. The app was uninstalled before the build.

## Setup (not app problems)
- The worktree had no `.env*` files. As in tickets 02 and 04, the run wrote a gitignored
  `.env.dev.local` from public values fetched by API: the dev URL, the anon and publishable keys
  (Management API), and the Test Store, dev App Store and dev Play public keys (RevenueCat). It also
  wrote empty `.env` and `.env.prod.local` files. Sentry, Mixpanel and the integrations stayed empty.
- The mobile MCP could not drive this device ("Agent is not installed on the device"). The run used
  idb for taps, text and the accessibility tree, and `simctl io` for screenshots and one screen
  recording. The recording (64 MB) was cut down to one frame strip and deleted.
- Slot 08:39Z, simulator 08:41Z, build lock 08:41Z–08:47Z (released at "Flutter run key commands").
  Everything was released at 10:50Z. `lock.mjs list` is empty.
- The wall clock jumped from about 08:52Z to 10:47Z between two steps of this run (cause not known;
  the app stayed in the foreground). That gap is why the renewals and the expiry were seen
  after the fact, from RevenueCat and the webhook logs, rather than live.

## What happened, in order (UTC)
- 08:47 app on the welcome screen. 08:48–08:49 onboarding with the same answers as ticket 04:
  Running, performance, pitfalls skipped, "I don't use training plan apps", female, metric, gut
  high, sweat heavy, plan reveal (no edit), daily preview, Save My Plan. Personal info was empty.
- 08:49:42 account B signed up: lee+e2e-05-20260924T0849Z@… (stored lowercased), id
  9a986318-7cbf-4489-8115-b60850a2bac7, confirmed at creation. It landed on the onboarding paywall.
  Row added to the credentials file at once.
- 08:50:11 before-checks: users 1 (onboarded), survey 1, `user_entitlements` 0; RevenueCat
  customer with no active entitlement and no subscription. As expected.md says.
- 08:50:27 Monthly → Continue. Test Store sheet: product `mealvana_pro_monthly`, $9.95, 1 month, no
  trial or offer text. 08:50:44 "Test valid purchase".
- The paywall stayed up with Continue live for about 2.4 s after the sheet closed, then the
  timeline appeared with the What's New ("Shake to tell us what's wrong") sheet on top (05-004).
- 08:51:17 RevenueCat: `pro` active, `expires_at` 08:55:45.150Z; subscription `test_store`,
  `sandbox`, active, will_renew, period 08:50:45 → 08:55:45. 08:51:21 `user_entitlements`: one row,
  `active_until` 08:55:45.15, `period_type NORMAL`. Equal. Webhook INITIAL_PURCHASE POST 200 at
  08:50:46 (05-001).
- 08:55–09:15 (read afterwards): four RENEWAL events and one EXPIRATION at 09:15:47, all 200. RevenueCat
  set the subscription `expired`, `will_not_renew` after the fourth renewal (05-003). The row
  ended at `active_until` 09:15:45.967.
- 10:48 the foreground app was still on the timeline (05-005). Home + relaunch (resume, not cold):
  the SDK reported `active: false` and the router went to `/paywall`. The ⋯ menu showed Restore
  purchases, Redeem code, Manage subscription, Sign out, Delete account (right for an account that
  has a subscription to manage, mp-494).
- 10:50 flutter run stopped, simulator and locks released. Account B kept (Lapsed), not deleted.

## Criteria against the run
- Criterion 3 asked for "the Gate opens without a paywall flash". The Gate opened, but the paywall
  stayed up and live for about 2.4 s first (05-004). A cold relaunch of a paid account was not
  checked because B had lapsed by then (05-007).
- The ticket's title says "a trial". The Test Store products have no trial (05-002), so the
  purchase was a paid first period, `period_type NORMAL` everywhere.

## Console lines and what they are
- Swift Package Manager and UIScene lifecycle warnings at build: toolchain noise.
- No error or exception lines from launch to the end of the run.
- `[RevenueCatService] logged in` appears four times around signup (lines 461–466). This is the
  same account each time and has no visible effect. Noted here, not a Finding. 03-002 covers the
  SDK's identity on sign-out.
- `auth_token_refreshed` twice with local-time stamps (04:49, 05:48 CDT). These are ordinary
  hourly refreshes during the long idle gap.
- The console scan for tokens (`eyJ…`, `Bearer `, `sk_`, `sbp_`) found nothing, so `console.log`
  is committed whole.

## Look-around, per screen
Onboarding (Welcome through Create Your Account and Sign Up with Email) was walked the same way as
ticket 04, whose Findings 04-002 to 04-008 and ticket 02's already cover its other paths. None were
written again. New screens and states this run:
- Paywall (onboarding, new account): double Continue and Continue during the post-purchase window
  (05-010). Cancel and failed purchase are already 04-005.
- Test Store sheet: failed purchase and cancel are already 04-005.
- Timeline (first entry after purchase): cold relaunch without a paywall frame (05-007); the −229
  kcal net balance on an empty day (05-009). The What's New sheet stacking is already 12-008.
- Paywall (Lapsed) and its ⋯ menu: Manage, Restore and Redeem for an expired Test Store
  subscription (05-008). Deleting a Lapsed account is already 02-016.

## Patrol
`integration_test/flows/paywall_purchase_flow_test.dart` (the ticket's Touches line) was not
written. The criteria do not ask for it, and the run's findings change what it would need. The
Test Store sheet is a native alert with the buttons "Test valid purchase", "Test failed purchase"
and "Cancel", which `$.native` can tap. The webhook lands the row within about 2 s. A paid
account stops being paid after about 25 minutes. See the report for the proposal.
