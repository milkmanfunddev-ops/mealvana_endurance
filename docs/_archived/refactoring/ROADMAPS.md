# Refactoring Roadmaps
*Updated: 2025-11-16 – Analyzer errors: 552 (Wave 2 stalled while sync + nutrition controllers migrate)*

## Snapshot
| Area | Current Focus | Owner / Touch Points | Blockers |
| --- | --- | --- | --- |
| Client ID Alignment | ActivityCompletion + carb-loading screens still pass `String` IDs; router extras expect strings | `lib/features/activities/domain/activity_completion.dart`, `lib/features/carb_loading/presentation/screens/create_custom_carb_loading_food_screen.dart`, `lib/shared/core/app_router.dart` | None – code changes + analyzer pass |
| Activity-Owned Nutrition | `NutritionPlanController` still orchestrates plans; repositories stub methods | `lib/features/nutrition_plan/presentation/providers/nutrition_plan_controller.dart`, `lib/features/nutrition_plan/data/nutrition_plan_repository.dart` | Need domain `Activity` to expose `nutritionPlanData` field |
| Sync & Edge Contracts | Sync still uploads with `device_id`, edge functions accept deleted payloads | `lib/shared/services/sync/data_sync_service.dart`, Supabase edge functions (`save-calendar-activity`, `sync-all-data`) | Flutter SDK permissions prevent running `flutter analyze` locally |
| Tests & Tooling | No regression coverage for activity-owned plans or sync payloads | `test/helpers`, `test/features/nutrition_plan/**`, CI scripts | Need stable fixtures after ID migration |

---

## Roadmap A – Completed Work

### Schema & Storage
- ✅ **Phase 0 destructive refresh** (`/docs/refactoring/phase0/*`, `database_schemas/migrations/PHASE_0_SCHEMA_SIMPLIFICATION.sql`) landed BIGSERIAL IDs, UUID user ownership, and dropped join tables.
- ✅ **Activity-owned nutrition plans** (`supabase/migrations/20251109000000_embed_nutrition_plan_on_activities.sql` + `20251111000003_embed_macros_and_notes_on_activities.sql`) push macro targets, workout notes, and plan JSON onto `activities`.
- ✅ **Events schema fix** (`20251113000001_fix_events_type_subtype.sql`) and **ActivityType unification** (`20251114000001_use_activity_type_for_events.sql`) standardized enums across activities/events/foods.

### Client & Services
- ✅ **Calendar sync retirement** – `CalendarSyncService` deleted, `DataSyncService` now merges activities/events/carb loading repos directly (see `CALENDAR-SYNC-RETIREMENT.md`).
- ✅ **Food data alignment** – `AppDatabase.saveUserFood` writes array columns, `food_preferences` now keyed by `user_id`, user foods store activity types/category JSON.
- ✅ **Wave 0 ID updates** – Core calendar services, controllers, and enum switches now use `int` IDs and handle multi-sport icons/logic (see `PHASE-3-ROADMAP.md` history section).

---

## Roadmap B – Remaining Work

### 1. Client ID Alignment (Wave 0 cleanup)
1. Convert `ActivityCompletion` to `int` IDs and propagate through calendar + journal controllers.
2. Update carb-loading screens, router extras, and providers to pass `int dayId`/`planId`.
3. Regenerate providers after removing leftover `String` casts; rerun `flutter analyze`.

### 2. Activity-Owned Nutrition (Wave 2)
1. Add `nutritionPlanData` (and helper getters) to the `Activity` domain model + repository mappers.
2. Replace `NutritionPlanController` global state with per-activity data via `ActivityDetailController`.
3. Fully implement `NutritionPlanRepository.getNutritionPlanByActivityId`, `getPlansPendingFeedback`, and feedback flows against activity JSON.

### 3. Sync + Edge Contract Hardening
1. Update `DataSyncService` uploads to send `userId` (UUID) instead of `device_id`, prune deprecated payload keys (`mealTypes`, `product_types`, `user_hidden_foods`).
2. Align Supabase edge functions (`save-calendar-activity`, `save-calendar-event`, `sync-all-data`, `run-plan`) with the trimmed payload and document contracts in `docs/api_documentation.txt`.
3. Add regression tests that diff payload schemas to catch reintroductions of dropped tables.

### 4. Tests & Tooling
1. Refresh fixtures to seed int IDs and embedded nutrition data; delete helpers referencing removed tables.
2. Add integration test: create activity → attach nutrition plan JSON → verify sync round-trip.
3. Gate CI on `flutter analyze` + new sync tests once Flutter SDK permissions are fixed.

### 5. Release Planning
1. Produce prod rollout checklist (Supabase migration order, edge deploy, mobile release gating).
2. Document rollback steps for the unified ActivityType + nutrition-owned flows.
3. Share timeline with leadership via `docs/roadmap.md` once analyzer hits zero.

---

## Updating This Document
After each working session:
1. Update the snapshot table with new analyzer error counts or blockers.
2. Move finished bullets from Roadmap B into the “Completed Work” section (with a short date note if helpful).
3. Cross-link any new deep-dive docs you create so contributors can find them quickly.
