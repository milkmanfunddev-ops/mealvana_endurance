# Mealvana Endurance - Sync Architecture Patterns

## Overview
This document provides the complete patterns for implementing the SyncableRepository mixin in new repositories for the Mealvana Endurance project. The sync architecture uses:
- **On-demand staleness checking**: Data is synced only when needed (>1 hour old)
- **Dependency resolution**: Dependencies are automatically synced first
- **Offline-first**: Write to local Drift first with `needs_upload = true`, sync later
- **Type-safe sync**: Shared classes for SyncResult and UploadResult

---

## SyncableRepository Mixin (Core Interface)

**File**: `lib/shared/data/syncable_repository.dart`

```dart
mixin SyncableRepository {
  /// Unique identifier for this repository (used in SharedPreferences)
  /// Examples: 'users', 'activities', 'events', 'food_preferences'
  String get repositoryKey;

  /// List of repository keys that must be synced before this repository
  /// Examples:
  /// - 'users' → [] (no dependencies)
  /// - 'activities' → ['users']
  /// - 'food_preferences' → ['users', 'foods']
  List<String> get dependencies => [];

  /// Check if this repository's data is stale (>1 hour since last sync)
  Future<bool> isStale() async {
    final lastSync = await getLastSyncTime();
    if (lastSync == null) return true;
    return DateTime.now().difference(lastSync) > staleDuration;
  }

  /// Get the last sync timestamp from SharedPreferences
  Future<DateTime?> getLastSyncTime() async {
    final prefs = await SharedPreferences.getInstance();
    final key = '${repositoryKey}_last_sync';
    final timestamp = prefs.getString(key);
    if (timestamp == null) return null;
    try {
      return DateTime.parse(timestamp);
    } catch (e) {
      return null;
    }
  }

  /// Update the last sync timestamp in SharedPreferences
  Future<void> setLastSyncTime(DateTime time) async {
    final prefs = await SharedPreferences.getInstance();
    final key = '${repositoryKey}_last_sync';
    await prefs.setString(key, time.toIso8601String());
  }

  /// Sync this repository's data from Supabase
  /// MUST implement: 1. Query Supabase, 2. Save to Drift, 3. Call setLastSyncTime()
  Future<SyncResult> syncFromRemote(String userId);

  /// Upload dirty records (needs_upload = true) to Supabase
  /// MUST implement: 1. Query Drift for dirty records, 2. Upload to Supabase, 3. Clear dirty flags
  Future<UploadResult> uploadDirtyRecords(String userId);
}
```

### SyncResult & UploadResult Classes

```dart
/// Result of a sync operation
class SyncResult {
  final bool success;
  final int count;
  final String? error;

  factory SyncResult.successful(int count) => SyncResult(success: true, count: count);
  factory SyncResult.failed(String error) => SyncResult(success: false, count: 0, error: error);
}

/// Result of an upload operation
class UploadResult {
  final bool success;
  final int count;
  final String? error;

  factory UploadResult.successful(int count) => UploadResult(success: true, count: count);
  factory UploadResult.nothingToUpload() => const UploadResult(success: true, count: 0);
  factory UploadResult.failed(String error) => UploadResult(success: false, count: 0, error: error);
}
```

---

## SyncCoordinator - Central Orchestrator

**File**: `lib/shared/services/sync/sync_coordinator.dart`

The SyncCoordinator manages all sync operations with dependency resolution and staleness tracking.

### Dependency Graph (Key Reference)

```dart
static const Map<String, List<String>> _dependencies = {
  'users': [],
  'foods': [],
  'carb_loading_foods': [],
  'activities': ['users'],
  'events': ['users'],
  'food_preferences': ['users', 'foods'],
  'user_foods': ['users'],
  'coaches': ['users'],
  'coach_athlete_relationships': ['coaches', 'users'],
  'carb_loading_plans': ['users', 'events'],
  'carb_loading_days': ['carb_loading_plans'],
  'carb_loading_day_meals': ['carb_loading_days', 'carb_loading_foods'],
  'coach_messages': ['coach_athlete_relationships'],
};
```

**Key points**:
- When you create a new repository, add its key to this map with its dependencies
- Dependencies are synced BEFORE the repository itself
- Example: 'food_preferences' depends on both 'users' and 'foods', so those sync first

### Main Sync Methods

#### 1. ensureSynced() - NEW Repository-Level Sync Pattern

```dart
Future<void> ensureSynced(
  String repoKey,
  String userId, {
  SyncableRepository? repository,
}) async {
  // Flow:
  // 1. Check if already syncing (prevent infinite loops)
  // 2. Check rate limiting (prevent retry spam after failures)
  // 3. Check staleness (is data >1h old?)
  // 4. If fresh, return immediately (no-op)
  // 5. If stale, sync dependencies FIRST (recursive)
  // 6. Upload dirty records (protect user data)
  // 7. Sync fresh data from Supabase
  // 8. Update timestamp and clear failure tracking
}
```

**Usage in Controllers** (MANDATORY PATTERN):

```dart
@riverpod
class ActivitiesController extends _$ActivitiesController {
  @override
  FutureOr<List<Activity>> build() async {
    final userId = await ref.read(userIdProvider.future);

    // NEW SYNC: Ensure activities (and dependencies) are synced
    try {
      await ref.read(syncCoordinatorProvider.notifier).ensureSynced(
        'activities',
        userId,
        repository: ref.read(activitiesRepositoryProvider),
      );
    } catch (e, stackTrace) {
      _logger.error('Sync failed', context: 'ACTIVITIES_CONTROLLER', error: e);
      // Don't rethrow - continue with cached data
    }

    // Load from local database (now guaranteed to be synced or cached)
    return _service.getAllActivities(userId);
  }
}
```

#### 2. sync() - Legacy Full Sync Method

```dart
Future<bool> sync({
  required String userId,
  SyncTrigger trigger = SyncTrigger.manual,
  bool skipInvalidation = false,
}) async {
  // Prevents concurrent syncs
  // Checks network connectivity
  // Calls DataSyncService.syncAllData()
  // Invalidates all providers on success
}
```

Used for full refresh operations (less common in Phase 5+).

#### 3. forceSyncRepository() - Force Refresh Single Repository

```dart
Future<void> forceSyncRepository(
  String repoKey,
  String userId, {
  required SyncableRepository repository,
}) async {
  // Bypasses staleness check - always syncs
  // Used for pull-to-refresh when user explicitly wants fresh data
  // Syncs dependencies first, then uploads dirty records, then this repo
}
```

---

## Complete Repository Implementation Example

### ActivitiesRepository (with SyncableRepository)

**File**: `lib/features/activities/data/activities_repository.dart`

```dart
import 'package:drift/drift.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../shared/database/app_database.dart';
import '../../../shared/database/database_provider.dart';
import '../../../shared/services/logging_service.dart';
import '../../../shared/data/syncable_repository.dart';

part 'activities_repository.g.dart';

@riverpod
ActivitiesRepository activitiesRepository(Ref ref) {
  return ActivitiesRepository(
    supabase: Supabase.instance.client,
    database: ref.read(appDatabaseProvider),
    logger: ref.read(appLoggerProvider),
    immediateRemoteWriteService: ref.read(immediateRemoteWriteServiceProvider),
  );
}

/// Repository for managing activities
/// Implements SyncableRepository for new sync architecture
class ActivitiesRepository with SyncableRepository {
  ActivitiesRepository({
    required SupabaseClient supabase,
    required AppDatabase database,
    required AppLogger logger,
    required ImmediateRemoteWriteService immediateRemoteWriteService,
  }) : _supabase = supabase,
       _database = database,
       _logger = logger,
       _immediateRemoteWriteService = immediateRemoteWriteService,
       _mapper = ActivityMapper(logger: logger);

  final SupabaseClient _supabase;
  final AppDatabase _database;
  final AppLogger _logger;
  final ImmediateRemoteWriteService _immediateRemoteWriteService;
  final ActivityMapper _mapper;

  // ========================================================================
  // SyncableRepository Implementation
  // ========================================================================

  @override
  String get repositoryKey => 'activities';

  @override
  List<String> get dependencies => ['users'];

  /// Sync activities from Supabase to local Drift database
  @override
  Future<SyncResult> syncFromRemote(String userId) async {
    try {
      _logger.info(
        'Syncing activities from Supabase',
        context: 'ACTIVITIES_REPOSITORY',
        data: {'userId': userId},
      );

      // Direct Supabase query (no edge function)
      final response = await _supabase
          .from('activities')
          .select('*')
          .eq('user_id', userId)
          .isFilter('deleted_at', null)
          .order('created_at', ascending: false);

      final syncedCount = await _upsertRemoteActivitiesPreservingDirty(
        response as List<dynamic>,
      );

      // CRITICAL: Update last sync timestamp
      await setLastSyncTime(DateTime.now());

      _logger.info(
        'Activities synced successfully',
        context: 'ACTIVITIES_REPOSITORY',
        data: {'userId': userId, 'count': syncedCount},
      );

      return SyncResult.successful(syncedCount);
    } catch (e, stackTrace) {
      _logger.error(
        'Failed to sync activities from remote',
        context: 'ACTIVITIES_REPOSITORY',
        error: e,
        stackTrace: stackTrace,
        data: {'userId': userId},
      );
      return SyncResult.failed(e.toString());
    }
  }

  /// Upsert remote activities while preserving dirty local records
  Future<int> _upsertRemoteActivitiesPreservingDirty(
    List<dynamic> rawActivities,
  ) async {
    // Map remote activities by ID
    final remoteById = <String, Map<String, dynamic>>{};
    for (final item in rawActivities) {
      if (item is! Map) continue;
      final mapped = Map<String, dynamic>.from(item);
      final id = mapped['id']?.toString();
      if (id == null || id.isEmpty) continue;
      remoteById[id] = mapped;
    }

    if (remoteById.isEmpty) return 0;

    // Find dirty records that shouldn't be overwritten
    final remoteIds = remoteById.keys.toList(growable: false);
    final dirtyRows = await (_database.select(_database.activitiesTable)
          ..where((tbl) => tbl.id.isIn(remoteIds) & tbl.needsUpload.equals(true)))
        .get();
    final dirtyIds = dirtyRows.map((row) => row.id).toSet();

    // Upsert in batch, skipping dirty records
    var upsertedCount = 0;
    await _database.batch((batch) {
      for (final entry in remoteById.entries) {
        if (dirtyIds.contains(entry.key)) continue; // Skip dirty records

        final activity = _mapper.fromJson(entry.value);
        batch.insert(
          _database.activitiesTable,
          _mapper.toCompanion(activity),
          mode: InsertMode.insertOrReplace,
        );
        upsertedCount++;
      }
    });

    return upsertedCount;
  }

  /// Upload dirty activities to Supabase
  @override
  Future<UploadResult> uploadDirtyRecords(String userId) async {
    try {
      // Query Drift for records with needsUpload = true
      final dirtyRecords = await (_database.select(_database.activitiesTable)
            ..where((t) =>
                t.userId.lower().equals(userId.toLowerCase()) &
                t.needsUpload.equals(true)))
          .get();

      if (dirtyRecords.isEmpty) {
        return UploadResult.nothingToUpload();
      }

      _logger.info(
        'Uploading dirty activities',
        context: 'ACTIVITIES_REPOSITORY',
        data: {'userId': userId, 'count': dirtyRecords.length},
      );

      // Handle brick activities specially (parent before children)
      final parentBricks = <Activity>[];
      final subActivities = <Activity>[];
      final regularActivities = <Activity>[];

      for (final record in dirtyRecords) {
        if (record.brickId != null) {
          subActivities.add(record);
        } else if (record.activityType == 'brick') {
          parentBricks.add(record);
        } else {
          regularActivities.add(record);
        }
      }

      final uploadedIds = <String>{};
      final failedIds = <String>{};

      // Upload in order: parent bricks → regular → sub-activities
      final batch1 = [...parentBricks, ...regularActivities];
      if (batch1.isNotEmpty) {
        final batchResult = await _uploadBatchWithRecordRetry(batch1);
        uploadedIds.addAll(batchResult.uploadedIds);
        failedIds.addAll(batchResult.failedIds);
      }

      if (subActivities.isNotEmpty) {
        final subBatchResult = await _uploadBatchWithRecordRetry(subActivities);
        uploadedIds.addAll(subBatchResult.uploadedIds);
        failedIds.addAll(subBatchResult.failedIds);
      }

      // Clear dirty flags for successful uploads
      if (uploadedIds.isNotEmpty) {
        await _database.batch((batch) {
          for (final activityId in uploadedIds) {
            batch.update(
              _database.activitiesTable,
              const ActivitiesTableCompanion(needsUpload: Value(false)),
              where: (t) => t.id.equals(activityId),
            );
          }
        });
      }

      if (failedIds.isNotEmpty) {
        return UploadResult.failed(
          'Uploaded ${uploadedIds.length}/${dirtyRecords.length}; '
          '${failedIds.length} failed and remain dirty for retry.',
        );
      }

      _logger.info(
        'Dirty activities uploaded successfully',
        context: 'ACTIVITIES_REPOSITORY',
        data: {'userId': userId, 'count': uploadedIds.length},
      );

      return UploadResult.successful(uploadedIds.length);
    } catch (e, stackTrace) {
      _logger.error(
        'Failed to upload dirty activities',
        context: 'ACTIVITIES_REPOSITORY',
        error: e,
        stackTrace: stackTrace,
        data: {'userId': userId},
      );
      return UploadResult.failed(e.toString());
    }
  }

  // ========================================================================
  // CRUD Methods (Offline-First Pattern)
  // ========================================================================

  /// Create activity (write to Drift first, then upload)
  Future<String> createActivity({
    required String userId,
    required String title,
    // ... other parameters
  }) async {
    // OFFLINE-FIRST: Save to Drift IMMEDIATELY with needsUpload = true
    final activity = Activity(
      id: const Uuid().v4(),
      userId: userId,
      title: title,
      needsUpload: true, // Mark for sync
      localUpdatedAt: DateTime.now(),
      // ... other fields
    );

    // Save to Drift
    final generatedId = await _saveToDrift(activity);
    var createdActivity = activity.copyWith(id: generatedId);

    // ATTEMPT IMMEDIATE UPLOAD (non-blocking)
    unawaited(
      _immediateRemoteWriteService.run(
        repository: repositoryKey,
        operation: 'create',
        recordId: createdActivity.id,
        method: 'INSERT',
        write: () => _uploadActivityToSupabase(createdActivity),
      ),
    );

    return createdActivity.id;
  }

  // ========================================================================
  // Helper Methods
  // ========================================================================

  Future<void> _saveToDrift(Activity activity) async {
    // Implementation
  }

  Future<void> _uploadActivityToSupabase(Activity activity) async {
    // Implementation
  }
}
```

---

## EventsRepository - Simpler Implementation

**File**: `lib/features/events/data/events_repository.dart`

EventsRepository shows a simpler pattern where `SyncableRepository` is implemented directly (not with mixin):

```dart
/// Repository for managing events
class EventsRepository implements SyncableRepository {
  const EventsRepository({
    required SupabaseClient supabase,
    required AppDatabase database,
    required AppLogger logger,
  }) : _supabase = supabase,
       _database = database,
       _logger = logger;

  final SupabaseClient _supabase;
  final AppDatabase _database;
  final AppLogger _logger;

  @override
  String get repositoryKey => 'events';

  @override
  List<String> get dependencies => ['users'];

  /// Optional: Override staleness duration for different cache periods
  @override
  Future<bool> isStale() async {
    final lastSync = await getLastSyncTime();
    if (lastSync == null) return true;
    const staleDuration = Duration(hours: 24); // Custom duration
    return DateTime.now().difference(lastSync) > staleDuration;
  }

  @override
  Future<SyncResult> syncFromRemote(String userId) async {
    try {
      final response = await _supabase
          .from('events')
          .select('*')
          .eq('user_id', userId)
          .order('created_at', ascending: false);

      final syncedCount = await _upsertRemoteEventsPreservingDirty(response as List<dynamic>);
      await setLastSyncTime(DateTime.now());

      return SyncResult.successful(syncedCount);
    } catch (e, stackTrace) {
      _logger.error('Failed to sync events', error: e, stackTrace: stackTrace);
      return SyncResult.failed(e.toString());
    }
  }

  @override
  Future<UploadResult> uploadDirtyRecords(String userId) async {
    try {
      final dirtyRecords = await (_database.select(_database.eventsTable)
            ..where((t) => t.needsUpload.equals(true) & t.userId.equals(userId)))
          .get();

      if (dirtyRecords.isEmpty) {
        return UploadResult.nothingToUpload();
      }

      // Map to JSON and upload
      final eventsToUpload = dirtyRecords.map((record) {
        return _toSupabaseJson(record);
      }).toList();

      await _supabase.from('events').upsert(eventsToUpload);

      // Clear dirty flags
      await _database.batch((batch) {
        for (final record in dirtyRecords) {
          batch.update(
            _database.eventsTable,
            const EventsTableCompanion(needsUpload: Value(false)),
            where: (t) => t.id.equals(record.id),
          );
        }
      });

      return UploadResult.successful(dirtyRecords.length);
    } catch (e, stackTrace) {
      _logger.error('Failed to upload dirty events', error: e);
      return UploadResult.failed(e.toString());
    }
  }

  // Helper methods...
  Future<int> _upsertRemoteEventsPreservingDirty(List<dynamic> remoteEvents) async {
    // Implementation similar to activities
  }

  Map<String, dynamic> _toSupabaseJson(Event record) {
    // Convert Drift record to JSON for Supabase upsert
  }
}
```

---

## Drift Table Example

**File**: `lib/shared/database/tables/events_table.dart`

All tables that need sync must have:
- `id` (UUID primary key)
- `userId` (foreign key to users)
- `needsUpload` (boolean for dirty tracking)
- `localUpdatedAt` (timestamp for sorting)

```dart
@DataClassName('Event')
class EventsTable extends Table {
  TextColumn get id => text().clientDefault(() => const Uuid().v4())();
  TextColumn get userId => text().named('user_id')();

  TextColumn get eventType => text().named('event_type')();
  TextColumn get eventSubtype => text().nullable().named('event_subtype')();
  TextColumn get eventName => text().nullable().named('event_name')();
  DateTimeColumn get eventDate => dateTime().nullable().named('event_date')();

  // Carb loading
  BoolColumn get hasCarbLoading => boolean()
      .withDefault(const Constant(false))
      .named('has_carb_loading')();
  IntColumn get carbLoadingDays => integer().nullable().named('carb_loading_days')();

  // Metadata
  DateTimeColumn get createdAt => dateTime().named('created_at')();
  DateTimeColumn get updatedAt => dateTime().named('updated_at')();

  // SYNC TRACKING (MANDATORY)
  BoolColumn get needsUpload => boolean().nullable().named('needs_upload')();
  DateTimeColumn get localUpdatedAt => dateTime().nullable().named('local_updated_at')();

  @override
  Set<Column> get primaryKey => {id};

  @override
  String get tableName => 'events';
}
```

---

## How to Add a New Repository to Sync Architecture

### Step 1: Create Repository with SyncableRepository

```dart
class MyNewRepository with SyncableRepository {
  @override
  String get repositoryKey => 'my_new_repo';

  @override
  List<String> get dependencies => ['users']; // If needed

  @override
  Future<SyncResult> syncFromRemote(String userId) async {
    // Implement sync logic
  }

  @override
  Future<UploadResult> uploadDirtyRecords(String userId) async {
    // Implement upload logic
  }
}
```

### Step 2: Add to SyncCoordinator Dependency Graph

**File**: `lib/shared/services/sync/sync_coordinator.dart`

```dart
static const Map<String, List<String>> _dependencies = {
  // ... existing entries ...
  'my_new_repo': ['users'], // Add this line
};
```

### Step 3: Use in Controllers

```dart
@riverpod
class MyController extends _$MyController {
  @override
  FutureOr<MyData> build() async {
    final userId = await ref.read(userIdProvider.future);

    // Sync before loading
    await ref.read(syncCoordinatorProvider.notifier).ensureSynced(
      'my_new_repo',
      userId,
      repository: ref.read(myNewRepositoryProvider),
    );

    // Load data
    return ref.read(myNewRepositoryProvider).getData(userId);
  }
}
```

### Step 4: Create Riverpod Provider

```dart
@riverpod
MyNewRepository myNewRepository(Ref ref) {
  return MyNewRepository(
    supabase: Supabase.instance.client,
    database: ref.read(appDatabaseProvider),
    logger: ref.read(appLoggerProvider),
  );
}
```

---

## Critical Implementation Details

### 1. Offline-First Pattern

Always write to Drift first with `needsUpload = true`:

```dart
// Create locally
final activity = Activity(
  id: generateUuid(),
  title: 'Morning Run',
  needsUpload: true, // Mark for sync
);

await _saveToDrift(activity);

// Attempt background upload
unawaited(_uploadToSupabase(activity));
```

### 2. Preserve Dirty Records During Sync

When syncing remote data, never overwrite records marked with `needsUpload = true`:

```dart
final dirtyRows = await (_database.select(_database.activitiesTable)
      ..where((tbl) => tbl.id.isIn(remoteIds) & tbl.needsUpload.equals(true)))
    .get();
final dirtyIds = dirtyRows.map((row) => row.id).toSet();

// Skip dirty records in upsert
for (final entry in remoteById.entries) {
  if (dirtyIds.contains(entry.key)) continue; // Skip!
  // ... upsert
}
```

### 3. Dependency Tracking

Always declare dependencies:

```dart
@override
List<String> get dependencies => ['users', 'foods']; // Dependencies sync first
```

### 4. Timestamp Management

Always update last sync timestamp AFTER successful sync:

```dart
@override
Future<SyncResult> syncFromRemote(String userId) async {
  // ... do sync ...
  await setLastSyncTime(DateTime.now()); // CRITICAL!
  return SyncResult.successful(count);
}
```

---

## Testing Patterns

See test files for examples:
- `test/new_sync/sync_coordinator_v2_test.dart`
- `test/new_sync/user_repository_sync_test.dart`
- `test/new_sync/edge_cases/dependency_chain_test.dart`

Key test scenarios:
1. Staleness boundary (exactly 1h)
2. Concurrent sync (prevents infinite loops)
3. Dependency chains (users syncs before activities)
4. Network failure (graceful degradation)
5. Dirty record preservation (local changes not overwritten)

---

## Key Points Summary

✅ **DO**:
- Implement `SyncableRepository` mixin for all data repositories
- Add repository key to SyncCoordinator dependency graph
- Write to Drift first with `needsUpload = true`
- Update last sync timestamp after successful sync
- Preserve dirty records during remote sync
- Use `ensureSynced()` in all controllers
- Declare all dependencies correctly
- Log sync operations at info/warning/error levels

❌ **DON'T**:
- Skip SyncableRepository implementation
- Hardcode sync intervals
- Overwrite dirty local records
- Forget to update last sync timestamp
- Sync without checking dependencies first
- Use direct Supabase queries in controllers
- Throw exceptions in sync methods (log and return SyncResult.failed())
