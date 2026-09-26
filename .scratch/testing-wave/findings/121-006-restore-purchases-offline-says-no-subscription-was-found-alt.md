# 121-006 · Restore purchases offline says no subscription was found although it never reached the store

- kind: bug
- status: triaged
- ticket: 121
- run: w34-20260925T2320Z
- screen: Paywall
- decision: 

**Steps.**
1. A never-paid account on the paywall, app cut off with `netcut.sh on --relaunch`.
2. ⋯ → Restore purchases.

**Expected.**
A message that the check could not be made (no connection), not a verdict on the account.

**Actual.**
"No active subscription was found for this account." Console `restore completed {active: false}` with every RevenueCat request failing NETWORK_ERROR in the same minute. A paying athlete restoring on a bad connection would be told they have no subscription. App build e3367d2c.

**Evidence.**
- runs/121/29-offline-restore-contact.png
- runs/121/console-redacted.log (`restore completed {active: false}` at 18:31:07 local)

**Decision quote.**
> 

**Triage.**

Fix ticket 140, Paywall, purchases, codes, coach pairing (Lee, 2026-09-26). Closed by the retest after it merges. Record: `triage-20260926.md`.
