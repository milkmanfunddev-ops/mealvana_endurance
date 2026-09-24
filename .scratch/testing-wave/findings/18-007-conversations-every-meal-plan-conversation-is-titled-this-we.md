# 18-007 · Conversations: every meal-plan conversation is titled This week's plan and an old one opens headed New meal plan, so the athlete cannot tell which draft Browse will write to

- kind: idea
- status: open
- ticket: 18
- run: w16-20260924T2100Z
- screen: Conversations (Meal plans), Vana planning chat
- decision: 

**Steps.**
1. Vana chat > Conversations > Meal plans.
2. Open any older row.

**Expected.**
Each planning conversation says which week and plan it holds (draft, confirmed, archived, empty), so the athlete knows which draft Browse and its "+" will write into.

**Actual.**
All 15+ rows read "This week's plan" with only a date and time; the row opened (0401b3d8, an old opener with no plan) is headed "New meal plan". Browse in that conversation then made a new draft for the current week (18-002). An athlete cannot tell from the list which conversation belongs to the confirmed plan (f6a0f7fa), which to an archived one, and which has none.

**Evidence.**
- runs/18/11-conversations-mealplans.png: the list, every row "This week's plan".
- runs/18/12-planning-chat-0401b3d8.png: the opened row headed "New meal plan".

**Decision quote.**
> 

**Triage.**

