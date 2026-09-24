# Ticket 08, run w7-20260924T1216Z: notes

Device: pool simulator wave-pool-1 (DBA3F10A-…), iOS 26.2, freshly cloned from the dev simulator
(`reused: false`). The app was uninstalled before the build. Simulator clock: CDT (UTC-5).

## Setup (not app problems)
- The worktree had no `.env*` files. `.env.dev.local` was copied from the main clone. `.env` and
  `.env.prod.local` were created empty, because pubspec bundles both but the dev entry point loads
  only `.env.dev.local` (the main clone's `.env` holds prod refs, so it was not copied).
- The device was driven with idb (accessibility tree taps, `idb ui text`) and `simctl io`
  screenshots, as tickets 05 and 06 did. The mobile MCP was not tried.
- Locks: slot 12:16:36Z. Simulator claimed first try (~12:18Z). Build lock 12:19:06Z → 12:23:42Z
  (released at "Flutter run key commands"; "Xcode build done 136.0s"). Patrol build under the lock
  12:38:34Z → 12:43:05Z (released at "Completed building", 237.6 s).
- `timeout` is not installed on this Mac (the first Patrol start at 12:38:42Z failed with
  "command not found: timeout", exit 127, before building). Patrol ran under
  `perl -e 'alarm shift; exec @ARGV' 900 patrol test …` instead. Known noise: a tool gap on the Mac,
  not the app; the prompt's `timeout 900` example assumes coreutils.
- A shell wait loop written for bash failed under zsh (`condition expected: >`) and spun from
  12:28:39Z to 12:35:23Z. Known noise: my own script. Cost: the planned "reopen at 12:32:10Z" check
  ran at 12:35–12:37Z instead (see below); the renewal at 12:31:39Z was **not seen live**.
- **Scratchpad clash, Finding 08-006.** Ticket 09 wrote `ui.py`, `rc.sh`, `sql.sh` and `pw` to the
  same scratchpad folder at 12:28–12:31Z. From then my `ui.py` pointed at 09's simulator and my
  `rc.sh` asked RevenueCat for a concatenated id (`resource_missing` at 12:35:33Z and 12:35:42Z;
  the files `revenuecat-D-1235-failed-read-*.txt` hold those failed reads, not a real missing customer; the
  RevenueCat MCP found customer D at 12:36Z). My one `ui.py tap "Back"` at 12:35:41Z against 09's
  device found no match, so nothing was tapped there; `ui.py ls` read 09's screen once. From
  12:36Z all helpers live in `scratchpad/t08/` with my UDID. A `bash -x` trace printed 09's
  `rc.sh`, which exposed the RevenueCat secret key in this agent's transcript (no repo file).
- **Console, Finding 08-007.** After Manage subscription sent the app to Safari (12:27:52Z), flutter
  run lost the debug connection at about 12:28:2xZ (console.log line 475). The app kept running.
  From 12:36:50Z the Flutter lines come from `simctl spawn … log stream` in console-oslog.log.
  12:28–12:36Z has no console.

## What happened, in order (UTC)
- 12:23:38 app on welcome. 12:24–12:25 onboarding with ticket 05/06's answers (Running,
  performance, no pitfalls, no training app, female, defaults, gut high, sweat heavy, plan reveal,
  daily preview, Save My Plan).
- 12:25:35 account D signed up: lee+e2e-08-20260924T1225Z@… (stored lowercased), id
  5f96cc61-71c9-4b43-82fd-a6cb16b85647, confirmed at creation. Landed on the onboarding paywall.
  Row added to the credentials file at once. No auth email was sent (auto-confirm).
- Before-checks: users 1, `user_entitlements` 0 (db-D-before-purchase.txt); RevenueCat customer
  with no entitlement or subscription (revenuecat-D-before-purchase.txt). As expected.
- Paywall ⋯ before purchase: Restore purchases, Redeem code, Sign out, Delete account; no Manage.
  Matches mp-494 for an account with nothing to manage (04-paywall-menu-before-purchase.png).
- 12:26:38 Monthly → Continue → Test Store sheet → "Test valid purchase". What's New over the
  timeline. **Paid window: purchase 12:26:38Z; the 20-minute limit was 12:46:38Z.**
- 12:26:52 RevenueCat: `pro` until 12:31:39.125Z; one `test_store` `sandbox` subscription, active,
  `will_renew`, period 12:26:39–12:31:39. Row at 12:26:57Z: `active_until 12:31:39.125`,
  `period_type NORMAL`, `event_at 12:26:39.313` (webhook under 1 s). They match.
- 12:27:23 Settings → Subscription: **"Subscribed", "Renews on September 24, 2026."**, Manage
  subscription, Redeem code, the Pro list; no Upgrade. RevenueCat's expiry 12:31:39Z is 07:31 CDT on
  24 September, so the date equals RevenueCat's. The plan is not named (08-001).
- 12:27:32 Redeem code → our own "Redeem a code" sheet (title, "Enter the code you were given.",
  field, Redeem); no App Store sheet. The X has no accessibility label (08-002). X closed it; the
  screen was unchanged.
- 12:27:52 Manage subscription → Safari at account.apple.com sign-in (08-003). RevenueCat's
  `management_url` for the subscription is null, so the app used its fallback
  `https://apps.apple.com/account/subscriptions`. 12:28:27 back to the app via the status-bar
  "◀ Endurance Dev"; the screen read the same.
- Period end 12:31:39Z. The row stayed at 12:31:39.125 until a renewal with `event_at 12:35:12.017`
  moved it to 12:36:39.125: 3.5 minutes with the server-side row past its end. Known, 06-002 and
  07-003; no new Finding.
- 12:35:4x one tap (idb, my UDID) on the Subscription screen hit nothing actionable (the ui.py
  Back had gone to the wrong device). 12:37:1x Back → Settings → Subscription: the app logged
  `customer info updated {active: true, expires_at: 12:41:39}` at 12:37:11.8 and RevenueCat's
  renewal `event_at` is 12:37:11.569, 32 s after the 12:36:39 period end and the same second as the
  app's fetch. Known, 07-003 (renewals landing with an app fetch); no new Finding.
- 12:37:14 screen "Renews on September 24, 2026."; RevenueCat 12:37:15Z: `pro` until 12:41:39Z
  (07:41 CDT, 24 September), subscription active `will_renew`; row `active_until 12:41:39.125`. They
  match. **All paid checks done by 12:37:15Z, 10.6 min after the purchase; no lapse during them.**
- 12:38:06 Settings → Delete Account → Delete. Welcome. 12:38:13Z auth 0, users 0,
  entitlements 0. RevenueCat still holds the customer and the renewing subscription (known 02-004,
  02-005). Credentials row set to `deleted`.

## Criteria against the run
- Dates on screen equal RevenueCat's: yes, twice (12:27:23Z and 12:37:14Z), to the day, which is
  all the screen shows (`DateFormat.yMMMMd`). The Test Store's 5-minute periods mean a day-level
  check cannot see a renewal move the date; 07-008 already notes that.
- Manage subscription shows: yes. Redeem code opens its sheet: yes.
- "Sees the plan they bought": the screen says "Subscribed" only (08-001, ssot-conflict vs mp-628).

## Console lines and what they are
- console.log (flutter run, 12:19–12:28Z): SPM and UIScene warnings at build (toolchain noise).
  No error or exception lines. Line 475 is the lost debug connection (08-007).
- console-oslog.log (12:36:50Z on): `customer info updated`, analytics lines. No error or exception
  lines.
- Token scan over every log and txt file in runs/08: see the commit step.

## Look-around, per screen
Onboarding, Create Your Account, the paywall and the Test Store sheet were walked as in tickets
04–06; covered by their Findings.
- Paywall ⋯ (new account): matches mp-494; its items are covered by 02-016, 04-003, 11-*.
- Settings (paid): covered by 06-007, 02-004.
- Subscription (paid): other states (cancelled, ended, Grants) 08-004; return from Manage, double
  tap, offline 08-005; plan name 08-001; Home and resume 07-011; Redeem with Pro 11-010.
- Redeem a code sheet: the close label 08-002; sheet paths 11-007.
- Manage subscription (Safari): 08-003.
- Delete Account dialog: cancel and offline covered by 02-009, 02-015.

## Patrol: integration_test/flows/subscription_screen_flow_test.dart
Written by this run, listed in `runner_exclusions.json` as clean-install and in
`integration_test/README.md`. `flutter analyze` on the file is clean and
`node --test test/scripts/patrol-targets.test.mjs` passes 11/11. It signs up
`lee+e2e-subscription-<millis>`, buys Monthly in the Test Store, reads the Entitlement row as the
account, opens Settings → Subscription and checks "Subscribed", no Upgrade, a "Renews…" date line
naming the row's `active_until` local day, Manage subscription, and Redeem code opening the "Redeem
a code" sheet and closing back to the same screen; then deletes itself from Settings and checks it
can no longer sign in. Tapping Manage stays agent-only.
- Run 1 (12:38:34Z start, 237.6 s build, test 12:43:2xZ): **passed 1/1, 44 steps, 0 skipped,
  1m 9s**, exit 0 (patrol-subscription-run1.log). No `lee+e2e-subscription-*` account is left on
  dev (db-P-after-flow.txt, 12:44:37Z).

## Release
Simulator wave-pool-1 released 12:44:39Z (app terminated, flutter run and the log stream stopped
first); build lock and slot released the same second; `lock.mjs list` then showed only
testing-wave-09's slot.
Token scan (`eyJ…`, `Bearer `, `sk_`, `sbp_`) over every log, txt and md file in runs/08: no hits.
