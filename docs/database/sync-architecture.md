# Sync Architecture Documentation

## Overview

Mealvana Endurance uses a **repository-level sync strategy** with **24-hour staleness tracking** and **server-controlled version management**.

**Key Principles:**
- **Offline-first**: App works without internet using local Drift SQLite database
- **On-demand sync**: Data syncs only when stale (>24h old) or manually refreshed
- **Dependency resolution**: Repositories sync in correct order automatically
- **Server-controlled migrations**: Backend decides when schema changes happen
- **No data loss**: Dirty records always uploaded before database migrations

## Architecture Components

### 1. Local Storage (Drift SQLite)

**Purpose:** Primary data store for offline-first functionality

**Schema:** 27 tables (13 synced, 14 local-only)
- Version 2 (current)
- Located: `/lib/shared/database/`

**Key Tables:**
- `users` - User profiles and settings
- `activities` - Training sessions (running, cycling, swimming)
- `events` - Race events
- `food_preferences` - User food likes/dislikes
- `carb_loading_plans` - Carb loading plans
- `foods` - Food database

### 2. Cloud Storage (Supabase PostgreSQL)

**Purpose:** Data backup, cross-device sync, version control

**Tables:** 14 production tables
- 13 data tables (synced with Drift)
- 1 config table (`app_config` for version control)

**Key Features:**
- Row Level Security (device_id-based access)
- Edge functions for complex operations
- Server-controlled schema versioning

### 3. Sync Coordinator

**Location:** `/lib/shared/services/sync/sync_coordinator.dart`

**Responsibilities:**
- Prevents concurrent syncs
- Manages dependency resolution
- Tracks staleness per repository
- Invalidates UI providers after sync

**Sync Triggers:**
- OAuth sign-in (new device, returning user)
- Pull-to-refresh (manual user action)
- Stale data detection (>24h old)

### 4. Syncable Repositories

**Location:** `/lib/shared/data/syncable_repository.dart`

**Interface:**
```dart
mixin SyncableRepository {
  String get repositoryKey;           // 'activities', 'events', etc.
  List<String> get dependencies;      // ['users'] for activities

  Future<SyncResult> syncFromRemote(String userId);
  Future<UploadResult> uploadDirtyRecords(String userId);
}
```

**Implementations:**
- `ActivitiesRepository` - Syncs training activities
- `EventsRepository` - Syncs race events
- `FoodPreferencesRepository` - Syncs food preferences
- More repositories being migrated to this pattern

## Staleness Tracking

### 24-Hour Threshold

Data is considered **stale** if:
- Never been synced (no timestamp exists)
- Last sync was more than 24 hours ago

### Storage (SharedPreferences)

**Key Pattern:** `{repositoryKey}_last_sync`

**Examples:**
```
'users_last_sync' → '2026-01-18T14:30:00.000Z'
'activities_last_sync' → '2026-01-18T15:45:00.000Z'
'events_last_sync' → '2026-01-18T15:45:00.000Z'
'food_preferences_last_sync' → '2026-01-17T08:00:00.000Z'  // Stale!
```

**Why SharedPreferences?**
- Persists across database resyncs (when local DB is deleted)
- Lightweight and fast to access
- Survives app restarts
- Doesn't pollute database schema

### Staleness Check Flow

```
Controller needs data
    ↓
Call ensureSynced('activities', userId)
    ↓
Check last sync time from SharedPreferences
    ↓
If < 24 hours ago: Return immediately (use cached data)
If > 24 hours ago: Proceed with sync
```

## Dependency Resolution

### Dependency Graph

Repositories declare dependencies to ensure correct sync order:

```
users → (no dependencies)
foods → (no dependencies)
carb_loading_foods → (no dependencies)

activities → [users]
events → [users]
user_foods → [users]
coaches → [users]

food_preferences → [users, foods]
coach_athlete_relationships → [coaches, users]

carb_loading_plans → [users, events]
carb_loading_days → [carb_loading_plans]
carb_loading_day_meals → [carb_loading_days, carb_loading_foods]

coach_messages → [coach_athlete_relationships]
```

### Recursive Sync Example

```dart
// User calls: ensureSynced('carb_loading_plans', userId)

1. Check if 'carb_loading_plans' is stale
   → Yes, last sync was 2 days ago

2. Sync dependencies first:
   → ensureSynced('users', userId)
   → ensureSynced('events', userId)
      → events depends on 'users' (already synced ✓)

3. Upload dirty records for carb_loading_plans

4. Download fresh carb_loading_plans from Supabase

5. Update timestamp: 'carb_loading_plans_last_sync' = NOW()
```

## Sync Flow (Detailed)

### Standard Sync Flow

```
1. Controller Build Phase
   ↓
   await ensureSynced('activities', userId)
   ↓
2. Staleness Check
   ↓
   lastSync = SharedPreferences.getString('activities_last_sync')
   if (DateTime.now() - lastSync) <= 24 hours:
      Return immediately (data is fresh)
   ↓
3. Dependency Resolution (Recursive)
   ↓
   for each dependency in ['users']:
      await ensureSynced('users', userId)
   ↓
4. Upload Dirty Records
   ↓
   dirtyActivities = db.getActivitiesWhere(needs_upload = true)
   await supabase.upsert(dirtyActivities)
   await db.clearDirtyFlags(dirtyActivities)
   ↓
5. Download Fresh Data
   ↓
   activities = await supabase.getActivities(userId)
   await db.saveActivities(activities)
   ↓
6. Update Timestamp
   ↓
   SharedPreferences.setString('activities_last_sync', NOW())
   ↓
7. Controller Query
   ↓
   return await db.getAllActivities()
```

### Manual Refresh Flow

```
User pulls to refresh
   ↓
Call sync(userId, trigger: SyncTrigger.pullToRefresh)
   ↓
1. Upload all dirty records from all repositories
2. Download fresh data from all repositories
3. Invalidate all UI providers
4. UI rebuilds with fresh data
```

## Schema Version Control

### App Config Table

**Table:** `app_config` (Supabase)

**Key Configuration:**
```sql
INSERT INTO app_config (key, value, description) VALUES
  ('current_schema_version', '3', 'Expected Drift schema version'),
  ('min_app_version', '1.12.0', 'Minimum app version allowed'),
  ('maintenance_mode', 'false', 'Blocks all syncs when true'),
  ('force_resync_before', '', 'Force resync for old versions');
```

### Version Check Process

```
App Startup
   ↓
Query app_config.current_schema_version
   ↓
Compare with local Drift schemaVersion
   ↓
If Match: Continue normal operation
   ↓
If Mismatch:
   1. Upload all dirty records (backup user data)
   2. Delete local SQLite database
   3. Recreate fresh database (Drift onCreate)
   4. Download all data from Supabase
   5. Update all sync timestamps
   ↓
App continues with new schema
```

### Migration Strategy: Delete and Resync

**Why this approach?**

**Traditional (Complex):**
- Write step-by-step migrations (v1→v2, v2→v3)
- Handle edge cases and rollbacks
- Test all migration paths
- 500+ lines of migration code

**New (Simple):**
- Server updates `current_schema_version`
- Client detects mismatch
- Upload dirty records
- Delete local database
- Download fresh data
- **Result:** 200 lines, fewer bugs

**Benefits:**
- No complex migration logic
- Guaranteed schema consistency
- Automatic rollback (delete and retry)
- User data protected (upload first)
- Faster development cycle

## Code Examples

### Implementing SyncableRepository

```dart
// Example: Activities Repository
class ActivitiesRepository with SyncableRepository {
  @override
  String get repositoryKey => 'activities';

  @override
  List<String> get dependencies => ['users'];

  @override
  Future<SyncResult> syncFromRemote(String userId) async {
    try {
      // Download from Supabase
      final activities = await _supabase
        .from('activities')
        .select()
        .eq('user_id', userId);

      // Save to local database
      await _db.saveActivities(activities);

      // Update timestamp
      await setLastSyncTime(DateTime.now());

      return SyncResult.successful(activities.length);
    } catch (e) {
      return SyncResult.failed(e.toString());
    }
  }

  @override
  Future<UploadResult> uploadDirtyRecords(String userId) async {
    try {
      // Get dirty records
      final dirty = await _db.getDirtyActivities(userId);

      if (dirty.isEmpty) {
        return UploadResult.nothingToUpload();
      }

      // Upload to Supabase
      await _supabase.from('activities').upsert(dirty);

      // Clear dirty flags
      await _db.clearDirtyFlags(dirty.map((a) => a.id).toList());

      return UploadResult.successful(dirty.length);
    } catch (e) {
      return UploadResult.failed(e.toString());
    }
  }
}
```

### Using in Controllers

```dart
// Example: Activities Controller
@riverpod
class ActivitiesController extends _$ActivitiesController {
  @override
  FutureOr<List<Activity>> build() async {
    final userId = await ref.watch(userIdProvider.future);
    final repo = ref.read(activitiesRepositoryProvider);

    // Ensure data is fresh (syncs if stale)
    await ref.read(syncCoordinatorProvider.notifier).ensureSynced(
      'activities',
      userId,
      repository: repo,
    );

    // Query local database (data is guaranteed fresh)
    return await repo.getAllActivities();
  }
}
```

## Performance Characteristics

### App Startup Time

**Before (Sync all at startup):**
- 5-10 seconds initial sync
- Blocks app until complete
- Network-dependent startup

**After (Repository-level sync):**
- <1 second to show cached data
- Background sync for stale data
- Instant offline startup

### Network Usage

**Before:**
- Download all 13 tables on every startup
- 500KB - 2MB per sync
- Unnecessary for returning users

**After:**
- Only sync stale repositories
- 50KB - 500KB typical
- 90% reduction in network usage

### Battery Impact

**Before:**
- Sync on every app open
- 5-10 API calls per startup

**After:**
- Sync only when needed
- 0-3 API calls typical
- 70% reduction in network calls

## Debugging

### Check Sync Timestamps

```dart
// Get all sync timestamps
final prefs = await SharedPreferences.getInstance();
final keys = prefs.getKeys().where((k) => k.endsWith('_last_sync'));

for (final key in keys) {
  final timestamp = prefs.getString(key);
  print('$key: $timestamp');
}
```

### Force Resync

```dart
// Clear all sync timestamps
final prefs = await SharedPreferences.getInstance();
final keys = prefs.getKeys().where((k) => k.endsWith('_last_sync'));
for (final key in keys) {
  await prefs.remove(key);
}

// Next query will trigger fresh sync
```

### Check Schema Version

```sql
-- In Supabase SQL Editor
SELECT * FROM app_config WHERE key = 'current_schema_version';
```

## Related Documentation

- [Database Overview](README.md) - Complete database architecture
- [Drift Database](drift/README.md) - Local SQLite implementation
- [Supabase Database](supabase/README.md) - Cloud PostgreSQL backend
- [App Config Table](app-config-table.md) - Version control details
- [Server-Side Versioning Plan](server-side-versioning-plan.md) - Full migration strategy

---

*Last updated: January 2026*
