# Ticket 125 expected records (wave 37, run w37-20260926T0221Z)

From the ticket and the Finding files it names. The run is judged against this.

## Accounts this run makes
- A `lee+e2e-125-…` bought **monthly** through the Test Store, signed out to lapse (#80).
  - Before lapse: RevenueCat active `pro` entitlement, `user_entitlements` row with a matching expiry.
  - After lapse (about 5 min after sign-out): RevenueCat entitlement expired; `user_entitlements` expiry in the past.
- B `lee+e2e-125-…` bought **Annual** through the Test Store (stays paid for the run).
  - RevenueCat active `pro`, `user_entitlements` expiry about 1 h out (Test Store annual period).

## Per check
- 02-009: after every Cancel / tap-outside on a delete dialog: auth.users 1, public.users 1, session kept.
- 02-015 / 02-008 (offline delete): the app refuses or says the account was not deleted; it does not wipe
  local data and sign out while the server account survives. auth.users and public.users rows remain => fail
  if the app lands on Welcome silently.
- 02-016 (lapsed delete from paywall ⋯): auth.users 0, public.users 0, user_entitlements 0; RevenueCat
  customer gone (404) or noted.
- 02-010: log in with a deleted address + old password: plain "wrong email or password" style error, no crash,
  no half-signed-in state.
- 06-007: Sign Out → Cancel: nothing changes. Offline Sign Out: Welcome, never the paywall. Online sign-in: app (mp-335).
- 06-008: wrong password: error, still on Log In; right password: app, no paywall frame.
- 07-007 (after data wipe): offline login: plain offline message; wrong then right: error then app; Apple/Google:
  reach the sheet only; lapsed account: full-screen paywall with ⋯ (Restore, Redeem code, Manage, Sign out,
  Delete account; mp-494); Restore finds nothing, Gate stays closed.
- 31-012: test@test.com comes back to its own data; a different account sees only its own data and subscription.
- 12-008: What's New, then TrainingPeaks sharing sheet (only with an active training_peaks integration); each
  shows once, closes by swipe or button.
- 07-009: note whether What's New shows again after a wipe for an account that dismissed it (per device vs per account).
- 31-010: note when the iOS notification prompt shows; after Allow, `users.notifications_enabled` (map: nothing written).

## test@test.com
Signed out and back in only. No other writes. Its `public.users` columns read before and after must match
except `updated_at`.
