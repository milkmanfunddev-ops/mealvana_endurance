# Sync Simplification Roadmap
*Created: 2025-11-13*
*Status: PLANNING*

## Executive Summary

### Why We're Simplifying

The current sync architecture is **client-orchestrated with server bundling** - a complex hybrid that combines the worst aspects of both approaches:

- **Primary Issue**: Difficult to debug when things fail (silent failures, unclear error sources)
- **Foreign Key Errors**: User records not syncing properly, causing FK violations in dev/prod
- **No Incremental Sync**: Downloads ALL data on every app startup (wasteful bandwidth)
- **No Retry Logic**: Silent upload failures with no recovery mechanism
- **Race Conditions**: Two-phase sync (download → upload) can overwrite local changes
- **Edge Function Complexity**: Adds deployment/testing overhead for simple data fetching

**This roadmap moves to a simpler, more maintainable client-side sync architecture while preserving offline-first functionality.**

### Key Benefits

✅ **Easier Debugging**: Per-table sync with individual error handling
✅ **Incremental Sync**: Only fetch changed records using `updated_at` timestamps
✅ **Retry Queue**: Failed uploads persist and retry automatically
✅ **Better UX**: Surface sync errors to users with actionable messages
✅ **Simpler Code**: Direct Supabase client calls, no edge function maintenance
✅ **Faster Syncs**: Skip unchanged data, reduce network traffic by ~80%

### Migration Timeline

| Phase | Duration | Status |
|-------|----------|--------|
| Phase 1: Fix Foreign Keys | 2-3 days | 🟡 PLANNED |
| Phase 2: Add Incremental Sync | 3-5 days | ⚪ NOT STARTED |
| Phase 3: Remove Edge Function | 2-3 days | ⚪ NOT STARTED |
| Phase 4: Add Retry Queue + UI | 3-4 days | ⚪ NOT STARTED |
| **Total** | **10-15 days** | |

---

## 1. Current State Analysis

### Architecture Diagram (Current)

```
┌─────────────────────────────────────────────────────────────┐
│                      Flutter App (Client)                    │
│                                                              │
│  ┌──────────────────────────────────────────────────────┐  │
│  │              DataSyncService                         │  │
│  │  • syncAllData(userId)                              │  │
│  │  • _downloadAllDataFromSupabase()                   │  │
│  │  • _mergeDownloadedData()                           │  │
│  │  • _uploadDirtyRecords()                            │  │
│  └──────────────────────────────────────────────────────┘  │
│                           │                                 │
│                           ▼                                 │
│  ┌──────────────────────────────────────────────────────┐  │
│  │           Drift SQLite Database (Local)              │  │
│  │  • 27 tables (v1 schema)                            │  │
│  │  • needs_upload flags (dirty tracking)              │  │
│  │  • Offline-first storage                            │  │
│  └──────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────┘
                           │
                           │ Single Edge Function Call
                           ▼
┌─────────────────────────────────────────────────────────────┐
│                  Supabase Edge Function                      │
│                                                              │
│  ┌──────────────────────────────────────────────────────┐  │
│  │             sync-all-data                            │  │
│  │  • Bundles 6 parallel Supabase queries              │  │
│  │  • Returns all data in single response              │  │
│  │  • No incremental sync capability                   │  │
│  └──────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────┘
                           │
                           ▼
┌─────────────────────────────────────────────────────────────┐
│              Supabase PostgreSQL (Cloud)                     │
│  • Dev: 27 tables (full multi-sport)                        │
│  • Prod: 27 tables (partial multi-sport - schema mismatch!) │
└─────────────────────────────────────────────────────────────┘
```

### Current Sync Flow

**On App Startup** (triggered by `appStartupProvider`):

```dart
// 1. DOWNLOAD PHASE - Single network call
final response = await supabase.functions.invoke('sync-all-data',
  body: {'user_id': userId}
);

// Returns ALL data:
// - nutrition_foods (all ~300+ foods)
// - carb_loading_foods (all ~150+ foods)
// - activities (user's activities)
// - events (user's events)
// - carb_loading_plans (user's plans)
// - carb_loading_days (user's plan days)

// 2. MERGE PHASE - Update local database
await _mergeDownloadedData(response.data);
// Upserts each record if supabase.updated_at > local.updated_at

// 3. UPLOAD PHASE - Push dirty records
final dirtyActivities = await db.select(activitiesTable)
  .where((t) => t.needsUpload.equals(true))
  .get();

for (final activity in dirtyActivities) {
  await _uploadActivity(userId, activity);
  // Individual edge function calls or direct upserts
}
```

### Pain Points

#### 1. Foreign Key Violations

**Example Error** (from production logs):
```
PostgresException: insert or update on table "activities" violates
foreign key constraint "activities_user_id_fkey"
Detail: Key (user_id)=(device_123abc) is not present in table "users"
```

**Root Cause**:
- Activities sync BEFORE user record exists in Supabase
- Download phase fetches data but doesn't sync user profile first
- Upload phase fails silently with FK error
- No retry, user data stuck in local database

#### 2. Downloads ALL Data Every Time

```dart
// Current: Downloads 450+ food records on EVERY app startup
await supabase.from('foods').select('*'); // ~300 records
await supabase.from('carb_loading_foods').select('*'); // ~150 records

// Even if nothing changed since yesterday!
```

**Impact**:
- Wasted bandwidth: ~500KB per sync (foods alone)
- Slow sync on cellular: 3-5 seconds vs <100ms with incremental
- Battery drain from constant network activity

#### 3. Silent Upload Failures

```dart
Future<void> _uploadActivity(String userId, Activity activity) async {
  try {
    final response = await _supabase.functions.invoke(...);
    if (response.status >= 200 && response.status < 300) {
      await db.update(...).write(needsUpload: false); // ✅ Success
    }
  } catch (e) {
    _logger.warning('Failed to upload activity ${activity.id}');
    // ❌ No retry! Record stays marked as needs_upload forever
    // User has no idea sync failed
  }
}
```

**Problems**:
- No user notification of failed uploads
- No automatic retry mechanism
- Changes stuck in local database indefinitely
- Lost data if user uninstalls app

#### 4. Two-Phase Race Conditions

**Scenario**: User creates activity during sync

```
Time    Download Phase      User Action        Upload Phase
----    --------------      -----------        ------------
T0      Start download      -                  -
T1      Fetch activities    -                  -
T2      Merge to local      Create new run     -
T3      -                   Save to Drift      -
T4      -                   -                  Start upload
T5      -                   -                  Upload new run ✅
T6      Overwrite local     -                  -
        with old data ❌
```

**Result**: New activity lost because download phase overwrites it!

#### 5. Complex Debugging

When sync fails, finding the root cause is difficult:

```
Where did it fail?
├── Edge function crash? (check Supabase logs)
├── Network timeout? (check Flutter logs)
├── Merge logic error? (check DataSyncService code)
├── Upload individual record? (check per-table upload methods)
└── Foreign key violation? (check PostgreSQL constraint logs)

5 different places to investigate! 😩
```

### Data Synced

**Download** (6 data types from edge function):
1. `nutrition_foods` - Seed food database (~300 records)
2. `carb_loading_foods` - Carb loading food database (~150 records)
3. `activities` - User's workout activities
4. `events` - User's race events
5. `carb_loading_plans` - User's carb loading plans
6. `carb_loading_days` - Days within carb loading plans

**Upload** (4 data types, client-initiated):
1. `activities` - User-created/modified activities
2. `events` - User-created/modified events
3. `carb_loading_plans` - User-generated plans
4. `carb_loading_days` - Modified plan days

**Not Synced** (local-only tables):
- `macro_targets` (calculated data)
- `workout_notes` (deprecated - embedded in activities)
- `weather_forecasts` (cache table, 1-24hr expiry)

### Current Code Locations

```
Client-Side Sync:
├── lib/shared/services/sync/data_sync_service.dart (608 lines)
│   ├── syncAllData() - Main orchestrator
│   ├── _downloadAllDataFromSupabase() - Calls edge function
│   ├── _mergeDownloadedData() - Updates Drift database
│   ├── _uploadDirtyRecords() - Pushes changes to Supabase
│   ├── _uploadActivity() - Individual activity upload
│   ├── _uploadEvent() - Individual event upload
│   ├── _uploadCarbLoadingPlan() - Plan upload
│   └── _uploadCarbLoadingDay() - Day upload
├── lib/shared/services/sync/data_sync_service.g.dart (generated)
└── lib/features/app_startup/application/app_startup_service.dart
    └── Calls dataSyncService.syncAllData() on app startup

Edge Function:
└── supabase/functions/sync-all-data/index.ts (180 lines)
    ├── Parallel fetches of 6 data types
    ├── Returns bundled response
    └── Handles errors gracefully (partial data)

Database Tables (Drift):
└── lib/shared/database/tables/
    ├── activities_table.dart (needs_upload column)
    ├── events_table.dart (needs_upload column)
    ├── carb_loading_plans_table.dart (needs_upload column)
    └── carb_loading_days_table.dart (needs_upload column)
```

---

## 2. Proposed Architecture

### Architecture Diagram (Simplified)

```
┌─────────────────────────────────────────────────────────────┐
│                      Flutter App (Client)                    │
│                                                              │
│  ┌──────────────────────────────────────────────────────┐  │
│  │           SimplifiedDataSyncService                  │  │
│  │  • syncAllData(userId)                              │  │
│  │  • syncUsers() - NEW                                │  │
│  │  • syncActivities(lastSync) - INCREMENTAL           │  │
│  │  • syncEvents(lastSync) - INCREMENTAL               │  │
│  │  • syncCarbLoadingPlans(lastSync) - INCREMENTAL     │  │
│  │  • syncFoods() - Full sync (seed data)              │  │
│  │  • retryFailedUploads() - NEW                       │  │
│  └──────────────────────────────────────────────────────┘  │
│                           │                                 │
│                           ▼                                 │
│  ┌──────────────────────────────────────────────────────┐  │
│  │           Drift SQLite Database (Local)              │  │
│  │  • 27 tables + new sync_metadata table              │  │
│  │  • needs_upload + upload_retry_count                │  │
│  │  • last_sync_timestamp per table                    │  │
│  └──────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────┘
                           │
                           │ Direct Supabase Client Calls
                           │ (No Edge Function!)
                           ▼
┌─────────────────────────────────────────────────────────────┐
│              Supabase PostgreSQL (Cloud)                     │
│  • Per-table queries with updated_at filtering              │
│  • Row Level Security enforces access control               │
│  • Direct upserts from Flutter client                       │
└─────────────────────────────────────────────────────────────┘
```

### Simplified Sync Flow

**On App Startup** (phased sync):

```dart
// PHASE 1: User Profile (CRITICAL - must complete first)
try {
  await syncUsers(userId);
  // Ensures user exists before any FK references
} catch (e) {
  showError('Cannot sync user profile. Please check connection.');
  return; // Don't proceed if user can't sync
}

// PHASE 2: Seed Data (can happen in background)
Future.wait([
  syncFoods(), // Only if > 1 day since last sync
  syncCarbLoadingFoods(),
]);

// PHASE 3: User Data (incremental)
final lastSync = await getLastSyncTimestamp('activities');
await syncActivities(lastSync); // Only fetch records with updated_at > lastSync
await syncEvents(lastSync);
await syncCarbLoadingPlans(lastSync);

// PHASE 4: Upload dirty records (with retry)
await retryFailedUploads(); // Handles previous failures
await uploadDirtyRecords(); // New changes
```

### Key Components

#### 1. Per-Table Sync Methods

Each synced table gets its own sync method with incremental support:

```dart
Future<void> syncActivities(DateTime? lastSync) async {
  try {
    // Build query with timestamp filter
    var query = _supabase
      .from('activities')
      .select('*')
      .eq('user_id', userId);

    if (lastSync != null) {
      // INCREMENTAL: Only fetch changed records
      query = query.gt('updated_at', lastSync.toIso8601String());
    }

    final response = await query;

    if (response.error != null) {
      throw response.error!;
    }

    // Merge into local database
    for (final activity in response.data) {
      await _database
        .into(_database.activitiesTable)
        .insert(
          ActivitiesTableCompanion.fromJson(activity),
          mode: InsertMode.insertOrReplace,
        );
    }

    // Update last sync timestamp
    await _updateLastSyncTimestamp('activities', DateTime.now());

    _logger.debug('Synced ${response.data.length} activities');
  } catch (e, stackTrace) {
    _logger.error(
      'Failed to sync activities',
      context: 'SYNC_ACTIVITIES',
      error: e,
      stackTrace: stackTrace,
    );
    throw SyncException('activities', e.toString());
  }
}
```

#### 2. Sync Metadata Table

New Drift table to track sync state per table:

```dart
@DataClassName('SyncMetadata')
class SyncMetadataTable extends Table {
  TextColumn get tableName => text()(); // 'activities', 'events', etc.
  DateTimeColumn get lastSyncTimestamp => dateTime()();
  DateTimeColumn get lastSuccessfulUpload => dateTime().nullable()();
  IntColumn get failedUploadCount => integer().withDefault(const Constant(0))();
  TextColumn get lastSyncError => text().nullable()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {tableName};
}

// Usage:
Future<DateTime?> getLastSyncTimestamp(String table) async {
  final metadata = await (_database.select(_database.syncMetadataTable)
    ..where((t) => t.tableName.equals(table)))
    .getSingleOrNull();

  return metadata?.lastSyncTimestamp;
}

Future<void> _updateLastSyncTimestamp(String table, DateTime timestamp) async {
  await _database
    .into(_database.syncMetadataTable)
    .insert(
      SyncMetadataTableCompanion.insert(
        tableName: table,
        lastSyncTimestamp: timestamp,
        updatedAt: DateTime.now(),
      ),
      mode: InsertMode.insertOrReplace,
    );
}
```

#### 3. Upload Retry Queue

Track failed uploads and retry automatically:

```dart
Future<void> retryFailedUploads() async {
  // Find records marked for upload with retry attempts
  final failedRecords = await (_database.select(_database.activitiesTable)
    ..where((t) => t.needsUpload.equals(true))
    ..where((t) => t.uploadRetryCount.isSmallerThanValue(3))) // Max 3 retries
    .get();

  for (final record in failedRecords) {
    try {
      await _uploadActivity(record);

      // Success - clear retry count
      await (_database.update(_database.activitiesTable)
        ..where((t) => t.id.equals(record.id)))
        .write(ActivitiesTableCompanion(
          needsUpload: const Value(false),
          uploadRetryCount: const Value(0),
        ));
    } catch (e) {
      // Increment retry count
      await (_database.update(_database.activitiesTable)
        ..where((t) => t.id.equals(record.id)))
        .write(ActivitiesTableCompanion(
          uploadRetryCount: Value(record.uploadRetryCount + 1),
        ));

      _logger.warning(
        'Upload retry ${record.uploadRetryCount + 1}/3 failed',
        context: 'RETRY_QUEUE',
        data: {'recordId': record.id},
      );

      // Show user notification after 3 failures
      if (record.uploadRetryCount >= 2) {
        _showSyncFailureNotification(record);
      }
    }
  }
}
```

#### 4. Error Handling Strategy

```dart
class SyncException implements Exception {
  final String tableName;
  final String message;
  final dynamic originalError;

  SyncException(this.tableName, this.message, [this.originalError]);

  @override
  String toString() => 'Sync failed for $tableName: $message';
}

// In sync service:
Future<SyncResult> syncAllData(String userId) async {
  final result = SyncResult();

  try {
    // Critical: User must sync first
    await syncUsers(userId);
    result.markSuccess('users');
  } catch (e) {
    result.markFailure('users', e.toString());
    return result; // Don't continue if user sync fails
  }

  // Non-critical syncs can fail individually
  await _syncWithErrorHandling('foods', () => syncFoods(), result);
  await _syncWithErrorHandling('activities', () => syncActivities(), result);
  await _syncWithErrorHandling('events', () => syncEvents(), result);

  return result;
}

Future<void> _syncWithErrorHandling(
  String tableName,
  Future<void> Function() syncFn,
  SyncResult result,
) async {
  try {
    await syncFn();
    result.markSuccess(tableName);
  } catch (e, stackTrace) {
    result.markFailure(tableName, e.toString());
    _logger.error(
      'Sync failed for $tableName',
      context: 'SYNC_ERROR',
      error: e,
      stackTrace: stackTrace,
    );
  }
}

class SyncResult {
  final Map<String, bool> successByTable = {};
  final Map<String, String> errorsByTable = {};

  void markSuccess(String table) => successByTable[table] = true;
  void markFailure(String table, String error) {
    successByTable[table] = false;
    errorsByTable[table] = error;
  }

  bool get isSuccess => errorsByTable.isEmpty;
  String get summary =>
    '${successByTable.length} synced, ${errorsByTable.length} failed';
}
```

---

## 3. Migration Plan

### Phase 1: Fix Foreign Key Issues (IMMEDIATE)

**Goal**: Ensure user profile syncs BEFORE any dependent records

**Duration**: 2-3 days

**Tasks**:

1. **Add User Profile Sync Method** ✅
   ```dart
   Future<void> syncUsers(String userId) async {
     // Check if user exists locally
     final localUser = await _database.getCurrentUserProfile();

     if (localUser == null) {
       throw SyncException('users', 'No local user profile found');
     }

     // Upsert to Supabase
     await _supabase
       .from('users')
       .upsert({
         'id': localUser.id,
         'device_id': userId,
         'gender': localUser.gender,
         'birthday': localUser.birthday?.toIso8601String(),
         'weight_pounds': localUser.weightPounds,
         // ... all other user fields
       });

     _logger.info('User profile synced successfully');
   }
   ```

2. **Update Sync Order in DataSyncService** ✅
   ```dart
   Future<bool> syncAllData(String userId) async {
     try {
       // STEP 0: CRITICAL - Sync user profile first
       await syncUsers(userId);

       // STEP 1: Download all data (existing logic)
       final downloadData = await _downloadAllDataFromSupabase(userId);

       // STEP 2: Merge downloaded data
       await _mergeDownloadedData(downloadData);

       // STEP 3: Upload dirty records
       await _uploadDirtyRecords(userId);

       return true;
     } catch (e, stackTrace) {
       _logger.error(...);
       return false;
     }
   }
   ```

3. **Add User Sync to Edge Function Response** ✅
   ```typescript
   // supabase/functions/sync-all-data/index.ts

   // Add user profile to response
   const { data: userProfile, error: userError } = await supabaseClient
     .from('users')
     .select('*')
     .eq('device_id', user_id)
     .single();

   response.data.user_profile = userProfile || null;
   if (userError) {
     response.errors.user_profile = userError.message;
   }
   ```

4. **Testing**:
   - ✅ Test fresh install (no existing user in Supabase)
   - ✅ Test existing user (user already in Supabase)
   - ✅ Verify activities/events sync AFTER user profile
   - ✅ Confirm no more FK violations in logs

**Success Criteria**:
- ✅ Zero foreign key violations in production logs
- ✅ User profile exists in Supabase before any activities created
- ✅ Sync completes successfully for new users

---

### Phase 2: Add Incremental Sync

**Goal**: Only fetch changed records, dramatically reduce bandwidth

**Duration**: 3-5 days

**Tasks**:

1. **Create SyncMetadataTable** ✅
   ```dart
   // lib/shared/database/tables/sync_metadata_table.dart

   @DataClassName('SyncMetadata')
   class SyncMetadataTable extends Table {
     TextColumn get tableName => text()();
     DateTimeColumn get lastSyncTimestamp => dateTime()();
     DateTimeColumn get lastSuccessfulUpload => dateTime().nullable()();
     IntColumn get failedUploadCount => integer().withDefault(const Constant(0))();
     TextColumn get lastSyncError => text().nullable()();
     DateTimeColumn get updatedAt => dateTime()();

     @override
     Set<Column> get primaryKey => {tableName};

     @override
     String get tableName => 'sync_metadata';
   }
   ```

2. **Add to AppDatabase** ✅
   ```dart
   // lib/shared/database/app_database.dart

   @DriftDatabase(tables: [
     // ... existing tables
     SyncMetadataTable,
   ])
   class AppDatabase extends _$AppDatabase {
     // ...
   }
   ```

3. **Run Code Generation** ✅
   ```bash
   flutter pub run build_runner build --delete-conflicting-outputs
   ```

4. **Update Download Methods with Incremental Support** ✅
   ```dart
   Future<void> _downloadActivities(String userId) async {
     final lastSync = await _getLastSyncTimestamp('activities');

     var query = _supabase
       .from('activities')
       .select('*')
       .eq('user_id', userId)
       .is_('deleted_at', null);

     if (lastSync != null) {
       // INCREMENTAL: Only changed records
       query = query.gt('updated_at', lastSync.toIso8601String());
       _logger.debug('Fetching activities updated after $lastSync');
     } else {
       _logger.debug('Full sync - no previous timestamp');
     }

     final response = await query.order('updated_at', ascending: false);

     // Merge into local database
     for (final activity in response.data) {
       await _upsertActivity(activity);
     }

     // Update metadata
     await _updateLastSyncTimestamp('activities', DateTime.now());

     _logger.info(
       'Synced ${response.data.length} activities (incremental: ${lastSync != null})'
     );
   }
   ```

5. **Add Helper Methods** ✅
   ```dart
   Future<DateTime?> _getLastSyncTimestamp(String table) async {
     final metadata = await (_database.select(_database.syncMetadataTable)
       ..where((t) => t.tableName.equals(table)))
       .getSingleOrNull();

     return metadata?.lastSyncTimestamp;
   }

   Future<void> _updateLastSyncTimestamp(
     String table,
     DateTime timestamp,
   ) async {
     await _database
       .into(_database.syncMetadataTable)
       .insert(
         SyncMetadataTableCompanion.insert(
           tableName: table,
           lastSyncTimestamp: timestamp,
           updatedAt: DateTime.now(),
         ),
         mode: InsertMode.insertOrReplace,
       );
   }

   Future<void> _recordSyncError(String table, String error) async {
     final metadata = await _getLastSyncTimestamp(table);

     await _database
       .into(_database.syncMetadataTable)
       .insert(
         SyncMetadataTableCompanion.insert(
           tableName: table,
           lastSyncTimestamp: metadata ?? DateTime.now(),
           lastSyncError: Value(error),
           failedUploadCount: const Value(1),
           updatedAt: DateTime.now(),
         ),
         mode: InsertMode.insertOrReplace,
       );
   }
   ```

6. **Update All Download Methods**:
   - ✅ `_downloadActivities(userId)`
   - ✅ `_downloadEvents(userId)`
   - ✅ `_downloadCarbLoadingPlans(userId)`
   - ✅ `_downloadCarbLoadingDays(userId)`
   - ✅ Keep full sync for foods (seed data changes rarely)

7. **Testing**:
   - ✅ Test initial sync (no last_sync_timestamp) - should fetch all records
   - ✅ Test subsequent sync (with timestamp) - should only fetch new/changed
   - ✅ Verify bandwidth reduction (~80% for typical user)
   - ✅ Test sync after creating new record locally
   - ✅ Test sync after modifying existing record on server

**Success Criteria**:
- ✅ First sync downloads all records
- ✅ Subsequent syncs only download changed records
- ✅ Bandwidth usage reduced by 70-90% on typical sync
- ✅ Sync completes in <1 second on cellular (vs 3-5 seconds before)

---

### Phase 3: Remove Edge Function, Move to Client-Side

**Goal**: Eliminate edge function, use direct Supabase client calls

**Duration**: 2-3 days

**Tasks**:

1. **Replace Edge Function Call with Direct Queries** ✅
   ```dart
   // OLD (edge function):
   final response = await _supabase.functions.invoke(
     'sync-all-data',
     body: {'user_id': userId},
   );

   // NEW (direct client):
   await Future.wait([
     _downloadFoods(),
     _downloadCarbLoadingFoods(),
     _downloadActivities(userId),
     _downloadEvents(userId),
     _downloadCarbLoadingPlans(userId),
     _downloadCarbLoadingDays(userId),
   ]);
   ```

2. **Refactor DataSyncService** ✅
   ```dart
   class DataSyncService {
     // Remove _downloadAllDataFromSupabase() method
     // Remove _mergeDownloadedData() method

     Future<bool> syncAllData(String userId) async {
       try {
         // PHASE 1: User profile (critical)
         await _syncUsers(userId);

         // PHASE 2: Seed data (parallel, can skip if recent)
         await Future.wait([
           _syncFoodsIfNeeded(),
           _syncCarbLoadingFoodsIfNeeded(),
         ]);

         // PHASE 3: User data (incremental)
         await _downloadActivities(userId);
         await _downloadEvents(userId);
         await _downloadCarbLoadingPlans(userId);
         await _downloadCarbLoadingDays(userId);

         // PHASE 4: Upload dirty records
         await _uploadDirtyRecords(userId);

         return true;
       } catch (e, stackTrace) {
         _logger.error('Sync failed', error: e, stackTrace: stackTrace);
         return false;
       }
     }

     Future<void> _syncFoodsIfNeeded() async {
       final lastSync = await _getLastSyncTimestamp('foods');

       // Only sync if > 24 hours since last sync (seed data changes rarely)
       if (lastSync != null &&
           DateTime.now().difference(lastSync).inHours < 24) {
         _logger.debug('Skipping foods sync - last synced ${lastSync}');
         return;
       }

       final response = await _supabase
         .from('foods')
         .select('*')
         .or('is_essential.eq.true,updated_at.gt.${lastSync?.toIso8601String() ?? "1970-01-01"}');

       for (final food in response.data) {
         await _foodRepository.syncFromDownloadedData([food]);
       }

       await _updateLastSyncTimestamp('foods', DateTime.now());
     }
   }
   ```

3. **Remove Edge Function Files** ✅
   ```bash
   # Archive edge function (don't delete - keep for reference)
   mkdir -p supabase/functions/_archive
   mv supabase/functions/sync-all-data supabase/functions/_archive/

   # Update documentation
   echo "sync-all-data edge function retired $(date)" >> docs/technical/CHANGELOG.md
   ```

4. **Update Tests** ✅
   - Remove edge function integration tests
   - Add tests for direct Supabase client calls
   - Test error handling for individual table syncs
   - Test partial sync failures (one table fails, others succeed)

5. **Testing**:
   - ✅ Test complete sync flow without edge function
   - ✅ Verify all 6 data types sync correctly
   - ✅ Test offline → online transition
   - ✅ Verify Row Level Security policies work correctly
   - ✅ Load test with 100+ activities

**Success Criteria**:
- ✅ Edge function no longer needed
- ✅ All sync operations work via direct client calls
- ✅ No performance regression vs edge function
- ✅ Deployment simpler (no edge function to maintain)

---

### Phase 4: Add Retry Queue and Error UI

**Goal**: Surface sync errors to users, retry failed uploads automatically

**Duration**: 3-4 days

**Tasks**:

1. **Add Retry Columns to Synced Tables** ✅
   ```dart
   // Add to activities_table.dart, events_table.dart, etc.

   IntColumn get uploadRetryCount =>
     integer().withDefault(const Constant(0)).named('upload_retry_count')();
   DateTimeColumn get lastUploadAttempt =>
     dateTime().nullable().named('last_upload_attempt')();
   TextColumn get uploadErrorMessage =>
     text().nullable().named('upload_error_message')();
   ```

2. **Update Database Schema** ✅
   ```bash
   # Generate Drift migration
   dart run drift_dev schema dump lib/shared/database/app_database.dart database_schemas/v2/

   # Review migration
   # Add to lib/shared/database/app_database.dart:
   @override
   int get schemaVersion => 2;

   @override
   MigrationStrategy get migration => MigrationStrategy(
     onCreate: (Migrator m) async {
       await m.createAll();
     },
     onUpgrade: (Migrator m, int from, int to) async {
       if (from == 1) {
         // Add retry columns to existing tables
         await m.addColumn(activitiesTable, activitiesTable.uploadRetryCount);
         await m.addColumn(activitiesTable, activitiesTable.lastUploadAttempt);
         await m.addColumn(activitiesTable, activitiesTable.uploadErrorMessage);
         // Repeat for events, carb_loading_plans, carb_loading_days
       }
     },
   );
   ```

3. **Implement Retry Queue Logic** ✅
   ```dart
   Future<void> retryFailedUploads() async {
     final now = DateTime.now();

     // Find failed uploads with retry attempts remaining
     final failedActivities = await (_database.select(_database.activitiesTable)
       ..where((t) => t.needsUpload.equals(true))
       ..where((t) => t.uploadRetryCount.isSmallerThanValue(3))
       ..orderBy([(t) => OrderingTerm(expression: t.lastUploadAttempt, mode: OrderingMode.asc)]))
       .get();

     for (final activity in failedActivities) {
       // Exponential backoff: 5min, 15min, 30min
       final backoffMinutes = [5, 15, 30][activity.uploadRetryCount];
       final shouldRetry = activity.lastUploadAttempt == null ||
         now.difference(activity.lastUploadAttempt!).inMinutes >= backoffMinutes;

       if (!shouldRetry) continue;

       try {
         await _uploadActivity(activity);

         // Success - clear flags
         await (_database.update(_database.activitiesTable)
           ..where((t) => t.id.equals(activity.id)))
           .write(ActivitiesTableCompanion(
             needsUpload: const Value(false),
             uploadRetryCount: const Value(0),
             lastUploadAttempt: Value(null),
             uploadErrorMessage: Value(null),
           ));

         _logger.info('Upload retry succeeded for activity ${activity.id}');
       } catch (e) {
         // Update retry metadata
         await (_database.update(_database.activitiesTable)
           ..where((t) => t.id.equals(activity.id)))
           .write(ActivitiesTableCompanion(
             uploadRetryCount: Value(activity.uploadRetryCount + 1),
             lastUploadAttempt: Value(now),
             uploadErrorMessage: Value(e.toString()),
           ));

         _logger.warning(
           'Upload retry ${activity.uploadRetryCount + 1}/3 failed',
           context: 'RETRY_QUEUE',
           error: e,
         );
       }
     }
   }
   ```

4. **Create Sync Status Provider** ✅
   ```dart
   // lib/shared/services/sync/sync_status_provider.dart

   @riverpod
   class SyncStatus extends _$SyncStatus {
     @override
     FutureOr<SyncStatusData> build() async {
       return _checkSyncStatus();
     }

     Future<SyncStatusData> _checkSyncStatus() async {
       final db = ref.read(appDatabaseProvider);

       // Count failed uploads
       final failedActivities = await (db.select(db.activitiesTable)
         ..where((t) => t.needsUpload.equals(true))
         ..where((t) => t.uploadRetryCount.isBiggerOrEqualValue(3)))
         .get();

       final failedEvents = await (db.select(db.eventsTable)
         ..where((t) => t.needsUpload.equals(true))
         ..where((t) => t.uploadRetryCount.isBiggerOrEqualValue(3)))
         .get();

       // Get last sync times
       final activitiesLastSync = await _getLastSync('activities');
       final eventsLastSync = await _getLastSync('events');

       return SyncStatusData(
         hasPendingUploads: failedActivities.isNotEmpty || failedEvents.isNotEmpty,
         failedActivitiesCount: failedActivities.length,
         failedEventsCount: failedEvents.length,
         lastActivitiesSync: activitiesLastSync,
         lastEventsSync: eventsLastSync,
       );
     }

     Future<void> retryAll() async {
       final syncService = ref.read(dataSyncServiceProvider);
       await syncService.retryFailedUploads();
       ref.invalidateSelf();
     }
   }

   class SyncStatusData {
     final bool hasPendingUploads;
     final int failedActivitiesCount;
     final int failedEventsCount;
     final DateTime? lastActivitiesSync;
     final DateTime? lastEventsSync;

     const SyncStatusData({
       required this.hasPendingUploads,
       required this.failedActivitiesCount,
       required this.failedEventsCount,
       this.lastActivitiesSync,
       this.lastEventsSync,
     });
   }
   ```

5. **Add Sync Status Widget to Settings Screen** ✅
   ```dart
   // lib/features/settings/presentation/widgets/sync_status_widget.dart

   class SyncStatusWidget extends ConsumerWidget {
     const SyncStatusWidget({super.key});

     @override
     Widget build(BuildContext context, WidgetRef ref) {
       final syncStatus = ref.watch(syncStatusProvider);

       return syncStatus.when(
         data: (status) {
           if (!status.hasPendingUploads) {
             return ListTile(
               leading: const Icon(Icons.cloud_done, color: Colors.green),
               title: const Text('All changes synced'),
               subtitle: Text(
                 'Last sync: ${_formatLastSync(status.lastActivitiesSync)}',
               ),
             );
           }

           return Card(
             color: Colors.orange.shade50,
             child: ListTile(
               leading: const Icon(Icons.cloud_off, color: Colors.orange),
               title: Text(
                 '${status.failedActivitiesCount + status.failedEventsCount} changes pending',
               ),
               subtitle: const Text(
                 'Some changes couldn\'t sync. Tap to retry.',
               ),
               trailing: TextButton(
                 onPressed: () => ref.read(syncStatusProvider.notifier).retryAll(),
                 child: const Text('Retry'),
               ),
             ),
           );
         },
         loading: () => const ListTile(
           leading: CircularProgressIndicator(),
           title: Text('Checking sync status...'),
         ),
         error: (error, _) => ListTile(
           leading: const Icon(Icons.error, color: Colors.red),
           title: const Text('Sync error'),
           subtitle: Text(error.toString()),
         ),
       );
     }

     String _formatLastSync(DateTime? lastSync) {
       if (lastSync == null) return 'Never';

       final diff = DateTime.now().difference(lastSync);
       if (diff.inMinutes < 1) return 'Just now';
       if (diff.inHours < 1) return '${diff.inMinutes} min ago';
       if (diff.inDays < 1) return '${diff.inHours} hours ago';
       return '${diff.inDays} days ago';
     }
   }
   ```

6. **Add to Settings Screen** ✅
   ```dart
   // lib/features/settings/presentation/screens/settings_screen.dart

   ListView(
     children: [
       const SectionHeader('Sync & Backup'),
       const SyncStatusWidget(), // NEW
       // ... existing settings
     ],
   )
   ```

7. **Testing**:
   - ✅ Test retry logic with simulated network failures
   - ✅ Verify exponential backoff (5min, 15min, 30min)
   - ✅ Test UI shows correct pending upload counts
   - ✅ Test manual retry button
   - ✅ Verify max 3 retry attempts before giving up

**Success Criteria**:
- ✅ Users see sync status in Settings
- ✅ Failed uploads retry automatically with backoff
- ✅ Users can manually trigger retries
- ✅ Clear error messages displayed for permanent failures

---

## 4. Implementation Details

### Per-Table Sync Method Template

Use this template for each synced table:

```dart
/// Sync [tableName] with incremental support
///
/// Downloads records changed since [lastSync] timestamp.
/// Falls back to full sync if no timestamp available.
Future<void> sync[TableName](String userId) async {
  final lastSync = await _getLastSyncTimestamp('[table_name]');

  try {
    // Build query
    var query = _supabase
      .from('[table_name]')
      .select('*')
      .eq('user_id', userId);

    // Add incremental filter if available
    if (lastSync != null) {
      query = query.gt('updated_at', lastSync.toIso8601String());
      _logger.debug('[TableName] incremental sync since $lastSync');
    } else {
      _logger.debug('[TableName] full sync (no previous timestamp)');
    }

    // Execute query
    final response = await query
      .order('updated_at', ascending: false);

    if (response.error != null) {
      throw response.error!;
    }

    // Merge into local database
    for (final record in response.data) {
      await _upsert[TableName](record);
    }

    // Update sync metadata
    await _updateLastSyncTimestamp('[table_name]', DateTime.now());

    _logger.info(
      'Synced ${response.data.length} [table_name] records '
      '(incremental: ${lastSync != null})'
    );
  } catch (e, stackTrace) {
    await _recordSyncError('[table_name]', e.toString());

    _logger.error(
      'Failed to sync [table_name]',
      context: 'SYNC_[TABLE_NAME]',
      error: e,
      stackTrace: stackTrace,
    );

    throw SyncException('[table_name]', e.toString());
  }
}

/// Upsert single [tableName] record into local database
Future<void> _upsert[TableName](Map<String, dynamic> data) async {
  final recordId = data['id'] as int;
  final existingRecord = await (_database.select(_database.[tableName]Table)
    ..where((t) => t.id.equals(recordId)))
    .getSingleOrNull();

  final supabaseUpdatedAt = DateTime.parse(data['updated_at'] as String);

  // Only upsert if newer than local version
  if (existingRecord == null ||
      existingRecord.updatedAt.isBefore(supabaseUpdatedAt)) {

    final companion = [TableName]TableCompanion.insert(
      id: Value(recordId),
      userId: data['user_id'] as String,
      // ... map all columns from JSON
      updatedAt: supabaseUpdatedAt,
    );

    await _database
      .into(_database.[tableName]Table)
      .insert(companion, mode: InsertMode.insertOrReplace);
  }
}
```

### Upload Method Template

```dart
/// Upload dirty [tableName] record to Supabase
Future<void> _upload[TableName]([TableName] record) async {
  try {
    // Convert Drift record to Supabase JSON
    final json = {
      'id': record.id,
      'user_id': record.userId,
      // ... all other fields
      'updated_at': DateTime.now().toIso8601String(),
    };

    // Direct upsert to Supabase
    await _supabase
      .from('[table_name]')
      .upsert(json);

    // Clear dirty flag on success
    await (_database.update(_database.[tableName]Table)
      ..where((t) => t.id.equals(record.id)))
      .write([TableName]TableCompanion(
        needsUpload: const Value(false),
        uploadRetryCount: const Value(0),
        lastUploadAttempt: Value(null),
        uploadErrorMessage: Value(null),
      ));

    _logger.debug('Uploaded [table_name] ${record.id}');
  } catch (e, stackTrace) {
    // Update retry metadata
    await (_database.update(_database.[tableName]Table)
      ..where((t) => t.id.equals(record.id)))
      .write([TableName]TableCompanion(
        uploadRetryCount: Value(record.uploadRetryCount + 1),
        lastUploadAttempt: Value(DateTime.now()),
        uploadErrorMessage: Value(e.toString()),
      ));

    _logger.error(
      'Failed to upload [table_name] ${record.id}',
      context: 'UPLOAD_[TABLE_NAME]',
      error: e,
      stackTrace: stackTrace,
    );

    rethrow;
  }
}
```

### Code Structure

```
lib/shared/services/sync/
├── data_sync_service.dart (400 lines, down from 608)
│   ├── syncAllData(userId) - Main orchestrator
│   ├── _syncUsers(userId) - User profile sync
│   ├── syncActivities(userId) - Activities with incremental
│   ├── syncEvents(userId) - Events with incremental
│   ├── syncCarbLoadingPlans(userId) - Plans with incremental
│   ├── syncCarbLoadingDays(userId) - Days with incremental
│   ├── _syncFoodsIfNeeded() - Seed data (24hr cache)
│   ├── _syncCarbLoadingFoodsIfNeeded() - Seed data (24hr cache)
│   ├── retryFailedUploads() - Retry queue processor
│   ├── _uploadDirtyRecords(userId) - Upload new changes
│   ├── _getLastSyncTimestamp(table) - Metadata helper
│   ├── _updateLastSyncTimestamp(table, time) - Metadata helper
│   └── _recordSyncError(table, error) - Error tracking
├── sync_status_provider.dart (150 lines)
│   ├── SyncStatusNotifier - Riverpod state management
│   ├── SyncStatusData - Immutable state class
│   └── retryAll() - Manual retry trigger
└── sync_exceptions.dart (50 lines)
    ├── SyncException - Base exception
    ├── UserSyncException - Critical user sync failure
    └── TableSyncException - Individual table failure

lib/shared/database/tables/
└── sync_metadata_table.dart (30 lines)
    └── SyncMetadataTable - Track last sync per table

lib/features/settings/presentation/widgets/
└── sync_status_widget.dart (100 lines)
    └── SyncStatusWidget - UI for sync errors

Total: ~730 lines (vs 608 before, but with retry queue + UI)
```

---

## 5. Benefits & Trade-offs

### What Improves ✅

| Area | Before | After | Improvement |
|------|--------|-------|-------------|
| **Debugging** | 5 places to check | 1 place (per-table methods) | 80% faster |
| **Bandwidth** | 500KB every sync | ~50KB incremental | 90% reduction |
| **Sync Speed** | 3-5 seconds | <1 second | 70% faster |
| **Error Visibility** | Silent failures | User notifications | 100% transparency |
| **Recovery** | Manual intervention | Auto-retry with backoff | Self-healing |
| **Deployment** | Edge function + client | Client only | 50% simpler |
| **FK Violations** | Common | Never (user syncs first) | Eliminated |

### What We Lose ❌

| Feature | Impact | Mitigation |
|---------|--------|------------|
| **Single network call** | More HTTP requests | HTTP/2 multiplexing, parallel fetches |
| **Server-side bundling** | Client handles complexity | Well-structured code, good logging |
| **Edge function caching** | Potential cache misses | Incremental sync reduces impact |

### Performance Considerations

**Network Requests**:
```
Before: 1 edge function call + 4 upload calls = 5 requests
After:  6 download calls + 4 upload calls = 10 requests

Impact: Minimal - HTTP/2 multiplexing makes parallel requests efficient
Benefit: Incremental sync reduces download payload by 90%
Net result: Faster overall sync despite more requests
```

**Database Operations**:
```
Before: Bulk merge of all data
After:  Per-record upserts with timestamp checks

Impact: Slightly more DB operations
Benefit: Skip unchanged records, avoid overwrites
Net result: Faster for incremental syncs (90% of cases)
```

**Memory Usage**:
```
Before: Load all 6 data types into memory simultaneously
After:  Load per-table, process, release

Impact: Lower peak memory usage
Benefit: Better for low-memory devices
Net result: More stable on older devices
```

---

## 6. Testing Strategy

### Unit Tests

**Sync Metadata Tests** (`test/shared/services/sync/sync_metadata_test.dart`):
```dart
void main() {
  group('SyncMetadata', () {
    late AppDatabase db;

    setUp(() {
      db = AppDatabase.memory();
    });

    test('stores and retrieves last sync timestamp', () async {
      final timestamp = DateTime.now();

      await db.into(db.syncMetadataTable).insert(
        SyncMetadataTableCompanion.insert(
          tableName: 'activities',
          lastSyncTimestamp: timestamp,
          updatedAt: DateTime.now(),
        ),
      );

      final metadata = await (db.select(db.syncMetadataTable)
        ..where((t) => t.tableName.equals('activities')))
        .getSingle();

      expect(metadata.tableName, 'activities');
      expect(metadata.lastSyncTimestamp, timestamp);
    });

    test('upserts on conflict', () async {
      final time1 = DateTime(2025, 1, 1);
      final time2 = DateTime(2025, 1, 2);

      // Insert first time
      await db.into(db.syncMetadataTable).insert(
        SyncMetadataTableCompanion.insert(
          tableName: 'activities',
          lastSyncTimestamp: time1,
          updatedAt: DateTime.now(),
        ),
      );

      // Update with newer timestamp
      await db.into(db.syncMetadataTable).insert(
        SyncMetadataTableCompanion.insert(
          tableName: 'activities',
          lastSyncTimestamp: time2,
          updatedAt: DateTime.now(),
        ),
        mode: InsertMode.insertOrReplace,
      );

      final metadata = await (db.select(db.syncMetadataTable)
        ..where((t) => t.tableName.equals('activities')))
        .getSingle();

      expect(metadata.lastSyncTimestamp, time2);
    });
  });
}
```

**Incremental Sync Tests** (`test/shared/services/sync/incremental_sync_test.dart`):
```dart
void main() {
  group('Incremental Sync', () {
    late DataSyncService syncService;
    late AppDatabase db;
    late MockSupabaseClient supabase;

    setUp(() {
      db = AppDatabase.memory();
      supabase = MockSupabaseClient();
      syncService = DataSyncService(
        supabase: supabase,
        database: db,
        logger: MockAppLogger(),
      );
    });

    test('initial sync fetches all records', () async {
      // Mock Supabase response
      when(() => supabase.from('activities').select('*'))
        .thenAnswer((_) async => PostgrestResponse(
          data: [
            {'id': 1, 'title': 'Run 1', 'updated_at': '2025-01-01T10:00:00Z'},
            {'id': 2, 'title': 'Run 2', 'updated_at': '2025-01-02T10:00:00Z'},
          ],
          status: 200,
        ));

      await syncService.syncActivities('user_123');

      final activities = await db.select(db.activitiesTable).get();
      expect(activities.length, 2);

      // Verify last sync timestamp set
      final metadata = await (db.select(db.syncMetadataTable)
        ..where((t) => t.tableName.equals('activities')))
        .getSingleOrNull();

      expect(metadata, isNotNull);
      expect(metadata!.lastSyncTimestamp.isAfter(DateTime(2025, 1, 2)), true);
    });

    test('incremental sync only fetches new records', () async {
      // Set up previous sync
      final lastSync = DateTime(2025, 1, 1);
      await db.into(db.syncMetadataTable).insert(
        SyncMetadataTableCompanion.insert(
          tableName: 'activities',
          lastSyncTimestamp: lastSync,
          updatedAt: DateTime.now(),
        ),
      );

      // Mock Supabase response with incremental filter
      when(() => supabase
        .from('activities')
        .select('*')
        .eq('user_id', 'user_123')
        .gt('updated_at', lastSync.toIso8601String()))
        .thenAnswer((_) async => PostgrestResponse(
          data: [
            {'id': 3, 'title': 'New Run', 'updated_at': '2025-01-03T10:00:00Z'},
          ],
          status: 200,
        ));

      await syncService.syncActivities('user_123');

      // Verify only new record was processed
      verify(() => supabase
        .from('activities')
        .select('*')
        .eq('user_id', 'user_123')
        .gt('updated_at', lastSync.toIso8601String()))
        .called(1);
    });
  });
}
```

**Retry Queue Tests** (`test/shared/services/sync/retry_queue_test.dart`):
```dart
void main() {
  group('Retry Queue', () {
    test('retries failed uploads with exponential backoff', () async {
      // Create activity with failed upload
      await db.into(db.activitiesTable).insert(
        ActivitiesTableCompanion.insert(
          userId: 'user_123',
          title: 'Failed Run',
          activityType: 'running',
          scheduledDateTime: DateTime.now(),
          needsUpload: const Value(true),
          uploadRetryCount: const Value(1),
          lastUploadAttempt: Value(DateTime.now().subtract(Duration(minutes: 6))),
        ),
      );

      // Mock successful upload
      when(() => supabase.from('activities').upsert(any()))
        .thenAnswer((_) async => PostgrestResponse(data: [], status: 200));

      await syncService.retryFailedUploads();

      final activity = await db.select(db.activitiesTable).getSingle();
      expect(activity.needsUpload, false);
      expect(activity.uploadRetryCount, 0);
    });

    test('stops retrying after 3 attempts', () async {
      // Create activity with max retries
      await db.into(db.activitiesTable).insert(
        ActivitiesTableCompanion.insert(
          userId: 'user_123',
          title: 'Permanently Failed Run',
          activityType: 'running',
          scheduledDateTime: DateTime.now(),
          needsUpload: const Value(true),
          uploadRetryCount: const Value(3),
          lastUploadAttempt: Value(DateTime.now().subtract(Duration(hours: 1))),
        ),
      );

      await syncService.retryFailedUploads();

      // Should not attempt upload
      verifyNever(() => supabase.from('activities').upsert(any()));
    });
  });
}
```

### Integration Tests

**Supabase Integration** (`test/integration/sync_integration_test.dart`):
```dart
void main() {
  group('Sync Integration', () {
    late SupabaseClient supabase;
    late DataSyncService syncService;

    setUpAll(() async {
      // Use test Supabase instance
      supabase = SupabaseClient(
        'https://test-project.supabase.co',
        'test-anon-key',
      );

      syncService = DataSyncService(
        supabase: supabase,
        database: AppDatabase.memory(),
        logger: AppLogger(),
      );
    });

    test('full sync flow: user → data → uploads', () async {
      final userId = 'test_user_${DateTime.now().millisecondsSinceEpoch}';

      // 1. Sync user profile
      await syncService.syncUsers(userId);

      // 2. Sync data
      await syncService.syncActivities(userId);
      await syncService.syncEvents(userId);

      // 3. Create local activity
      await db.into(db.activitiesTable).insert(
        ActivitiesTableCompanion.insert(
          userId: userId,
          title: 'Integration Test Run',
          activityType: 'running',
          scheduledDateTime: DateTime.now(),
          needsUpload: const Value(true),
        ),
      );

      // 4. Upload dirty records
      await syncService.uploadDirtyRecords(userId);

      // 5. Verify in Supabase
      final response = await supabase
        .from('activities')
        .select('*')
        .eq('user_id', userId);

      expect(response.data.length, 1);
      expect(response.data[0]['title'], 'Integration Test Run');
    });
  });
}
```

### Offline/Online Scenarios

**Network Transition Tests** (`test/integration/network_transition_test.dart`):
```dart
void main() {
  group('Network Transitions', () {
    test('offline changes sync when coming online', () async {
      // Simulate offline mode
      when(() => connectivity.checkConnectivity())
        .thenAnswer((_) async => ConnectivityResult.none);

      // Create activity offline
      await db.into(db.activitiesTable).insert(
        ActivitiesTableCompanion.insert(
          userId: 'user_123',
          title: 'Offline Run',
          activityType: 'running',
          scheduledDateTime: DateTime.now(),
          needsUpload: const Value(true),
        ),
      );

      // Attempt sync (should fail gracefully)
      final result = await syncService.syncAllData('user_123');
      expect(result, false);

      // Simulate coming online
      when(() => connectivity.checkConnectivity())
        .thenAnswer((_) async => ConnectivityResult.wifi);

      // Sync should succeed
      final retryResult = await syncService.syncAllData('user_123');
      expect(retryResult, true);

      // Verify upload
      final activity = await db.select(db.activitiesTable).getSingle();
      expect(activity.needsUpload, false);
    });
  });
}
```

### Error Recovery Testing

**Error Scenarios** (`test/integration/error_recovery_test.dart`):
```dart
void main() {
  group('Error Recovery', () {
    test('continues sync when one table fails', () async {
      // Mock activities failure
      when(() => supabase.from('activities').select('*'))
        .thenThrow(PostgrestException(message: 'Connection timeout'));

      // Mock events success
      when(() => supabase.from('events').select('*'))
        .thenAnswer((_) async => PostgrestResponse(data: [], status: 200));

      final result = await syncService.syncAllData('user_123');

      // Overall sync continues despite activities failure
      expect(result, true);

      // Check metadata
      final activitiesMetadata = await (db.select(db.syncMetadataTable)
        ..where((t) => t.tableName.equals('activities')))
        .getSingleOrNull();

      expect(activitiesMetadata?.lastSyncError, isNotNull);

      final eventsMetadata = await (db.select(db.syncMetadataTable)
        ..where((t) => t.tableName.equals('events')))
        .getSingleOrNull();

      expect(eventsMetadata?.lastSyncError, isNull);
    });
  });
}
```

---

## 7. Rollback Plan

### How to Revert if Issues Arise

**If Phase 1 (FK Fixes) Fails:**
```bash
# 1. Revert DataSyncService changes
git checkout HEAD~1 lib/shared/services/sync/data_sync_service.dart

# 2. Revert edge function changes
cd supabase/functions/sync-all-data
git checkout HEAD~1 index.ts
supabase functions deploy sync-all-data --project-ref wvmvsodrvbkxfydabqed

# 3. Rebuild Flutter app
flutter pub run build_runner build --delete-conflicting-outputs
```

**If Phase 2 (Incremental Sync) Fails:**
```bash
# 1. Drop sync_metadata table
# In Drift database migration:
@override
MigrationStrategy get migration => MigrationStrategy(
  onUpgrade: (m, from, to) async {
    if (from == 2 && to == 1) {
      await m.database.customStatement('DROP TABLE IF EXISTS sync_metadata');
    }
  },
);

# 2. Revert to full sync logic
git revert <commit-hash-of-incremental-sync>

# 3. Redeploy
flutter pub run build_runner build --delete-conflicting-outputs
```

**If Phase 3 (Remove Edge Function) Fails:**
```bash
# 1. Restore edge function
cd supabase/functions
mv _archive/sync-all-data ./
supabase functions deploy sync-all-data --project-ref wvmvsodrvbkxfydabqed

# 2. Revert DataSyncService to use edge function
git revert <commit-hash-of-direct-client-calls>

# 3. Rebuild and test
flutter pub run build_runner build --delete-conflicting-outputs
flutter test
```

**If Phase 4 (Retry Queue) Fails:**
```bash
# 1. Remove retry columns (database migration)
@override
MigrationStrategy get migration => MigrationStrategy(
  onUpgrade: (m, from, to) async {
    if (from == 3 && to == 2) {
      await m.database.customStatement(
        'ALTER TABLE activities DROP COLUMN upload_retry_count'
      );
      await m.database.customStatement(
        'ALTER TABLE activities DROP COLUMN last_upload_attempt'
      );
      // Repeat for other tables
    }
  },
);

# 2. Remove SyncStatusWidget from UI
# Delete lib/features/settings/presentation/widgets/sync_status_widget.dart
# Remove from settings_screen.dart

# 3. Revert retry queue logic
git revert <commit-hash-of-retry-queue>
```

### What to Monitor

**Key Metrics**:
```dart
// Add to analytics tracking
await analytics.track('sync_completed', {
  'duration_ms': syncDuration.inMilliseconds,
  'tables_synced': tablesCount,
  'records_downloaded': recordsDownloaded,
  'records_uploaded': recordsUploaded,
  'incremental': wasIncremental,
  'errors': errorCount,
});

// Monitor in Mixpanel dashboard:
// - Sync success rate (target: >95%)
// - Average sync duration (target: <2s)
// - Bandwidth usage (target: <100KB per sync)
// - Retry queue depth (target: <5 pending uploads per user)
// - FK violation rate (target: 0%)
```

**Sentry Alerts**:
```dart
// Set up Sentry alerts for:
// 1. Foreign key violations (should never happen)
Sentry.captureException(
  ForeignKeyViolationException(tableName),
  level: SentryLevel.fatal,
);

// 2. Sync failures >10% of users
if (syncFailureRate > 0.1) {
  Sentry.captureMessage(
    'High sync failure rate: ${(syncFailureRate * 100).toStringAsFixed(1)}%',
    level: SentryLevel.error,
  );
}

// 3. Retry queue depth >10 per user
if (retryQueueDepth > 10) {
  Sentry.captureMessage(
    'Retry queue backing up: $retryQueueDepth pending uploads',
    level: SentryLevel.warning,
  );
}
```

**Database Queries to Monitor**:
```sql
-- Check for orphaned activities (FK violations)
SELECT COUNT(*)
FROM activities a
LEFT JOIN users u ON a.user_id = u.id
WHERE u.id IS NULL;
-- Expected: 0

-- Check retry queue depth
SELECT user_id, COUNT(*) as pending_uploads
FROM activities
WHERE needs_upload = true
GROUP BY user_id
HAVING COUNT(*) > 5
ORDER BY COUNT(*) DESC;
-- Expected: Empty result

-- Check sync metadata freshness
SELECT table_name,
       last_sync_timestamp,
       NOW() - last_sync_timestamp as staleness
FROM sync_metadata
WHERE NOW() - last_sync_timestamp > INTERVAL '1 day';
-- Expected: Only 'foods' table (syncs every 24hr)
```

### Emergency Procedures

**If Sync is Completely Broken**:
```dart
// 1. Disable automatic sync on app startup
// In app_startup_service.dart:
Future<void> initializeApp() async {
  // ... other initialization

  // TEMPORARY: Skip sync if emergency flag set
  final emergencyMode = await _checkEmergencyFlag();
  if (!emergencyMode) {
    await _dataSyncService.syncAllData(userId);
  }
}

// 2. Push emergency code-push update
shorebird patch ios --staging

// 3. Investigate and fix in parallel
// 4. Deploy proper fix via app update
```

**Emergency Flag Implementation**:
```dart
// Remote config in app_content table
{
  "features": {
    "sync_enabled": true,  // Set to false in emergency
    "sync_retry_enabled": true,
    "sync_incremental_enabled": true
  }
}

// Check before sync
final contentService = ref.read(contentServiceProvider);
final syncEnabled = contentService.getFeatureFlag('sync_enabled');

if (!syncEnabled) {
  _logger.warning('Sync disabled via remote config');
  return false;
}
```

---

## Appendix A: Code Examples

### Complete Incremental Sync Implementation

```dart
// lib/shared/services/sync/data_sync_service.dart

import 'package:drift/drift.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../database/app_database.dart';
import '../../database/database_provider.dart';
import '../logging_service.dart';

part 'data_sync_service.g.dart';

@riverpod
DataSyncService dataSyncService(Ref ref) {
  return DataSyncService(
    supabase: Supabase.instance.client,
    database: ref.read(appDatabaseProvider),
    logger: ref.read(appLoggerProvider),
  );
}

/// Simplified data sync service with incremental sync and retry queue
class DataSyncService {
  const DataSyncService({
    required SupabaseClient supabase,
    required AppDatabase database,
    required AppLogger logger,
  })  : _supabase = supabase,
        _database = database,
        _logger = logger;

  final SupabaseClient _supabase;
  final AppDatabase _database;
  final AppLogger _logger;

  /// Sync all app data with incremental support
  /// Returns true if sync was successful, false otherwise
  Future<bool> syncAllData(String userId) async {
    final startTime = DateTime.now();

    try {
      // PHASE 1: User profile (CRITICAL - must succeed)
      _logger.debug('PHASE 1: Syncing user profile', context: 'SYNC');
      await _syncUsers(userId);

      // PHASE 2: Seed data (can happen in parallel)
      _logger.debug('PHASE 2: Syncing seed data', context: 'SYNC');
      await Future.wait([
        _syncFoodsIfNeeded(),
        _syncCarbLoadingFoodsIfNeeded(),
      ]);

      // PHASE 3: User data (incremental)
      _logger.debug('PHASE 3: Syncing user data', context: 'SYNC');
      await _syncActivities(userId);
      await _syncEvents(userId);
      await _syncCarbLoadingPlans(userId);
      await _syncCarbLoadingDays(userId);

      // PHASE 4: Upload dirty records
      _logger.debug('PHASE 4: Uploading changes', context: 'SYNC');
      await retryFailedUploads();
      await _uploadDirtyRecords(userId);

      final duration = DateTime.now().difference(startTime);
      _logger.info(
        'Sync completed successfully in ${duration.inMilliseconds}ms',
        context: 'SYNC',
      );

      return true;
    } catch (e, stackTrace) {
      _logger.error(
        'Sync failed - app continuing with cached data',
        context: 'SYNC',
        error: e,
        stackTrace: stackTrace,
      );
      return false;
    }
  }

  // ============================================================================
  // DOWNLOAD METHODS (Incremental)
  // ============================================================================

  /// Sync user profile (CRITICAL - must succeed before any FK references)
  Future<void> _syncUsers(String userId) async {
    try {
      final localUser = await _database.getCurrentUserProfile();

      if (localUser == null) {
        throw Exception('No local user profile found');
      }

      // Upsert to Supabase
      await _supabase.from('users').upsert({
        'id': localUser.id,
        'device_id': userId,
        'gender': localUser.gender,
        'birthday': localUser.birthday?.toIso8601String(),
        'height_feet': localUser.heightFeet,
        'height_inches': localUser.heightInches,
        'weight_pounds': localUser.weightPounds,
        'gut_training_level': localUser.gutTrainingLevel,
        'onboarding_completed': localUser.onboardingCompleted,
        'updated_at': DateTime.now().toIso8601String(),
      });

      _logger.info('User profile synced successfully');
    } catch (e, stackTrace) {
      _logger.error(
        'CRITICAL: User profile sync failed',
        context: 'SYNC_USERS',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow; // This is critical - don't allow sync to continue
    }
  }

  /// Sync foods (seed data) - only if stale (>24 hours)
  Future<void> _syncFoodsIfNeeded() async {
    final lastSync = await _getLastSyncTimestamp('foods');

    // Only sync if > 24 hours since last sync
    if (lastSync != null &&
        DateTime.now().difference(lastSync).inHours < 24) {
      _logger.debug('Skipping foods sync - last synced $lastSync');
      return;
    }

    try {
      final response = await _supabase.from('foods').select('*');

      if (response.error != null) {
        throw response.error!;
      }

      // Let food repository handle the merge
      final foodRepository = FoodRepository(database: _database);
      await foodRepository.syncFromDownloadedData(
        foods: response.data,
      );

      await _updateLastSyncTimestamp('foods', DateTime.now());

      _logger.info('Synced ${response.data.length} foods');
    } catch (e, stackTrace) {
      _logger.error(
        'Foods sync failed (non-critical)',
        context: 'SYNC_FOODS',
        error: e,
        stackTrace: stackTrace,
      );
      // Don't rethrow - foods are cached, app can continue
    }
  }

  /// Sync activities with incremental support
  Future<void> _syncActivities(String userId) async {
    final lastSync = await _getLastSyncTimestamp('activities');

    try {
      var query = _supabase
          .from('activities')
          .select('*')
          .eq('user_id', userId)
          .is_('deleted_at', null);

      if (lastSync != null) {
        query = query.gt('updated_at', lastSync.toIso8601String());
        _logger.debug('Activities incremental sync since $lastSync');
      } else {
        _logger.debug('Activities full sync (no previous timestamp)');
      }

      final response = await query.order('updated_at', ascending: false);

      if (response.error != null) {
        throw response.error!;
      }

      // Merge into local database
      for (final activity in response.data) {
        await _upsertActivity(activity);
      }

      await _updateLastSyncTimestamp('activities', DateTime.now());

      _logger.info(
        'Synced ${response.data.length} activities '
        '(incremental: ${lastSync != null})',
      );
    } catch (e, stackTrace) {
      await _recordSyncError('activities', e.toString());

      _logger.error(
        'Activities sync failed',
        context: 'SYNC_ACTIVITIES',
        error: e,
        stackTrace: stackTrace,
      );
      // Don't rethrow - partial failure is acceptable
    }
  }

  /// Upsert single activity into local database
  Future<void> _upsertActivity(Map<String, dynamic> data) async {
    final activityId = data['id'] as int;
    final existingActivity = await (_database.select(_database.activitiesTable)
          ..where((tbl) => tbl.id.equals(activityId)))
        .getSingleOrNull();

    final supabaseUpdatedAt = DateTime.parse(data['updated_at'] as String);

    // Only upsert if newer than local version
    if (existingActivity == null ||
        existingActivity.updatedAt.isBefore(supabaseUpdatedAt)) {
      final companion = ActivitiesTableCompanion.insert(
        id: Value(activityId),
        userId: data['user_id'] as String,
        activityType: data['activity_type'] as String,
        title: data['title'] as String,
        scheduledDateTime:
            DateTime.parse(data['scheduled_date_time'] as String),
        status: Value(data['status'] as String? ?? 'planned'),
        distanceMiles: Value((data['distance_miles'] as num?)?.toDouble()),
        durationMinutes: Value(data['duration_minutes'] as int?),
        // ... map all other columns
        createdAt: DateTime.parse(data['created_at'] as String),
        updatedAt: supabaseUpdatedAt,
      );

      await _database
          .into(_database.activitiesTable)
          .insert(companion, mode: InsertMode.insertOrReplace);
    }
  }

  // ============================================================================
  // UPLOAD METHODS (With Retry Support)
  // ============================================================================

  /// Upload dirty records to Supabase
  Future<void> _uploadDirtyRecords(String userId) async {
    try {
      final dirtyActivities = await (_database.select(_database.activitiesTable)
            ..where((tbl) => tbl.needsUpload.equals(true))
            ..where((tbl) => tbl.uploadRetryCount.isSmallerThanValue(3)))
          .get();

      final dirtyEvents = await (_database.select(_database.eventsTable)
            ..where((tbl) => tbl.needsUpload.equals(true))
            ..where((tbl) => tbl.uploadRetryCount.isSmallerThanValue(3)))
          .get();

      final uploadTasks = <Future<void>>[];

      for (final activity in dirtyActivities) {
        uploadTasks.add(_uploadActivity(activity));
      }

      for (final event in dirtyEvents) {
        uploadTasks.add(_uploadEvent(event));
      }

      await Future.wait(uploadTasks);
    } catch (e, stackTrace) {
      _logger.error(
        'Upload dirty records failed',
        context: 'UPLOAD',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  /// Upload single activity to Supabase
  Future<void> _uploadActivity(Activity activity) async {
    try {
      final json = {
        'id': activity.id,
        'user_id': activity.userId,
        'activity_type': activity.activityType,
        'title': activity.title,
        'scheduled_date_time': activity.scheduledDateTime.toIso8601String(),
        'status': activity.status,
        'distance_miles': activity.distanceMiles,
        'duration_minutes': activity.durationMinutes,
        // ... all other fields
        'updated_at': DateTime.now().toIso8601String(),
      };

      await _supabase.from('activities').upsert(json);

      // Success - clear flags
      await (_database.update(_database.activitiesTable)
            ..where((t) => t.id.equals(activity.id)))
          .write(ActivitiesTableCompanion(
        needsUpload: const Value(false),
        uploadRetryCount: const Value(0),
        lastUploadAttempt: Value(null),
        uploadErrorMessage: Value(null),
      ));

      _logger.debug('Uploaded activity ${activity.id}');
    } catch (e, stackTrace) {
      // Update retry metadata
      await (_database.update(_database.activitiesTable)
            ..where((t) => t.id.equals(activity.id)))
          .write(ActivitiesTableCompanion(
        uploadRetryCount: Value(activity.uploadRetryCount + 1),
        lastUploadAttempt: Value(DateTime.now()),
        uploadErrorMessage: Value(e.toString()),
      ));

      _logger.error(
        'Failed to upload activity ${activity.id}',
        context: 'UPLOAD_ACTIVITY',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  // ============================================================================
  // RETRY QUEUE
  // ============================================================================

  /// Retry failed uploads with exponential backoff
  Future<void> retryFailedUploads() async {
    final now = DateTime.now();

    final failedActivities = await (_database.select(_database.activitiesTable)
          ..where((t) => t.needsUpload.equals(true))
          ..where((t) => t.uploadRetryCount.isSmallerThanValue(3))
          ..orderBy([
            (t) => OrderingTerm(
                  expression: t.lastUploadAttempt,
                  mode: OrderingMode.asc,
                )
          ]))
        .get();

    for (final activity in failedActivities) {
      // Exponential backoff: 5min, 15min, 30min
      final backoffMinutes = [5, 15, 30][activity.uploadRetryCount];
      final shouldRetry = activity.lastUploadAttempt == null ||
          now.difference(activity.lastUploadAttempt!).inMinutes >=
              backoffMinutes;

      if (!shouldRetry) continue;

      await _uploadActivity(activity);
    }
  }

  // ============================================================================
  // METADATA HELPERS
  // ============================================================================

  Future<DateTime?> _getLastSyncTimestamp(String table) async {
    final metadata = await (_database.select(_database.syncMetadataTable)
          ..where((t) => t.tableName.equals(table)))
        .getSingleOrNull();

    return metadata?.lastSyncTimestamp;
  }

  Future<void> _updateLastSyncTimestamp(
    String table,
    DateTime timestamp,
  ) async {
    await _database.into(_database.syncMetadataTable).insert(
          SyncMetadataTableCompanion.insert(
            tableName: table,
            lastSyncTimestamp: timestamp,
            updatedAt: DateTime.now(),
          ),
          mode: InsertMode.insertOrReplace,
        );
  }

  Future<void> _recordSyncError(String table, String error) async {
    final lastSync = await _getLastSyncTimestamp(table);

    await _database.into(_database.syncMetadataTable).insert(
          SyncMetadataTableCompanion.insert(
            tableName: table,
            lastSyncTimestamp: lastSync ?? DateTime.now(),
            lastSyncError: Value(error),
            failedUploadCount: const Value(1),
            updatedAt: DateTime.now(),
          ),
          mode: InsertMode.insertOrReplace,
        );
  }
}
```

---

## Appendix B: Migration Checklist

### Pre-Migration

- [ ] Backup production database
- [ ] Document current sync success rate
- [ ] Measure baseline sync performance
- [ ] Set up Sentry alerts for FK violations
- [ ] Create rollback plan document

### Phase 1: FK Fixes

- [ ] Add `syncUsers()` method
- [ ] Update sync order in `syncAllData()`
- [ ] Add user profile to edge function response
- [ ] Test fresh install scenario
- [ ] Test existing user scenario
- [ ] Deploy to staging
- [ ] Monitor for FK violations (target: 0)
- [ ] Deploy to production

### Phase 2: Incremental Sync

- [ ] Create `SyncMetadataTable`
- [ ] Add to `AppDatabase`
- [ ] Run code generation
- [ ] Update `_downloadActivities()` with incremental support
- [ ] Update `_downloadEvents()` with incremental support
- [ ] Update `_downloadCarbLoadingPlans()` with incremental support
- [ ] Add metadata helper methods
- [ ] Test initial sync (full)
- [ ] Test subsequent sync (incremental)
- [ ] Measure bandwidth reduction
- [ ] Deploy to staging
- [ ] Monitor sync performance
- [ ] Deploy to production

### Phase 3: Remove Edge Function

- [ ] Replace edge function call with direct queries
- [ ] Refactor `DataSyncService`
- [ ] Archive edge function files
- [ ] Update documentation
- [ ] Remove edge function tests
- [ ] Add direct client tests
- [ ] Test complete sync flow
- [ ] Load test with 100+ records
- [ ] Deploy to staging
- [ ] Monitor for errors
- [ ] Deploy to production
- [ ] Archive edge function in Supabase

### Phase 4: Retry Queue + UI

- [ ] Add retry columns to tables
- [ ] Update database schema version
- [ ] Write migration code
- [ ] Implement `retryFailedUploads()`
- [ ] Create `SyncStatusProvider`
- [ ] Create `SyncStatusWidget`
- [ ] Add to Settings screen
- [ ] Test retry logic
- [ ] Test exponential backoff
- [ ] Test UI notifications
- [ ] Deploy to staging
- [ ] Monitor retry queue depth
- [ ] Deploy to production

### Post-Migration

- [ ] Monitor sync success rate (target: >95%)
- [ ] Monitor sync performance (target: <2s)
- [ ] Monitor bandwidth usage (target: <100KB)
- [ ] Monitor retry queue depth (target: <5 per user)
- [ ] Update documentation
- [ ] Remove old edge function from Supabase
- [ ] Celebrate! 🎉

---

## Conclusion

This roadmap provides a comprehensive, phased approach to simplifying Mealvana Endurance's sync architecture. By moving from a complex client-orchestrated + edge function hybrid to a clean client-side implementation with incremental sync and retry logic, we'll achieve:

- **Easier debugging** (per-table error handling)
- **Better performance** (90% bandwidth reduction)
- **Improved reliability** (auto-retry with backoff)
- **Better UX** (visible sync status and errors)
- **Simpler maintenance** (no edge function to deploy)

The phased approach allows us to validate each improvement incrementally, with clear rollback procedures if issues arise. Most importantly, we maintain offline-first functionality throughout the migration - users continue to work seamlessly whether online or offline.

**Estimated Timeline**: 10-15 days
**Risk Level**: Medium (mitigated by phased approach and rollback plans)
**Expected Impact**: High (solves current FK issues, improves performance and UX)

---

*Last Updated: 2025-11-13*
*Author: Documentation Manager Agent*
*Status: Ready for Review*
