# Ticket 04, run w4-20260924T0418Z: expected records

Written before the app was touched. Dev project `vlmtsdzpnjnavdgytcmi` and the RevenueCat project
only. Decisions: mp-457 (closed Gate = full-screen paywall, stays there), mp-494 (the ⋯ menu),
mp-624 (this ticket's card).

## Account A: `lee+e2e-04-<UTC time>@rightpathprogramming.com`, driven by hand (mobile MCP / idb)

After signup and onboarding, on the paywall (before the delete):
- Screen: the full-screen paywall. No close button, no back control, an edge swipe does not
  leave it (mp-457).
- ⋯ menu, in this order: Restore purchases, Redeem code, Sign out, Delete account. No Manage
  subscription (nothing to manage, mp-494).
- RevenueCat: a customer whose id is A's user id exists, with no active entitlement and no
  subscription. Read by the v2 API.
- Dev database: `auth.users` 1 row; `public.users` 1 row with `onboarding_completed = true`;
  `public.onboarding_surveys` 1 row; `public.user_entitlements` 0 rows. Read by SQL.

After Delete account from the paywall ⋯ menu:
- The app lands on the welcome screen.
- Footprint for A's id (`sweep-accounts.mjs footprint`): no rows.
- A failed delete is a Finding.

## Account P: the Patrol onboarding signup flow's own `lee+e2e-signup-<millis>` address

- The flow passes: paywall with no close button, the mp-494 menu without Manage, users and survey
  rows with the onboarding answers, no `user_entitlements` row, and the account deletes itself.
- Known red before the run: 03-009 (the plan-reveal edit is not saved), so the flow's last
  assertion is expected to fail until that is fixed.
- After the flow: footprint for P's id empty.
