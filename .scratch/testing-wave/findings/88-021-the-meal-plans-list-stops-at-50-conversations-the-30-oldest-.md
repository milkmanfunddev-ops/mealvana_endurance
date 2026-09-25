# 88-021 · The Meal plans list stops at 50 conversations; the 30 oldest can't be reached

- kind: bug
- status: triaged
- ticket: 88
- run: w29-20260925T1949Z
- screen: Conversations
- decision: 

**Steps.**
1. Retest of 15-007. Conversations > Meal plans; scroll to the bottom with slow drags (20:30Z).
2. Count meal_planning conversations in vana_conversations (not deleted).

**Expected.**
Every stored conversation is reachable (paging or load more).

**Actual.**
The list ends at "Sep 8, 8:23 AM", the 50th row by last_message_at; dev holds 80 meal_planning conversations back to 2026-06-12, so 30 can't be opened from the app. `fetchConversations` has `limit = 50` and the screen asks for no more. Long-press or swipe on a row offers nothing (long-press opens it).

**Evidence.**
- runs/88/122-15-007-list-very-bottom.png
- runs/88/db-28-15-007-counts.txt: 80 rows, and rows 49–52 by the list's order.

**Decision quote.**
> 

**Triage.**

Fix ticket 126 (Lee, 2026-09-25). Closed by the retest after it merges.
