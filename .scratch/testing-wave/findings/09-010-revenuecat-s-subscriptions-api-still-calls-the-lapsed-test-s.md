# 09-010 · RevenueCat's subscriptions API still calls the lapsed Test Store subscription active with gives_access true minutes after it ended, while active_entitlements is empty

- kind: idea
- status: open
- ticket: 09
- run: w7-20260924T1219Z
- screen: none
- decision: 

**Steps.**
1. Account D's Test Store monthly ends at 12:56:29.761Z.
2. Read `GET /v2/projects/proj77b3c48f/customers/{id}/subscriptions` and `/active_entitlements` at 12:56:51Z, 12:58:11Z and 13:03:23Z.
Idea: harness scripts and future tickets that read a lapse from RevenueCat should read `active_entitlements` (or `ends_at` against now), not the subscription's `status`/`gives_access`. Ticket 05 read `status expired` 90 minutes after its lapse, so RevenueCat does get there later.

**Expected.**
After the period end, the subscription reads `expired` or at least `gives_access: false`, matching the empty `active_entitlements`.

**Actual.**
At 13:03:23Z, seven minutes after the end and four after the EXPIRATION webhook, the subscription still reads `status active`, `auto_renewal_status will_not_renew`, `gives_access true`, `current_period_ends_at` 12:56:29.761, while `active_entitlements` is empty and the app's SDK says `active: false`. The poll kept seeing `status active` until it stopped at 13:20:16Z, 24 minutes after the end.

**Evidence.**
- runs/09/revenuecat-D-after-lapse.json
- runs/09/poll-lapse.log

**Decision quote.**
> 

**Triage.**

