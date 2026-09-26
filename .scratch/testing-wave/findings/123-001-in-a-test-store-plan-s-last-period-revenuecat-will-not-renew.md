# 123-001 · In a Test Store plan's last period (RevenueCat will_not_renew) the Subscription screen still says Renews on after its fresh fetch

- kind: bug
- status: open
- ticket: 123
- run: w38-20260926T0341Z
- screen: Subscription
- decision: 

**Steps.**
Retest of 87-006 (fix ticket 105, item 1).
1. Account A buys the Test Store monthly at 03:46:08Z and stays signed in with the app open. It renews at 03:51, 03:56, 04:01 and 04:06.
2. At 04:06:31Z RevenueCat's v2 API shows the fifth period 04:06:08→04:11:08 as `will_not_renew`.
3. At 04:06:38Z open Settings → Subscription.

**Expected.**
Ticket 105: opening the Subscription screen fetches fresh customer info, and a plan in its last period reads "Ends on <date>. It won't renew." (mp-558), never "Renews on".

**Actual.**
The screen read "Subscribed", "Pro Monthly", "Renews on September 25, 2026.". The fetch-on-open did run: `customer info cache invalidated` at 23:06:38.742 local, then `customer info fetched {active: true, expires_at 04:11:08}` at .810, with no `customer info updated` line, so the copy the SDK returned was the same as the saved one and still read as renewing. The screen takes `willRenew` from the SDK's entitlement (`subscription_service.dart:358`), and for the Test Store's planned end the SDK's copy evidently never says "won't renew" even though RevenueCat's v2 API does. The v1 subscriber record the SDK reads cannot be fetched with the v2 secret key (code 7723), so this run could not see whether it carries `unsubscribe_detected_at`. This may be Test Store only; an App Store cancel mid-period sets that field and may show "Ends on". Needs a device check with an App Store sandbox cancel. The Gate half of the fix holds (the Gate closed at 04:11:08, see notes).

**Evidence.**
- runs/123/11-A-87-006-subscription-last-period.png ("Renews on" in the last period)
- runs/123/revenuecat-A-last-period.json (fifth period `will_not_renew`)
- runs/123/poll-A.log (04:06:31Z onward: RevenueCat `will_not_renew`, row `will_renew: true`)
- runs/123/console-redacted.log (23:06:38 local, `SubscriptionService` lines)

**Decision quote.**
> 

**Triage.**
