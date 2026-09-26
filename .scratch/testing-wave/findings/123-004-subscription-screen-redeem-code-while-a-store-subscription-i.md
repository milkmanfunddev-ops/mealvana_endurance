# 123-004 · Subscription screen: Redeem code while a store subscription is running

- kind: followup-test
- status: open
- ticket: 123
- run: w38-20260926T0341Z
- screen: Subscription
- decision: 

**Steps.**
1. A Monthly (Test Store) account opens Settings → Subscription.
2. Redeem code with a giveaway code (not the once-in-total one another run needs).
3. Read the screen, RevenueCat and the Entitlement row; let the monthly end.

**Expected.**
mp-558: which Pro the screen shows (the store plan with Manage, or the Grant with its days left), and Manage stays while a store subscription is on record. The Grant keeps Pro past the store plan's end.

**Actual.**
Not run (look-around, ticket 123).

**Evidence.**
- runs/123/04-A-07-008-subscription-monthly.png

**Decision quote.**
> 

**Triage.**
