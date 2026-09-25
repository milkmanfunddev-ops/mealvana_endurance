# 05-001 · Test Store purchases reach the dev webhook: purchase, four renewals and the expiry all land and the Entitlement row matches RevenueCat

- kind: idea
- status: wontfix
- ticket: 05
- run: w5-20260924T0839Z
- screen: Paywall
- decision: 

**Steps.**
1. New account B (id 9a986318-…) signs up and meets the onboarding paywall. RevenueCat: customer, no entitlement. `user_entitlements`: 0 rows.
2. Monthly → Continue → Test Store sheet → "Test valid purchase" at 08:50:44Z.
3. Read RevenueCat (v2 API), `user_entitlements` (SQL) and the dev `revenuecat-webhook` logs, then again after the subscription ran out.

**Expected.**
The ticket's open question: whether a Test Store purchase reaches the dev webhook at all, and if so whether `user_entitlements.active_until` matches RevenueCat's `pro` expiry.

**Actual.**
It does. The dev webhook integration (all environments) delivers Test Store events, and the `REVENUECAT_SANDBOX_ONLY` filter lets them through: RevenueCat labels them `environment: sandbox`, `store: test_store`, and the filter only drops `PRODUCTION` events.
- 08:50:46Z INITIAL_PURCHASE, POST 200: `active_until=08:55:45.150Z period=NORMAL`, Allowance 4,000,000 granted. RevenueCat's `pro` `expires_at` = 1790240145150 = 08:55:45.150Z. **Equal to the millisecond.**
- RENEWAL at 08:59:37Z, 09:03:43Z, 09:07:43Z and 09:11:43Z, each POST 200, each moving `active_until` on 5 minutes (to 09:00:45.150Z … 09:15:45.150Z), each forfeiting and re-granting the Allowance.
- 09:15:47Z EXPIRATION, POST 200: `active_until=09:15:45.967Z` (RevenueCat's period end is 09:15:45.150Z; the row takes the expiration time, 0.8 s later) and the Allowance forfeited to 0.
- Renewals reach the webhook up to about 4 minutes after the period they extend has ended (the 08:55:45 renewal logged at 08:59:37). In each gap the row says expired while RevenueCat has already renewed, so the server may refuse an AI call from a paying account for a few minutes. That is probably the Test Store's own renewal timing, not something Apple does, but a retest on the iPhone sandbox ticket would show it.
So `user_entitlements` can be checked on a simulator after all; the device is needed only for Apple's own path (mp-289).

**Evidence.**
- runs/05/expected.md
- runs/05/db-B-before-purchase.txt, runs/05/revenuecat-B-before-purchase.json
- runs/05/revenuecat-B-active-entitlements.json, runs/05/revenuecat-B-subscriptions.json (08:51Z)
- runs/05/db-B-after-purchase.txt (08:51Z: `active_until 08:55:45.15+00`, `period_type NORMAL`)
- runs/05/edge-logs-webhook.txt (08:51Z), runs/05/edge-logs-webhook-through-expiry.txt (full timeline, UTC)
- runs/05/db-B-after-expiry.txt, runs/05/revenuecat-B-subscriptions-1047Z.json

**Decision quote.**
> 

**Triage.**

Won't fix (Lee, 2026-09-25): the Test Store path to the dev webhook works; nothing to fix, kept as a record of how it behaves.
