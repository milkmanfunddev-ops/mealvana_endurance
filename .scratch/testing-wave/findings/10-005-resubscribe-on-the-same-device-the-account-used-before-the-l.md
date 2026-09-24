# 10-005 · Resubscribe on the same device the account used before the lapse (local data present) and let the new subscription lapse again

- kind: followup-test
- status: open
- ticket: 10
- run: w8-20260924T1418Z
- screen: Paywall (lapsed)
- decision: 

**Steps.**
1. Buy, log a meal and make a plan on one simulator; let the Test Store subscription lapse there with the app kept installed (ticket 09's path).
2. On the same simulator, resubscribe from the full-screen paywall.
3. Edit the plan and log a new meal while Pro is live; let the second subscription lapse too; resubscribe a third time.

**Expected.**
Step 2: the timeline and the plan are there at once, from the local database. Step 3: the second lapse lands on the full-screen paywall again, and after the third purchase both the old and the new meals and the edited plan are there; RevenueCat and the Entitlement row agree on each new expiry.

**Actual.**


**Evidence.**
- runs/10/notes.md

**Decision quote.**
> 

**Triage.**

