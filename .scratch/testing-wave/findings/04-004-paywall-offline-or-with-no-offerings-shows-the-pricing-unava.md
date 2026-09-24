# 04-004 · Paywall offline or with no offerings shows the pricing-unavailable state and still no way off

- kind: followup-test
- status: open
- ticket: 04
- run: w4-20260924T0418Z
- screen: Paywall
- decision: 

**Steps.**
1. Turn the simulator's network off (or point at an offering that fails to load).
2. Sign in a new account, or open the app on the paywall.

**Expected.**
The `paywall.pricing_unavailable` state shows instead of the plans, Continue does nothing harmful,
the ⋯ menu still works, and there is still no way off the paywall (mp-457).

**Actual.**
Not run (look-around, ticket 04).

**Evidence.**
- runs/04/14-paywall.png

**Decision quote.**
> 

**Triage.**

