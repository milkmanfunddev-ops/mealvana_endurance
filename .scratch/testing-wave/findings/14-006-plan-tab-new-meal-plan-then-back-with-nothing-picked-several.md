# 14-006 · Plan tab: New meal plan then Back with nothing picked, several times

- kind: followup-test
- status: triaged
- ticket: 14
- run: w8-20260924T1418Z
- screen: Plan tab / Vana chat (New meal plan)
- decision: 

**Steps.**
1. Plan tab → New meal plan. 2. Wait for the opener, pick nothing, tap Back. 3. Repeat three times. 4. Open the conversation list.

**Expected.**
Each tap costs one opener; the list shows what the athlete would expect (probably not three empty "This week's plan" conversations). No draft rows are left behind; nothing on the Plan tab changes.

**Actual.**
Not run (followup). Seen here: the tap alone writes a conversation row titled "This week's plan" with the opener in it.

**Evidence.**
- runs/14/db-diff.txt — one conversation per tap.

**Decision quote.**
> 

**Triage.**

Picked for retest ticket 88 (Lee, 2026-09-25: every open follow-up test folded into the planned runs, cap of ten lifted for this pass).
