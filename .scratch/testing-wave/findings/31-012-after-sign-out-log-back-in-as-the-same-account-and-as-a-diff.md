# 31-012 · After sign-out: log back in as the same account and as a different account on the same phone

- kind: followup-test
- status: open
- ticket: 31
- run: w11-20260924T1648Z
- screen: Welcome
- decision: 

**Steps.**
1. After signing out of test@test.com, log in again as test@test.com: which screen opens, is the plan and the water-bottle value back.
2. On the same phone, sign in as a different (lapsed) account: does it see the paywall, and does any of the first account's local data show.

**Expected.**
The same account comes back to its data; a different account sees only its own data and its own subscription state.

**Actual.**
Not run. After this run's sign-out and relaunch the console still printed `[SubscriptionService] customer info updated {active: true, expires_at: 2027-09-15...}` while on Welcome, which matches existing finding 03-002 (the RevenueCat SDK stays identified as the last account).

**Evidence.**
- runs/31/console-excerpts.log: customer info active true at 11:54:05 and 11:54:21 local, after sign-out
- runs/31/19-relaunch-after-signout.png: Welcome after relaunch

**Decision quote.**
> 

**Triage.**
