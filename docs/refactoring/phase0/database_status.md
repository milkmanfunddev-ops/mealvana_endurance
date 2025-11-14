# Phase 0 – Database Layer Status
*Updated: 2025-11-09*

This file tracks Drift/schema alignment tasks for Phase 0. Use it while touching anything under `lib/shared/database` or `lib/shared/services/database`.

## Summary
- ✅ **COMPLETED (2025-11-09):** All critical table schema updates finished
- ✅ All obsolete table files removed and int primary keys implemented
- ✅ `food_preferences` now uses `user_id` instead of `device_id`
- ✅ Activity rows now own nutrition plan JSON, macro targets, and workout notes (legacy tables removed)
- ✅ `AppDatabase.saveUserFood` now persists `categories` and `activityTypes` arrays
- ✅ Legacy `nutrition_plans` table dropped – activities now own `nutrition_plan_data` directly

## Detailed Checklist

### Table cleanup & imports
- ✅ Legacy join tables deleted (no `categories_table.dart`, `product_types_table.dart`, etc.).
- ✅ `app_database.dart` now embeds plan JSON directly on `activities_table` (no standalone cache table).

### Identity & integer primary keys
- ✅ `activities_table.dart`, `events_table.dart`, `carb_loading_plans_table.dart`, `carb_loading_days_table.dart`, `workout_notes_table.dart`, and `feature_survey_responses_table.dart` now auto-increment ints.
- ⚠️ Drift type aliases have not propagated to the domain layer, so `Activity.id` et al. still use `String` (see `lib/features/activities/domain/activity.dart`). This leaves 200+ type errors suppressed.

### Array-based food metadata
- ✅ `foods_table.dart` and `user_foods_table.dart` declare `categories`/`activityTypes` text columns.
- ✅ **COMPLETED:** `AppDatabase.saveUserFood` now serializes arrays to PostgreSQL format `{value1,value2}` (lines 677-738)
- ✅ Added `activityTypes` parameter to `saveUserFood()` method signature
- ⚠️ Carb loading foods define `meal_types`, but there is no validation that the JSON strings contain enum values; consider adding helper converters or wrapper methods when data moves in/out of Drift.

### Preferences & ownership
- ✅ **COMPLETED:** `food_preferences.dart` now uses `user_id` (UUID) instead of `device_id` (`lib/shared/database/tables/food_preferences.dart:11`)
- ✅ **COMPLETED:** Uniqueness constraint updated to `UNIQUE(user_id, food_name)` (line 30)
- ⚠️ **ACTION REQUIRED:** Repositories/widgets that call food preferences methods (e.g., onboarding, `food_preferences_content.dart`) must be updated to pass `user_id` instead of `device_id`. This will be handled in Phase 2/3.

### Nutrition, macros, and notes
- ✅ Nutrition plans now live on `activities_table` (`nutrition_plan_data` column); no client references to the old Supabase table remain.
- ✅ Supabase migration `20251111000003_embed_macros_and_notes_on_activities.sql` backfills every `macro_targets_table` row into `activities.nutrition_plan_data->macroTargets`, copies the latest `workout_notes` entry into `completion_notes`/`completion_rating`, and drops both legacy tables.
- ✅ Flutter now reads/writes notes and macro data via `CalendarService`/`ActivitiesRepository`; no code paths hit the removed tables.

### Build runner + seed handling
- ✅ Custom onCreate logic protects seed tables.
- ✅ **COMPLETED:** Build runner executed successfully (2025-01-09) - 388 outputs generated in 55 seconds
- ✅ All Drift code regenerated with new schema

## Completed Actions (2025-11-09)
1. ✅ Dropped `lib/shared/database/tables/nutrition_plans.dart` and embedded plan JSON directly on `activities_table`
2. ✅ Updated `AppDatabase` helpers + `NutritionPlanRepository` to use the new cache table
3. ✅ Removed Supabase sync logic for nutrition plans from `DataSyncService`
4. ✅ Made `saveUserFood` store `user_id` alongside `device_id` and updated all call sites
5. ✅ Ran `dart run build_runner build --delete-conflicting-outputs` successfully
6. ✅ Cleaned up providers/docs to reflect the new cache table
7. ✅ Added Supabase migration `20251109000000_embed_nutrition_plan_on_activities.sql` to backfill `nutrition_plan_*` columns on `activities` and drop the legacy `nutrition_plans` table

## Next Actions (Phase 2 - Domain Layer)
1. Update domain models to use `int` IDs instead of `String`:
   - `lib/features/activities/domain/activity.dart`
   - `lib/features/events/domain/event.dart`
   - `lib/features/carb_loading/domain/carb_loading_plan_simple.dart`
   - `lib/features/carb_loading/domain/carb_loading_day.dart`
2. Update all repositories to use new column names (`userId`, `activityId`)
3. Update food preferences call sites to pass `user_id` instead of `device_id`
4. Fix ~200 type errors (String ↔ int mismatches) that currently exist

## Phase 1 Database Layer Status: ✅ COMPLETE
