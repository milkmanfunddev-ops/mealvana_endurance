# 89-007 · Conversations Meal plans rows all read No plan yet, while the chat itself is headed Sep 20 week Draft

- kind: bug
- status: triaged
- ticket: 89
- run: w29-20260925T1950Z
- screen: Vana > Conversations > Meal plans
- decision: 

**Steps.**
1. test@test.com. Ask Vana > Open full screen > Conversations > Meal plans.
2. Open the Sep 22, 9:24 PM row (conversation 0401b3d8, which owns draft 173cebb2).

**Expected.**
Ticket 97: meal-plan conversations are titled by week and plan state ("Sep 20 week · Draft", "Sep 13 week · Confirmed", "No plan yet"), the same title in the list and in the chat's header.

**Actual.**
Every row in the list reads "No plan yet", including f6a0f7fa (owner of confirmed plan be6abf2f, Sep 23 6:16 AM row) and 0401b3d8 (draft 173cebb2 with 2 meals). Opening 0401b3d8 heads the chat "Sep 20 week · Draft". Ticket 100 retests 97; filed here because it was seen on the way to Browse.

**Evidence.**
- runs/89/55-conversations-meal-plans.png: the list.
- runs/89/56-conv-0401b3d8.png: the chat header.
- runs/89/db-00-baseline.txt: 173cebb2 and be6abf2f with their conversations.

**Decision quote.**
> 

**Triage.**

Fix ticket 126 (Lee, 2026-09-25). Closed by the retest after it merges.
