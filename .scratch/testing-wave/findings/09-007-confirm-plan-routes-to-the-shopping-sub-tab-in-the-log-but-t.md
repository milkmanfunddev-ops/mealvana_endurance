# 09-007 · Confirm plan routes to the Shopping sub-tab in the log but the Plan sub-tab shows; check which one the athlete should land on

- kind: followup-test
- status: closed
- ticket: 09
- run: w7-20260924T1219Z
- screen: Food (Plan tab)
- decision: 

**Steps.**
1. Confirm a Vana plan (Review plan → Confirm plan).
2. Read the console: at 12:34:36Z it logged `GoRouter: INFO: going to /main?tab=food&food=shopping`.
3. Look at which sub-tab is selected.

**Expected.**
One answer: the router's target and the selected sub-tab agree (either the Shopping list the confirm just built, or the Plan).

**Actual.**
This run: the log says `food=shopping`, the screen showed the Plan sub-tab selected (17-after-confirm.png). Not a clear bug yet; needs a look at what the design wants.

**Evidence.**
- runs/09/console.log line 477
- runs/09/17-after-confirm.png

**Decision quote.**
> 

**Triage.**

Picked for retest ticket 88 (Lee, 2026-09-25: every open follow-up test folded into the planned runs, cap of ten lifted for this pass).

Closed by retest ticket 88 (run w29-20260925T1949Z, build e3367d2c): pass, evidence in runs/88/verdicts.md.
