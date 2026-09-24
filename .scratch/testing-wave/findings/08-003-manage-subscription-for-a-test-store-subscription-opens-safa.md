# 08-003 · Manage subscription for a Test Store subscription opens Safari on Apple's account sign-in page, where the subscription cannot be managed

- kind: followup-test
- status: open
- ticket: 08
- run: w7-20260924T1216Z
- screen: Subscription
- decision: 

**Steps.**
1. A paid account (Test Store Monthly) opens Settings → Subscription → Manage subscription.
2. Repeat on a real iPhone with a sandbox App Store subscription (the iPhone sandbox ticket).

**Expected.**
mp-495: Manage subscription opens "the store's own screen". On a device with an App Store subscription, the App Store's Subscriptions page with this plan listed.

**Actual.**
Run on the simulator at 12:27:52Z: Safari opened `account.apple.com` at the Apple Account sign-in form (`https://apps.apple.com/account/subscriptions`, the app's fallback, redirected there). RevenueCat's `management_url` for the `test_store` subscription is null, so the app used its fallback. A Test Store subscription has no page where it can be managed, so on dev there is no way to cancel from Manage; this also answers the Manage half of 05-008. Nothing here is known to be wrong on a device; the device run is the follow-up.

**Evidence.**
- runs/08/12-after-manage.png
- runs/08/revenuecat-D-after-purchase.txt

**Decision quote.**
> 

**Triage.**
