# 16-005 · A resumed older meal-plan conversation is headed New meal plan

- kind: bug
- status: triaged
- ticket: 16
- run: w9-20260924T1446Z
- screen: Vana chat (meal planning)
- decision: 

**Steps.**
1. Conversations → Meal plans → open an older conversation, e.g. Sep 23, 6:16 AM (`f6a0f7fa`, whose plan is confirmed) or Sep 24, 9:23 AM (`d8efbdb3`).

**Expected.**
A header that names the conversation or the plan (for example "This week's plan", the row's own title), not the label of the button that starts a fresh one.

**Actual.**
Both headers read "New meal plan", including one whose plan bar says "Plan confirmed".

**Evidence.**
- runs/16/05-conversation-f6a0f7fa.png — "New meal plan" above "Your plan · 4 meals, Plan confirmed".
- runs/16/04-draft-conversation-d8efbdb3.png

**Decision quote.**
> 

**Triage.**
Fix ticket 48 (Lee, 2026-09-25). Closed by the retest after it merges.
