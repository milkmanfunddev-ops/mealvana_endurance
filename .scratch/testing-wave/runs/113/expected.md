# Ticket 113 expected records (run w40-20260926T1051Z)

Account: test@test.com (dev user 607f9dd5-6fa7-48ee-a628-720d4a0506a1). No RevenueCat record is read or written (no purchase in scope). Dev database only, `meal_logs`, rows this run logs are named "W40-113 <what>".

## Before
- No `meal_logs` row named `W40-113%`.
- Old row a61f94fd ("W14-25 Decimal kcal", calories null) exists, is_deleted false (25-005 may correct it).

## Retests
- 25-001: Manual tab, calories 250.5, carbs 30.2, protein 12.25, fat 8.4 -> row with calories 251 (integer column, fix 41 rounds), macros as entered; timeline shows 251 kcal. Build a Meal's Manual food with 250.5 kcal -> the item and the row carry 251 (or the item 250.5 and the total 251).
- 27-002: after an edit and after a remove, `created_at` of the row keeps its microseconds (unchanged from the first server write); `updated_at` moves; remove sets is_deleted true.
- 27-003: console [ANALYTICS]: `meal_logged` x2 after two manual logs; `diary_closed` with items_logged 2 on leaving Log a Meal; `meal_log_updated` on Save changes; `meal_log_deleted` on timeline Remove.
- 28-001: after `simctl privacy reset camera`, first scanner open -> iOS camera alert; Allow -> no raw "MobileScannerController is already running" text; the scanner shows the plain no-camera state or plain words. Real scan: not run (needs a device).
- 28-002: console `barcode_scanner_opened` carries `context: meal_log_discover` from Log a Meal and `context: build_meal_add_food` from Build a Meal. Scan result routing: not run (needs a device).

## Follow-ups (records they should leave)
- 27-004: Undo after Remove -> row back, is_deleted false on server. Offline Remove -> is_deleted true after netcut off. Remove then kill -> row stays removed after relaunch (server is_deleted true, or uploaded on relaunch).
- 25-003 / 25-004: built rows' items (`components`) and totals equal what the builder showed; quantity 1.5 scales nutrients; favorite -> `saved_meals` row.
- 27-005: Edit Meal save writes what the fields show; Discard leaves the row unchanged.
- 25-002: empty name refused; saves of large/decimal values hold what was typed (or are refused before save).
- 28-005: every scanner path ends on athlete-readable text, no raw exception.
- 25-005: the 250.5 row can be corrected in Edit Meal (calories 250 or 251).

## After
- Every W40-113 row this run keeps is either is_deleted true or listed in notes.md as left on the account.
