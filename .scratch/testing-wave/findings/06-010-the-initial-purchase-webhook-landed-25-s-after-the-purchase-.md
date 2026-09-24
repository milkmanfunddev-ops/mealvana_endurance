# 06-010 · The INITIAL_PURCHASE webhook landed 25 s after the purchase; ticket 05 saw about 1 s

- kind: idea
- status: open
- ticket: 06
- run: w6-20260924T1117Z
- screen: Paywall
- decision: 

**Steps.**
Record how long a Test Store purchase takes to reach the dev webhook, across runs, and say in the spec what delay a run should wait for before reading `user_entitlements`.

**Expected.**
A run reads the Entitlement row only after the webhook can have landed.

**Actual.**
INITIAL_PURCHASE landed at 11:29:02Z, 25 s after the 11:28:36Z purchase; ticket 05 saw about 1 s. No cause known. A run that reads the row within 25 s would see no row and could file a false bug. Written by the wave lead from the run's notes.

**Evidence.**
- runs/06/notes.md (11:28:25 entry)
- runs/06/db-C-after-purchase.txt

**Decision quote.**
> 

**Triage.**

