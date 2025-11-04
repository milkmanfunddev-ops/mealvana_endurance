# Single Edge Function Sync Roadmap (REVISED)

**Goal**: Replace 7+ network calls with 1 unified sync + implement true offline-first architecture

**Current Status**: Architecture analysis complete, ready to implement Phase 2A

**Timeline**: 2-3 days for Phase 2A (single network call + offline-first)

---

## 🚨 Critical Discovery: Current Architecture is NOT Offline-First

### Problem Found
The current implementation is **Supabase-first**, not Drift-first:

```dart
// Current pattern in ActivitiesRepository (WRONG)
Future<Activity> updateActivity(...) async {
  // 1. Call Supabase edge function FIRST ❌
  final response = await _supabase.functions.invoke('save-calendar-activity', ...);

  // 2. Only cache locally if Supabase succeeds ❌
  if (response.status == 200) {
    await _cacheActivityLocally(activity);
  }
  // 3. If offline → user can't edit anything! ❌
}
```

**Result**: App breaks when offline, user can't edit activities/events without internet.

### Solution: True Offline-First
```dart
// New pattern (CORRECT)
Future<Activity> updateActivity(...) async {
  // 1. Save to Drift FIRST ✅ (offline-first!)
  await _saveToDrift(activity.copyWith(needsUpload: true));

  // 2. Attempt background upload (non-blocking) ✅
  unawaited(_uploadToSupabase(activity));

  // 3. If offline → data saved locally, will upload later ✅
  return activity;
}
```

---

## Schema Analysis

### ✅ Good News: Schemas Already Match!

**Drift uses `.named()` to match Supabase column names:**
- Supabase: `distance_miles`, `user_id`, `scheduled_date_time`
- Drift: `.named('distance_miles')`, `.named('user_id')`, `.named('scheduled_date_time')`

**No complex field mapping needed!** The confusion was:
- Drift Dart properties: `camelCase` (e.g., `distanceMiles`)
- Drift SQL columns: `snake_case` (e.g., `distance_miles`)
- Supabase columns: `snake_case` (e.g., `distance_miles`)

**Result**: Schemas are identical, sync is straightforward! 🎉

### ⚠️ Schema Fixes Required

1. **Events table missing `user_id`**
   - Currently joins via `activities` to get user ownership
   - Need to add `user_id` column for faster queries
   - Requires Supabase migration + Drift schema update

2. **Add dirty flag tracking** to user-editable tables:
   - `needs_upload BOOLEAN DEFAULT false`
   - `local_updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP`

   Tables needing this:
   - `activities`
   - `events`
   - `carb_loading_plans`
   - `carb_loading_days`
   - `activity_completions`
   - `user_foods_table`

---

## Architecture Overview

### Current Flow (Sequential + Supabase-First)
```
App Startup:
  ↓
Sequential network calls (3-5 seconds):
  1. CalendarSyncService → queries Supabase directly (activities)
  2. CalendarSyncService → queries Supabase directly (events)
  3. CalendarSyncService → queries Supabase directly (carb plans)
  4. CalendarSyncService → queries Supabase directly (carb days)
  5. CalendarSyncService → queries Supabase directly (completions)
  6. CarbLoadingFoodSyncService → queries Supabase directly
  7. FoodRepository → calls get-foods edge function

User Edits:
  ↓
ActivitiesRepository.updateActivity():
  1. Call save-calendar-activity edge function ❌ (Supabase-first)
  2. If successful → cache to Drift
  3. If failed (offline) → ERROR, nothing saved ❌
```

**Problems:**
- ❌ 7+ network calls on startup (slow)
- ❌ App breaks when offline
- ❌ User can't edit activities/events without internet
- ❌ Data loss if network fails during edit

---

### Target Flow (Single Call + Offline-First)

```
App Startup:
  ↓
DataSyncService.syncAllData():
  ↓
1️⃣ DOWNLOAD: Single call to sync-all-data edge function (0.5-1 sec)
     - Returns all 8 tables in one response
     - Merge into local Drift database
  ↓
2️⃣ UPLOAD: Push any dirty records to Supabase
     - Find records with needs_upload = true
     - Upload via existing edge functions
     - Clear needs_upload flag on success
  ↓
App ready with latest data ✅

User Edits:
  ↓
ActivitiesRepository.updateActivity():
  ↓
1. Save to Drift IMMEDIATELY ✅ (offline-first)
2. Set needs_upload = true, local_updated_at = now()
3. Attempt background upload (non-blocking)
     ↓
     If successful: Clear needs_upload flag
     If failed: Keep dirty flag, will retry on next sync
  ↓
User sees changes instantly ✅ (works 100% offline)
```

**Benefits:**
- ✅ 75% faster app startup (1-2 sec vs 3-5 sec)
- ✅ App works 100% offline
- ✅ No data loss (Drift is source of truth)
- ✅ Automatic retry on network recovery
- ✅ Multi-device sync works perfectly

---

## Implementation Plan

### **Phase 2A: Single Network Call + Offline-First** (2-3 days)

**Goal**: Replace 7+ calls with 1 call + fix offline-first architecture

#### Step 1: Add Schema Columns (2 hours)

**1.1 Create Supabase Migration**

File: `supabase/migrations/20251029000000_add_sync_columns.sql`

```sql
-- Add user_id to events table
ALTER TABLE events ADD COLUMN user_id text;

-- Backfill user_id from activities
UPDATE events e
SET user_id = a.user_id
FROM activities a
WHERE e.activity_id = a.id;

-- Make user_id NOT NULL after backfill
ALTER TABLE events ALTER COLUMN user_id SET NOT NULL;

-- Add index for faster queries
CREATE INDEX idx_events_user_id ON events(user_id);

-- Add sync tracking columns to user-editable tables
ALTER TABLE activities
  ADD COLUMN needs_upload BOOLEAN DEFAULT false,
  ADD COLUMN local_updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP;

ALTER TABLE events
  ADD COLUMN needs_upload BOOLEAN DEFAULT false,
  ADD COLUMN local_updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP;

ALTER TABLE carb_loading_plans
  ADD COLUMN needs_upload BOOLEAN DEFAULT false,
  ADD COLUMN local_updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP;

ALTER TABLE carb_loading_days
  ADD COLUMN needs_upload BOOLEAN DEFAULT false,
  ADD COLUMN local_updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP;

ALTER TABLE activity_completions
  ADD COLUMN needs_upload BOOLEAN DEFAULT false,
  ADD COLUMN local_updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP;

ALTER TABLE user_foods
  ADD COLUMN needs_upload BOOLEAN DEFAULT false,
  ADD COLUMN local_updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP;

-- Add indexes for sync queries
CREATE INDEX idx_activities_needs_upload ON activities(needs_upload) WHERE needs_upload = true;
CREATE INDEX idx_events_needs_upload ON events(needs_upload) WHERE needs_upload = true;
CREATE INDEX idx_carb_loading_plans_needs_upload ON carb_loading_plans(needs_upload) WHERE needs_upload = true;
CREATE INDEX idx_carb_loading_days_needs_upload ON carb_loading_days(needs_upload) WHERE needs_upload = true;
CREATE INDEX idx_activity_completions_needs_upload ON activity_completions(needs_upload) WHERE needs_upload = true;
CREATE INDEX idx_user_foods_needs_upload ON user_foods(needs_upload) WHERE needs_upload = true;
```

**1.2 Update Drift Tables**

Files to modify:
- `lib/shared/database/tables/activities_table.dart`
- `lib/shared/database/tables/events_table.dart` (add user_id)
- `lib/shared/database/tables/carb_loading_plans_table.dart`
- `lib/shared/database/tables/carb_loading_days_table.dart`
- `lib/shared/database/tables/activity_completions_table.dart`
- `lib/shared/database/tables/user_foods_table.dart`

Add to each table:
```dart
// Sync tracking columns
BoolColumn get needsUpload => boolean()
    .withDefault(const Constant(false))
    .named('needs_upload')();

DateTimeColumn get localUpdatedAt => dateTime()
    .withDefault(currentDateAndTime)
    .named('local_updated_at')();
```

Add to EventsTable specifically:
```dart
TextColumn get userId => text().named('user_id')(); // NEW!
```

**1.3 Generate Drift Schema**
```bash
dart run build_runner build --delete-conflicting-outputs
dart run drift_dev schema dump lib/shared/database/app_database.dart database_schemas/v2/
```

---

#### Step 2: Refactor DataSyncService (4 hours)

**2.1 Update DataSyncService to use sync-all-data edge function**

File: `lib/shared/services/sync/data_sync_service.dart`

```dart
/// Unified data sync service with single network call + offline-first
class DataSyncService {
  const DataSyncService({
    required SupabaseClient supabase,
    required AppDatabase database,
    required AppLogger logger,
    required CalendarSyncService calendarSyncService,
    required CarbLoadingFoodSyncService carbLoadingFoodSyncService,
    required FoodRepository foodRepository,
  })  : _supabase = supabase,
        _database = database,
        _logger = logger,
        _calendarSyncService = calendarSyncService,
        _carbLoadingFoodSyncService = carbLoadingFoodSyncService,
        _foodRepository = foodRepository;

  final SupabaseClient _supabase;
  final AppDatabase _database;
  final AppLogger _logger;
  final CalendarSyncService _calendarSyncService;
  final CarbLoadingFoodSyncService _carbLoadingFoodSyncService;
  final FoodRepository _foodRepository;

  /// Sync all app data using single network call + upload dirty records
  Future<bool> syncAllData(String userId) async {
    final startTime = DateTime.now();

    try {
      _logger.info(
        'Starting unified data sync (single network call)',
        context: 'DATA_SYNC',
        data: {'userId': userId},
      );

      // STEP 1: DOWNLOAD - Single network call to sync-all-data edge function
      final downloadData = await _downloadAllDataFromSupabase(userId);

      // STEP 2: MERGE - Update local Drift database with downloaded data
      await _mergeDownloadedData(downloadData);

      // STEP 3: UPLOAD - Push dirty records to Supabase
      await _uploadDirtyRecords(userId);

      final duration = DateTime.now().difference(startTime);
      _logger.info(
        'Unified data sync completed successfully',
        context: 'DATA_SYNC',
        data: {
          'userId': userId,
          'durationMs': duration.inMilliseconds,
        },
      );

      return true;
    } catch (e, stackTrace) {
      final duration = DateTime.now().difference(startTime);
      _logger.error(
        'Unified data sync failed - app continuing with cached data',
        context: 'DATA_SYNC',
        error: e,
        stackTrace: stackTrace,
        data: {'durationMs': duration.inMilliseconds},
      );
      return false;
    }
  }

  /// Download all data from Supabase using single network call
  Future<Map<String, dynamic>> _downloadAllDataFromSupabase(String userId) async {
    try {
      _logger.debug('Calling sync-all-data edge function', context: 'DATA_SYNC');

      final response = await _supabase.functions.invoke(
        'sync-all-data',
        body: {'user_id': userId},
      );

      if (response.status != 200) {
        throw Exception('sync-all-data failed: ${response.data}');
      }

      final data = response.data['data'] as Map<String, dynamic>;

      _logger.debug(
        'Downloaded data from Supabase',
        context: 'DATA_SYNC',
        data: {
          'activities': (data['activities'] as List).length,
          'events': (data['events'] as List).length,
          'nutrition_foods': (data['nutrition_foods'] as List).length,
          'carb_loading_foods': (data['carb_loading_foods'] as List).length,
        },
      );

      return data;
    } catch (e, stackTrace) {
      _logger.error(
        'Failed to download data from Supabase',
        context: 'DATA_SYNC',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Merge downloaded data into local Drift database
  Future<void> _mergeDownloadedData(Map<String, dynamic> data) async {
    try {
      _logger.debug('Merging downloaded data into Drift', context: 'DATA_SYNC');

      // Run all merges in parallel for speed
      await Future.wait([
        // Calendar data (activities, events, carb loading, completions)
        _calendarSyncService.syncFromDownloadedData(
          activities: data['activities'] as List<dynamic>,
          events: data['events'] as List<dynamic>,
          carbLoadingPlans: data['carb_loading_plans'] as List<dynamic>,
          carbLoadingDays: data['carb_loading_days'] as List<dynamic>,
          activityCompletions: data['activity_completions'] as List<dynamic>,
        ),

        // Carb loading foods and meal types
        _carbLoadingFoodSyncService.syncFromDownloadedData(
          carbLoadingFoods: data['carb_loading_foods'] as List<dynamic>,
          mealTypes: data['meal_types'] as List<dynamic>,
        ),

        // Nutrition plan foods
        _foodRepository.syncFromDownloadedData(
          foods: data['nutrition_foods'] as List<dynamic>,
        ),
      ]);

      _logger.debug('Successfully merged all data', context: 'DATA_SYNC');
    } catch (e, stackTrace) {
      _logger.error(
        'Failed to merge downloaded data',
        context: 'DATA_SYNC',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Upload dirty records to Supabase
  Future<void> _uploadDirtyRecords(String userId) async {
    try {
      _logger.debug('Checking for dirty records to upload', context: 'DATA_SYNC');

      // Find all dirty records across all tables
      final dirtyActivities = await (_database.select(_database.activitiesTable)
            ..where((tbl) => tbl.userId.equals(userId) & tbl.needsUpload.equals(true)))
          .get();

      final dirtyEvents = await (_database.select(_database.eventsTable)
            ..where((tbl) => tbl.userId.equals(userId) & tbl.needsUpload.equals(true)))
          .get();

      final dirtyCarbPlans = await (_database.select(_database.carbLoadingPlansTable)
            ..where((tbl) => tbl.userId.equals(userId) & tbl.needsUpload.equals(true)))
          .get();

      final dirtyCarbDays = await (_database.select(_database.carbLoadingDaysTable)
            ..where((tbl) => tbl.needsUpload.equals(true)))
          .get();

      final dirtyCompletions = await (_database.select(_database.activityCompletionsTable)
            ..where((tbl) => tbl.userId.equals(userId) & tbl.needsUpload.equals(true)))
          .get();

      final totalDirty = dirtyActivities.length +
          dirtyEvents.length +
          dirtyCarbPlans.length +
          dirtyCarbDays.length +
          dirtyCompletions.length;

      if (totalDirty == 0) {
        _logger.debug('No dirty records to upload', context: 'DATA_SYNC');
        return;
      }

      _logger.info(
        'Uploading dirty records',
        context: 'DATA_SYNC',
        data: {
          'activities': dirtyActivities.length,
          'events': dirtyEvents.length,
          'carb_plans': dirtyCarbPlans.length,
          'carb_days': dirtyCarbDays.length,
          'completions': dirtyCompletions.length,
        },
      );

      // Upload all dirty records in parallel
      await Future.wait([
        _uploadDirtyActivities(dirtyActivities),
        _uploadDirtyEvents(dirtyEvents),
        _uploadDirtyCarbPlans(dirtyCarbPlans),
        _uploadDirtyCarbDays(dirtyCarbDays),
        _uploadDirtyCompletions(dirtyCompletions),
      ]);

      _logger.info('Successfully uploaded all dirty records', context: 'DATA_SYNC');
    } catch (e, stackTrace) {
      _logger.error(
        'Failed to upload dirty records',
        context: 'DATA_SYNC',
        error: e,
        stackTrace: stackTrace,
      );
      // Don't rethrow - app should continue even if upload fails
    }
  }

  // Upload helper methods (to be implemented)
  Future<void> _uploadDirtyActivities(List<Activity> activities) async {
    // TODO: Implement batch upload
  }

  Future<void> _uploadDirtyEvents(List<Event> events) async {
    // TODO: Implement batch upload
  }

  Future<void> _uploadDirtyCarbPlans(List<CarbLoadingPlan> plans) async {
    // TODO: Implement batch upload
  }

  Future<void> _uploadDirtyCarbDays(List<CarbLoadingDay> days) async {
    // TODO: Implement batch upload
  }

  Future<void> _uploadDirtyCompletions(List<ActivityCompletion> completions) async {
    // TODO: Implement batch upload
  }
}
```

---

#### Step 3: Add syncFromDownloadedData() to Sync Services (4 hours)

**3.1 Update CalendarSyncService**

File: `lib/features/calendar/application/calendar_sync_service.dart`

Add new method:
```dart
/// Sync calendar data from pre-downloaded data (single network call pattern)
Future<void> syncFromDownloadedData({
  required List<dynamic> activities,
  required List<dynamic> events,
  required List<dynamic> carbLoadingPlans,
  required List<dynamic> carbLoadingDays,
  required List<dynamic> activityCompletions,
}) async {
  try {
    _logger.info(
      'Syncing calendar data from downloaded data',
      context: 'CALENDAR_SYNC',
      data: {
        'activities': activities.length,
        'events': events.length,
        'carb_plans': carbLoadingPlans.length,
        'carb_days': carbLoadingDays.length,
        'completions': activityCompletions.length,
      },
    );

    // Sync in dependency order
    for (final activityData in activities) {
      await _upsertActivity(activityData as Map<String, dynamic>);
    }

    for (final eventData in events) {
      await _upsertEvent(eventData as Map<String, dynamic>);
    }

    for (final planData in carbLoadingPlans) {
      await _upsertCarbLoadingPlan(planData as Map<String, dynamic>);
    }

    for (final dayData in carbLoadingDays) {
      await _upsertCarbLoadingDay(dayData as Map<String, dynamic>);
    }

    for (final completionData in activityCompletions) {
      await _upsertActivityCompletion(completionData as Map<String, dynamic>);
    }

    _logger.info(
      'Calendar data sync completed successfully',
      context: 'CALENDAR_SYNC',
    );
  } catch (e, stackTrace) {
    _logger.error(
      'Calendar data sync failed',
      context: 'CALENDAR_SYNC',
      error: e,
      stackTrace: stackTrace,
    );
    rethrow;
  }
}
```

Update `_upsertEvent` to handle new `user_id` field:
```dart
Future<void> _upsertEvent(Map<String, dynamic> data) async {
  // ... existing code ...

  final companion = EventsTableCompanion.insert(
    id: data['id'] as String,
    userId: data['user_id'] as String, // NEW!
    activityId: Value(data['activity_id'] as String?),
    // ... rest of fields ...
  );
}
```

**3.2 Update CarbLoadingFoodSyncService**

File: `lib/features/carb_loading/application/carb_loading_food_sync_service.dart`

Add new method:
```dart
/// Sync carb loading foods from pre-downloaded data
Future<void> syncFromDownloadedData({
  required List<dynamic> carbLoadingFoods,
  required List<dynamic> mealTypes,
}) async {
  try {
    _logger.info(
      'Syncing carb loading foods from downloaded data',
      context: 'CARB_LOADING_SYNC',
      data: {
        'carb_foods': carbLoadingFoods.length,
        'meal_types': mealTypes.length,
      },
    );

    // Sync meal types first (dependency)
    for (final mealTypeData in mealTypes) {
      await _upsertMealType(mealTypeData as Map<String, dynamic>);
    }

    // Sync carb loading foods
    for (final foodData in carbLoadingFoods) {
      await _upsertCarbLoadingFood(foodData as Map<String, dynamic>);
    }

    _logger.info('Carb loading foods sync completed', context: 'CARB_LOADING_SYNC');
  } catch (e, stackTrace) {
    _logger.error(
      'Carb loading foods sync failed',
      context: 'CARB_LOADING_SYNC',
      error: e,
      stackTrace: stackTrace,
    );
    rethrow;
  }
}
```

**3.3 Update FoodRepository**

File: `lib/features/nutrition_plan/data/food_repository.dart`

Add new method:
```dart
/// Sync nutrition foods from pre-downloaded data
Future<void> syncFromDownloadedData({
  required List<dynamic> foods,
}) async {
  try {
    _logger.info(
      'Syncing nutrition foods from downloaded data',
      context: 'FOOD_REPOSITORY',
      data: {'count': foods.length},
    );

    // Clear existing foods (server is source of truth)
    await _database.delete(_database.foodsTable).go();

    // Insert all foods
    for (final foodData in foods) {
      await _insertFood(foodData as Map<String, dynamic>);
    }

    _logger.info('Nutrition foods sync completed', context: 'FOOD_REPOSITORY');
  } catch (e, stackTrace) {
    _logger.error(
      'Nutrition foods sync failed',
      context: 'FOOD_REPOSITORY',
      error: e,
      stackTrace: stackTrace,
    );
    rethrow;
  }
}

/// Insert a single food into Drift
Future<void> _insertFood(Map<String, dynamic> data) async {
  // Map Supabase JSON to Drift companion
  final companion = FoodsTableCompanion.insert(
    id: data['id'] as String,
    name: Value(data['name'] as String?),
    imageAddress: Value(data['image_address'] as String?),
    // ... map all fields ...
  );

  await _database.into(_database.foodsTable)
      .insert(companion, mode: InsertMode.insertOrReplace);
}
```

---

#### Step 4: Refactor ALL Repositories to Offline-First (12 hours)

**CRITICAL: All user data operations must be offline-first**

### Complete List of Operations Requiring Offline-First

| Repository | Operations | Current Edge Function | Needs Refactor |
|-----------|-----------|----------------------|----------------|
| **ActivitiesRepository** | create, update, delete, complete | `save-calendar-activity` | ✅ YES |
| **EventsRepository** | create, update, delete | `save-calendar-event` | ✅ YES |
| **CarbLoadingRepository** | create plan, update plan, delete plan | `save-carb-loading-plan` | ✅ YES |
| **ActivityCompletionsRepository** | save completion, update completion | `save-activity-completion` | ✅ YES |
| **UserFoodsRepository** | like, dislike, hide, add custom | `update-food-preferences` | ✅ YES |
| **NutritionPlanRepository** | save plan, update plan | `generate-nutrition-plan` | ✅ YES |
| **MacroTargetsRepository** | save targets, update targets | `generate-macros` | ✅ YES |

**Total Operations to Refactor**: ~25 methods across 7 repositories

**Pattern: Drift-First + Background Upload**
```dart
// 1. Write to Drift IMMEDIATELY (user sees instant response)
// 2. Set needs_upload = true
// 3. Attempt background upload (non-blocking)
// 4. On success: clear needs_upload flag
// 5. On failure: keep flag, retry on next sync
```

---

**4.1 Refactor ActivitiesRepository**

File: `lib/features/calendar/data/activities_repository.dart`

```dart
/// Create a new activity (offline-first)
Future<domain.Activity> createActivity({
  required String deviceId,
  required domain.Activity activity,
}) async {
  try {
    // 1. Save to Drift FIRST (offline-first) ✅
    await _saveToDrift(activity.copyWith(needsUpload: true));

    // 2. Attempt background upload (non-blocking)
    unawaited(_uploadActivityToSupabase(deviceId, activity, 'create'));

    _logger.info(
      'Created activity locally (will upload in background)',
      context: 'ACTIVITIES_REPOSITORY',
      data: {'activityId': activity.id},
    );

    return activity;
  } catch (e, stackTrace) {
    _logger.error(
      'Failed to create activity',
      context: 'ACTIVITIES_REPOSITORY',
      error: e,
      stackTrace: stackTrace,
    );
    rethrow;
  }
}

/// Update an existing activity (offline-first)
Future<domain.Activity> updateActivity({
  required String deviceId,
  required domain.Activity activity,
}) async {
  try {
    // 1. Save to Drift FIRST (offline-first) ✅
    await _saveToDrift(activity.copyWith(
      needsUpload: true,
      localUpdatedAt: DateTime.now(),
    ));

    // 2. Attempt background upload (non-blocking)
    unawaited(_uploadActivityToSupabase(deviceId, activity, 'update'));

    _logger.info(
      'Updated activity locally (will upload in background)',
      context: 'ACTIVITIES_REPOSITORY',
      data: {'activityId': activity.id},
    );

    return activity;
  } catch (e, stackTrace) {
    _logger.error(
      'Failed to update activity',
      context: 'ACTIVITIES_REPOSITORY',
      error: e,
      stackTrace: stackTrace,
    );
    rethrow;
  }
}

/// Save activity to Drift database
Future<void> _saveToDrift(domain.Activity activity) async {
  final companion = ActivitiesTableCompanion.insert(
    id: activity.id,
    userId: activity.userId,
    activityType: activity.activityType.name,
    title: activity.title,
    scheduledDateTime: activity.scheduledDateTime,
    status: Value(activity.status.name),
    distanceMiles: Value(activity.distanceMiles),
    durationMinutes: Value(activity.durationMinutes),
    paceTargetMinutesPerMile: Value(activity.paceTargetMinutesPerMile),
    intensityLevel: Value(activity.intensityLevel?.name),
    notes: Value(activity.notes),
    // Cycling fields
    cyclingSpeedMph: Value(activity.cyclingSpeedMph),
    cyclingTerrain: Value(activity.cyclingTerrain),
    cyclingIndoorOutdoor: Value(activity.cyclingIndoorOutdoor),
    cyclingElevationGainFt: Value(activity.cyclingElevationGainFt),
    cyclingSessionGoal: Value(activity.cyclingSessionGoal),
    // Swimming fields
    swimmingPacePer100mSeconds: Value(activity.swimmingPacePer100mSeconds),
    swimmingPoolOrOpenWater: Value(activity.swimmingPoolOrOpenWater),
    swimmingWaterTempC: Value(activity.swimmingWaterTempC),
    // Shared fields
    intensityTarget: Value(activity.intensityTarget),
    timeBeforeMinutes: Value(activity.timeBeforeMinutes),
    // Completion fields
    completedAt: Value(activity.completedAt),
    completionRating: Value(activity.completionRating),
    completionNotes: Value(activity.completionNotes),
    actualDistanceMiles: Value(activity.actualDistanceMiles),
    actualDurationMinutes: Value(activity.actualDurationMinutes),
    // Sync tracking
    needsUpload: Value(activity.needsUpload ?? true),
    localUpdatedAt: Value(activity.localUpdatedAt ?? DateTime.now()),
    // Metadata
    createdAt: activity.createdAt ?? DateTime.now(),
    updatedAt: activity.updatedAt ?? DateTime.now(),
  );

  await _database
      .into(_database.activitiesTable)
      .insert(companion, mode: InsertMode.insertOrReplace);
}

/// Upload activity to Supabase in background (non-blocking)
Future<void> _uploadActivityToSupabase(
  String deviceId,
  domain.Activity activity,
  String operation,
) async {
  try {
    final response = await _supabase.functions.invoke(
      'save-calendar-activity',
      body: {
        'device_id': deviceId,
        'activity': activity.toJson(),
        'operation': operation,
      },
    );

    if (response.status >= 200 && response.status < 300) {
      // Upload successful - clear dirty flag
      await _clearDirtyFlag(activity.id);

      _logger.debug(
        'Successfully uploaded activity to Supabase',
        context: 'ACTIVITIES_REPOSITORY',
        data: {'activityId': activity.id},
      );
    } else {
      throw Exception('Edge function failed: ${response.data}');
    }
  } catch (e) {
    _logger.warning(
      'Failed to upload activity (will retry on next sync)',
      context: 'ACTIVITIES_REPOSITORY',
      error: e,
      data: {'activityId': activity.id},
    );
    // Don't rethrow - keep dirty flag, will retry on next sync
  }
}

/// Clear dirty flag after successful upload
Future<void> _clearDirtyFlag(String activityId) async {
  await (_database.update(_database.activitiesTable)
        ..where((tbl) => tbl.id.equals(activityId)))
      .write(const ActivitiesTableCompanion(needsUpload: Value(false)));
}
```

**4.2 Refactor EventsRepository** (same offline-first pattern)

File: `lib/features/calendar/data/events_repository.dart`

- `createEvent()` → Save to Drift first, background upload
- `updateEvent()` → Save to Drift first, background upload
- `deleteEvent()` → Mark deleted in Drift, background upload

**4.3 Refactor CarbLoadingRepository** (same offline-first pattern)

File: `lib/features/calendar/data/carb_loading_repository.dart`

- `createCarbLoadingPlan()` → Save to Drift first, background upload
- `updateCarbLoadingPlan()` → Save to Drift first, background upload
- `deleteCarbLoadingPlan()` → Mark deleted in Drift, background upload

**4.4 Refactor ActivityCompletionsRepository** (same offline-first pattern)

File: `lib/features/calendar/data/activity_completions_repository.dart`

- `saveCompletion()` → Save to Drift first, background upload
- `updateCompletion()` → Save to Drift first, background upload

**4.5 Refactor UserFoodsRepository** (same offline-first pattern)

File: `lib/features/nutrition_plan/data/user_foods_repository.dart`

- `likeFood()` → Save to Drift first, background upload
- `dislikeFood()` → Save to Drift first, background upload
- `hideFood()` → Save to Drift first, background upload
- `addCustomFood()` → Save to Drift first, background upload

**4.6 Refactor NutritionPlanRepository** (same offline-first pattern)

File: `lib/features/nutrition_plan/data/nutrition_plan_repository.dart`

- `savePlan()` → Save to Drift first, background upload
- `updatePlan()` → Save to Drift first, background upload

**4.7 Refactor MacroTargetsRepository** (same offline-first pattern)

File: `lib/features/nutrition_plan/data/macro_repository.dart`

- `saveMacroTargets()` → Save to Drift first, background upload
- `updateMacroTargets()` → Save to Drift first, background upload

---

#### Step 5: Update Edge Function (1 hour)

**5.1 Update sync-all-data to include user_id in events**

File: `supabase/functions/sync-all-data/index.ts`

```typescript
// 5. Events - NOW INCLUDES user_id
supabaseClient
  .from('events')
  .select('*')
  .eq('user_id', user_id)  // Direct filtering now!
  .order('created_at', { ascending: false }),
```

---

#### Step 6: Testing (4 hours)

**6.1 Unit Tests**
- Test `DataSyncService.syncAllData()`
- Test offline-first save in repositories
- Test dirty flag tracking

**6.2 Integration Tests**
- Test single network call downloads all data
- Test offline editing (airplane mode)
- Test upload on network recovery
- Test multi-device sync

**6.3 Manual Testing**
- Create activity offline → verify saved locally
- Go online → verify uploads to Supabase
- Switch devices → verify data appears
- Edit same record on two devices → verify conflict resolution

---

### **Phase 2B: Timestamp-Based Conflict Resolution** (Optional - Week 2)

**Goal**: Handle edge cases where same record edited on multiple devices

**Not implementing yet** - Phase 2A provides sufficient functionality for most use cases.

**Future enhancement:**
- Three-way merge based on `local_updated_at` vs `updated_at`
- User notification on conflicts
- Conflict resolution UI

---

## Performance Targets

### App Startup Time

| Metric | Before | After Phase 2A | Improvement |
|--------|--------|----------------|-------------|
| Network calls | 7+ sequential | 1 call | 85% reduction |
| Startup time (fast network) | 3-5 seconds | 0.5-1 second | 75% faster |
| Startup time (slow network) | 10-15 seconds | 2-3 seconds | 80% faster |
| Offline capability | ❌ Broken | ✅ Full support | ∞ improvement |

### User Experience Improvements

| Feature | Before | After Phase 2A |
|---------|--------|----------------|
| Edit activity offline | ❌ Error | ✅ Works perfectly |
| Create event offline | ❌ Error | ✅ Works perfectly |
| Multi-device sync | ⚠️ Unreliable | ✅ Reliable |
| Data loss risk | ⚠️ High | ✅ Zero |
| Network failure handling | ❌ App breaks | ✅ Graceful degradation |

---

## Risk Assessment

### Phase 2A Risks

| Risk | Severity | Mitigation |
|------|----------|------------|
| Schema migration fails | HIGH | Test on dev database first, have rollback plan |
| Breaking repository changes | MEDIUM | Update all callers, comprehensive testing |
| Dirty records not uploading | MEDIUM | Add logging, retry logic, manual sync button |
| Performance regression | LOW | Benchmark before/after, monitor in production |
| Data corruption | LOW | Timestamp-based conflict resolution, Supabase is source of truth |

---

## Rollout Plan

### Development Phase
1. ✅ Create feature branch: `feature/unified-sync`
2. ✅ Run Supabase migration on dev database
3. ✅ Update Drift schema
4. ✅ Implement Phase 2A
5. ✅ Test on dev environment

### Testing Phase
1. Manual testing on iOS simulator
2. Manual testing on Android emulator
3. Test offline scenarios (airplane mode)
4. Test multi-device sync (2 simulators)
5. Load testing (100+ activities)

### Production Deployment
1. Merge to `develop` branch
2. Deploy to staging environment
3. Beta test with 5-10 users
4. Monitor logs for errors
5. Deploy to production
6. Monitor for 24 hours

### Rollback Plan
If critical issues found:
1. Revert repository changes (restore Supabase-first pattern)
2. Keep schema changes (backward compatible)
3. Keep `sync-all-data` edge function (not breaking)
4. Investigate and fix issues
5. Re-deploy when ready

---

## Success Metrics

### Technical Metrics
- ✅ App startup < 1 second on fast network
- ✅ App works 100% offline
- ✅ Zero data loss scenarios
- ✅ < 5% upload failure rate
- ✅ Dirty records uploaded within 60 seconds of network recovery

### User Experience Metrics
- ✅ Zero "can't edit offline" support tickets
- ✅ Zero "data disappeared" support tickets
- ✅ 75% reduction in sync-related errors
- ✅ Improved app ratings (faster startup)

---

## Files to Create/Modify

### New Files
- `supabase/migrations/20251029000000_add_sync_columns.sql`
- `lib/shared/services/sync/sync_upload_service.dart` (optional)
- `database_schemas/v2/drift_schema_v2.json`
- `database_schemas/v2/schema.sql`

### Modified Files
- `lib/shared/services/sync/data_sync_service.dart` (major refactor)
- `lib/features/calendar/application/calendar_sync_service.dart` (add syncFromDownloadedData)
- `lib/features/carb_loading/application/carb_loading_food_sync_service.dart` (add syncFromDownloadedData)
- `lib/features/nutrition_plan/data/food_repository.dart` (add syncFromDownloadedData)
- `lib/features/calendar/data/activities_repository.dart` (offline-first refactor)
- `lib/features/calendar/data/events_repository.dart` (create + offline-first)
- `lib/features/calendar/data/activity_completions_repository.dart` (offline-first refactor)
- `lib/shared/database/tables/activities_table.dart` (add needsUpload, localUpdatedAt)
- `lib/shared/database/tables/events_table.dart` (add userId, needsUpload, localUpdatedAt)
- `lib/shared/database/tables/carb_loading_plans_table.dart` (add needsUpload, localUpdatedAt)
- `lib/shared/database/tables/carb_loading_days_table.dart` (add needsUpload, localUpdatedAt)
- `lib/shared/database/tables/activity_completions_table.dart` (add needsUpload, localUpdatedAt)
- `lib/shared/database/tables/user_foods_table.dart` (add needsUpload, localUpdatedAt)
- `supabase/functions/sync-all-data/index.ts` (update events query)

---

## Timeline Estimate

| Phase | Tasks | Duration | Status |
|-------|-------|----------|--------|
| **Phase 2A Setup** | Schema migrations, Drift updates | 2 hours | ✅ DONE |
| **Phase 2A Core** | DataSyncService refactor | 4 hours | ✅ DONE |
| **Phase 2A Services** | Add syncFromDownloadedData methods | 4 hours | ✅ DONE |
| **Phase 2A Edge Function** | Update sync-all-data | 1 hour | ✅ DONE |
| **Phase 2A Event Domain** | Add userId to Event model | 2 hours | ✅ DONE |
| **PHASE 2A TOTAL** | | **13 hours** | ✅ **COMPLETE** |
| | | | |
| **Phase 2B Repositories** | Offline-first refactor (7 repos, ~25 methods) | 16 hours | ⏳ TODO |
| **Phase 2B Testing** | Unit + integration + manual | 4 hours | ⏳ TODO |
| **PHASE 2B TOTAL** | | **20 hours** | ⏳ **PENDING** |
| | | | |
| **Phase 2C Upload** | Implement _uploadDirtyRecords() | 6 hours | ⏳ TODO |
| **Phase 2C Testing** | Test background upload + retry logic | 2 hours | ⏳ TODO |
| **PHASE 2C TOTAL** | | **8 hours** | ⏳ **PENDING** |
| | | | |
| **Phase 2D Schema** | Add sync columns to remaining tables | 2 hours | ⏳ TODO |
| **Phase 2D Deployment** | Staging + production | 2 hours | ⏳ TODO |
| **PHASE 2D TOTAL** | | **4 hours** | ⏳ **PENDING** |
| | | | |
| **GRAND TOTAL** | | **45 hours (5-6 days)** | **30% DONE** |

---

## Decision Log

### 2025-10-29: Architecture Decision - Offline-First Required

**Decision**: Refactor repositories from Supabase-first to Drift-first

**Reasoning**:
- Current architecture breaks when offline
- Users cannot edit activities/events without internet
- Not truly "offline-first" as claimed
- Multi-device sync requires dirty flag tracking

**Impact**:
- Breaking changes to repository methods
- Requires schema additions (needsUpload, localUpdatedAt)
- Significant refactor but necessary for production quality

**Approved by**: User confirmed all breaking changes acceptable

### 2025-10-29: Schema Decision - Add user_id to Events

**Decision**: Add `user_id` column to events table

**Reasoning**:
- Eliminates need for joins during sync
- Faster queries (direct filtering by user_id)
- Simpler RLS policies
- Consistent with other tables

**Migration**: Backfill from activities.user_id, add NOT NULL constraint

---

**Status**: Ready for implementation
**Created**: 2025-10-29
**Last Updated**: 2025-10-29
**Author**: Claude Code (Architecture Analysis & Planning)
