# Ticket 10, run w8-20260924T1418Z: expected records

Written before the app was touched. Dev project `vlmtsdzpnjnavdgytcmi` and RevenueCat project
`proj77b3c48f` only. Decisions: mp-280 (the lapsed account meets the full-screen paywall, stays
signed in, data kept and all there again the moment Pro is back), mp-457 (the Gate is open or
closed; closed is the full-screen paywall).

Account D from ticket 09: `lee+e2e-09-20260924T1229Z@rightpathprogramming.com`,
id d88b5741-f2f2-455c-b2dc-c346d904b01b.

## Before buying (Lapsed)
- RevenueCat: no active entitlement; one `test_store` subscription `expired`, `will_not_renew`,
  ended 12:56:29.761Z.
- Dev database: `user_entitlements` 1 row, `active_until` in the past (12:59:36.902Z per 09-009).
  users 1; meal_plans 1 (`d297659d` confirmed); plan_meals 6; meal_logs 1 (`346a6d5b`);
  shopping_lists 1 (21 items); vana_conversations 1 (3 messages).
- Screen after signing in: the full-screen paywall, no close button, ⋯ menu with Restore
  purchases, Redeem code, Manage subscription, Sign out, Delete account.

## Right after buying Test Store Monthly from that paywall ("Test valid purchase")
- Screen: the app (the Gate opens), not the paywall.
- RevenueCat: `pro` active for D, `expires_at` about 5 minutes out; a new `test_store`
  subscription for the monthly product, active.
- Dev database: the same single `user_entitlements` row for D, `active_until` now in the future
  and equal to RevenueCat's `pro` expiry.

## Data as it was (mp-280)
- Dev database: the counts above unchanged; plan `d297659d` still `confirmed`, meal log `346a6d5b`
  still there.
- Screen: the Food → Plan tab shows the confirmed plan (6 meals) and its shopping list; the
  timeline for 2026-09-24 shows the logged Eggs + toast breakfast.

## At the end
- Account D deleted through the app's Delete account flow; dev `auth.users`, `users`,
  `user_entitlements` and D's data rows 0. Credentials row marked `deleted`.
