# Phase 0 – Client Backlog
*Updated: 2025-11-09*

Use this file to coordinate the remaining client-side work. Most tasks map directly to the discrepancies listed in `database_status.md` and the Complete Migration Roadmap.

## Phase 2 – Domain Layer (Not Started)
- [ ] Convert `Activity.id`, `Event.id`, `CarbLoadingPlan.id`, `CarbLoadingDay.id`, and related FK fields from `String` to `int` (`lib/features/**/domain/*.dart`).
- [ ] Update repositories/services that still expect string IDs (activities, calendar, carb loading, nutrition plan flows).
- [ ] Regenerate freezed/json serializable outputs (if any) and re-run analyzer.

## Phase 3 – Application Layer
- [x] Reconciled `NutritionPlanRepository` with the activity-owned macro design (plans + macro targets now live on `activities.nutrition_plan_data`).
- [ ] Remove `NutritionPlanController` and its provider bindings after the UI reads nutrition data from activities (`lib/features/nutrition_plan/presentation/providers/nutrition_plan_controller.dart`).
- [ ] Replace `nutritionPlanState` references in controllers (`activity_detail_controller.dart`, etc.) with the new activity-owned nutrition data.
- [ ] Ensure carb-loading planners and surveys now reference the int IDs and `user_id` UUIDs instead of device IDs.

## Sync, Storage, and Services
- [x] Update `AppDatabase.saveUserFood` and related DAOs to persist `categories`/`activityTypes` arrays and store `user_id` everywhere.
- [x] Strip `nutrition_plans` from `DataSyncService` download/upload paths (`lib/shared/services/sync/data_sync_service.dart`). Product-type and user-hidden-food cleanup still pending.
- [ ] Remove the remaining `product_types`/`user_hidden_foods` references from sync jobs and Supabase payloads.
- [ ] Align Supabase Edge Function payloads (`supabase/functions/sync-all-data`, `run-plan`, etc.) so they no longer send/receive dropped tables or device IDs. Document any contract changes in `docs/api_documentation.txt`.

## UI & Feature Screens
- [ ] Audit onboarding/settings food preference screens (`lib/features/onboarding/presentation/screens/food_preferences_screen.dart`, `lib/features/settings/presentation/screens/food_preferences_edit_screen.dart`) to ensure they use `user_id` and handle the new server validation errors.
- [ ] Verify `food_preferences_content.dart` and shared widgets still display correctly once the schema flips.
- [ ] Update barcode and scanned-food flows to surface validation errors when categories/activity types are missing, and add unit tests for `_saveSearchedFood`.

## Testing & Tooling
- [ ] Add repository tests that prove `(userId, foodName)` uniqueness works after the schema change.
- [ ] Create an integration test that creates an activity, writes macro targets, and asserts the JSON payload persists on the activity row (no legacy tables involved).
- [ ] Add regression tests for `DataSyncService` so it fails fast if Supabase responds with deprecated payload keys.
- [ ] Capture a checklist for prod rollout (Supabase migration order, seed verification, mobile release gating).

## Dependencies & Coordination
- Database migrations **must** be applied to Supabase Dev before toggling the client.
- Coordinate with the API team for the new sync payloads.
- Keep the Complete Migration Roadmap updated as tasks land.
