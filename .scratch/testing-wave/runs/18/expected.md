# Ticket 18 expected records (run w16-20260924T2100Z)

Account: test@test.com (dev user 607f9dd5-6fa7-48ee-a628-720d4a0506a1), entitled dev admin. RevenueCat: not
touched (nothing bought; nothing expected to change). Ticket 29 runs read-only on the same account at the same time;
its sessions, events and edge requests are expected and not checked here.

## Before (db-00-before.txt, 21:0xZ)
- Week 2026-09-20: confirmed plan be6abf2f (conversation f6a0f7fa, 4 meals, meal_plans.shopping empty, no list:
  finding 19-001). Archived plans 6f365c30, 15b6b4f4, b82409d9, 54a02440 (54a02440 belongs to conversation
  d8efbdb3 and owns list 9bdc9556, 6 items, the list the Shopping tab shows).
- Conversations d8efbdb3 (meal_planning, 3 messages) and 4d62c862 (general, 1 message), untouched by this run.

## How the browse screen is reached and what each control should write
The browse screen (`/vana/browse?c=<conversation>`) opens only from a Vana chat: the composer's plus menu
("Browse meals", mp-236 clause 5) or "Browse meals" under a picker. Reaching a chat means Ask Vana's opener,
one chat call (COST spend 16 chat 18 first). The opener is a chat turn, not a plan: no meal_plans row from it.

Per the code (vana_browse_screen.dart, vana actions.ts `pick_meals`, plan.ts `addMeal`/`getConversationPlan`):
1. Open browse, Back, Done, search, filter, rails, See all, open a card's detail and back: no write.
2. Add (the tick) on a card: one `vana-action pick_meals` with this conversation id and servings 4. The server
   finds the conversation's newest plan, or inserts a DRAFT meal_plans row for week 2026-09-20 tied to the new
   conversation when there is none, then inserts one plan_meals row (servings 4, servings_left 4) and rebuilds
   that draft's shopping. No model call, no vana_calls row for a plan. The card turns ticked, a success toast shows.
3. "Add to plan" on the detail opened from browse (`?pick=`): same pick_meals, one more plan_meals row (or the
   same row's servings +N for the same meal); the detail pops true and the card turns ticked.
4. Done / Back to the chat: the chat reloads its draft (refreshDraft) and its plan bar shows the picked meals.

Must not change: be6abf2f (status, 4 meals, empty shopping), 54a02440 and list 9bdc9556, conversations d8efbdb3
and 4d62c862. No plan is generated (no draft_week / new_plan / model-drafted plan).

## Run decision
Add is tried only inside the new conversation this run opens, so the draft it creates is this run's own and no
inherited plan, list or conversation changes. Picking from d8efbdb3 would write into archived plan 54a02440 and
rebuild list 9bdc9556 (the Shopping tab's list); picking from f6a0f7fa would change confirmed plan be6abf2f.
