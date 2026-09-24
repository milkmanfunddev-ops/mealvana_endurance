# Ticket 09, run w7-20260924T1219Z: expected records

Written before the app was touched. Dev project `vlmtsdzpnjnavdgytcmi` and the RevenueCat project
`proj77b3c48f` only. Decisions: mp-457 (the Gate is open or closed; closed is always the
full-screen paywall; no read-only mode, no plan-ended bar, no write check; the server refuses AI
calls without Pro on its own), mp-280 (a lapsed account meets the full-screen paywall with no close
button and stays signed in; the ⋯ menu offers Restore purchases, Redeem code, Manage subscription,
Sign out and Delete account; data is kept), mp-629 (this ticket's card).

## Account D: `lee+e2e-09-<UTC time>@rightpathprogramming.com`, driven by hand (idb / simctl)

Before the purchase (on the onboarding paywall after signup):
- RevenueCat: customer D exists, no active entitlement, no subscription.
- Dev database: `public.user_entitlements` 0 rows for D.

Right after buying Monthly in the Test Store sheet ("Test valid purchase"), within a few minutes:
- Screen: the app (timeline), not the paywall.
- RevenueCat: `pro` active for D, `expires_at` about 5 minutes out; one `test_store`
  subscription for `mealvana_pro_monthly`, active.
- Dev database: one `user_entitlements` row for D, `active_until` equal to RevenueCat's `pro`
  expiry, `period_type NORMAL`.

Before the lapse (inside the paid window):
- One Vana meal plan made (counts 1 of the wave's 3 plans) and one meal logged (by hand, no AI
  call). Dev database: the plan's rows and one `meal_logs` row for D.

The cancellation:
- If the Test Store lets D cancel (Settings → Subscription → Manage subscription, or the
  paywall's Manage): RevenueCat shows the subscription `will_not_renew` with the same period end;
  the row keeps that `active_until`; the app stays open until it.
- Otherwise the Test Store monthly lapses on its own about 25 minutes after the purchase (05-003):
  RevenueCat `expired`, `will_not_renew`, no active `pro`; the row's `active_until` in the past
  and equal to RevenueCat's last `expires_at`.

After the end:
- Screen: still signed in; the full-screen paywall on resume and on a cold relaunch, no close
  button, not a sheet, no plan-ended bar, no read-only app behind it. ⋯ menu: Restore purchases,
  Redeem code, Manage subscription, Sign out, Delete account.
- Server: one `vana-chat` call with D's access token answers 403 `{error: pro_required}`.
- Dev database: D's `users` row, its survey, its plan rows, its `meal_logs` row and its
  `user_entitlements` row (with the past `active_until`) are all still there.
- RevenueCat: `pro` inactive for D; its end equals the row's `active_until`.

At the end:
- Account D is kept, Lapsed, for ticket 10, and marked so in the credentials file. Not deleted.

## Patrol flow (integration_test/flows/cancellation_flow_test.dart), throwaway account

- `lee+e2e-cancel-<millis>`: signs up, buys Monthly, the Gate opens, one row in the future; waits
  in the foreground for the lapse; on resume the full-screen paywall with the five ⋯ items;
  `vana-chat` 403 `pro_required`; `users` row and Entitlement row kept; then deletes itself.
