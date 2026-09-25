# 09-005 · Log a Meal quick add: the same item twice, a changed time eaten, and logging offline

- kind: followup-test
- status: triaged
- ticket: 09
- run: w7-20260924T1219Z
- screen: Log a Meal (Common, quick add sheet)
- decision: 

**Steps.**
1. Timeline → + Add Food → Common → Eggs + toast → Log it, then the same item again straight away.
2. Change "Time eaten" to yesterday evening and log.
3. Turn the network off and log a quick add; turn it back on.

**Expected.**
Two separate meal_logs rows for the double log (or a clear "already logged"); the changed time lands on the right day; the offline log shows at once, uploads when back online (offline-first), and the timeline totals follow each change.

**Actual.**


**Evidence.**
- 

**Decision quote.**
> 

**Triage.**

Picked for retest ticket 91 (Lee, 2026-09-25: every open follow-up test folded into the planned runs, cap of ten lifted for this pass).
Moved to retest ticket 112 when 91 was split (Lee, 2026-09-25).
