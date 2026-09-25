# Ticket 87 expected records (retest, wave 25, RUN w25-20260925T1325Z)

Two accounts: B (redeem line) and A (purchase line). Both deleted at the end.

## Account B (redeem, never paid)
- Before: RevenueCat customer exists after signup, no `pro`; no `user_entitlements` row.
- 11-004: the Redeem code field stops at 32 characters.
- 11-003: an overlong code (over 32 once spaces are stripped) answers 400 `code_too_long`, not `code is required`, on the server; the app logs the same.
- 11-006: offline Redeem shows `redeem_code.failed_unavailable` under the field, sheet open, no `code_redemptions` row for B. Back online, Redeem works: one row, Pro from the code.
- 08-004 (Grant): Subscription screen reads "Pro from a code, N days left" (365-day giveaway), no Manage.
- 11-012: after B is deleted, its `code_redemptions` row for E2EGIVE365 stays (user_id null), per-code count stays 1; a new account (A) entering E2EGIVE365 is refused as used.

## Account A (Test Store monthly, 5-minute periods, lapses ~25 min after purchase)
- 05-004: after "Test valid purchase" the paywall never shows Continue enabled again; timeline follows.
- After purchase: RevenueCat `pro` active, one `test_store` subscription; `user_entitlements` row `active_until` = RevenueCat's expiry.
- 06-001: offline cold launch inside the paid period opens the timeline, no paywall.
- 08-001: Subscription card names Monthly. 09-001: Manage subscription opens no blank Safari page; it says where to manage.
- 08-004 running/cancelled(last period, will_not_renew)/ended states per mp-495/mp-558.
- 06-002: in the gap between a period end and a late RENEWAL webhook, the server still counts Pro (renewal grace, 15 min) while the row says will renew.
- 09-009: after the lapse, the row's `active_until` equals RevenueCat's last expiry (the EXPIRATION event's expiration time), not the webhook arrival time.
- 05-005: app left in the foreground lands on the paywall at expiry (non-renewing) or expiry + 15 min (renewing), with no resume.
- 10-002: resubscribing from the lapsed paywall is not greeted with "Welcome to Mealvana Endurance!".
- 07-002: a cold launch offline with a saved copy more than 15 min past its own expiry lands on the paywall; a fresh answer (online) opens it again.
- 02-004: with an active store subscription, the Delete Account confirm says deleting does not cancel the subscription and names where to cancel.
- After delete: dev rows gone; RevenueCat subscription still exists (store side, expected).
