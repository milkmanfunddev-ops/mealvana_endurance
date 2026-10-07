# 08 expected records (written before the first launch, 2026-10-07 ~11:08Z)

Read-only ticket: no RevenueCat or dev database record changes. No account made.

## Part A: Drift database, before the first launch

- File: `Documents/mealvana_endurance_db.sqlite` in the app's data container on wave-pool-3 (journal_mode `delete`, no -wal).
- `PRAGMA user_version` = **22**. Build under test (`ce1a1527`, develop-next) declares `schemaVersion => 22`.
- Lineage: develop's v22. Evidence: Vana tables present (`meal_plans`, `plan_meals`, `user_memories`, `user_entitlements`, `recipes`, `saved_meals`), `activities.duration_source` present, no `users.home_*` columns (mealplanning's v22 adds `users.home_*` and has no `duration_source`). So the last writer was a develop-lineage build at v22 (develop or develop-next), not mealplanning.
- Tables (40): activities, app_content_table, athlete_pairing_codes, carb_loading_day_meals, carb_loading_days, carb_loading_foods, carb_loading_plans, carb_loading_user_foods, coach_athlete_relationships, coach_messages, coach_pairing_codes, coaches, daily_macro_targets, during_workout_templates, edge_functions_table, events, feedback, food_preferences_table, foods, formula_pins, integrations, meal_logs, meal_plans, onboarding_surveys, personal_formulas, personal_templates, plan_meals, post_workout_templates, pre_workout_templates, race_checklist_items, recipes, saved_meals, template_foods, templates, tp_writeback_log, user_entitlements, user_foods, user_memories, users, weather_forecasts_table.
- Row counts before: activities 380, events 5, meal_logs 115, users 1 (`test@test.com`, id 607f9dd5-…), meal_plans 6, plan_meals 17, recipes 0, user_memories 22.
- Dev `app_config`: current_schema_version 20, latest_schema_version 20, min_supported 4. Local 22 is ahead of the server, so VersionCheckService has no reason to resync.

## Part A: what each device should do (HANDOFF "Drift" bullet + app_database.dart)

- **A v21 device (develop's v21, Vana tables):** `from 21 < 22` runs the v22 step (`addColumn('activities','duration_source')`, idempotent), `_validateSchemaIntegrity` walks only the declared tables and ignores extras, passes. Vana tables stay as orphans. No reset.
- **A v22 device (this one):** `from == to`, `onUpgrade` skipped. `duration_source` already present, validation passes. No reset.
- Expected after launch: `user_version` still **22**, same table list (orphans kept), no `DatabaseReset`/`deleteAndResync` line, no `DriftRemoteException`, no "schema is corrupted" (DEV-A6), test@test.com's data on the Timeline. Row counts may change only by sync pulls, never drop to zero.

## Part B / C

- No writes anywhere. Sign-out/sign-in on test@test.com only (auth session, no table rows). Opening screens and pressing Back.
