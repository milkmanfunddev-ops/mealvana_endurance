# Ticket 27 expected records (run w15-20260924T2039Z)

Account: test@test.com (user 607f9dd5-6fa7-48ee-a628-720d4a0506a1), the entitled dev test account. No new account.
RevenueCat: nothing expected to change (no purchase); not checked.
AI: no AI call from this run (manual entry only); COST not spent.

## Before (dev `meal_logs`, log_date 2026-09-24, read 20:40:29Z: db-totals-before.txt)
Eight non-deleted rows from waves 13-14 (38c4f0ed, 00a120e5, f952f981, 46b1d076, 35409440, a61f94fd, f510d5d3,
ae7dba02), untouched by this run. Sums: 2743 kcal (a61f94fd has calories null), 381.9 C, 169.25 P, 84.2 F.
Ticket 28 (same account, other simulator) may add one barcode row, preferably on 09-23; if on 09-24 it counts in the
day's totals and is listed, not judged.

## My rows (Log a Meal -> Manual tab), log_date 2026-09-24, source 'manual'
1. "W15-27 edit": slot lunch, 520 kcal, 60 C, 30 P, 15 F.
2. "W15-27 delete": slot snack, 210 kcal, 25 C, 10 P, 8 F.

After both logs: 10 rows (+ any of 28's), sums 3473 kcal, 466.9 C, 209.25 P, 107.2 F.

## Edit (timeline row menu -> edit, EditMealLogScreen, simple macro fields since items [])
"W15-27 edit" -> name "W15-27 edited", 610 kcal, 70 C, 35 P, fat unchanged 15. Same id, updated_at moves, is_deleted false.
After edit: sums 3563 kcal, 476.9 C, 214.25 P, 107.2 F.

## Delete (timeline row menu -> delete)
"W15-27 delete" -> is_deleted true on the server (soft delete, softDeleteLog + immediate upload), row gone from
the timeline. After delete: 9 non-deleted rows, sums 3353 kcal, 451.9 C, 204.25 P, 99.2 F.

## Screen
Every place that shows the day's consumed totals equals the SQL sums at each moment, counting only the rows the
phone holds; any gap from rows the phone has not synced (10-001) is written down with the row ids.
