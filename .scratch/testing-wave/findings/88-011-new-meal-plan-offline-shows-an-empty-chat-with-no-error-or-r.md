# 88-011 · New meal plan offline shows an empty chat with no error or retry, and its Browse does nothing

- kind: bug
- status: triaged
- ticket: 88
- run: w29-20260925T1949Z
- screen: Vana chat (New meal plan)
- decision: 

**Steps.**
1. Retest of 14-009. App relaunched with netcut; Food > Plan; netcut on (20:15:10Z); tap New meal plan.
2. Watch for 25 s; then plus > Browse meals (20:16:25Z).
3. Read vana_conversations.

**Expected.**
14-009: the chat says it can't reach Vana and offers a retry; no half conversation or plan row is left; the Plan tab is unchanged.

**Actual.**
The console logs `[VANA_CHAT_CONTROLLER] Vana turn failed {kind: meal_planning, opener: true}` and a network error at 20:15:16Z, but the screen stays an empty chat headed "New meal plan" with "Your plan · 0 meals" and no message, error or Retry for 25 s and more. Browse meals from its plus menu does nothing. Nothing was written on dev (no conversation row) and the Plan tab was unchanged, which is right. The Ask Vana sheet has an offline line with Retry ("You're offline — Vana will reply when you're back."); the planning chat has none. (netcut limit: the connectivity check reads online, 20-006, so this is the network-error path.)

**Evidence.**
- runs/88/75-14-009-offline-2s.png, runs/88/77-14-009-offline-25s.png: empty chat.
- runs/88/80-offline-browse-1s.png, runs/88/81-offline-browse-6s.png: Browse did not open.
- runs/88/db-17-14-009-offline.txt: no conversation row.
- runs/88/console-redacted.log: "Vana turn failed" at 15:15:16 local.

**Decision quote.**
> 

**Triage.**

Fix ticket 129 (Lee, 2026-09-25). Closed by the retest after it merges.
