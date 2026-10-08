# 49 expected records (written before the run, from the ticket's checks and ticket 45's Decisions)

Account: test@test.com (dev, user 607f9dd5-6fa7-48ee-a628-720d4a0506a1). RevenueCat: nothing read or written (no check names it).
Baseline: db-before.txt (17:20:13Z): wallet 2490; newest ledger row 13:12:03Z describe-meal; no live meal_logs from today; saved_meals newest 2026-09-26; food_preferences newest updated_at 08:07:20+00 (pre-fix local-as-UTC).

| # | Action | Expected after |
|---|---|---|
| 1 | Spend 1, describe "two scrambled eggs, a slice of whole wheat toast with butter, a banana" | exactly one token_ledger row (-1, debit_usage, describe-meal); Back on Review -> Describe with text + "Review again"; reopening Review adds no ledger row; empty name -> Log this meal disabled + "Give this meal a name to log it."; Log -> one meal_logs row source describe |
| 2 | Swap one item, quantity 2 | row "2 × 1 <unit>"; Edit Item reopened: Quantity 2, Portion "1 <unit>"; picker kcal == row kcal; stored item carries quantity 2 |
| 3 | Spend 2, "my bike ride" | Describe shows "That doesn't sound like food or drink…" under kept text; no Review; NO token_ledger row (Lee 2026-10-08: not-food is free); describe-meal function_logs line "Not food … 422, no debit" |
| 4 | 3 characters + Analyze | "Add a bit more: at least 5 characters, like what you ate and how much."; no call, no ledger row |
| 5 | Spend 3, photo + text | exactly one ledger row ref analyze-meal-photo; meal_logs row source photo, photo_path `<uid>/<uuid>.jpg`, notes = AI note; function_edge_logs request line may be missing (ticket 41 ruling: ingestion gap) -> confirm via function_logs "Analyzing photo"/"Success" |
| 6 | Reconnect notice + Save as favorite | words, not raw keys; Save as favorite writes one saved_meals row (leftover, no in-app delete) |
| 7 | Food Preferences: move one food one level, Save | newest food_preferences.updated_at carries +00 and equals UTC wall clock of the save (±1 min); then move back and Save |
| 8 | Remove item (Review swipe) / remove meal (Timeline) | record confirm/undo seen; Timeline Remove -> soft delete (is_deleted true); Undo (if shown) -> is_deleted false |
| 9 | Reconnect notice | record whether it shows, Reconnect -> Connected Apps, X -> gone, relaunch behaviour |
| 10 | Edit Meal / Describe / swap picker untried paths | record behaviour; Back with unsaved edits -> "Discard changes?" dialog |
| end | cleanup | every meal_logs row this run made is_deleted true; food_preferences back to original level; wallet = 2490 - (debits seen) |
