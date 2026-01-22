# Data Synchronization Architecture

**Status**: Active (as of 2026-01-18)
**Branch**: `new_sync`
**Author**: Claude Code + Lee Martin

---

## Table of Contents

1. [Overview](#overview)
2. [Architecture Principles](#architecture-principles)
3. [Core Components](#core-components)
4. [SyncableRepository Pattern](#syncablerepository-pattern)
5. [SyncCoordinator Service](#synccoordinator-service)
6. [Controller Integration](#controller-integration)
7. [Dependency Graph](#dependency-graph)
8. [Dirty Record Protection](#dirty-record-protection)
9. [Schema Migration Strategy](#schema-migration-strategy)
10. [Version Check and Force Upgrade](#version-check-and-force-upgrade)
11. [Troubleshooting Guide](#troubleshooting-guide)
12. [Migration from Old Sync](#migration-from-old-sync)

---

## Overview

Mealvana Endurance uses a **repository-level, on-demand sync architecture** that replaces the previous monolithic "sync all at startup" approach. This design provides:

- **Lazy Loading**: Data is only synced when needed (when a feature accesses it)
- **Automatic Dependency Resolution**: Dependencies are synced first automatically
- **Staleness Tracking**: Each repository independently tracks when it was last synced
- **Dirty Record Protection**: Local changes are backed up to JSON if upload fails
- **Simplified Migrations**: Schema changes trigger delete & resync (no complex step-by-step migrations)

### Key Differences from Old Sync

| Aspect | Old Sync | New Sync |
|--------|----------|----------|
| **Trigger** | Manual (OAuth or pull-to-refresh) | Automatic (on controller build) |
| **Granularity** | All-or-nothing | Per-repository |
| **Dependencies** | Implicit (edge function ordering) | Explicit (dependency graph) |
| **Staleness** | No tracking | 1-hour threshold per repo |
| **Dirty Records** | Upload or lose | Backup to JSON on failure |
| **Schema Migrations** | 500+ lines of step-by-step code | Delete & resync |
| **Edge Functions** | Required for sync | Optional (direct Supabase queries) |

---

## Architecture Principles

### 1. Local-First Design
- All reads from local Drift SQLite database
- Writes to local database first (with `needs_upload = true` flag)
- Sync happens in background

### 2. On-Demand Sync
- Controllers call `ensureSynced(repoKey, userId)` in their `build()` method
- Sync only happens if data is stale (>1 hour)
- Fresh data returns immediately (no network call)

### 3. Dependency Awareness
- Each repository declares its dependencies
- SyncCoordinator resolves dependencies recursively
- Parent data always synced before child data

### 4. Best-Effort Upload
- Dirty records uploaded before syncing fresh data
- Upload failures logged but don't block sync
- Failed uploads backed up to JSON for recovery

### 5. Simplified Schema Evolution
- Schema version mismatches trigger delete & resync
- No complex migration code to maintain
- Clean slate with every schema change

---

## Core Components

### 1. SyncableRepository Mixin
Abstract interface that all syncable repositories implement.

**Location**: `lib/shared/data/syncable_repository.dart`

### 2. SyncCoordinator Service
Central orchestrator managing sync operations and dependency graph.

**Location**: `lib/shared/services/sync/sync_coordinator.dart`

### 3. SyncResult and UploadResult Models
Type-safe result objects for sync operations.

**Location**: `lib/shared/models/sync_result.dart`

### 4. DirtyRecordBackupService
Handles backing up failed uploads to JSON.

**Location**: `lib/shared/services/dirty_record_backup_service.dart`

### 5. VersionCheckService
Validates app version and schema version on startup.

**Location**: `lib/shared/services/version_check_service.dart`

---

## SyncableRepository Pattern

### Interface Definition

```dart
abstract class SyncableRepository {
  /// Repository identifier for staleness tracking
  /// Used as key in SharedPreferences: '{repositoryKey}_last_sync'
  String get repositoryKey;

  /// Dependencies that must be synced first
  /// Example: activities → ['users']
  List<String> get dependencies => [];

  /// Check if data is stale (>1 hour since last sync)
  Future<bool> isStale();

  /// Sync this repository's data from Supabase
  /// Returns count of records synced
  Future<SyncResult> syncFromRemote(String userId);

  /// Upload dirty records for this repository
  /// Returns count of records uploaded
  Future<UploadResult> uploadDirtyRecords(String userId);

  /// Get last sync timestamp from SharedPreferences
  Future<DateTime?> getLastSyncTime();

  /// Update last sync timestamp
  Future<void> setLastSyncTime(DateTime time);
}
```

### Implementation Example: ActivitiesRepository

```dart
class ActivitiesRepository with SyncableRepository {
  final SupabaseClient _supabase;
  final AppDatabase _db;
  final SharedPreferences _prefs;

  ActivitiesRepository(this._supabase, this._db, this._prefs);

  @override
  String get repositoryKey => 'activities';

  @override
  List<String> get dependencies => ['users'];

  @override
  Future<bool> isStale() async {
    final lastSync = await getLastSyncTime();
    if (lastSync == null) return true;

    const staleDuration = Duration(hours: 1);
    return DateTime.now().difference(lastSync) > staleDuration;
  }

  @override
  Future<SyncResult> syncFromRemote(String userId) async {
    try {
      // Direct Supabase query (no edge function needed)
      final response = await _supabase
          .from('activities')
          .select('*')
          .eq('user_id', userId)
          .is_('deleted_at', null)
          .order('created_at', ascending: false);

      // Save to Drift in batch
      await _db.batch((batch) {
        for (final activity in response) {
          batch.insertOrReplace(
            _db.activitiesTable,
            ActivitiesTableCompanion.insert(
              id: activity['id'],
              userId: activity['user_id'],
              name: activity['name'],
              distance: activity['distance'],
              // ... map all fields
            ),
          );
        }
      });

      // Update last sync timestamp
      await setLastSyncTime(DateTime.now());

      return SyncResult.success(count: response.length);
    } catch (e, stackTrace) {
      return SyncResult.failure(error: e.toString(), stackTrace: stackTrace);
    }
  }

  @override
  Future<UploadResult> uploadDirtyRecords(String userId) async {
    try {
      // Find dirty records
      final dirtyRecords = await (_db.select(_db.activitiesTable)
            ..where((t) => t.needsUpload.equals(true)))
          .get();

      if (dirtyRecords.isEmpty) {
        return UploadResult.nothingToUpload();
      }

      // Upload to Supabase (upsert)
      await _supabase
          .from('activities')
          .upsert(dirtyRecords.map((r) => r.toJson()).toList());

      // Clear dirty flags
      await _db.batch((batch) {
        for (final record in dirtyRecords) {
          batch.update(
            _db.activitiesTable,
            ActivitiesTableCompanion(needsUpload: Value(false)),
            where: (t) => t.id.equals(record.id),
          );
        }
      });

      return UploadResult.success(count: dirtyRecords.length);
    } catch (e, stackTrace) {
      // On failure, backup service will save to JSON
      return UploadResult.failure(
        error: e.toString(),
        stackTrace: stackTrace,
        recordCount: dirtyRecords.length,
      );
    }
  }

  @override
  Future<DateTime?> getLastSyncTime() async {
    final timestamp = _prefs.getInt('${repositoryKey}_last_sync');
    if (timestamp == null) return null;
    return DateTime.fromMillisecondsSinceEpoch(timestamp);
  }

  @override
  Future<void> setLastSyncTime(DateTime time) async {
    await _prefs.setInt(
      '${repositoryKey}_last_sync',
      time.millisecondsSinceEpoch,
    );
  }
}
```

### Multi-Table Repository Example: CarbLoadingRepository

Some repositories manage multiple related tables that must be synced together:

```dart
class CarbLoadingRepository with SyncableRepository {
  @override
  String get repositoryKey => 'carb_loading_plans';

  @override
  List<String> get dependencies => ['users', 'events'];

  @override
  Future<SyncResult> syncFromRemote(String userId) async {
    // Sync both plans AND days in a single transaction
    await _db.transaction(() async {
      // 1. Sync carb_loading_plans
      final plans = await _supabase
          .from('carb_loading_plans')
          .select('*')
          .eq('user_id', userId);

      await _db.batch((batch) {
        for (final plan in plans) {
          batch.insertOrReplace(_db.carbLoadingPlansTable, plan);
        }
      });

      // 2. Sync carb_loading_days for all plans
      final planIds = plans.map((p) => p['id']).toList();
      final days = await _supabase
          .from('carb_loading_days')
          .select('*')
          .in_('plan_id', planIds);

      await _db.batch((batch) {
        for (final day in days) {
          batch.insertOrReplace(_db.carbLoadingDaysTable, day);
        }
      });
    });

    await setLastSyncTime(DateTime.now());
    return SyncResult.success(count: plans.length);
  }
}
```

---

## SyncCoordinator Service

The SyncCoordinator is the brain of the sync system. It knows the dependency graph and orchestrates sync operations.

### Key Responsibilities

1. **Dependency Resolution**: Recursively sync dependencies before syncing a repository
2. **Loop Prevention**: Track currently syncing repositories to prevent infinite loops
3. **Staleness Checking**: Only sync if data is actually stale
4. **Error Handling**: Continue on errors (best-effort sync)

### Dependency Graph

```dart
class SyncCoordinatorV2 {
  /// Static dependency graph
  /// Key = repository key, Value = list of dependencies
  static const Map<String, List<String>> _dependencies = {
    // Level 0: No dependencies
    'users': [],
    'foods': [],
    'carb_loading_foods': [],
    'app_content': [],

    // Level 1: Depends on users
    'activities': ['users'],
    'events': ['users'],
    'food_preferences': ['users', 'foods'],
    'user_foods': ['users'],
    'coaches': ['users'],
    'feedback': ['users'],

    // Level 2: Depends on Level 1
    'coach_athlete_relationships': ['coaches', 'users'],
    'carb_loading_plans': ['users', 'events'],

    // Level 3: Depends on Level 2
    'carb_loading_days': ['carb_loading_plans'],
    'coach_messages': ['coach_athlete_relationships'],

    // Level 4: Depends on Level 3
    'carb_loading_day_meals': ['carb_loading_days', 'carb_loading_foods'],
  };

  /// Track what's currently being synced to prevent infinite loops
  final Set<String> _syncingNow = {};

  /// Main entry point - ensures a repository is synced
  Future<void> ensureSynced(String repoKey, String userId) async {
    // 1. Prevent infinite loops
    if (_syncingNow.contains(repoKey)) {
      return;
    }

    // 2. Get repository instance
    final repository = _getRepository(repoKey);

    // 3. Check if data is fresh
    if (!await repository.isStale()) {
      return; // Data is fresh, no sync needed
    }

    // 4. Mark as syncing
    _syncingNow.add(repoKey);

    try {
      // 5. Sync dependencies FIRST (recursive)
      final deps = _dependencies[repoKey] ?? [];
      for (final dep in deps) {
        await ensureSynced(dep, userId);
      }

      // 6. Upload dirty records (with backup on failure)
      final uploadResult = await repository.uploadDirtyRecords(userId);
      if (uploadResult.isFailure) {
        // Backup dirty records to JSON
        await _backupService.backupDirtyRecords(
          repoKey,
          uploadResult.records,
          uploadResult.error,
        );
      }

      // 7. Sync this repository
      final syncResult = await repository.syncFromRemote(userId);
      if (syncResult.isFailure) {
        _logger.error('Sync failed for $repoKey: ${syncResult.error}');
        // Continue anyway (best-effort sync)
      }

      // 8. Update timestamp (even on failure - prevents retry loops)
      await repository.setLastSyncTime(DateTime.now());
    } finally {
      _syncingNow.remove(repoKey);
    }
  }

  /// Get repository instance by key
  SyncableRepository _getRepository(String repoKey) {
    switch (repoKey) {
      case 'users':
        return ref.read(userRepositoryProvider);
      case 'activities':
        return ref.read(activitiesRepositoryProvider);
      case 'events':
        return ref.read(eventsRepositoryProvider);
      // ... all other repositories
      default:
        throw UnimplementedError('Unknown repository: $repoKey');
    }
  }
}
```

### Provider Definition

```dart
@riverpod
SyncCoordinatorV2 syncCoordinator(SyncCoordinatorRef ref) {
  return SyncCoordinatorV2(ref);
}
```

---

## Controller Integration

Controllers use `ensureSynced` to guarantee fresh data before returning to the UI.

### Pattern: Call ensureSynced in build()

```dart
@riverpod
class ActivitiesController extends _$ActivitiesController {
  SyncCoordinator get _syncCoordinator => ref.read(syncCoordinatorProvider);
  ActivitiesRepository get _repository => ref.read(activitiesRepositoryProvider);

  @override
  Future<List<Activity>> build(String userId) async {
    // CRITICAL: Ensure data is fresh before returning
    await _syncCoordinator.ensureSynced('activities', userId);

    // Return data from local Drift database
    return _repository.getActivities(userId);
  }

  // Mutation methods still write to local DB first
  Future<void> createActivity(Activity activity) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      // Write to local DB with needs_upload = true
      await _repository.createActivity(activity);

      // Re-fetch from local DB
      return _repository.getActivities(userId);
    });
  }
}
```

### What Happens When Widget Loads

```
User opens ActivitiesScreen
    ↓
Widget: ref.watch(activitiesControllerProvider(userId))
    ↓
Controller.build(userId) is called
    ↓
Call: _syncCoordinator.ensureSynced('activities', userId)
    ↓
SyncCoordinator checks: Is 'activities' stale?
    ↓
├── No (synced <1h ago)
│   └── Return immediately (no network call)
│
└── Yes (synced >1h ago OR never synced)
    ↓
    Check dependencies: activities → ['users']
    ↓
    Recursively: ensureSynced('users', userId)
    ↓
    Upload dirty user records (if any)
    ↓
    Sync users from Supabase → Save to Drift
    ↓
    Update 'users_last_sync' timestamp
    ↓
    Now sync activities:
    ↓
    Upload dirty activity records (if any)
    ↓
    Sync activities from Supabase → Save to Drift
    ↓
    Update 'activities_last_sync' timestamp
    ↓
Return to controller.build()
    ↓
Query local Drift: _repository.getActivities(userId)
    ↓
Return data to widget
```

### AsyncValue Pattern

Controllers naturally show loading/error states via AsyncValue:

```dart
// In widget
@override
Widget build(BuildContext context, WidgetRef ref) {
  final activitiesAsync = ref.watch(activitiesControllerProvider(userId));

  return activitiesAsync.when(
    data: (activities) => ListView.builder(
      itemCount: activities.length,
      itemBuilder: (context, index) => ActivityTile(activities[index]),
    ),
    loading: () => const Center(child: CircularProgressIndicator()),
    error: (error, stack) => ErrorWidget(error: error),
  );
}
```

---

## Dependency Graph

Visual representation of data dependencies:

```
                    ┌─────────────┐
                    │   users     │ (Level 0)
                    └──────┬──────┘
                           │
    ┌──────────────────────┼──────────────────────┐
    │          │           │           │          │
    ▼          ▼           ▼           ▼          ▼
┌────────┐ ┌────────┐ ┌────────┐ ┌────────┐ ┌────────┐
│activit.│ │ events │ │food_pr.│ │user_fd.│ │coaches │
└────────┘ └───┬────┘ └────────┘ └────────┘ └───┬────┘
               │                                │
               ▼                                ▼
        ┌──────────────┐              ┌─────────────────┐
        │carb_load_plan│              │coach_ath_relat. │
        └──────┬───────┘              └────────┬────────┘
               │                               │
               ▼                               ▼
        ┌──────────────┐              ┌─────────────────┐
        │carb_load_days│              │ coach_messages  │
        └──────┬───────┘              └─────────────────┘
               │
               ▼
        ┌──────────────┐
        │day_meals     │
        └──────────────┘

Seed Data (Independent):
┌─────────┐  ┌────────────────┐  ┌─────────────┐
│  foods  │  │carb_load_foods │  │ app_content │
└─────────┘  └────────────────┘  └─────────────┘
```

### Why Dependencies Matter

**Problem Without Dependencies:**
If activities are synced before users, you might get foreign key violations:
```sql
INSERT INTO activities (user_id, ...) VALUES ('uuid-123', ...);
-- ERROR: foreign key constraint violation (user 'uuid-123' doesn't exist)
```

**Solution With Dependencies:**
SyncCoordinator automatically syncs users first, then activities.

---

## Dirty Record Protection

### The Problem

User creates an activity offline. App tries to sync, but network fails. Without protection, the local change could be lost if we sync fresh data from Supabase (which doesn't have the new activity).

### The Solution: Three-Layer Protection

1. **Upload First**: Always try to upload dirty records before syncing fresh data
2. **Retry Logic**: Retry uploads 3 times with exponential backoff
3. **JSON Backup**: If all retries fail, save dirty records to JSON file

### Backup Flow

```
Repository.uploadDirtyRecords() fails
    ↓
SyncCoordinator calls:
    _backupService.backupDirtyRecords(repoKey, records, error)
    ↓
DirtyRecordBackupService:
    1. Get app support directory
    2. Create backup file: dirty_records_backup.json
    3. Save records with metadata
    4. Log to Sentry (warning level)
    ↓
Proceed with sync from Supabase (data is backed up)
```

### Backup File Structure

**Location**: `{App Support Directory}/dirty_records_backup.json`

**Contents**:
```json
{
  "backup_created_at": "2026-01-18T10:30:00Z",
  "app_version": "1.12.1",
  "schema_version": 3,
  "user_id": "uuid-123",
  "device_id": "device-456",
  "dirty_records": {
    "activities": [
      {
        "id": "uuid-789",
        "user_id": "uuid-123",
        "name": "Morning Run",
        "distance": 5.2,
        "created_at": "2026-01-18T08:00:00Z",
        "needs_upload": true
      }
    ],
    "events": []
  },
  "upload_errors": [
    {
      "repository": "activities",
      "error": "SocketException: Network unreachable",
      "timestamp": "2026-01-18T10:30:00Z",
      "retry_count": 3
    }
  ]
}
```

### Recovery on Startup

**AppStartupService** checks for backup file during initialization:

```dart
Future<void> checkForDirtyRecordBackup() async {
  final backupFile = await _backupService.getBackupFile();
  if (!await backupFile.exists()) return;

  // Parse backup
  final backup = await _backupService.parseBackup(backupFile);

  // Show recovery dialog
  final choice = await _showRecoveryDialog(
    context,
    recordCount: backup.totalRecords,
    createdAt: backup.createdAt,
  );

  if (choice == RecoveryChoice.uploadNow) {
    // Retry upload
    await _backupService.retryUploadFromBackup(backup);
  }

  // Delete backup file
  await backupFile.delete();
}
```

### Recovery Dialog UI

```dart
class RecoveryDialog extends StatelessWidget {
  final int recordCount;
  final DateTime createdAt;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Unsaved Data Found'),
      content: Text(
        'You have $recordCount unsaved changes from ${_formatDate(createdAt)}. '
        'Would you like to upload them now?',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, RecoveryChoice.discard),
          child: Text('Discard'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, RecoveryChoice.uploadNow),
          child: Text('Upload Now'),
        ),
      ],
    );
  }
}
```

---

## Schema Migration Strategy

### Old Approach: Step-by-Step Migrations

**Problem**: Complex migration code that's hard to maintain and test.

```dart
// Old migration code (500+ lines)
@override
MigrationStrategy get migration {
  return MigrationStrategy(
    onUpgrade: stepByStep(
      from1To2: (m, schema) async {
        await m.addColumn(schema.users, schema.users.preferenceLevel);
        await m.addColumn(schema.users, schema.users.dietaryPreference);
        // ... 50 more lines
      },
      from2To3: (m, schema) async {
        // Another 50 lines
      },
      // ... more migrations
    ),
  );
}
```

### New Approach: Delete and Resync

**Benefits**:
- Simple: No migration code to maintain
- Safe: Dirty records uploaded first (with backup)
- Clean: Fresh database with correct schema
- Fast: Full resync takes <5 seconds for typical user

**How It Works**:

```
App Startup
    ↓
VersionCheckService.checkVersion()
    ↓
Query app_config table:
    SELECT value FROM app_config WHERE key = 'current_schema_version';
    ↓
Compare remote version (e.g., "3") with local (e.g., "2")
    ↓
Version mismatch detected
    ↓
AppStartupService.performSchemaResync()
    ↓
1. Upload all dirty records (with backup on failure)
    ↓
2. Close database connection
    ↓
3. Delete database file
    ↓
4. Invalidate appDatabaseProvider (triggers recreation)
    ↓
5. New database created with current schema
    ↓
6. Full resync from Supabase
    ↓
App continues normally
```

**Implementation**:

```dart
// In VersionCheckService
Future<VersionCheckResult> checkVersion() async {
  final remoteVersion = await _getRemoteSchemaVersion();
  final localVersion = AppDatabase.schemaVersion;

  if (localVersion != remoteVersion) {
    return VersionCheckResult.resyncRequired(
      currentVersion: localVersion,
      requiredVersion: remoteVersion,
    );
  }

  return VersionCheckResult.ok();
}

// In AppStartupService
Future<void> handleVersionCheck(VersionCheckResult result) async {
  if (result is ResyncRequired) {
    await _performSchemaResync(result);
  }
}

Future<void> _performSchemaResync(ResyncRequired result) async {
  // 1. Upload dirty records with backup
  await _syncCoordinator.uploadAllDirtyRecords(userId);

  // 2. Delete database
  final dbFile = await _getDatabaseFile();
  await dbFile.delete();

  // 3. Recreate database (triggers onCreate with new schema)
  ref.invalidate(appDatabaseProvider);

  // 4. Full resync
  await _syncCoordinator.syncAll(userId);
}
```

**When to Use**:
- Schema version changes (column additions, table restructuring)
- NOT for data-only changes (use normal sync)

---

## Version Check and Force Upgrade

### app_config Table

**Purpose**: Server-controlled app configuration

**Schema**:
```sql
CREATE TABLE app_config (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    key TEXT NOT NULL UNIQUE,
    value TEXT NOT NULL,
    description TEXT,
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Initial data
INSERT INTO app_config (key, value, description) VALUES
('min_app_version', '1.12.0', 'Minimum app version allowed to connect'),
('current_schema_version', '3', 'Current Drift schema version'),
('maintenance_mode', 'false', 'Block all operations if true');
```

**RLS Policies**:
```sql
-- Public read access (no auth required)
CREATE POLICY "Anyone can read app_config"
ON app_config FOR SELECT
USING (true);

-- Service role write access only
CREATE POLICY "Service role can update app_config"
ON app_config FOR ALL
USING (auth.role() = 'service_role');
```

### Version Check Flow

```
App Startup (main.dart)
    ↓
Initialize Supabase
    ↓
RootAppWidget → AppStartupWidget
    ↓
appStartupProvider.build()
    ↓
FIRST STEP: VersionCheckService.checkVersion()
    ↓
Query: SELECT value FROM app_config WHERE key IN ('min_app_version', 'current_schema_version')
    ↓
├── min_app_version check
│   ↓
│   Compare current app version (from PackageInfo) vs min_app_version
│   ↓
│   If current < min:
│       └── Return VersionCheckResult.updateRequired(currentVersion, requiredVersion)
│
└── current_schema_version check
    ↓
    Compare local Drift schemaVersion vs current_schema_version
    ↓
    If local != remote:
        └── Return VersionCheckResult.resyncRequired(currentVersion, requiredVersion)
    ↓
    Otherwise:
        └── Return VersionCheckResult.ok()
```

### Force Upgrade Screen

**When Shown**: If `VersionCheckResult.updateRequired`

**UI**:
```dart
class ForceUpgradeScreen extends StatelessWidget {
  final String currentVersion;
  final String requiredVersion;

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false, // Prevent back navigation
      child: Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.system_update, size: 80, color: Colors.orange),
                SizedBox(height: 24),
                Text('Update Required',
                  style: Theme.of(context).textTheme.headlineMedium),
                SizedBox(height: 16),
                Text(
                  'Please update to version $requiredVersion or later to continue using the app.',
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 8),
                Text('Your current version: $currentVersion',
                  style: TextStyle(color: Colors.grey)),
                SizedBox(height: 32),
                ElevatedButton(
                  onPressed: () => _openAppStore(),
                  child: Text('Update Now'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _openAppStore() async {
    if (Platform.isIOS) {
      await launchUrl('https://apps.apple.com/app/mealvana-endurance/id...');
    } else if (Platform.isAndroid) {
      await launchUrl('https://play.google.com/store/apps/details?id=com.mealvana.endurance');
    } else {
      // Web - reload page to get latest version
      window.location.reload();
    }
  }
}
```

**Navigation**:
```dart
// In app_router.dart
GoRoute(
  path: '/force-upgrade',
  name: AppRoute.forceUpgrade.name,
  builder: (context, state) {
    final currentVersion = state.uri.queryParameters['current'] ?? 'Unknown';
    final requiredVersion = state.uri.queryParameters['required'] ?? 'Unknown';
    return ForceUpgradeScreen(
      currentVersion: currentVersion,
      requiredVersion: requiredVersion,
    );
  },
),

// In AppStartupWidget
if (versionCheck is UpdateRequired) {
  context.goNamed(
    AppRoute.forceUpgrade.name,
    queryParameters: {
      'current': versionCheck.currentVersion,
      'required': versionCheck.requiredVersion,
    },
  );
  return const SizedBox.shrink(); // Block further rendering
}
```

---

## Troubleshooting Guide

### Issue: Controller loads stale data

**Symptoms**: UI shows old data even though Supabase has newer data

**Diagnosis**:
```dart
// Check if controller calls ensureSynced
@override
Future<List<Activity>> build(String userId) async {
  // MISSING: await _syncCoordinator.ensureSynced('activities', userId);
  return _repository.getActivities(userId);
}
```

**Solution**: Add `ensureSynced` call in controller's `build()` method

---

### Issue: Infinite sync loop

**Symptoms**: App constantly syncs, never finishes loading

**Diagnosis**:
- Check Sentry logs for repeated sync attempts
- Look for circular dependencies in `_dependencies` map

**Solution**: SyncCoordinator tracks `_syncingNow` set to prevent re-entry

**Verify**:
```dart
// This should prevent infinite loops
if (_syncingNow.contains(repoKey)) {
  return; // Already syncing this repo
}
```

---

### Issue: Lost local changes

**Symptoms**: User creates data offline, it disappears after sync

**Diagnosis**:
- Check if `needs_upload` flag is set on local records
- Check if dirty records were uploaded before sync

**Solution**: All repositories must upload dirty records first

**Verify**:
```dart
// In SyncCoordinator.ensureSynced()
// Step 6: Upload dirty records (with backup on failure)
final uploadResult = await repository.uploadDirtyRecords(userId);
if (uploadResult.isFailure) {
  await _backupService.backupDirtyRecords(...);
}

// Step 7: THEN sync fresh data
await repository.syncFromRemote(userId);
```

---

### Issue: Foreign key violations during sync

**Symptoms**: Sync fails with SQL errors about foreign key constraints

**Diagnosis**:
```
Error: FOREIGN KEY constraint failed
INSERT INTO activities (user_id, ...) VALUES ('uuid-123', ...)
```

**Root Cause**: Child table synced before parent table

**Solution**: Dependencies must be synced first

**Verify Dependency Graph**:
```dart
static const Map<String, List<String>> _dependencies = {
  'activities': ['users'], // ✅ Correct: users synced first
  // NOT: 'users': ['activities'], // ❌ Wrong: circular dependency
};
```

---

### Issue: Sync is very slow

**Symptoms**: Takes >10 seconds to sync a repository

**Diagnosis**:
- Check network latency (use Supabase dashboard)
- Check if syncing unnecessary dependencies
- Check batch insert performance

**Solutions**:
1. **Reduce frequency**: Increase staleness threshold (default is 1 hour)
2. **Optimize queries**: Add indexes on Supabase tables
3. **Batch inserts**: Use `db.batch()` for multiple inserts

**Example Optimization**:
```dart
// BAD: Individual inserts
for (final activity in activities) {
  await db.into(db.activitiesTable).insert(activity);
}

// GOOD: Batch insert
await db.batch((batch) {
  for (final activity in activities) {
    batch.insert(db.activitiesTable, activity);
  }
});
```

---

### Issue: App crashes on startup after schema change

**Symptoms**: App crashes with Drift schema errors

**Diagnosis**:
```
Error: table activities has no column named new_field
```

**Root Cause**: Local database still has old schema

**Solution**: Delete local database and resync

**Manual Recovery**:
```dart
// In AppStartupService
try {
  await ref.read(appDatabaseProvider);
} catch (e) {
  if (e.toString().contains('no such column')) {
    // Delete database
    final dbFile = await _getDatabaseFile();
    await dbFile.delete();

    // Recreate
    ref.invalidate(appDatabaseProvider);
  }
}
```

**Prevention**: Use version check to trigger automatic resync

---

## Migration from Old Sync

### Old Sync Pattern (Deprecated)

```dart
// OLD: Monolithic sync at startup or manual trigger
class SyncCoordinator {
  Future<void> sync(String userId) async {
    // 1. Upload all dirty records via edge function
    await _dataSyncService.uploadAllData(userId);

    // 2. Sync all data via edge function
    final response = await _dataSyncService.syncAllData(userId);

    // 3. Process response and save to Drift
    await _processResponse(response);
  }
}

// Controllers did NOT call sync - it was manual
@riverpod
class ActivitiesController extends _$ActivitiesController {
  @override
  Future<List<Activity>> build() async {
    // NO sync here - user had to manually pull-to-refresh
    return _repository.getActivities(userId);
  }
}
```

### New Sync Pattern

```dart
// NEW: Repository-level sync with ensureSynced
class SyncCoordinator {
  Future<void> ensureSynced(String repoKey, String userId) async {
    // Only sync if stale
    // Handle dependencies automatically
    // Direct Supabase queries (no edge function)
  }
}

// Controllers automatically ensure fresh data
@riverpod
class ActivitiesController extends _$ActivitiesController {
  @override
  Future<List<Activity>> build() async {
    // NEW: Automatically sync if stale
    await _syncCoordinator.ensureSynced('activities', userId);
    return _repository.getActivities(userId);
  }
}
```

### Migration Checklist

For each repository:

- [ ] Implement `SyncableRepository` mixin
- [ ] Define `repositoryKey` and `dependencies`
- [ ] Implement `syncFromRemote()` with direct Supabase query
- [ ] Implement `uploadDirtyRecords()` with retry logic
- [ ] Update controller to call `ensureSynced()` in `build()`
- [ ] Remove manual sync triggers (pull-to-refresh can stay)
- [ ] Test staleness behavior (force timestamp >1h ago)
- [ ] Test dependency resolution (verify parent syncs first)
- [ ] Test dirty record backup (disconnect network, create record, sync)

---

## Summary

The new sync architecture provides:

✅ **On-Demand Sync**: Data synced only when needed
✅ **Automatic Dependencies**: Parents synced before children
✅ **Staleness Tracking**: 1-hour threshold per repository (ensures athletes see coach changes quickly)
✅ **Dirty Record Protection**: JSON backup on upload failure
✅ **Simplified Migrations**: Delete & resync on schema changes
✅ **Force Upgrade**: Server-controlled minimum app version
✅ **Direct Queries**: No edge function dependency
✅ **Best-Effort Sync**: Continue on errors, log warnings

**Result**: Simpler, more maintainable, and more reliable data synchronization.

---

**Document Version**: 1.1
**Last Updated**: 2026-01-21
**Authors**: Claude Code, Lee Martin

### Changelog

- **v1.1 (2026-01-21)**: Changed staleness threshold from 24 hours to 1 hour to ensure athletes see coach changes quickly
- **v1.0 (2026-01-18)**: Initial sync architecture documentation
