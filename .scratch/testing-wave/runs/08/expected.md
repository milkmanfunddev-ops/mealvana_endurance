# Ticket 08, run w7-20260924T1216Z: expected records

Written before the app was touched. Dev project `vlmtsdzpnjnavdgytcmi` and the RevenueCat project
`proj77b3c48f` only. Decisions: mp-494 (Manage subscription only when the account has a
subscription to manage; Redeem code opens our own Code entry, never the App Store's sheet),
mp-495 (the Subscription screen: active with its renewal date, Manage subscription when there is a
subscription, Redeem code), mp-558 (Manage shows for a `pro` entitlement from a real store),
mp-615 (proposed: Grants only; not in play for a store purchase), mp-628 (this ticket's card:
"sees the plan they bought, the date it renews or ends as RevenueCat has it, and Manage
subscription").

## Account D: `lee+e2e-08-<UTC time>@rightpathprogramming.com`, driven by hand (idb / simctl)

Before the purchase (on the onboarding paywall after signup):
- RevenueCat: customer D has no active entitlement and no subscription.
- Dev database: `public.user_entitlements` 0 rows for D.

Right after buying Monthly in the Test Store sheet ("Test valid purchase"):
- Screen: the app (timeline), What's New over it.
- RevenueCat: `pro` active for D, expiry about 5 minutes out; one `test_store` subscription for
  `mealvana_pro_monthly`, active, will renew.
- Dev database: one `user_entitlements` row for D, `active_until` equal to RevenueCat's `pro`
  expiry, `period_type NORMAL`.

Settings → Subscription, within 20 minutes of the purchase:
- Status: the plan bought, Pro Monthly (mp-628). The code's copy for an active store plan is
  "Subscribed"; whether the plan is named is checked, not assumed.
- Date line: "Renews on <date>." where <date> is RevenueCat's current `pro` expiry /
  `current_period_ends_at` in the device's local calendar day. `will_renew` true, so "Renews",
  never "Ends".
- Manage subscription shows (a `test_store` subscription is on record, mp-558).
- No Upgrade button (the plan has not ended).
- Redeem code shows; tapping it opens our own Redeem a code sheet (title "Redeem a code"), never
  the App Store's offer-code sheet (mp-494). Closing it leaves the screen as it was.
- Manage subscription tapped: RevenueCat's management URL or the store's page opens, or the
  "Manage your subscription in the App Store or Google Play app" message shows. Where a Test
  Store subscription goes is recorded (05-008 asked).
- After a renewal (every 5 minutes), reopening the screen shows the date RevenueCat then has.

At the end:
- Account D is deleted through the app's delete-account flow. Afterwards D cannot sign in and its
  dev `users` and `user_entitlements` rows are gone. RevenueCat keeps its customer record
  (Test Store, nothing to refund; known 02-004 / 02-005).

## Patrol flow account: `lee+e2e-subscription-<millis>`
Same shape as D, checked from inside the app: the date line equals the SDK's `pro` expiry day,
Manage shows, Redeem opens its sheet; deletes itself at the end.
