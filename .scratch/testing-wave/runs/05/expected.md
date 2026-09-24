# Ticket 05, run w5-20260924T0839Z: expected records

Written before the app was touched. Dev project `vlmtsdzpnjnavdgytcmi` and the RevenueCat project
`proj77b3c48f` only. Decisions: mp-279 (store runs the seven-day trial, RevenueCat `pro` is the only
gate), mp-457 (Gate open or closed; closed is the full-screen paywall), mp-625 (this ticket's card).

## Known before the run (read by API, 08:40 UTC)

- The Test Store app (`appa283bb35a2`) sells `mealvana_pro_monthly` (P1M) and
  `mealvana_pro_annual` (P1Y), both with `trial_duration: null`
  (`revenuecat-teststore-products.json`). So a Test Store purchase cannot start a seven-day free
  trial; the run expects a normal paid period (dev Test Store monthly renews about every 5 minutes).
- Webhook integrations: the dev one (all environments, all lifecycle events) points at the dev
  `revenuecat-webhook`; the prod one (all environments, purchase/renewal only) points at prod.
  The dev function drops `PRODUCTION` events unless the store is `PROMOTIONAL`
  (`REVENUECAT_SANDBOX_ONLY`).

## Account B: `lee+e2e-05-<UTC time>@rightpathprogramming.com`, driven by hand (mobile MCP / idb)

Before the purchase (on the onboarding paywall, as ticket 04 left it):
- RevenueCat: customer B exists, no active entitlement, no subscription.
- Dev database: `public.user_entitlements` 0 rows for B.

After buying Monthly in the Test Store sheet ("valid purchase"):
- Screen: the paywall closes straight into the app (the Gate opens); no paywall flash on the way,
  and none on a cold relaunch.
- RevenueCat: `pro` active for B with an `expires_at` in the future; one subscription for
  `mealvana_pro_monthly` on the Test Store with the same end. Trial or normal period recorded as
  RevenueCat reports it.
- Webhook: a dev `revenuecat-webhook` call for an `INITIAL_PURCHASE` on B, visible in the edge
  logs, if RevenueCat delivers Test Store events. Either way the answer is a Finding (idea or bug).
- Dev database, if the webhook fires: one `user_entitlements` row for B whose `active_until`
  equals RevenueCat's `pro` expiry (to the second) and whose `period_type` matches RevenueCat's.
  If the webhook does not fire: 0 rows, and that is the Finding.

At the end:
- Account B is kept (not deleted) for tickets 06 to 09 and marked so in the credentials file.
