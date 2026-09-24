# 14-001 · New meal plan neither archives the plan it is on nor starts a draft; the draft appears at the first pick and the old plan stays confirmed

- kind: ssot-conflict
- status: open
- ticket: 14
- run: w8-20260924T1418Z
- screen: Plan tab → Vana chat (New meal plan)
- decision: mp-241

**Steps.**
1. Signed in as the dev test account test@test.com (entitled). Plan tab shows Sep 20 – Sep 26, 4 meals: the confirmed plan `be6abf2f` (14:21:53Z).
2. Tap New meal plan (14:22:03Z). A new chat opens with Vana's opener only.
3. SQL snapshot at 14:22:40Z: one new `vana_conversations` row `d8efbdb3` (meal_planning, 1 message), no new `meal_plans` row, `be6abf2f` still `confirmed`.
4. Tap the chip "Show me what fits the training" (14:23:04Z), then pick Egg & Veggie Scramble (14:23:36Z).
5. SQL again at 14:23:50Z: draft `54a02440` (week 2026-09-20, conversation `d8efbdb3`, 1 meal) created 14:23:36Z. `be6abf2f` still `confirmed`, `updated_at` unchanged (2026-09-24 01:10:06Z).
6. Back to the Plan tab: it still shows the old confirmed plan's 4 meals.

**Expected.**
Per mp-241, tapping New meal plan archives the plan the athlete is on (`be6abf2f` → `archived`) and starts a fresh, empty draft (a new `meal_plans` row, `draft`, 0 meals, tied to the new conversation) at the tap.

**Actual.**
The tap creates only the conversation. No plan row is archived or created. The draft appears at the first pick, and the old confirmed plan stays `confirmed` and stays on the Plan tab. This is what the code is built to do: `plan_tab.dart` pushes `/vana?c=new&mode=meal_planning&intent=new_plan` and nothing in `lib/` calls `MealPlanController.newPlan()` (the `new_plan` action that "Archive[s] the current plan and start[s] an empty draft"). The server's own new-plan rule (`persona.ts` NEW_PLAN_STANDING) says the old plan "is replaced the moment this one is confirmed".

mp-241 disagrees with itself here: its second sentence says "the Plan tab keeps the confirmed plan until a new one is confirmed", its third says New meal plan "archives the plan it is on". mp-234's example also has the old plan left as it was while the new one is built. The built app follows the keep-until-confirm reading. Triage has to rule which sentence stands.

**Evidence.**
- runs/14/db-before.txt — all plans and conversations before the tap (be6abf2f confirmed).
- runs/14/db-after.txt — after the tap, only conversation d8efbdb3 is new.
- runs/14/db-diff.txt — the diff before → after the tap.
- runs/14/db-after-pick.txt — after the first pick, draft 54a02440 appears; be6abf2f unchanged.
- runs/14/db-diff-after-pick.txt — the diff before → after the first pick.
- runs/14/02-plan-tab-synced-4-meals.png — the plan it was on.
- runs/14/05-new-conversation-opener-only.png — the new conversation, opener only.
- runs/14/08-plan-tab-after-new-plan-old-plan-still-shown.png — Plan tab after, old plan still shown.

**Decision quote.**
> Every conversation with Vana builds its own Draft, so an athlete can hold any number of drafts but only one confirmed plan per week. Confirming a draft archives every other plan for that week, drafts from other conversations included, and the Plan tab keeps the confirmed plan until a new one is confirmed. "New meal plan" archives the plan it is on and starts a fresh, empty draft. Example: an athlete starts a draft in Monday's conversation and another in Wednesday's; confirming Wednesday's archives Monday's draft and the week's old confirmed plan.

**Triage.**

