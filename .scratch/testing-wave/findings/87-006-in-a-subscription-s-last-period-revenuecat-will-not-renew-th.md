# 87-006 · In a subscription's last period (RevenueCat will_not_renew) the Subscription screen still says Renews on, and the app and the server both keep the 15-minute renewal grace past its end

- kind: bug
- status: triaged
- ticket: 87
- run: w25-20260925T1325Z
- screen: Subscription
- decision: 

**Steps.**
Found in the retest of 08-004 (the cancelled leg) and 05-005 (ticket 77).
1. Account A buys the Test Store monthly at 13:35:14Z (5-minute periods; the Test Store ends it after five, at 14:00:14Z) and leaves the app open.
2. At 13:55:26Z RevenueCat's API shows the last period 13:55:14.534→14:00:14.534 as `will_not_renew`. At 13:56:27Z open Settings → Subscription; reopen it.
3. Leave the app on the timeline across 14:00:14Z; poll the Entitlement row and a Pro check (kroger `status`, whose `available` is `requirePro`) every 30 s.

**Expected.**
mp-495: the screen says where the plan stands, "active and when it renews", or when it ends if it will not renew (mp-558's "Ends on <date>. It won't renew."). Tickets 67 and 77 (mp-679): only a renewing subscription keeps the 15-minute grace past its expiry; one that will not renew closes at its end, in the app and on the server.

**Actual.**
The screen read "Subscribed", "Pro Monthly", "Renews on September 25, 2026." in the last period; reopening made no fetch. The app's copy was fetched at 13:55:15.5Z (by ticket 77's re-count timer), less than a second into the last period, and its willRenew stayed true, so the Gate kept the grace and the app stayed open until 14:15:14Z, 15 min after the plan ended (05-005 retest). The server did the same for 90 s: no CANCELLATION webhook came for the Test Store's last period, the row kept `will_renew: true`, and kroger answered `available: true` at 14:00:34 and 14:01:09Z until the EXPIRATION webhook at 14:01:44Z closed it. The Test Store may never send a CANCELLATION for its planned end, so the server side may be Test Store only; the app side applies to any cancellation the saved copy has not yet seen (an App Store cancel mid-period is only learned at the next fetch, and the next re-count is at expiry + 15 min).

**Evidence.**
- runs/87/22-A-08-004-subscription-last-period.png ("Renews on" in the last period)
- runs/87/poll-A.log (13:55:26Z onward: RevenueCat `will_not_renew`, row `will_renew: true`)
- runs/87/probe-A-pro-check.log (14:00:34Z and 14:01:09Z `available: true`; 14:01:47Z false)
- runs/87/edge-logs-webhook-A.txt (RENEWAL 08:55:15, EXPIRATION 09:01:46 local; no CANCELLATION)
- runs/87/screen-watch-05-005.log (timeline until 14:15:06Z, paywall 14:15:26Z)
- runs/87/console-redacted.log (`customer info fetched` 08:55:15.545 and 09:15:14.552 local)

**Decision quote.**
> 

**Triage.**
Fix ticket 105 (Lee, 2026-09-25): app side only; the app fetches before granting grace and the Subscription screen fetches on open. Server side won't fix: the Test Store sends no CANCELLATION for its planned end. Closed by retest ticket 107 after it merges.
