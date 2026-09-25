# 88-018 · A half-built new-plan draft can't be found from the Plan tab

- kind: bug
- status: open
- ticket: 88
- run: w29-20260925T1949Z
- screen: Food > Plan
- decision: 

**Steps.**
1. Retest of 14-008. Plan options > Start a new plan; Browse adds one meal (draft 666be167 in conversation `9db7c080`, 20:25:43Z). Back to Food > Plan.
2. Look on the Plan tab, the Vana note card, Plan options > Previous plans, and Conversations > Meal plans.

**Expected.**
The athlete can find and finish the draft: the Plan tab says a new plan is in progress, or triage decides it need not (14-008).

**Actual.**
The Plan tab shows only the confirmed plan; Previous plans lists one "Sep 20 – Sep 26 · 5 meals" row with no state tag (the archived be6abf2f) and not the draft; every Conversations row reads "No plan yet" (88-002), so the draft's conversation is one of several identical rows at the top. The only way back is to guess the row by its time. Once the confirmed plan was deleted (14-007), the Plan tab did show the draft with "Confirm plan · build shopping list". Product question: should the Plan tab show a draft in progress next to the confirmed plan?

**Evidence.**
- runs/88/109-14-008-plan-tab-with-draft.png
- runs/88/110-14-008-previous-plans.png
- runs/88/db-24-before-delete.txt: 666be167 draft, 8ebeb6da confirmed.

**Decision quote.**
> 

**Triage.**
