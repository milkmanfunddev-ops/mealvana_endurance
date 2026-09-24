# 16-010 · Conversation of a Draft archived by another confirm: what its plan bar, cards and Review sheet say

- kind: followup-test
- status: open
- ticket: 16
- run: w9-20260924T1446Z
- screen: Vana chat (meal planning)
- decision: 

**Steps.**
1. Open Conversations → Meal plans → Sep 24, 9:23 AM (`d8efbdb3`), whose Draft `54a02440` is now archived (16-001).
2. Read the plan bar; tap Review plan if offered; tap Confirm plan; pick a meal card; send a message.
3. Also check the resumed conversation's meal cards: on the first visit the Egg & Veggie Scramble card showed an empty checkbox although that meal was in the Draft (04-draft-conversation-d8efbdb3.png).

**Expected.**
An archived Draft reads as archived (or the conversation starts a fresh Draft on the next pick, per mp-241's "every conversation builds its own Draft"), and Confirm never touches another plan. A card for a meal already in the plan shows as picked.

**Actual.**


**Evidence.**
- runs/16/04-draft-conversation-d8efbdb3.png — card with an empty checkbox, plan bar "1 meal".
- runs/16/db-after.txt — 54a02440 archived.

**Decision quote.**
> 

**Triage.**

