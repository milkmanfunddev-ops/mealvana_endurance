# 07-010 · RevenueCat's customer events API returned an empty list for the account throughout the run

- kind: idea
- status: wontfix
- ticket: 07
- run: w6-20260924T1118Z
- screen: none
- decision: 

**Steps.**
Find out why RevenueCat's v2 customer events endpoint returns an empty list for a Test Store customer that bought and renewed, and whether events exist for Test Store customers at all.

**Expected.**
The events API lists the purchase and renewals, so a run can check them without the webhook logs.

**Actual.**
The customer events API returned an empty list for customer C throughout the run, although RevenueCat showed the subscription and the webhook logged the purchase and a renewal. The run used the webhook logs instead. Written by the wave lead from the run's notes.

**Evidence.**
- runs/07/notes.md (11:36:56 entry)
- runs/07/edge-logs-rc-webhook-C.txt

**Decision quote.**
> 

**Triage.**

Won't fix (Lee, 2026-09-25): RevenueCat's customer events API returns nothing for Test Store customers; runs read customers and subscriptions instead.
