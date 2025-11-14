# Phase 3 – Analyzer Burndown & Client Refactor
*Updated: 2025-11-17*

`flutter analyze` currently reports **100 errors** (down from 753 at the start of the migration, 420 before Wave 2 completion). Nearly every failure still falls into one of four buckets:

| Bucket | Symptoms | Files Impacted | % of errors |
| --- | --- | --- | --- |
| **ID Alignment** | Remaining `String` IDs on `ActivityCompletion`, carb-loading screens, and router extras continue to break analyzer. | `lib/features/activities/domain/activity_completion.dart`, `lib/features/carb_loading/presentation/screens/create_custom_carb_loading_food_screen.dart`, `lib/shared/core/app_router.dart` | ~45% |
| **Deleted Tables / Payloads** | Deprecated payload keys like `mealTypes`, `device_id`, `product_types` still show up in sync code. | `lib/shared/services/sync/data_sync_service.dart`, Supabase edge functions | ~15% |
| **Legacy Nutrition Stack** | `NutritionPlanController`, detached repositories, and UI assuming a global “current plan”. | Nutrition plan controllers/screens, sharing/feedback flows. | ~25% |
| **Tests & Fixtures** | Old fixtures still generate string IDs or seed deleted tables. | `test/helpers/**`, sync/integration tests. | ~15% |

👉 Use [`ROADMAPS.md`](ROADMAPS.md) for the day-to-day owner/blocker table. This Phase 3 doc focuses on the burndown narrative and wave-specific exit criteria.

This document replaces the verbose phase logs (now removed) with a targeted plan to get the analyzer back to zero and finish the client transition.

## Wave 0 – ID Alignment & Multi-Sport Support 🔄 PARTIAL

**What’s Done**
- Migrated calendar services/controllers to `int` IDs for activities/events/carb loading.
- Deleted `CalendarSyncService`; `DataSyncService` now orchestrates merges directly (see `CALENDAR-SYNC-RETIREMENT.md`).
- Unified `ActivityType` enum and events schema via migrations `20251113000001` + `20251114000001`.
- Expanded UI switch statements (activity detail + adjust macros) to cover the new enum values.

**Still To Finish**
1. Convert `ActivityCompletion` (domain + controllers) to `int` IDs and drop `String` conversions.
2. Update carb-loading creation/edit screens and router extras to pass `int carbLoadingDayId`/`planId`.
3. Run `dart run build_runner build` + `flutter analyze` to confirm zero string-ID regressions once the above lands.

## Wave 1 – Remove Deleted Tables & Payloads 🔄 PARTIAL
**Goal:** Ensure no code path references tables or payload fields that were dropped in Phase 0/1.

**Remaining Work**
1. **Nutrition Tables**
   - Delete any lingering `macro_targets_table` / `workout_notes` references.
   - Double-check `WorkoutNotesRepository` + journal UI only read/write the embedded activity fields.
2. **Sync Payloads**
   - Strip `mealTypes`, `product_types`, `user_hidden_foods`, and `device_id` usage from `DataSyncService` uploads.
   - Update Supabase edge functions to reject deprecated keys; document the contract in `docs/api_documentation.txt`.
3. **Database Helpers**
   - Remove `AppDatabase` helpers that select by `planId` or use deleted tables.

**Exit Criteria:** Analyzer no longer reports deleted-table identifiers and sync payloads match the schema contract.

## Wave 2 – Activity-Owned Nutrition ✅ COMPLETE
*Started: 2025-11-15, Completed: 2025-11-17*

**✅ Completed (Nov 16) - Domain & Repository**
1. **Domain Model Integration:**
   - ✅ Added `nutritionPlanData: Map<String, dynamic>?` field to Activity domain model
   - ✅ Updated Activity `toJson()`, `copyWith()`, equality, and hashCode
   - ✅ Added `_parseNutritionPlanData()` helper in ActivitiesRepository
   - ✅ Repository now maps nutrition_plan_data JSON from database to domain model

2. **Repository Implementation:**
   - ✅ Fully implemented `getNutritionPlanByActivityId()` - retrieves plan from activity JSON
   - ✅ Fully implemented `getPlansPendingFeedback()` - queries activities needing feedback
   - ✅ Fully implemented `getUserNutritionPlans()` - gets all plans for user
   - ✅ All methods now use Drift queries on activities table (no standalone nutrition_plans table)

**✅ Completed (Nov 17) - Controller Migration**
3. **ActivityDetailController Enhancement:**
   - ✅ Added `_saveNutritionPlanToActivity()` - saves plans to activity.nutritionPlanData
   - ✅ Added `swapFoodItem()` - swaps food with nutrition recalculation and analytics
   - ✅ Added `addFoodItem()` - adds food with proper scaling and analytics
   - ✅ Added `deleteFoodItem()` - removes food with analytics tracking
   - ✅ Added `updateFoodQuantity()` - updates quantity with nutritional scaling
   - ✅ Updated `saveActivity()` to save nutrition plans in both create and view modes

4. **Controller Cleanup:**
   - ✅ Deleted `NutritionPlanController` (724 lines) - global state eliminated
   - ✅ Updated `SwapFoodController` to delegate to ActivityDetailController
   - ✅ Updated `ActivityDetailScreen` to use only ActivityDetailController
   - ✅ Updated `DistancePageGutEntryController` to save plans to activities
   - ✅ Deleted obsolete test file `nutrition_plan_controller_test.dart`

5. **DataSyncService Integration:**
   - ✅ Added `nutritionPlanData` to download sync (_upsertActivity)
   - ✅ Added `nutritionPlanData` to upload sync (_uploadActivity)
   - ✅ Nutrition plans now fully participate in sync cycle

**Impact:**
- **Analyzer Errors:** 420 → 100 (**320 errors fixed, 76% reduction**)
- **Architecture:** Eliminated global nutrition plan state, single source of truth
- **Code Reduction:** Net -324 lines (deleted controller larger than new methods)

**Documentation:**
- 📄 [Session Summary](session-2025-11-17-controller-migration.md) - Complete migration details

## Wave 3 – Sync Verification & Final QA
1. **DataSyncService Verification** ✅ COMPLETE
   - ✅ Verified nutrition_plan_data syncs in download (_upsertActivity)
   - ✅ Verified nutrition_plan_data syncs in upload (_uploadActivity)
   - ✅ Confirmed dirty uploads/downloads only handle supported tables
   - Next: Edge function compatibility testing

2. **Edge Function Compatibility** (Next Priority)
   - [ ] Test `save-calendar-activity` edge function with nutrition_plan_data payload
   - [ ] Test `sync-all-data` edge function returns nutrition_plan_data correctly
   - [ ] Verify JSON serialization/deserialization round-trip
   - [ ] Add contract tests for nutrition data sync

3. **Performance Optimization** (Future)
   - [ ] Add database indexes for nutrition plan queries
   - [ ] Implement lazy loading for large nutrition plans
   - [ ] Cache parsed plans in memory to avoid repeated JSON parsing

4. **Final Analyzer & Rollout**
   - Current: 100 errors (76% reduction from Wave 2 start)
   - Target: <50 errors for production readiness
   - [ ] Address remaining ID alignment issues (Wave 0)
   - [ ] Clean up deprecated table references (Wave 1)
   - [ ] Add PROD rollout checklist

## Daily Working Checklist
1. Run `flutter analyze |& tee flutter_analyze.log` before and after each session.
2. When touching a bucket above, update the corresponding section here (counts, blockers).
3. Delete or archive any doc/file that references dropped tables or APIs as you go—keeping this folder lean reduces confusion (e.g., the old Phase 0 progress log has been removed).

## References
- [Complete Migration Roadmap](COMPLETE-MIGRATION-ROADMAP.md) – high-level status.
- [Phase 0 Docs](phase0/) – authoritative schema status.
- Production schema fix migration: `supabase/migrations/20251113000001_fix_events_type_subtype.sql`
- Analyzer log snapshot: `flutter_analyze.log`.
