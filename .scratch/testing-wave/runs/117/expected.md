# Ticket 117 (wave 40): records expected before and after

Account: test@test.com (user 607f9dd5-6fa7-48ee-a628-720d4a0506a1), shared with ticket 113. Read-only here.

## 30-001 (FinalSurge past rows)
- Before sign-in: every past FinalSurge row (scheduled before today, 2026-09-26) has `provider_deleted_at` NULL
  (ticket 42's cleanup SQL cleared them on 09-25). Saved in `db-before-signin-provider-rows.txt`.
- After this run's first sign-in (FinalSurge sync from the cleared app): the same rows still have
  `provider_deleted_at` NULL. Only a row inside the fetched (upcoming) window that vanished upstream may be flagged.

## 30-002 (last_synced_at)
- A row the sign-in's FinalSurge sync updates has `last_synced_at` equal to the UTC time of the sync
  (within a minute of the sign-in's UTC minute, and of db `now()`), not the CDT wall clock (5 h earlier).

## 10-004 / 05-007 (own accounts)
- RevenueCat: a customer per new account; after the Test Store purchase an active `pro` entitlement.
- Dev DB: `entitlements` row for the account after purchase (if the Test Store reaches the webhook), meal logs and
  the planned workout the run makes present again after resubscribing.
- Both accounts deleted at the end through the app's delete-account flow.

## Everything else
- No writes to test@test.com: no meals, no settings, no integration change (Keep Sharing only).
