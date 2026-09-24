# 20-006 · Checked items offline with real airplane mode on a device, where the connectivity check also says offline

- kind: followup-test
- status: open
- ticket: 20
- run: w10-20260924T1614Z
- screen: Food (Shopping sub-tab)
- decision: 

**Steps.**
1. On Lee's iPhone (or any device), open the dev app's Shopping list online and tick two rows.
2. Turn on airplane mode, tick two more, force-quit and reopen, look at the list.
3. Turn airplane mode off, wait, reopen Shopping; SQL on shopping_items.

**Expected.**
As 20-001: ticks made offline stay and reach the database when the network returns.

**Actual.**


**Evidence.**
- runs/20/notes.md — this run's cut made `connect()` fail inside the app only; the OS still reported Wi-Fi, so paths that ask `connectivity_plus` (the sync coordinator, `connectivity_checker.dart`) saw "online" and were not tested offline.

**Decision quote.**
> 

**Triage.**

