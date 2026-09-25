# 88-002 · Every row in Conversations > Meal plans reads No plan yet, whatever plan the conversation holds

- kind: bug
- status: open
- ticket: 88
- run: w29-20260925T1949Z
- screen: Conversations
- decision: 

**Steps.**
1. Signed in as test@test.com. Ask Vana > full screen > Conversations > Meal plans (19:54:45Z).
2. Read the row titles; open Sep 23 6:16 AM (`f6a0f7fa`) and Sep 22 7:08 AM (`ebac747d`).

**Expected.**
Each row is titled by its plan's week and state (ticket 97, 16-006/18-007): "Sep 20 week · Confirmed", "Sep 20 week · Archived", "No plan yet" only for a conversation with no plan or an empty draft. The resumed chat's header already shows these titles.

**Actual.**
All 50 rows read "No plan yet", including `f6a0f7fa` (confirmed be6abf2f, 4 meals), `ebac747d` (archived 15b6b4f4, 4 meals) and `0401b3d8` (draft 173cebb2). Opening them shows the right header ("Sep 20 week · Confirmed", "Sep 20 week · Archived"), so list and header disagree. Cause, read from the code: `VanaChatRepository.fetchConversations` selects `id, kind, title, summary, last_message_at, created_at` only, so `VanaConversationSummary.plan` is always null and `planConversationTitle` falls back to "No plan yet" (ticket 97, 0f7890b4, added the title but not the plan to the query). With every row the same, the athlete can't tell which conversation holds which plan (see also the half-built draft Finding from this run).

**Evidence.**
- runs/88/10-conversations-meal-plans.png: every row "No plan yet".
- runs/88/25-f6a0f7fa-open.png: the same conversation headed "Sep 20 week · Confirmed".
- runs/88/12-ebac747d-5s.png: headed "Sep 20 week · Archived".
- runs/88/db-00-before.txt: which conversation owns which plan.

**Decision quote.**
> 

**Triage.**
