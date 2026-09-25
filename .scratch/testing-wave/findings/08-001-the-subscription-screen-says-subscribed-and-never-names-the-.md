# 08-001 · The Subscription screen says Subscribed and never names the plan bought (Monthly), which the ticket card mp-628 asks for

- kind: ssot-conflict
- status: closed
- ticket: 08
- run: w7-20260924T1216Z
- screen: Subscription
- decision: mp-628

**Steps.**
1. Account D (lee+e2e-08-20260924T1225Z@…) bought Pro Monthly in the Test Store sheet at 12:26:38Z.
2. Settings → Subscription at 12:27:23Z.

**Expected.**
mp-628, this ticket's card: the athlete "sees the plan they bought". Pro Monthly, or at least "Monthly", on the status card.

**Actual.**
The status card reads "Subscribed" and "Renews on September 24, 2026." Nothing names Monthly or its price. The code maps every running store plan other than a founding one to `subscription.status_active` = "Subscribed" (`SubscriptionScreenState.from`), and the state carries no product. mp-495, the screen's own decision, lists only the status ("active and when it renews"), so the code meets mp-495 and misses mp-628. Ticket 07 saw the same thing as a look-around (07-008). Triage question: does "the plan they bought" mean the plan's name (Monthly or Annual), or only that a plan is running?

**Evidence.**
- runs/08/09-subscription-paid.png
- runs/08/revenuecat-D-after-purchase.txt (one `test_store` subscription, product `prod350601b768` = `mealvana_pro_monthly` in the console's `purchase started {sku: mealvana_pro_monthly}`)

**Decision quote.**
> The paid athlete opens the Subscription screen and sees the plan they bought, the date it renews or ends as RevenueCat has it, and Manage subscription.

**Triage.**

Fix ticket 66 (Lee, 2026-09-25). Closed by the retest after it merges.

Closed by retest ticket 87 (wave 25, build 5e05f8a6): pass, evidence in runs/87/verdicts.md.
