# 09-012 · No CANCELLATION event reached the webhook when the Test Store turned auto-renew off at the fourth renewal; check the cancel-then-run-out path with a store that can cancel

- kind: followup-test
- status: triaged
- ticket: 09
- run: w7-20260924T1219Z
- screen: none
- decision: 

**Steps.**
1. Buy Test Store Monthly; let it renew until RevenueCat sets `will_not_renew` (here at the fourth renewal, 12:51Z).
2. Read the webhook log for a CANCELLATION event.
3. With a store that lets the athlete cancel (Apple sandbox on Lee's iPhone), cancel mid-period and read RevenueCat, the webhook and the row until the period ends.

**Expected.**
A cancellation keeps access to the period end: CANCELLATION arrives, the row keeps RevenueCat's end date, the app stays open until then, then the full-screen paywall (mp-609 clause 3, mp-457).

**Actual.**
This run saw no CANCELLATION: the webhook got RENEWAL at 12:51:39Z carrying the new end 12:56:29.761, then EXPIRATION at 12:59:38Z. The Test Store cannot be cancelled from the app (09-001), so a real cancel-then-run-out was not tested.

**Evidence.**
- runs/09/edge-logs-webhook-D.txt

**Decision quote.**
> 

**Triage.**

Picked for ticket 13 (Lee's iPhone session) (Lee, 2026-09-25: every open follow-up test folded into the planned runs, cap of ten lifted for this pass).
