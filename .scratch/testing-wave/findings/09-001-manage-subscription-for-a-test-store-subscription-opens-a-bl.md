# 09-001 · Manage subscription for a Test Store subscription opens a blank Safari start page, so the Test Store monthly cannot be cancelled in the app

- kind: bug
- status: triaged
- ticket: 09
- run: w7-20260924T1219Z
- screen: Subscription
- decision: 

**Steps.**
1. Account D (`lee+e2e-09-20260924T1229Z`) buys Test Store Monthly at 12:31:29Z.
2. Settings → Subscription ("Subscribed, Renews on September 24, 2026") → Manage subscription, at 12:35:26Z.

**Expected.**
A way to cancel, or at least a page about the subscription. Ticket 09's first choice was to cancel inside the Test Store; mp-280 lists Manage subscription as the lapsed paywall's way to manage it.

**Actual.**
The app hands off to Safari, which opens on its blank Start Page (no URL, no RevenueCat or store page). There is no cancel anywhere in the app for a Test Store subscription, so this run fell back to the Test Store monthly's own lapse (05-003) in place of a cancellation. On the App Store the management URL is Apple's page, so this may be Test Store only: RevenueCat has no management URL for a `test_store` subscription and the app opens an empty one. Related: 05-008 (Manage from the lapsed paywall, not run then).

**Evidence.**
- runs/09/19-subscription.png (Subscription screen before the tap)
- runs/09/20-manage-subscription.png (Safari Start Page after the tap)
- runs/09/console.log (`settings_subscription_tapped`, nothing logged after)

**Decision quote.**
> 

**Triage.**

Fix ticket 66 (Lee, 2026-09-25). Closed by the retest after it merges.
