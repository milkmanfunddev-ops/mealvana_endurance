# Ticket 19 expected records (run w11-20260924T1647Z)

Account: test@test.com (dev user 607f9dd5-6fa7-48ee-a628-720d4a0506a1). RevenueCat: not touched by this ticket
(entitled dev admin; nothing bought, nothing expected to change).

## Before (from the wave-10 hand-off, checked by SQL in db-00-before.txt)
- Confirmed plan be6abf2f (week 2026-09-20), its list 03c4c52b "Week of 2026-09-20": 15 rows, 0 checked;
  meal_plans.shopping mirror of be6abf2f has 15 lines.
- 13 other lists on the account (older plans' lists and two empty hand-made lists).

## Each action and the rows it should leave (shopping_lists / shopping_items / meal_plans.shopping)
1. Open "Previous lists" from the shopping tab's menu: no write. Sheet lists every list except the one on screen.
2. "New list": one new shopping_lists row, user_id = test, plan_id null, name "List 2026-09-24" (or the typed name),
   0 shopping_items. The tab opens it as the most recent list. 03c4c52b unchanged (15 rows).
3. Delete the NEW list: its shopping_lists row gone, no shopping_items left with its list_id. The tab falls back to the
   most recent list left (03c4c52b by confirmed_at). No other list changes.
4. Delete 03c4c52b (the confirmed plan's list), last action: by the server contract (contracts.ts delete_shopping_list,
   shopping.ts deleteList) the list row and its 15 items go and meal_plans.shopping of be6abf2f becomes [];
   the plan itself stays confirmed. mp-244 says the list is built at confirm and rebuilt after every plan edit, and
   no decision says whether the athlete may delete a confirmed plan's list; the result is recorded either way.
