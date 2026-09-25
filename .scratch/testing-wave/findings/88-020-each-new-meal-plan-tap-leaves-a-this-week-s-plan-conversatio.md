# 88-020 · Each New meal plan tap leaves a This week's plan conversation and a paid opener, even when the athlete backs out

- kind: idea
- status: open
- ticket: 88
- run: w29-20260925T1949Z
- screen: Food > Plan / Vana chat (New meal plan)
- decision: 

**Steps.**
1. Retest of 14-006 (one repeat; the wave's chat cap was used). Food > Plan > New meal plan (20:28:40Z); wait for the opener; Back with nothing picked.
2. Read vana_conversations, meal_plans and vana_calls; open Conversations.

**Expected.**
14-006: no draft rows left and the Plan tab unchanged (both hold); the list shows what the athlete would expect, probably not an empty "This week's plan" conversation per tap.

**Actual.**
The tap wrote conversation `7cc15497` ("This week's plan", 1 opener message, no plan) and a paid opener ($0.0025); it shows as one more "No plan yet" row at the top of Meal plans. This run added three such rows (449da56d, 9db7c080, 7cc15497). Idea: start the conversation row on the first pick or message, or drop an opener-only new-plan conversation from the list.

**Evidence.**
- runs/88/db-27-14-006.txt
- runs/88/118-14-006-opener.png, runs/88/119-14-006-after-back.png

**Decision quote.**
> 

**Triage.**
