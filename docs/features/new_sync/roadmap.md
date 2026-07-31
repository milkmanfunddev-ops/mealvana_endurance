# Sync Architecture Refactor Plan

**Status**: In Progress
**Created**: 2026-01-18
**Author**: Claude Code + Lee Martin
**Branch**: `new_sync`

---

## Executive Summary

This document outlines a comprehensive refactor of Mealvana Endurance's data synchronization architecture. The goal is to move from a monolithic "sync all at startup" approach to a **repository-level, on-demand sync system** with simplified schema migrations.

### Key Decisions Made

| Decision | Choice |
|----------|--------|
| Sync Trigger | 24-hour staleness threshold per repository |
| Timestamp Storage | SharedPreferences |
| Dependency Resolution | Auto-resolve (sync dependencies first) |
| Dirty Records Protection | Push first, save to JSON backup on failure |
| Backup Location | App Support directory |
| Schema Migration | Delete and resync (no step-by-step) |
| Version Check | At startup in appStartupProvider |
| Force Upgrade | app_config table with min_app_version + current_schema_version |
| Edge Functions | Keep for backwards compatibility |
| Sync Orchestration | Central coordinator knows deps, repos contain sync logic |
| Error Handling | Continue & report (best effort) |
| Offline on Version Change | Block app until sync |

---

## Part 1: Current State Analysis

### Current Sync Flow
```
App Startup
    ↓
appStartupProvider
    ↓
[No sync at startup - deliberate]
    ↓
User triggers sync (OAuth sign-in OR pull-to-refresh)
    ↓
SyncCoordinator.sync()
    ↓
DataSyncService.uploadDirtyRecords()  →  upload-all-data edge function
    ↓
DataSyncService.syncAllData()  →  sync-all-data edge function
    ↓
Process response → Save to Drift → Invalidate providers
```

### Current Problems
1. **All-or-nothing sync**: Either sync everything or nothing
2. **Complex Drift migrations**: 500+ lines of step-by-step migration code
3. **No version enforcement**: Old app versions can access new schemas
4. **Edge function dependency**: Requires edge functions for sync
5. **Race conditions risk**: No formal dependency ordering
6. **No dirty record protection**: If sync fails, dirty records may be lost

### Current Repository Structure
- **10+ repositories** with inconsistent sync patterns
- **No base class** for common sync logic
- **Dirty flag pattern** (`needs_upload = true`) used inconsistently
- **No staleness tracking** per repository

### Data Dependency Hierarchy
```
Level 0 (CRITICAL): users
    ↓
Level 1 (Parallel): activities, events, food_preferences, user_foods,
                    carb_loading_user_foods, feedback, integrations, coaches
    ↓
Level 1.5: coach_athlete_relationships (depends on coaches)
    ↓
Level 2: carb_loading_plans (depends on events optionally)
    ↓
Level 3: carb_loading_days (depends on plans)
    ↓
Level 4: carb_loading_day_meals (depends on days + foods)
    ↓
Level 5: coach_messages (depends on relationships)

Seed Data (Independent): foods, carb_loading_foods, app_content
```

---

## Part 2: Proposed Architecture

### 2.1 Version Check at Startup

**New Flow:**
```
main.dart
    ↓
Initialize Supabase (non-recoverable)
    ↓
appStartupProvider
    ↓
VersionCheckService.checkVersion()  ← NEW
    ↓ (query app_config table)
    ├── min_app_version check
    │   └── If current < min → Show ForceUpgradeScreen (BLOCK)
    │
    └── current_schema_version check
        ├── If local == remote → Continue normally
        └── If local != remote → Trigger schema resync
```

**New Supabase Table: `app_config`**
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
('maintenance_mode', 'false', 'Block all sync operations'),
('force_resync_before', '', 'App versions before this must resync');
```

### 2.2 Repository-Level Sync with Staleness

**New Pattern:**
```dart
abstract class SyncableRepository {
  /// Repository identifier for staleness tracking
  String get repositoryKey;

  /// Dependencies that must be synced first
  List<String> get dependencies => [];

  /// Check if data is stale (>24 hours since last sync)
  Future<bool> isStale();

  /// Sync this repository's data from Supabase
  Future<SyncResult> syncFromRemote(String userId);

  /// Upload dirty records for this repository
  Future<UploadResult> uploadDirtyRecords(String userId);

  /// Get last sync timestamp from SharedPreferences
  Future<DateTime?> getLastSyncTime();

  /// Update last sync timestamp
  Future<void> setLastSyncTime(DateTime time);
}
```

**Staleness Check Logic:**
```dart
Future<bool> isStale() async {
  final lastSync = await getLastSyncTime();
  if (lastSync == null) return true;

  const staleDuration = Duration(hours: 24);
  return DateTime.now().difference(lastSync) > staleDuration;
}
```

**SharedPreferences Keys:**
```dart
// Pattern: '{repository_key}_last_sync'
'users_last_sync'
'activities_last_sync'
'events_last_sync'
'food_preferences_last_sync'
'user_foods_last_sync'
'carb_loading_plans_last_sync'
'carb_loading_days_last_sync'
'foods_last_sync'
'carb_loading_foods_last_sync'
```

### 2.3 Sync Coordinator v2 (Dependency Resolution)

**How `ensureSynced` Works:**

`ensureSynced` guarantees a repository's data is fresh (synced within 24 hours) before use. It's called lazily - only when a feature needs the data.

**Example Flow:**
```
User opens Activities screen
    ↓
ActivitiesController.build() calls:
    await syncCoordinator.ensureSynced('activities', userId)
    ↓
SyncCoordinator checks: "Is activities stale (>24h)?"
    ↓
├── No  → Return immediately (data is fresh)
│
└── Yes → Sync activities (and dependencies first)
```

**Dependency Resolution:**
```
ensureSynced('activities')
    ↓
Check: Is 'activities' stale? → YES
    ↓
Look up dependencies: activities → ['users']
    ↓
Recursively call: ensureSynced('users')
    ↓
    Check: Is 'users' stale? → YES
    ↓
    Upload dirty user records (if any)
    ↓
    Sync users from Supabase
    ↓
    Update 'users_last_sync' timestamp
    ↓
Now back to 'activities':
    ↓
Upload dirty activity records (if any)
    ↓
Sync activities from Supabase
    ↓
Update 'activities_last_sync' timestamp
```

**New SyncCoordinator Code:**
```dart
class SyncCoordinatorV2 extends _$SyncCoordinatorV2 {
  /// Repository dependency graph
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

  /// Track what's currently being synced (prevent loops)
  final Set<String> _syncingNow = {};

  /// Main entry point - ensures a repository is synced
  Future<void> ensureSynced(String repoKey, String userId) async {
    // 1. Prevent infinite loops
    if (_syncingNow.contains(repoKey)) return;

    // 2. Check if data is fresh
    if (!await _isStale(repoKey)) return;

    // 3. Mark as syncing
    _syncingNow.add(repoKey);

    try {
      // 4. Sync dependencies FIRST (recursive)
      for (final dep in _dependencies[repoKey] ?? []) {
        await ensureSynced(dep, userId);
      }

      // 5. Upload dirty records
      await _uploadDirtyRecords(repoKey, userId);

      // 6. Sync this repository
      await _syncRepository(repoKey, userId);

      // 7. Update timestamp
      await _setLastSyncTime(repoKey, DateTime.now());
    } finally {
      _syncingNow.remove(repoKey);
    }
  }

  bool _isStale(DateTime lastSync) {
    const staleDuration = Duration(hours: 24);
    return DateTime.now().difference(lastSync) > staleDuration;
  }
}
```

### 2.4 Dirty Records Protection

**Backup Flow:**
```
Repository wants to sync
    ↓
Check for dirty records (needs_upload = true)
    ↓
├── No dirty records → Proceed with sync
│
└── Has dirty records
    ↓
    Try upload to Supabase (3 retries)
    ↓
    ├── Success → Clear dirty flags → Proceed with sync
    │
    └── All retries failed
        ↓
        Save to JSON backup file
        ↓
        Log warning (Sentry)
        ↓
        Proceed with sync (data is backed up)
```

**Backup File Structure:**
```json
{
  "backup_created_at": "2026-01-18T10:30:00Z",
  "app_version": "1.12.1",
  "schema_version": 3,
  "user_id": "uuid-123",
  "dirty_records": {
    "activities": [
      { "id": "uuid-456", "name": "Morning Run", ... }
    ],
    "events": [],
    "carb_loading_plans": [],
    "carb_loading_days": []
  },
  "upload_errors": [
    { "repository": "activities", "error": "Network timeout", "timestamp": "..." }
  ]
}
```

**Backup Location:**
```dart
// App Support directory (hidden, persists across updates)
final appSupport = await getApplicationSupportDirectory();
final backupFile = File('${appSupport.path}/dirty_records_backup.json');
```

**Recovery on Startup:**
```dart
Future<void> checkForDirtyRecordBackup() async {
  final backupFile = await _getBackupFile();
  if (await backupFile.exists()) {
    // Show dialog: "Unsaved data found. Upload now?"
    final userChoice = await _showRecoveryDialog();

    if (userChoice == RecoveryChoice.upload) {
      await _uploadBackupRecords(backupFile);
    }

    await backupFile.delete();
  }
}
```

### 2.5 Schema Migration Strategy (Delete & Resync)

**New Approach:**
```
App Startup
    ↓
Check app_config.current_schema_version
    ↓
Compare to local Drift schemaVersion
    ↓
├── Match → Normal startup
│
└── Mismatch (local != remote)
    ↓
    Check for dirty records in local DB
    ↓
    ├── No dirty → Delete DB, resync
    │
    └── Has dirty records
        ↓
        Upload dirty records (with backup on failure)
        ↓
        Delete local DB
        ↓
        Reinitialize empty DB (new schema)
        ↓
        Full resync from Supabase
```

**Simplified app_database.dart:**
```dart
@override
MigrationStrategy get migration {
  return MigrationStrategy(
    onCreate: (Migrator m) async {
      await m.createAll();
    },
    // No onUpgrade - handled by VersionCheckService
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );
}
```

### 2.6 Direct Supabase Queries

**New Repository Pattern:**
```dart
class ActivitiesRepository implements SyncableRepository {
  final SupabaseClient _supabase;
  final AppDatabase _db;

  @override
  String get repositoryKey => 'activities';

  @override
  List<String> get dependencies => ['users'];

  @override
  Future<SyncResult> syncFromRemote(String userId) async {
    // Direct Supabase query (no edge function)
    final response = await _supabase
        .from('activities')
        .select('*')
        .eq('user_id', userId)
        .is_('deleted_at', null)
        .order('created_at', ascending: false);

    // Save to Drift
    await _db.batch((batch) {
      for (final activity in response) {
        batch.insertOrReplace(_db.activitiesTable, activity);
      }
    });

    await setLastSyncTime(DateTime.now());
    return SyncResult.success(count: response.length);
  }

  @override
  Future<UploadResult> uploadDirtyRecords(String userId) async {
    final dirtyRecords = await (_db.select(_db.activitiesTable)
      ..where((t) => t.needsUpload.equals(true)))
      .get();

    if (dirtyRecords.isEmpty) {
      return UploadResult.nothingToUpload();
    }

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
  }
}
```

### 2.7 Force Upgrade Screen

```dart
class ForceUpgradeScreen extends StatelessWidget {
  final String currentVersion;
  final String requiredVersion;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
              Text('Please update to version $requiredVersion or later.',
                textAlign: TextAlign.center),
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
    );
  }
}
```

---

## Part 3: Implementation Phases

See [checklist.md](./checklist.md) for detailed task tracking.

### Phase Overview

| Phase | Focus | Duration |
|-------|-------|----------|
| Phase 1 | Foundation (app_config, VersionCheckService, ForceUpgradeScreen) | Week 1 |
| Phase 2 | Repository Base Class, SyncCoordinator v2, Backup Service | Week 2 |
| Phase 3 | Migrate All Repositories | Weeks 3-4 |
| Phase 4 | Remove Step-by-Step Migrations, Schema Resync | Week 5 |
| Phase 5 | UI Integration | Week 5 |
| Phase 6 | Testing & Cleanup | Week 6 |

---

## Part 4: File Changes Summary

### New Files to Create

```
lib/
├── shared/
│   ├── data/
│   │   └── syncable_repository.dart
│   ├── services/
│   │   ├── version_check_service.dart
│   │   └── dirty_record_backup_service.dart
│   └── models/
│       ├── sync_result.dart
│       └── version_check_result.dart
├── features/
│   ├── app_startup/presentation/screens/
│   │   └── force_upgrade_screen.dart
│   ├── food_preferences/data/
│   │   └── food_preferences_repository.dart
│   └── user_foods/data/
│       └── user_foods_repository.dart

test/new_sync/
├── app_config_test.dart
├── models_test.dart
├── version_check_service_test.dart
├── syncable_repository_test.dart
├── sync_coordinator_v2_test.dart
├── dirty_record_backup_service_test.dart
├── activities_repository_sync_test.dart
├── ... (tests for each repository)

supabase/migrations/
└── 20260118_create_app_config_table.sql
```

### Files to Modify

```
lib/shared/database/app_database.dart
lib/shared/services/sync/sync_coordinator.dart
lib/features/app_startup/application/app_startup_provider.dart
lib/shared/core/app_router.dart
lib/features/activities/data/activities_repository.dart
lib/features/events/data/events_repository.dart
lib/features/carb_loading/data/carb_loading_repository.dart
lib/features/nutrition_plan/data/food_repository.dart
lib/features/auth/data/user_repository.dart
lib/features/feedback/data/feedback_repository.dart
lib/features/coach_mode/data/coach_repository.dart
```

### Files to Delete

```
lib/shared/database/migrations/migration_v1_to_v2.dart
lib/shared/database/migrations/migration_v2_to_v3.dart
```

---

## Part 5: Risk Mitigation

| Risk | Mitigation |
|------|------------|
| Data loss during migration | Always upload dirty records first; JSON backup as safety net |
| Infinite resync loop | Store `last_resync_attempt` timestamp; show error if <5 min ago |
| Backward compatibility break | Keep edge functions; use min_app_version to force updates |
| Poor connectivity | Version check fast (single row); cache result with staleness warning |
| Coach-athlete data | Keep on-demand `syncAthleteData()` separate from staleness pattern |

---

## Part 6: Success Metrics

| Metric | Before | After |
|--------|--------|-------|
| Sync all data | ~2-5 seconds | N/A (no full sync) |
| Individual repo sync | N/A | ~200-500ms |
| Migration code | 500+ lines | ~50 lines |
| Sync failure recovery | Limited | Full backup/restore |

---

## Appendix A: Dependency Graph

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

---

*Document Version: 1.1*
*Last Updated: 2026-01-18*
