# Ticket 123 expected records (retest, wave 38, RUN w38-20260926T0341Z)

Account A: new, signs up at lee+e2e-123-<UTC>@rightpathprogramming.com; deleted at the end.

## Before purchase
- RevenueCat customer exists after signup, no active `pro`; no `user_entitlements` row.

## Monthly (Test Store, 5-minute periods)
- After "Test valid purchase": RevenueCat `pro` active, one `test_store` subscription, `will_renew` true; `user_entitlements` row `active_until` = RevenueCat's expiry.
- 07-008: Subscription screen names the plan (Monthly), its status and date (mp-495, mp-628), Manage subscription (store subscription on record, mp-558) and Redeem code.
- 07-011: after a renewal while the screen is open, Home and resume shows the new renewal (or the screen is refetched on open, ticket 105).
- 08-005: Manage on a Test Store plan says where the plan is (no page, no blank Safari); twice quickly gives one message; offline the screen stays usable.
- 87-006: in the last period (RevenueCat `will_not_renew`), opening Subscription fetches fresh and reads "Ends on <date>. It won't renew." (mp-558, ticket 105). The Gate closes at the period end, not 15 minutes later (mp-679 grace only for a renewing plan).
- After the lapse: RevenueCat `pro` inactive; the row `active_until` = RevenueCat's last expiry, `will_renew` false.

## Lapsed (mp-457, mp-280, mp-494)
- Full-screen paywall, no close button, signed in; ⋯ menu: Restore purchases, Redeem code, Manage subscription, Sign out, Delete account.
- 87-007: ⋯ → Manage subscription shows the Test Store message, the same as the Subscription screen (ticket 106).
- 87-008: no way from the lapsed paywall to Settings or a Subscription ended state; no `PlanStatus.ended` in the code (ticket 106).
- 05-008: Restore purchases restores nothing, Gate stays closed.
- 09-011: Sign out lands on Welcome with no paywall frame; logging back in lands on the paywall; an offline relaunch shows the paywall, never the app.
- 10-003: failed purchase leaves the paywall with a MealvanaSnackbar and Continue usable; Cancel returns with Continue enabled; a double tap opens one sheet; the retry opens the Gate. Annual resubscribe: RevenueCat and the row agree on the annual expiry.
- 10-005: after resubscribing on the same device, the earlier local data (logged meal) is there at once.
- 87-009: a cold launch offline with a saved copy more than 15 min past its own expiry routes straight to /paywall (no /main first), within about 2 s of the router starting; back online a fresh answer opens the Gate if Pro is live.

## After delete
- auth user and `user_entitlements` row gone; RevenueCat keeps the store subscription (expected).
