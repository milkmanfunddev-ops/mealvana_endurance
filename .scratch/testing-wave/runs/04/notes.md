# Ticket 04, run w4-20260924T0418Z: notes

Device: pool simulator wave-pool-1 (03DCC14A-…), iOS 26.2. App uninstalled before each run.

## Setup (not app problems)
- The worktree had no `.env*` files. As in ticket 02, the run wrote a gitignored `.env.dev.local`
  from public values fetched by API (dev URL, anon and publishable keys from the Management API,
  the Test Store and dev App Store public keys from RevenueCat), plus empty `.env` and
  `.env.prod.local`. Sentry, Mixpanel and integrations stayed empty.
- Driven with idb (taps, text, accessibility tree) and `simctl io screenshot`. `idb ui text`
  dropped most of a 50-character address in one call; typing it in 6-character chunks worked.
- Build lock held twice: the `run_dev.sh` build (released at "Flutter run key commands") and the
  Patrol build (released at "Completed building").

## What happened, in order (UTC)
- 04:20 `run_dev.sh` build; 04:25 app on the welcome screen. No notification prompt was seen.
- 04:26–04:27 onboarding: Running, performance goal, gut-issues pitfall, "I don't use training plan
  apps", female, metric, gut high, sweat heavy, plan reveal (no edit), daily preview, Save My Plan.
  Personal info was empty (02-001 did not recur on a freshly uninstalled app), and the Riverpod
  assertion of 02-002 did not appear in the console.
- 04:27:35 account A signed up: lee+e2e-04-20260924T0426Z@… (stored lowercased by Supabase), id
  a92da7e2-4198-4090-942b-5c590702473a, confirmed at creation. Landed on `/paywall?onboarding=1`.
- Paywall: no close or back control; an edge swipe from the left did not leave it
  (15-paywall-after-edge-swipe.png). ⋯ menu: Restore purchases, Redeem code, Sign out, Delete
  account; no Manage subscription (16-paywall-menu.png). Matches mp-494 for an account with nothing
  to manage.
- 04:28:30 SQL: users 1 (onboarding_completed true, female/metric/high/heavy), survey 1,
  user_entitlements 0 (db-A-on-paywall.txt). RevenueCat: customer exists, no active entitlements,
  no subscriptions (revenuecat-A-on-paywall.json). Both as expected.md says.
- 04:28:55 ⋯ → Delete account → Delete. Welcome screen; delete-user logged success
  (edge-logs-A.txt); footprint empty (db-A-after-delete.txt). The RevenueCat customer stays
  (known, 02-005).
- 04:40–04:45 Patrol `onboarding_signup_flow_test` on a fresh install: passed, 42 steps, 1 test,
  0 skipped (patrol-signup.log). Its account (id d0fa0e02-…) deleted itself from the paywall menu;
  footprint empty (db-P-after-flow.txt, edge-logs-patrol.txt).

## 03-009 did not reproduce
The flow drags the long-run slider on the plan reveal and asserts that
`nutrition_target_overrides.duringRun` is set after signup. That assertion passed this run, where
ticket 03 saw null. The account is deleted, so the row can no longer be read. Triage should decide
whether 03-009 needs a retest before it is closed; this run does not close it.

## Console lines and what they are
- Swift Package Manager and UIScene lifecycle warnings at build: toolchain noise.
- No error or exception lines in `console.log` from launch to the delete.
- `settings_delete_account_tapped` for the paywall delete: Finding 04-001.

## Look-around, per screen
Welcome, Sports, Goals, Pitfalls, Connect training, Personal info, Body composition, Nutrition
settings, Plan reveal, Daily plan preview, Create Your Account, Sign Up with Email, Paywall and its
⋯ menu, the delete confirm. Followup-tests 04-002 to 04-007 and ideas 04-001, 04-008. Paths already
listed by tickets 02 and 03 (existing address, delete cancel, offline delete, Lapsed delete, verify
code) were not written again.
- The debug build shows two floating dev buttons ("Open testing tools", "Show accessibility
  issues") that sit over the right end of Continue on onboarding steps. Dev-only, noted, not a
  Finding.
