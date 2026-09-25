# 16-001 · Confirm plan in the Draft's conversation confirmed the week's old plan and archived the Draft it showed

- kind: bug
- status: triaged
- ticket: 16
- run: w9-20260924T1446Z
- screen: Vana chat → Review plan sheet (Confirm plan)
- decision: 

**Steps.**
1. Signed in as test@test.com. Week 2026-09-20 holds the confirmed plan `be6abf2f` (4 dinners, conversation `f6a0f7fa`) and the Draft `54a02440` (1 meal, Egg & Veggie Scramble, conversation `d8efbdb3`, made in ticket 14). db-before.txt.
2. Conversations → Meal plans → the Sep 24, 9:23 AM row (`d8efbdb3`). The plan bar reads "Your plan · 1 meal" with Review plan.
3. Review plan: the sheet shows "Your week, 1 meals · 1 servings", Egg & Veggie Scramble. Tap Confirm plan (14:53:12.9Z). The button spins about 3 s, then the app goes to Food.
4. SQL at 14:53:30Z (db-after.txt).

**Expected.**
The Draft the sheet showed is confirmed: `54a02440` → `confirmed`, every other plan of the week archived (`be6abf2f` → `archived`), and the Draft's list `9bdc9556` confirmed with its 6 rows. mp-241: "Every conversation with Vana builds its own Draft, so an athlete can hold any number of drafts but only one confirmed plan per week. Confirming a draft archives every other plan for that week, drafts from other conversations included, and the Plan tab keeps the confirmed plan until a new one is confirmed."

**Actual.**
The server confirmed the other plan. `be6abf2f` stayed `confirmed` (updated_at 14:53:15.81Z), and the Draft `54a02440` was archived at the same instant. The list that was rebuilt and confirmed is `be6abf2f`'s list `03c4c52b` (15 rows, confirmed_at 14:53:15.87Z); the Draft's list `9bdc9556` is untouched (confirmed_at null). The edge log shows `type=confirm_plan` at 09:53:16 local and day notes built "for be6abf2f". After Confirm, the Plan tab and the Shopping tab show the old 4-dinner plan, and the Egg & Veggie Scramble plan is gone.

Cause, read from the code at 52c68764 (not changed): the Review sheet's `onConfirm` in `vana_chat_screen.dart` calls `planController.confirmPlan()` with no `conversationId` or `planId`. The server's `resolvePlan` then falls back to "the week's active plan", which puts a confirmed plan before a draft (`plan.ts` getPlan: "confirmed first, else the newest draft"). So when the week already has a confirmed plan, Confirm in any Draft's conversation re-confirms the old plan and archives the Draft. When the week has no confirmed plan it lands on the newest draft, which only happens to be right. The criterion "SQL shows one confirmed plan for the week and the rest archived" holds, but for the wrong plan.

Not stopped: the list-vs-plan comparison still ran on the plan the server confirmed (see list-vs-plan-be6abf2f.txt). The Draft can no longer be confirmed through the app (it is archived), so the retest needs a new Draft (16-011).

**Evidence.**
- runs/16/db-before.txt — week 2026-09-20 before: be6abf2f confirmed, 54a02440 draft.
- runs/16/db-after.txt — after Confirm: be6abf2f confirmed (updated 14:53:15), 54a02440 archived.
- runs/16/04-draft-conversation-d8efbdb3.png — the Draft's conversation, plan bar "1 meal".
- runs/16/05-review-sheet-draft-54a02440.png — the Review sheet showing Egg & Veggie Scramble.
- runs/16/06-confirm-tapped-0.5s.png — Confirm waiting on the server.
- runs/16/08-after-confirm-8s.png — landed on Food, showing the old 4-dinner plan.
- runs/16/edge-function-logs.txt — confirm_plan at 09:53:16, day notes for be6abf2f at 09:53:21.
- runs/16/db-before-draft-list-items.txt — the Draft's own 6-row list, never confirmed.

**Decision quote.**
> Every conversation with Vana builds its own Draft, so an athlete can hold any number of drafts but only one confirmed plan per week. Confirming a draft archives every other plan for that week, drafts from other conversations included, and the Plan tab keeps the confirmed plan until a new one is confirmed. "New meal plan" archives the plan it is on and starts a fresh, empty draft. Example: an athlete starts a draft in Monday's conversation and another in Wednesday's; confirming Wednesday's archives Monday's draft and the week's old confirmed plan.

**Triage.**
Fix ticket 34 (Lee, 2026-09-25). Closed by the retest after it merges.
