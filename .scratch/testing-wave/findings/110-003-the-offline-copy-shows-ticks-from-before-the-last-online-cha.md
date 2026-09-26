# 110-003 · The offline copy shows ticks from before the last online change: a tick sent just before going offline is missing

- kind: bug
- status: triaged
- ticket: 110
- run: w30-20260925T2103Z
- screen: Food (Shopping sub-tab), offline copy
- decision: 

**Steps.**
1. Online, the tab replays two ticks at 21:12:45Z (Mixed vegetables checked, Avocado unchecked); the server row and the server's meal_plans.shopping mirror agree.
2. Cold restart with the network cut at 21:13:34Z, Food > Shopping.

**Expected.**
The offline copy shows the list as it last was on this phone: Mixed vegetables ticked.

**Actual.**
The offline copy shows Mixed vegetables unticked. The phone's copy of the plan (the Drift mirror the offline copy reads) was not refreshed after the tick went through, although the server's mirror was (db-03-plan-mirror.txt). Any tick made online shortly before the athlete loses signal can show as not done in the store.

**Evidence.**
- runs/110/31-clean-C-avocado-ticked-offline.png — offline copy: Mixed vegetables unticked.
- runs/110/db-03-plan-mirror.txt — server mirror: Mixed vegetables checked true.
- runs/110/db-01-after-reconnect.txt — row checked since 21:12:45Z.

**Decision quote.**
> 

**Triage.**

Fix ticket 133, Shopping lists and Kroger (Lee, 2026-09-26). Closed by the retest after it merges. Record: `triage-20260926.md`.
