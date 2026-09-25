# Triage analysis: local wipe, offline sync and user scoping (2026-09-25)

Written at triage of wave 25 (86-001, 86-007) from a read-only pass over the code at `dcbf75fa`. Line
numbers are from that commit.

## Tables and upload state (`lib/shared/database/tables/`)

- `user_id` and `needs_upload`: activities, events, meal_logs, meal_plans, plan_meals,
  carb_loading_plans, integrations, daily_macro_targets, saved_meals, user_foods, user_memories,
  onboarding_surveys, personal_formulas, personal_templates, formula_pins.
- Flag under another key: users (`id`), carb_loading_days (through the plan), feedback (`device_id`).
- `user_id`, no flag: food_preferences (its upload re-sends every row,
  `food_preferences_repository.dart:111-118`); race_checklist_items and carb_loading_user_foods (no
  Supabase write found: local-only, so every sign-out destroys them); tp_writeback, coaches,
  athlete_pairing_codes, user_entitlements. coach_* tables key on `coach_user_id` / `athlete_user_id`.

## Pre-logout upload (`settings_controller.dart:787-858`)

`_uploadDirtyBeforeLogout` runs `uploadDirtyRecords(userId)` on 10 repositories. Each returns
`UploadResult.failed()` on error; the function only logs failures, and `clearUserData` runs anyway
(`:785-795`). Not in the list: user_foods, integrations, formula_pins, onboarding_surveys,
personal_formulas, personal_templates, so their dirty rows are wiped with no upload attempt, even
online. `sync_coordinator.dart:334-349` also lacks personal_formulas and personal_templates.

## Unscoped reads

- `calendar_service.dart:151` `getAllEvents(userId)` ignores `userId` (its comment says events have no
  user column; they do). Used by `calendar_controller.dart:110, 440, 545`. The scoped version is
  `events_service.dart:101`.
- `user_dao.dart:56` `getLocalUserProfile()` returns the latest-updated profile of any account; used by
  `app_startup_service.dart:528` for analytics identity.
- `coach_repository.dart:1510` matches a pairing code against every local profile.
- `integrations_repository.dart:517` `getAllIntegrations()` is unscoped but has no caller.
- The Plan tab's `watchActivePlan` (`meal_plan_repository.dart:268-282`) is scoped, so 14-003's stray
  meal was most likely the account's own stale row.

## Sync on sign-in

Pulls merge and keep `needs_upload` rows (`meal_log_repository.dart:545`; meal plans delete only clean
rows missing on the server, `meal_plan_repository.dart:150-165`). Sign-out clears the last-synced
markers (`sync_coordinator.dart:660`), so the next sign-in syncs fully. Every upload query filters on
the signed-in `user_id` (`activities_repository.dart:194`, `events_repository.dart:174`,
`user_foods_repository.dart:84`, …): another account's dirty rows are never sent.

## A failed upload blocks the pull (Finding 86-012)

`sync_coordinator.dart:210-217`: `ensureSynced` throws a `StateError` when `uploadDirtyRecords` fails,
before step 7's `syncFromRemote`. The failure is recorded for rate limiting (2-minute in-memory
cooldown) and the repository's download is skipped. A row the server rejects every time (RLS, a
constraint, a bad value) therefore stops that repository, and every repository that lists it as a
dependency (`:205-208`), from pulling until it is fixed.
