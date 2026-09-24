# Ticket 15 expected records (RUN w12-20260924T1712Z)

Account: test@test.com (dev admin, user 607f9dd5-6fa7-48ee-a628-720d4a0506a1). No new account.

## Before (db-before.txt, db-messages-*.txt)
- user_entitlements: one row, active_until 2027-09-15 (entitled).
- Subject conversation `ebac747d-86a7-4182-b9f1-327895bc96e3` (meal_planning, "This week's plan", Sep 22 12:08 UTC):
  11 stored messages, ordered assistant, user, assistant, user, assistant, user, assistant, user,
  assistant, user, assistant (db-messages-ebac747d.txt). Its Draft `15b6b4f4` is archived (4 meals:
  Injera with shiro wot, Käsespätzle, Rice black beans guac, Rice black beans plantain), archived by a
  later confirm of the same week (mp-241).
- Second subject `1a24f2bf-df4d-4f94-ad5d-2f06bf20e9f8` (Sep 16, week 2026-09-13): 7 stored messages,
  plan `f2c0bc78` confirmed, 6 meals.
- Totals: 40 meal_plans, 135 vana_conversations, 407 vana_messages; last message 2026-09-24 14:50:07Z.

## During / after (db-after.txt)
- The screen shows, for each opened conversation, one turn per stored message, same count, same order,
  same roles; its Draft/plan shown per mp-241 (for ebac747d: an archived Draft, not a live one).
- No new plan: meal_plans count stays 40; no row with created_at after the run start.
- Opening a conversation writes no new message to it (ebac747d stays at 11, 1a24f2bf at 7).
- Statuses of 15b6b4f4, f2c0bc78, be6abf2f unchanged.
- RevenueCat: not touched by this ticket (no purchase, no grant); no check planned.
- COST: 0 plans, 0 logging calls.
