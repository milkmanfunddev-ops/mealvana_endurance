# Phase 0 Client Refactor – Overview
*Updated: 2025-11-09*

Phase 0 keeps the Flutter/Drift client in lock-step with the Phase 0 Supabase schema refresh. The migrations under `docs/database/migrations/phase0_*` have already been executed in Supabase Dev; this folder tracks what the client still needs.

## High-Level Goal
Replace the legacy device-id centric nutrition data model with the new UUID/int based schema so the app can sync activities, foods, and macro targets without bespoke join tables.

## Prerequisites
- ✅ `/docs/database/migrations/phase0_schema_refresh.sql`
- ✅ `/docs/database/migrations/phase0_followups.sql`
- 📌 Make sure build_runner output is regenerated after each Drift change (`flutter pub run build_runner build --delete-conflicting-outputs`).

## Current Progress Snapshot
| Area | Status | Notes |
| --- | --- | --- |
| Drift schema + generated code | ✅ Complete | All Drift tables match the Phase 0 + follow-up SQL. Activities now store plan JSON directly (`nutrition_plan_data`). |
| Domain models (Phase 2) | ❌ Not started | `Activity`, `Event`, `CarbLoading*` models still expose `String` ids. |
| Application layer + repositories | ❌ Not started | `NutritionPlanRepository` / controller still drive all nutrition flows; macros are not keyed by `activity_id`. |
| Sync + services | ⚠️ Partial | `DataSyncService` no longer touches `nutrition_plans`, but the rest of the batch-sync work is pending. |
| UI wiring | ⚠️ Partial | Barcode + preferences flows now write array categories, but most screens still rely on `NutritionPlanController`. |
| Testing / verification | ❌ Not started | No tests exist for the new UUID/int paths or macro-per-activity guarantees. |

Legend: ✅ complete · ⚠️ partial · ❌ not started

## Completed to Date
- Deleted the old join-table Drift files (`categories`, `food_categories`, `meal_types`, `product_types`, `user_hidden_foods`, etc.).
- Converted the primary keys for activities, events, carb loading plans/days, workout notes, and feature survey responses to auto-incrementing ints (`lib/shared/database/tables/*.dart`).
- Updated `add_food_screen.dart` and the shared CRUD services to collect array-based categories + activity types (now persisted in Drift).
- Embedded nutrition plan JSON directly on `activities_table` (no separate cache) and regenerated Drift code (see `build_runner` log in `docs/logs.txt`).

## Outstanding Themes
1. **Finish the database layer** – Continue migrating remaining `device_id` usages to `user_id` and finish the column rename work in repositories.
2. **Update the domain layer** – Switch all `id`/`activityId` fields in the domain models and repositories to `int` so the type errors disappear instead of being ignored.
3. **Remove nutrition plan globals** – Delete `NutritionPlanController`/`NutritionPlanRepository` once macro targets live on activities, and migrate the UI to consume `Activity.nutritionData` instead of a global cache.
4. **Unify sync** – `DataSyncService` and the Supabase functions must stop pushing/pulling dropped tables (`nutrition_plans`, `product_types`, `user_hidden_foods`) and instead sync macros, workout notes, foods, and carb-loading data only.
5. **Testing + tooling** – Add integration tests that create activities, assert a single macro row per activity, and verify that preference uniqueness now keys off `user_id`.

## Related Documents
- [Database layer status](database_status.md)
- [Client backlog & action items](client_backlog.md)
- [Complete migration roadmap](../COMPLETE-MIGRATION-ROADMAP.md)
