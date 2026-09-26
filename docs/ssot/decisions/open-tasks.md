# Open tasks

Things the decisions wait on that only Lee or Xuan can do. These are not decisions, and they are
not on the decision cards. When one is done, remove its line here and reseed the page (README,
Reference).

Updated 2026-09-26.

## Lee

| Task | Why it matters | Decision it serves |
|---|---|---|
| Run the store checks on a phone, on both the App Store and Google Play (paywall ticket 13) | This is the release gate for meal planning: no release without a green trial-and-purchase run on both stores | mp-266, mp-429 |
| Switch RevenueCat's Test Store to the four new `me_pro_*` products | So testing uses the products we actually sell | mp-429 |
| Confirm that the item sent to your real Kroger cart on 09-10 arrived (kroger-delivery ticket 02) | This closes the Kroger delivery check | Kroger |

## Xuan

| Task | Why it matters | Decision it serves |
|---|---|---|
| Sign off on the paywall's trial and renewal lines, or rewrite them (content keys `paywall.trial_terms` and `paywall.renewal_terms`) | Apple reviews this wording | mp-266, mp-493 |
| Decide whether the glass paywall sheet has a grabber, plus its top gap and slide-in timing | The build keeps its current look until she answers | mp-493 |
| Decide what the during-run band shows once an athlete has lowered their own carb rate | This is a fuelling question, so it belongs to the nutrition spec | Nutrition SSOT |

## Done on 2026-09-26

- The six decisions that needed code are merged on `mealplanning` and live on dev: the `pro_grants` table, plus `grace-claim`, `redeem-code`, `describe-meal`, `analyze-meal-photo`, `vana-action`, `vana-chat`, `vana-day-notes` and `jade-chat`. Prod follows the normal release sequence. The app-side parts ship with the next build.
