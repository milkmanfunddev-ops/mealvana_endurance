# 07-006 · Restore after a reinstall with a real store receipt, where sign-in does not find Pro on its own

- kind: followup-test
- status: open
- ticket: 07
- run: w6-20260924T1118Z
- screen: Paywall
- decision: 

**Steps.**
1. On Lee's iPhone with an Apple sandbox tester (the ready-for-human sandbox ticket), buy Monthly on the paywall.
2. Delete the app, install it again from TestFlight or Xcode, sign in to the same account.
3. If the paywall shows, ⋯ → Restore purchases. Also try: buy while signed in as account A, reinstall, sign in as a new account B, Restore.

**Expected.**
Same account: the app opens after sign-in, or Restore opens it; RevenueCat shows no second purchase. Account B: RevenueCat's transfer rule for a receipt already tied to A decides; whatever it is, the paywall's answer and RevenueCat agree and the record states the rule.

**Actual.**
Not run. The simulator's Test Store cannot reach this branch (07-001).

**Evidence.**
- runs/07/notes.md

**Decision quote.**
> 

**Triage.**
