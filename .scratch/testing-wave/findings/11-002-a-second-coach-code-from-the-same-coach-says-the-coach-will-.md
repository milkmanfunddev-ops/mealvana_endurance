# 11-002 · A second coach code from the same coach says the coach will see a new request, and overwrites the first code in RevenueCat's coach_code

- kind: idea
- status: open
- ticket: 11
- run: w5-20260924T0840Z
- screen: Paywall
- decision: 

**Steps.**
1. A new athlete on the paywall redeems DEVCOACH30 (paired, pending pairing opened) and then DEVCOACH18, both owned by the same coach.
2. Idea: when the pairing with that coach is already pending or active, say so ("You've already asked this coach to pair") and keep the first code in `coach_code` (or record both), so referral counts per code stay right.

**Expected.**


**Actual.**
Both redeem with the same success message, "Code redeemed. Your coach will see your request to pair." The second leaves the existing pending pairing as it is (one row, requested 08:58:42), so nothing new reaches the coach. It still spends a claim (`code_redemptions` gets a DEVCOACH18 row) and RevenueCat's `coach_code` attribute changes from DEVCOACH30 to DEVCOACH18, so the first code no longer shows as the referrer. mp-458 and mp-535 do not say what a second code from the same coach should do.

**Evidence.**
- runs/11/db-A-after-step3.txt, runs/11/db-A-after-step6.txt
- runs/11/revenuecat-A-after-step3.json (coach_code DEVCOACH30), runs/11/revenuecat-A-after-step6.json (coach_code DEVCOACH18)
- runs/11/13-step6-devcoach18-paired.png
- runs/11/edge-logs-redeem-console.txt

**Decision quote.**
> 

**Triage.**

