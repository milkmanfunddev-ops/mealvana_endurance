# Ticket 68 expected records (wave 7, run w7-20261008T2309Z)

Account: test@test.com (user 607f9dd5-6fa7-48ee-a628-720d4a0506a1). Copied from the ticket's checks.

## Before
- `food_preferences`: 9 rows (db-food-preferences-before.txt); `sports_drink` level 4 (like).
- `token_ledger` newest debit 3120a9bd… balance_after 2488 (db-ledger-before.txt).
- `meal_logs`: 6 rows in the last 3 days, none by this run (db-meal-logs-before.txt).
- `user_foods`: 1 row (Gatorade Kiwi Strawberry fe370e02…).

## After each check
1. Screen shows the server levels (sports_drink 4).
2. The moved food's row level changes within seconds; `updated_at` is `+00` and equals the UTC wall clock of the save; the Drift copy holds the same snake_case key, no display-name rows.
3. After sign-out/sign-in the screen shows check 2's level from the server. At the end the level is put back and the row read.
4. "egg": the full line "Add a bit more: at least 5 characters, like what you ate and how much." wrapped, no call, no ledger row.
5. "my bike ride": not-food line shown in full; no ledger debit; console `expected_failure` (not_food) and no `error_reported`; no FunctionException in dev Sentry for that minute.
6. >2,000 chars: message says the text is too long; no ledger debit. Camera after revoke: a message that explains itself.
7. Camera (no camera alert) and Gallery cancel: no `meal_ai_photo_attached`.
8. Gallery pick: one `meal_ai_photo_attached`; double-tap Analyze: one analyze-meal-photo request, one ledger debit (-1, ref analyze-meal-photo); the `meal-photos` object has no GPS EXIF.
9. Review: swipe away -> snackbar with Undo restores item and total; Back after rename -> Discard dialog; Log this meal -> one `meal_logs` row.
10. Swap picker: "2 × 1 cup" then "3 × 1 cup"; kcal follows; `items->n->>'quantity'` = 3.
11. Edit Meal: Discard leaves `meal_logs.updated_at` unchanged; Keep editing keeps the edit; Hide-details toggle alone gives no dialog.
12. Log a Meal: empty search feedback recorded; barcode Enter known/unknown; Recent/Common empty states; integrations read at sign-in and end.

## End
- Every meal this run logged deleted; preference row back at its start level; custom food deleted or a named leftover; ledger shows at most 3 debits... at most 1 (photo) expected: not-food and too-long are free.
