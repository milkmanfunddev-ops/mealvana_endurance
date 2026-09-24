# Ticket 07, run w6-20260924T1118Z: expected records

Written at 11:18Z, before the app was touched. Dev project `vlmtsdzpnjnavdgytcmi` and the
RevenueCat project `proj77b3c48f` only. Decisions: mp-494 (the paywall's ⋯ menu holds Restore
purchases, Redeem code, Manage subscription when there is one, Sign out, Delete account), mp-335
(on a phone the Gate reads RevenueCat's saved copy; startup waits for the Gate at most two seconds;
the saved copy counts only once it belongs to the signed-in account; the router alone moves people
to or from the paywall), mp-627 (this ticket's card).

## Account C: `lee+e2e-07-<UTC time>@rightpathprogramming.com`, driven by hand (idb/simctl)

Before the purchase (on the onboarding paywall, as ticket 04 left it):
- RevenueCat: customer C exists, no active entitlement, no subscription.
- Dev database: `public.user_entitlements` 0 rows for C.

After buying Monthly in the Test Store sheet ("Test valid purchase"), as ticket 05 saw:
- Screen: the Gate opens into the app.
- RevenueCat: `pro` active with `expires_at` about 5 minutes out; one subscription for
  `mealvana_pro_monthly` on the Test Store, sandbox, active; one INITIAL_PURCHASE.
- Dev database: one `user_entitlements` row for C with `active_until` equal to RevenueCat's `pro`
  expiry; webhook INITIAL_PURCHASE answered 200.

After uninstall, reinstall of the same built .app, launch, and sign-in as C (inside 20 minutes of
the purchase, so the subscription is still active):
- Screen: either the app opens straight away (the Gate reads RevenueCat for C after login), or
  the paywall shows and ⋯ → Restore purchases opens the app with the restore-success message.
  Either is a pass; which one happened is written down.
- RevenueCat: still exactly one subscription and one purchase for C (same subscription id and
  original purchase time as before); no second INITIAL_PURCHASE event. Renewals of the same
  subscription (every ~5 min) are expected and do not count as a second purchase.
- Dev database: still one `user_entitlements` row for C (the row may move forward with renewals).
- Whether a Test Store purchase survives the reinstall at all is written down as an idea Finding,
  with evidence.

At the end:
- Account C is deleted through the app's delete-account flow; dev database has no `users`,
  survey or `user_entitlements` rows for C afterwards (RevenueCat keeps a customer, known 02-005).
