# 04-005 · Continue then cancel the Test Store sheet leaves the new account on the paywall

- kind: followup-test
- status: open
- ticket: 04
- run: w4-20260924T0418Z
- screen: Paywall
- decision: 

**Steps.**
1. A new account on the paywall: pick Monthly, tap Continue.
2. Cancel the Test Store sheet (and, separately, pick its "failed purchase" option).

**Expected.**
No snackbar for a cancel, the failure snackbar for a failed purchase, the account stays on the
paywall, and RevenueCat and `user_entitlements` stay empty.

**Actual.**
Not run (look-around, ticket 04).

**Evidence.**
- runs/04/14-paywall.png

**Decision quote.**
> 

**Triage.**

