# 05-002 · Test Store Pro products carry no trial, so a simulator purchase is a paid period and the seven-day free week cannot be tried there

- kind: idea
- status: open
- ticket: 05
- run: w5-20260924T0839Z
- screen: Paywall
- decision: mp-279

**Steps.**
The Test Store app (`appa283bb35a2`) sells `mealvana_pro_monthly` and `mealvana_pro_annual` with `trial_duration: null`. Idea: give both Test Store products a seven-day trial in RevenueCat (if the Test Store supports one) so a simulator run can walk the trial path that mp-279 describes: `period_type TRIAL` in RevenueCat and in `user_entitlements`, the `is_trial` flag in the app, and the Subscription screen's trial line. Until then, every simulator purchase is a paid first period. The ticket's title ("a trial bought through the Test Store") cannot be met there.

**Expected.**
mp-279: every subscription product carries a seven-day free offer. The ticket expected a trial through the Test Store.

**Actual.**
The Test Store sheet shows "Price: $9.95, SubscriptionPeriod: 1 month" with no offer. RevenueCat records `period_type NORMAL`, the app logs `is_trial: false`, and the webhook writes `period=NORMAL`. The Create Your Account screen and the paywall say "$9.95 a month or $69.00 a year. Cancel any time." with no free week. That is consistent with the product, but it is not what mp-279 describes for the store products. mp-289 already puts the real trial on Apple's and Google's sandboxes by hand.

**Evidence.**
- runs/05/revenuecat-teststore-products.json
- runs/05/15-test-store-sheet.png, runs/05/11-create-account.png
- runs/05/revenuecat-B-subscriptions.json, runs/05/db-B-after-purchase.txt

**Decision quote.**
> The store does. Every subscription product carries a seven-day free offer on both stores, set on Xuan's new products (mp-429). The athlete subscribes at the end of onboarding with a card on file, pays nothing for seven days and is charged on day eight unless they cancel; the store allows one trial per person, so a cancelled trial never comes back. Whether someone may use the app is RevenueCat's `pro` being live from day one, and neither the app nor the server keeps a trial clock.

**Triage.**

