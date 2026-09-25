# 87-007 · The lapsed paywall's Manage subscription names the App Store or Google Play for a Test Store plan, while the Subscription screen names the RevenueCat dashboard

- kind: idea
- status: triaged
- ticket: 87
- run: w25-20260925T1325Z
- screen: Paywall ⋯ menu (lapsed)
- decision: 

**Steps.**
Idea: account A's Test Store monthly ended; on the lapsed paywall ⋯ → Manage subscription shows "Manage your subscription in the App Store or Google Play app on your phone." The Subscription screen's Manage for the same Test Store plan (ticket 66) says "This plan is from RevenueCat's Test Store, which has no store page. Its subscription is in the RevenueCat dashboard." Use one message per store in both places (the paywall's names a store the plan was never bought in), or say why they differ. On the App Store both should open Apple's page when RevenueCat has a management URL (not tried on a simulator).

**Expected.**


**Actual.**
Snackbar over the lapsed paywall at 14:16:07Z; no Safari opened, so 09-001's blank page did not come back.

**Evidence.**
- runs/87/25-A-lapsed-manage-tapped.png
- runs/87/19-A-09-001-manage-message.png

**Decision quote.**
> 

**Triage.**
Fix ticket 106 (Lee, 2026-09-25): the lapsed paywall uses the Subscription screen's store-aware Manage. Closed by retest ticket 107 after it merges.
