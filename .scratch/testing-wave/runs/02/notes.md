# Ticket 02, run w2-20260923T1442Z: notes

Device: pool simulator wave-pool-1 (ED26CF8C-…), iOS 26.2, dev debug build (`scripts/run_dev.sh`).

## Setup the run needed (not app problems)

- The worktree has no `.env*` files, and the build bundles `.env`, `.env.dev.local` and
  `.env.prod.local` as assets. The run wrote a minimal gitignored `.env.dev.local` from public
  values fetched by API (dev URL, dev anon and publishable keys from the Management API, the
  Test Store public key from RevenueCat) plus empty `.env` / `.env.prod.local`. No file was read
  from the main clone for this. Everything else in the env (Sentry, Mixpanel, integrations) was
  left empty.
- The first launch used the anon key from `TestConfig`'s default, which is stale; signup failed
  with `Invalid API key` (Finding 02-007). The app was rebuilt with the live key under the build
  lock. That first console is kept as `console-launch1.log`.
- The mobile MCP could not drive this device ("Agent is not installed on the device"), so the run
  used idb for taps, text and the accessibility tree, and `simctl io screenshot` for pictures.
  `idb ui text` parses a chunk that starts with `-` as a flag and drops it; type with `--`.

## What happened, in order (UTC)

- 14:50 address chosen: lee+e2e-02-20260923T1450Z@rightpathprogramming.com.
- 14:55:45 account A signed up (e7ab5001-cfa4-4fe6-8876-5c0a092a0e11), confirmed at creation
  (dev `mailer_autoconfirm` is on, so no signup code is sent). Landed on the paywall's onboarding
  shape; ⋯ menu: Restore purchases, Redeem code, Sign out, Delete account (no Manage), as mp-494.
- 14:56:37 paywall ⋯ → Delete account → Delete. delete-user logged success; footprint empty.
- 14:58:32 same address signed up again: account A2 (a816e3ba-552c-437f-ac06-fede919b534c), a new
  id, no entitlement row, paywall shown.
- 14:59:48 A2 signed out from the paywall menu, then Log in with email → Forgot Password → code
  requested; the Gmail tool found it at 14:59:50 (gmail-reset-code.md). Code entered, password
  reset, signed in again: paywall (never paid).
- 15:01:17 Test Store "valid purchase" of Monthly. The dev webhook wrote `user_entitlements` with
  `active_until` 15:06:18.067, equal to RevenueCat's expiry: Test Store purchases DO reach the dev
  webhook (one of the spec's open unknowns). Test Store monthly periods are 5 minutes.
- 15:02:27 Settings → Delete Account → Delete. delete-user logged success; footprint empty,
  including user_entitlements, token_wallets, token_ledger and daily_macro_targets.

## Console lines and what they are

- `Invalid API key` (console-launch1.log): the stale key in the run's own env, Finding 02-007.
- Riverpod "Tried to modify a provider while the widget tree was building": Finding 02-002.
- `[SETTINGS] Pro entitlement clear failed`: Finding 02-003.
- Build-time plugin warning about Swift Package Manager adoption: toolchain noise.
- At first launch, before any sign-in, `[SubscriptionService] customer info updated {active: true,
  expires_at: 2027-09-15…}`: the signed-out RevenueCat anonymous customer on this cloned simulator
  holds an active entitlement. It did not open the Gate for either new account; noted, not a
  Finding.

## Look-around, per screen

Welcome, the onboarding steps, Create Your Account, Sign Up with Email, Paywall and its ⋯ menu and
confirms, Log In, Forgot Password, Enter Reset Code, Set New Password, the Test Store sheet,
Timeline (first screen past the paywall) and Settings (Account section) were visited. The
followup-test Findings 02-008 to 02-017 list the other paths.
- 15:07:12 the Test Store renewed the deleted A2's subscription; the webhook ignored it (user not in this project) and wrote nothing (Finding 02-004).
