# 09-009 · After the lapse RevenueCat ends Pro at 12:56:29 but the Entitlement row says 12:59:36, the time the EXPIRATION webhook arrived (mp-609 clause 4)

- kind: idea
- status: closed
- ticket: 09
- run: w7-20260924T1219Z
- screen: none
- decision: 

**Steps.**
1. Account D's Test Store monthly ends: RevenueCat's last period is 12:51:29.761 → 12:56:29.761Z, `will_not_renew`.
2. Read the dev `user_entitlements` row every minute (poll-lapse.log) and the webhook log.
Idea for triage: ticket 09's card (mp-629) asks that "RevenueCat and the Entitlement row agree on the end date". Before the end they did, to the millisecond. After it, they cannot under mp-609 clause 4, because the row records when the EXPIRATION arrived, not when Pro ended. Either word the ticket criterion as "before the end", or have clause 4 close the row at RevenueCat's last expiry when that is in the past (min(event time, last known end)). No access is given: the row is already in the past when written.

**Expected.**
Ticket 09 / mp-629: RevenueCat and the Entitlement row agree on the date access ends, before and after it passes (spec story 43).

**Actual.**
Until 12:59:36Z the row said `active_until 12:56:29.761`, equal to RevenueCat. The EXPIRATION webhook (event 12:59:36.902Z, logged 12:59:38Z) then moved it later, to `active_until 12:59:36.902`, `event_at 12:59:36.902`. From then on the row says Pro ended 3 min 7 s after RevenueCat says it did. This is what mp-609 clause 4 says ("When RevenueCat reports no `pro`, the row closes at the event time") and what `entitlementRowFor` does (`currentExpiry ?? eventAt`).

**Evidence.**
- runs/09/poll-lapse.log (12:58:53Z and 12:59:54Z lines)
- runs/09/edge-logs-webhook-D.txt (EXPIRATION line)
- runs/09/revenuecat-D-after-lapse.json, runs/09/db-D-after-lapse.txt

**Decision quote.**
> 

**Triage.**
Fix ticket 38 (Lee, 2026-09-25). Closed by the retest after it merges.

Closed by retest ticket 87 (wave 25, build 5e05f8a6): pass, evidence in runs/87/verdicts.md.
