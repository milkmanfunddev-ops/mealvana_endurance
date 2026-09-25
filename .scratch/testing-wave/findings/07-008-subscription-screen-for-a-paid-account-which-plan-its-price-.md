# 07-008 · Subscription screen for a paid account: which plan, its price and the renewal time

- kind: followup-test
- status: triaged
- ticket: 07
- run: w6-20260924T1118Z
- screen: Subscription
- decision: 

**Steps.**
1. A paid account (Monthly) opens Settings → Subscription.
2. Compare with Annual, and with a Test Store subscription whose 5-minute period ends the same day.

**Expected.**
Spec user story 50: the screen shows the plan, its expiry and a way to manage it.

**Actual.**
Not run beyond a look (ticket 07). For account C (Monthly) the screen read "Subscribed" and "Renews on September 24, 2026.", then Manage subscription and Redeem code; it did not name the plan (Monthly) or its price, and on the Test Store the date gives no time, so a period ending in minutes reads like a day. At 11:38Z, after the period end with the renewal not yet landed (07-003), the open screen still said "Renews on September 24".

**Evidence.**
- runs/07/12-subscription-screen.png

**Decision quote.**
> 

**Triage.**

Picked for retest ticket 107 (Lee, 2026-09-25: every open follow-up test folded into the planned runs, cap of ten lifted for this pass).
