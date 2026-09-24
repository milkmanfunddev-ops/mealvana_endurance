# Ticket 06, run w6-20260924T1117Z: expected records

Written before the app was touched. Dev project `vlmtsdzpnjnavdgytcmi` and the RevenueCat project
`proj77b3c48f` only. Decisions: mp-457 (Gate open or closed; closed is the full-screen paywall),
mp-335 (on a phone the Gate reads RevenueCat's saved copy; startup waits for the Gate, at most two
seconds, so a subscriber never sees the paywall flash; the router alone moves people to or from the
paywall), mp-626 (this ticket's card).

## Account C: `lee+e2e-06-<UTC time>@rightpathprogramming.com`, driven by hand (idb / simctl)

Before the purchase (on the onboarding paywall after signup):
- RevenueCat: customer C exists, no active entitlement, no subscription.
- Dev database: `public.user_entitlements` 0 rows for C.

Right after buying Monthly in the Test Store sheet ("Test valid purchase"), as ticket 05 saw it:
- Screen: the app (timeline). Ticket 05 saw the paywall linger about 2.4 s first (05-004); this run
  only notes whether that repeats.
- RevenueCat: `pro` active for C, `expires_at` about 5 minutes out; one `test_store` subscription
  for `mealvana_pro_monthly`, active, will renew.
- Dev database: one `user_entitlements` row for C, `active_until` equal to RevenueCat's `pro`
  expiry to the second, `period_type NORMAL`.

After each of these, all within 20 minutes of the purchase:
1. Sign out (Settings) → the welcome / sign-in screen, no paywall.
2. Sign in with C's email and password → the app (timeline). No paywall frame at any point.
3. Terminate the app (`simctl terminate`) and launch it again (cold start) → the app. No paywall
   frame at any point.
- RevenueCat after each step: `pro` still active for C, same subscription, the same original
  purchase; only `expires_at` may move forward by a Test Store renewal (every 5 minutes).
- Dev database after each step: still exactly one `user_entitlements` row for C; `active_until`
  equal to RevenueCat's current `pro` expiry (it moves with renewals, nothing else changes).
- No new customer or alias in RevenueCat for C (sign-in logs the same app user id back in).

At the end:
- Account C is deleted through the app's delete-account flow. Afterwards C cannot sign in, the
  dev `users` row is gone. RevenueCat keeps its customer record (Test Store, nothing to refund).
