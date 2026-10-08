# 31 expected records (written 12:57Z, before the app was touched)

Account test@test.com (user 607f9dd5-6fa7-48ee-a628-720d4a0506a1). Start state in db-before.txt:
wallet balance 2493 unit credit; newest ledger row debit_usage -1 describe-meal 02:15:20Z;
one live meal_logs row from 10-07 (40600e48…, run 02's, not this run's); TrainingPeaks row
is_active true, last_sync_status `error` (not `requires_reauth`).

meal_logs columns (information_schema): id, user_id, log_date, slot, name, source, items, calories,
carbs_g, protein_g, fat_g, sodium_mg, photo_path, recipe_id, saved_meal_id, notes, eaten_at,
created_at, updated_at, is_deleted, plan_meal_id, servings.

- Each meal this run logs: one meal_logs row (created_at inside the run's minutes, name/items from
  the run's text) whose calories/carbs_g/protein_g/fat_g equal Review's totals (rounded as shown).
- 02-003: `notes` equals the AI note shown on Review (trimmed; empty -> null).
- 02-006 c: the meal logged with no slot ("Any time") stores `slot` null.
- 02-005: an item edited to quantity 2 then back to 1 stores no `quantity` (or 1) and its base macros.
- 02-010: the photo meal stores `source` = `photo` and a non-null `photo_path`; one debit for photo+text.
- Credits: before/after each spend, token_wallets.balance and the newest token_ledger rows.
  One `debit_usage -1` per successful analysis; none for empty/short input (stopped client-side),
  none for the offline attempt, none for a refused/failed call. Pill equals token_wallets.balance
  before and after (unit credit, whole tokens).
- 02-009: edit on the Timeline moves `updated_at`, `items` and totals; card and Net Balance "Eaten" agree.
- Step 7 delete: each logged row `is_deleted` true; cards gone after relaunch.
- 02-008: device prefs only: `flutter.tp_writeback_notice_shown`, `flutter.tp_writeback_enabled`.
  Close by scrim -> notice_shown true, enabled true. Turn Off -> enabled false. Keep -> enabled true.
  integrations row for training_peaks unchanged by this run (columns named, no token columns).
- Edge log: no describe-meal request for the empty, short and offline attempts; one per spend.
