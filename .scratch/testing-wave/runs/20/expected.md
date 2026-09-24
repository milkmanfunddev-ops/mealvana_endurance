# Ticket 20 expected records (w10-20260924T1614Z)

Account: test@test.com (dev admin, user 607f9dd5-6fa7-48ee-a628-720d4a0506a1). No new account, no plan edit, no COST spend.

## Before (checked by SQL at 16:15Z, db-before.txt; matches the wave-9 hand-off)
- Week of 2026-09-20: plan be6abf2f confirmed; 6f365c30, 15b6b4f4, b82409d9, 54a02440 archived.
- Most recent list 03c4c52b-33f0-4c32-b0c6-a1984f43142f "Week of 2026-09-20", plan_id be6abf2f, confirmed_at 14:53:15Z.
- 15 shopping_items rows, 15 distinct names, 0 checked, 0 have. meal_plans.shopping mirror: the same 15 names, none checked.

## During / after (from the ticket's criteria)
- Rows checked online in the app show `checked = true` in shopping_items within seconds, and in the mirror.
- After a cold restart the same rows show checked on screen.
- Rows checked while offline stay checked on screen through an offline restart; once the network is back, shopping_items shows them checked.
- Nothing lost or doubled: list 03c4c52b still 15 rows, 15 distinct names, no new list, plan be6abf2f still confirmed and untouched.

## End
- Every row put back unchecked through the app: 15 rows, 0 checked (unless that hides a Finding; notes say which).
