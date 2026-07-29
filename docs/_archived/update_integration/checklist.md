# Integration Sync Update - Implementation Checklist

> **Design Decisions**: See `design-decisions.md` for all finalized decisions.

---

## Phase 1: Database & Domain Layer

### Database Schema Changes

- [x] **Add Sync Tracking Columns to Activities Table**
  - File: `/lib/shared/database/tables/activities_table.dart`
  - Add columns:
    ```dart
    BoolColumn get needsNutritionRefresh => boolean().withDefault(const Constant(false))();
    DateTimeColumn get providerDeletedAt => dateTime().nullable()();
    DateTimeColumn get providerScheduledAt => dateTime().nullable()();
    DateTimeColumn get scheduleChangedAt => dateTime().nullable()();
    ```

- [x] **Create Drift Migration**
  - Bump schema version in `app_database.dart` (v3 → v4)
  - Add migration in `onUpgrade()` method with ALTER TABLE statements
  - Run: `dart run drift_dev schema dump lib/shared/database/app_database.dart database_schemas/v4/`

- [x] **Add Supabase Migration**
  - Create migration file: `/supabase/migrations/20260125000000_add_integration_sync_tracking.sql`
  - Add same columns to Supabase activities table with indexes

### Domain Models

- [x] **Create SyncChangeResult Model**
  - New file: `/lib/features/integrations/domain/sync_change_result.dart`
  - ✅ Completed with all required fields plus enhancements:
    - Added distance/duration tracking fields
    - Added computed properties (timeDifferenceMinutes, distanceChangePercentage, etc.)
    - Added helper properties (totalChanges, hasChanges, hasScheduleChanges)
    - Comprehensive documentation for staleness criteria
  ```dart
  class SyncChangeResult {
    final List<Activity> newActivities;
    final List<ActivityChange> updatedActivities;
    final List<String> deletedActivityIds;
    final int unchangedCount;
  }

  class ActivityChange {
    final String activityId;
    final Activity updatedActivity;
    final bool scheduleChanged; // Triggers nutrition refresh flag
    final DateTime? oldScheduledAt;
    final DateTime? newScheduledAt;
  }
  ```

---

## Phase 2: Change Detection Service

### Service Layer

- [x] **Create ChangeDetectionService**
  - New file: `/lib/features/integrations/application/change_detection_service.dart`
  - ✅ Completed with full implementation:
    - Method: `detectChanges(List<Activity> local, List<Activity> remote, String provider)`
    - Compares by `provider_workout_id`
    - Detects: NEW, UPDATED (schedule/minor), DELETED, UNCHANGED
    - Significant schedule change criteria:
      - Time change > 30 minutes
      - Different day
      - Duration change > 15 minutes
      - Distance change > 10%
    - Also detects minor changes (title, notes, pace, intensity)
    - Uses Riverpod provider pattern with code generation

- [x] **Update Final Surge Sync Service**
  - File: `/lib/features/integrations/application/final_surge_sync_service.dart`
  - Replace insert-only logic with change detection
  - On UPDATE: Set `needsNutritionRefresh = true` if schedule changed significantly
  - On DELETE: Set `providerDeletedAt = DateTime.now()`
  - Integrate with `ensureSynced()` pattern

- [x] **Update Training Peaks Sync Service**
  - File: `/lib/features/integrations/application/training_peaks_sync_service.dart`
  - ✅ Integrated ChangeDetectionService for change detection
  - ✅ Replaced insert-only logic with NEW/UPDATE/DELETE handling
  - ✅ On UPDATE: Sets `needsNutritionRefresh = true` if schedule changed
  - ✅ On DELETE: Calls `softDeleteFromProvider()`
  - ✅ Returns enhanced `TrainingPeaksSyncResult` with change statistics
  - ✅ Applied to both `syncWorkouts()` and `syncWorkoutsByDateRange()` methods

### Repository Updates

- [x] **Add Update Methods to Activities Repository**
  - File: `/lib/features/activities/data/activities_repository.dart`
  - Method: `updateActivityFromProvider(Activity activity)` - Updates schedule, preserves nutrition ✅
  - Method: `softDeleteFromProvider(String activityId)` - Sets `providerDeletedAt` ✅ ENABLED
  - Method: `clearNutritionRefreshFlag(String activityId)` - After regeneration ✅ ENABLED
  - Method: `getActivitiesByUserAndProvider(String userId, String provider)` - Gets all activities from a specific provider ✅

- [x] **Enable Repository Methods (2026-01-25)**
  - ✅ `softDeleteFromProvider` - Database write code enabled, fully functional
  - ✅ `clearNutritionRefreshFlag` - Database write code enabled, fully functional
  - Both methods now perform actual database operations using Drift API
  - Ready for integration with sync services and UI components

- [x] **Add Single Workout Fetch to Final Surge API Client**
  - File: `/lib/features/integrations/data/final_surge_api_client.dart`
  - Method: `getWorkoutById(String accessToken, String workoutKey)`
  - For single-activity refresh button

- [x] **Add Single Workout Fetch to Training Peaks API Client**
  - File: `/lib/features/integrations/data/training_peaks_api_client.dart`
  - Method: `getWorkoutById(String accessToken, String workoutId)`

---

## Phase 3: UI Components

### Sync Status Widget

- [x] **Create SyncStatusWidget**
  - New file: `/lib/features/integrations/presentation/widgets/sync_status_widget.dart`
  - Props: `lastSyncAt`, `onRefresh`, `isLoading`, `isSyncedActivity`
  - Display: "Last updated: Jan 16, 2026 at 3:42 PM"
  - Refresh icon button (only shown for synced activities)
  - Loading indicator during refresh

### Stale Plan Warning Banner

- [x] **Create StalePlanWarningWidget**
  - New file: `/lib/features/nutrition_plan/presentation/widgets/stale_plan_warning.dart`
  - Shows when `activity.needsNutritionRefresh == true`
  - Message: "Schedule has changed since this plan was generated"
  - Single button: "Regenerate Plan"
  - Dismissible (sets flag to false without regenerating)

### Activity Detail Screen Updates

- [x] **Add Sync Status to Activity Detail Header**
  - File: `/lib/features/nutrition_plan/presentation/screens/activity_detail_screen.dart`
  - Location: Below activity title in hero section
  - Show `SyncStatusWidget` for activities where `syncedFromProvider != null`
  - Show `StalePlanWarningWidget` above nutrition sections when flagged
  - Note: StalePlanWarning is conditionally shown but set to `false` until Activity model is updated with `needsNutritionRefresh` field

- [x] **Add Refresh Controller Method**
  - Added placeholder method `_handleRefreshActivity()` with snackbar message (TODO: implement single activity refresh)
  - Implemented full `_handleRegeneratePlan()` method with nutrition service integration
  - Regenerate handler calls `nutritionPlanService.regenerateForScheduleChange()`
  - Loading state handled via controller's existing `state.isSaving` flag
  - Success triggers controller invalidation to refresh UI with new plan
  - Analytics tracking and error handling implemented

### Integration Settings Updates

- [x] **Update Integration Provider Card**
  - File: `/lib/features/integrations/presentation/widgets/integration_provider_card.dart`
  - Show persistent "Last synced: [timestamp]" from `integrations.last_sync_at`
  - Replace in-memory "Synced!" state
  - ✅ Added lastSyncAt prop to IntegrationProviderCard
  - ✅ Updated ConnectTrainingState to include finalSurgeLastSyncAt and trainingPeaksLastSyncAt
  - ✅ Modified controller to fetch lastSyncAt from integrations repository
  - ✅ Updated connected_apps_screen.dart to pass lastSyncAt to cards
  - ✅ Implemented smart timestamp formatting (relative for recent, absolute for older)

---

## Phase 4: Nutrition Regeneration

### Staleness Detection

- [x] **Define Significant Schedule Change Logic**
  - ✅ Implemented in `ChangeDetectionService` (completed 2026-01-25):
    - Time change > 30 minutes → significant (`significantTimeChangeMinutes = 30`)
    - Date change → significant (day/month/year comparison in `_isScheduleChangeSignificant`)
    - Duration change > 15 minutes → significant (`significantDurationChangeMinutes = 15`)
    - Distance change > 10% → significant (`significantDistanceChangePercentage = 10.0`)
  - Location: `/lib/features/integrations/application/change_detection_service.dart`
  - All constants defined and used in `_isScheduleChangeSignificant()` method

### Regeneration Flow

- [x] **Add Regeneration Method to Nutrition Service**
  - File: `/lib/features/nutrition_plan/application/nutrition_plan_service.dart`
  - Method: `regenerateForScheduleChange(Activity activity)`
  - Recalculates macros based on new timing/duration
  - Preserves user food preferences
  - Clears `needsNutritionRefresh` flag on success

- [x] **Wire Up Regenerate Button**
  - In `StalePlanWarningWidget`, tap "Regenerate Plan" calls `_handleRegeneratePlan()` in Activity Detail Screen
  - Loading indicator shown during regeneration (uses `state.isSaving` flag)
  - Refresh activity detail on success (invalidates controller provider to trigger rebuild)
  - Error handling with user-facing error messages
  - Analytics tracking for regeneration events

---

## Phase 5: Testing

### Unit Tests

- [x] **Test ChangeDetectionService** (2026-01-25)
  - Test: New workout detected correctly ✅
  - Test: Updated workout with schedule change detected ✅
  - Test: Updated workout with minor change (< 30 min) not flagged ✅
  - Test: Deleted workout detected ✅
  - Test: Unchanged workout handled ✅
  - Test file: `/test/features/integrations/application/change_detection_service_test.dart`
  - Coverage: 59 comprehensive test cases covering all scenarios
  - Includes boundary tests (30 min, 15 min, 10% thresholds)
  - Includes null/edge case handling
  - Includes computed property tests for SyncChangeResult and ActivityChange

- [x] **Test Staleness Logic** (2026-01-25)
  - Test: 30+ min time change → `needsNutritionRefresh = true` ✅
  - Test: < 30 min time change → `needsNutritionRefresh = false` ✅
  - Test: Date change → `needsNutritionRefresh = true` ✅
  - Test: Distance change > 10% → `needsNutritionRefresh = true` ✅
  - Test: Duration change > 15 min → `needsNutritionRefresh = true` ✅
  - All boundary cases tested (exactly 30 min, 31 min, 15 min, 16 min, 10%, 10.1%)

### Integration Tests

- [ ] **Test Full Sync Flow with Changes**
  - Mock provider API returning changed data
  - Verify local activities updated correctly
  - Verify `needsNutritionRefresh` flag set
  - Verify UI reflects changes

- [ ] **Test Single Activity Refresh**
  - Mock single workout fetch
  - Verify activity updated
  - Verify timestamp updated in UI

### Manual Testing Checklist

- [ ] Connect to Final Surge
- [ ] Sync workouts initially
- [ ] In Final Surge: Change workout to different day
- [ ] Open app → activities list → verify sync happens (staleness check)
- [ ] Open affected activity → verify "Last updated" timestamp
- [ ] Verify stale plan warning banner appears
- [ ] Tap "Regenerate Plan" → verify new plan generated
- [ ] Test refresh button on single activity
- [ ] Repeat all tests for Training Peaks

---

## Phase 6: Documentation & Cleanup

- [x] **Update CLAUDE.md** with integration sync architecture
- [x] **Update /docs/database/README.md** if schema changes
- [ ] **Add analytics events** for sync actions:
  - `integration_sync_changes_detected` (newCount, updatedCount, deletedCount)
  - `nutrition_plan_regenerated_after_schedule_change`
  - `single_activity_refreshed`

---

## Summary of Key Files

| Type | File | Changes |
|------|------|---------|
| Database | `/lib/shared/database/tables/activities_table.dart` | Add sync tracking columns |
| Domain | `/lib/features/integrations/domain/sync_change_result.dart` | New file |
| Service | `/lib/features/integrations/application/change_detection_service.dart` | New file |
| Service | `/lib/features/integrations/application/final_surge_sync_service.dart` | Add change detection |
| Service | `/lib/features/integrations/application/training_peaks_sync_service.dart` | Add change detection |
| Repository | `/lib/features/activities/data/activities_repository.dart` | Add update methods |
| API | `/lib/features/integrations/data/final_surge_api_client.dart` | Add single workout fetch |
| API | `/lib/features/integrations/data/training_peaks_api_client.dart` | Add single workout fetch |
| Widget | `/lib/features/integrations/presentation/widgets/sync_status_widget.dart` | New file |
| Widget | `/lib/features/nutrition_plan/presentation/widgets/stale_plan_warning.dart` | New file |
| Screen | `/lib/features/nutrition_plan/presentation/screens/activity_detail_screen.dart` | Add sync UI |
| Widget | `/lib/features/integrations/presentation/widgets/integration_provider_card.dart` | Show persistent timestamp |
