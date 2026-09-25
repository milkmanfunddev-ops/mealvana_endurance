# 07-003 · Test Store renewals land only when the app next fetches the customer, so RevenueCat and the Entitlement row show no Pro between period end and that fetch

- kind: idea
- status: wontfix
- ticket: 07
- run: w6-20260924T1118Z
- screen: none
- decision: 

**Steps.**
1. Account C bought Test Store Monthly at 11:31:55Z; the first period ended at 11:36:56.226Z.
2. Read RevenueCat and the dev `user_entitlements` row at 11:37:45Z, 11:38:16Z and 11:38:37Z without touching the app.
3. Cold relaunch the app at 11:39:00Z; read again.

**Expected.**
The Test Store renews at the period end (05-003 saw four renewals every 5 minutes, read afterwards), so RevenueCat, the webhook and the row move on at 11:36:56Z.

**Actual.**
Until the app fetched the customer, nothing moved: at 11:38:16Z the subscription was `active`, `will_renew`, with `current_period_ends_at` 11:36:56; at 11:38:37Z `active_entitlements` was empty; the row stayed at `active_until 11:36:56.226`. The RENEWAL landed at 11:39:04.351Z (`event_at`), the same second as the app's launch fetch, and the webhook logged it at 11:39:05Z with the new end 11:41:56 (still on the 5-minute grid). So for 2 min 8 s the server side (row, and so the server's own Pro check, mp-505) said no Pro for a paying account.

The idea: on dev, Test Store renewals appear to be processed when the SDK asks, not on a clock. Tests that read the row or call a Pro-checked function between period end and the next app fetch will see a false lapse. Worth confirming with RevenueCat's docs, and writing into the testing-wave spec next to 05-003. 05-011's "renewals read afterwards" timeline may also be shaped by this.

Review note (wave lead): this rests on one run. In ticket 06 the renewal landed at 11:36:13Z with no
app fetch tied to it (06-002), so "only when the app asks" is not established; read with 06-002.

**Evidence.**
- runs/07/revenuecat-C-after-renewal.json (11:37:45Z), runs/07/db-C-after-renewal.txt
- runs/07/revenuecat-db-C-after-renewal-2.txt (11:38:16Z)
- runs/07/revenuecat-db-C-after-renewal-3.txt (after 11:39:04Z: period end 11:41:56, row event_at 11:39:04.351)
- runs/07/edge-logs-rc-webhook-C.txt (RENEWAL at 11:39:05Z)

**Decision quote.**
> 

**Triage.**

Wave 7 (ticket 09, runs/09/notes.md and poll-lapse.log): four renewals landed 2–3 minutes after each period end with no `customer info` fetch from the app in the console from 12:31 to 13:01, so renewals do not need an app fetch. Ticket 08 saw one land in the same second as a fetch, which reads as coincidence.

Won't fix (Lee, 2026-09-25): Test Store renewals land when the app next fetches the customer; this is how the Test Store works.
