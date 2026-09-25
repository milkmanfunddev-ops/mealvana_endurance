# Ticket 121 expected records (run w34-20260925T2320Z)

Written before touching the app. Judged against this file.

## Retests (fix ticket 104, app build e3367d2c)
- 86-004: paywall ⋯ → Sign out confirm body reads exactly Settings' text: "You'll need to sign in again to use
  Mealvana. Your data stays with your account." Title "Sign out?".
- 86-006: console `user_registered {device_id: …}` equals the device id `app_opened` sent on this simulator,
  not the new account's user id.

## Follow-up tests
- 86-009: Use a different email from Verify your email returns to a signup form; the second address signs up
  and verifies. Dev: the first address leaves no half-made account that blocks a later signup (if an
  unconfirmed auth.users row is left, it is filed and listed for the lead). Resend code, then the superseded
  first code: a message that points to the newest code (the current wrong-code copy is "That code is wrong or
  has expired. Check the digits, or tap Resend for a new one.").
- 86-011: offline ⋯ → Delete account → Delete: a clear failure message, the athlete still signed in, account
  and local rows kept; no half delete. Online afterwards (SELECT): public.users and auth.users row still there.
- 04-002: cold relaunch of a signed-in never-paid account lands on the paywall (no close button), never a tab
  or timeline frame first; background 1 min and back: still paywall (mp-457).
- 04-003: ⋯ → Restore purchases on a never-paid account: info message "No active subscription was found for
  this account." (paywallRestoreNone), stays on paywall; no user_entitlements row; RevenueCat customer has no
  active entitlement.
- 04-004: offline, the paywall shows "Plans aren't available right now. Please check back later."
  (pricing_unavailable) instead of plans; Continue harmless; ⋯ menu works; no way off.
- 04-005: Continue then cancel the Test Store sheet: no snackbar, stays on paywall; "failed purchase": the
  failure snackbar, stays on paywall. RevenueCat: no subscription/entitlement; user_entitlements: no row.
- 05-010: Continue tapped twice quickly → one Test Store sheet / one purchase; tapping Continue in the ~2.4 s
  after a purchase buys nothing more; failed then valid = one purchase. RevenueCat: one subscription; webhook
  one INITIAL_PURCHASE; user_entitlements one row with the RevenueCat expiry; app lands on timeline once, no
  error snackbar.

## Accounts
- Every account the run creates is deleted through the app at the end: public.users and auth.users have no row.
  RevenueCat customer may remain (known, 02-005).
