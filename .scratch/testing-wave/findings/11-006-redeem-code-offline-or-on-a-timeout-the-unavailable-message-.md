# 11-006 · Redeem code offline or on a timeout: the unavailable message, the code not spent, and a retry that works

- kind: followup-test
- status: triaged
- ticket: 11
- run: w5-20260924T0840Z
- screen: Redeem code (paywall ⋯ menu)
- decision: 

**Steps.**
1. A new athlete on the paywall, ⋯ → Redeem code, type DEVCOACH30.
2. Turn the network off (Network Link Conditioner "100% Loss", or airplane mode on a device), tap Redeem; wait out the 20 s timeout.
3. Turn the network back on and tap Redeem again.
4. RevenueCat failing after the claim (mp-535's "never spent") cannot be caused from the app without changing dev's function config; it is covered by the handler's seam test, and a device retest needs a way Lee approves.

**Expected.**
(mp-535, mp-598) Step 2: the `redeem_code.failed_unavailable` line under the field, the sheet open, no `code_redemptions` row. Step 3: paired, one row. mp-535: "a Code is never spent when RevenueCat cannot be reached, so trying again works".

**Actual.**
Not run (look-around, ticket 11).

**Evidence.**
- runs/11/06-redeem-sheet.png

**Decision quote.**
> A Code that is wrong, expired or already used gets a plain reason, and a Code is never spent when RevenueCat cannot be reached, so trying again works.

**Triage.**

Picked for retest ticket 87 (Lee, 2026-09-25).
