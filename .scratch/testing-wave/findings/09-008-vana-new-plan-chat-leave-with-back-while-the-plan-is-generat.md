# 09-008 · Vana new-plan chat: leave with Back while the plan is generating, then come back

- kind: followup-test
- status: closed
- ticket: 09
- run: w7-20260924T1219Z
- screen: Vana chat (New meal plan)
- decision: 

**Steps.**
1. Food → New meal plan → Just decide for me.
2. While Vana is still building the plan (before "Your plan · N meals" shows), tap Back.
3. Open the Food tab and the conversation again.

**Expected.**
The plan finishes or is cleanly dropped; coming back shows the same conversation with its draft, not a second draft or a stuck spinner; at most one new-plan spend is counted.

**Actual.**


**Evidence.**
- 

**Decision quote.**
> 

**Triage.**

Picked for retest ticket 88 (Lee, 2026-09-25: every open follow-up test folded into the planned runs, cap of ten lifted for this pass).

Closed by retest ticket 88 (run w29-20260925T1949Z, build e3367d2c): pass, evidence in runs/88/verdicts.md.
