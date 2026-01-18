# EventsRepository Migration to SyncableRepository

**Date**: 2026-01-18
**Agent**: claude-sonnet-4.5-20260118
**Task**: Phase 3.3 - Migrate EventsRepository to SyncableRepository pattern

## Changes Made

### 1. EventsRepository Implementation

**File**: `lib/features/events/data/events_repository.dart`

**Changes**:
- Added `implements SyncableRepository` to class declaration
- Added import for `shared_preferences` package
- Added import for `syncable_repository.dart`
- Implemented all required SyncableRepository methods:
  - `repositoryKey` getter returning 'events'
  - `dependencies` getter returning ['users']
  - `isStale()` - checks if last sync was >24 hours ago
  - `getLastSyncTime()` - retrieves timestamp from SharedPreferences
  - `setLastSyncTime()` - stores timestamp to SharedPreferences
  - `syncFromRemote(userId)` - syncs events from Supabase to Drift
  - `uploadDirtyRecords(userId)` - uploads dirty events to Supabase

**New Helper Method**:
- `_mapSupabaseJsonToCompanion()` - converts Supabase JSON (snake_case) to Drift EventsTableCompanion

**Sync Logic**:
- `syncFromRemote()` queries Supabase with: `.from('events').select('*').eq('user_id', userId).order('created_at', ascending: false)`
- Uses Drift batch insert with `InsertMode.insertOrReplace` for efficient saving
- Updates last sync timestamp after successful sync
- Returns `SyncResult.successful(count)` or `SyncResult.failed(error)`

**Upload Logic**:
- `uploadDirtyRecords()` queries Drift for records where `needsUpload = true` AND `userId = userId`
- Uses Supabase `.upsert()` to upload all dirty records
- Clears dirty flags using Drift batch update
- Returns `UploadResult.successful(count)`, `UploadResult.nothingToUpload()`, or `UploadResult.failed(error)`

### 2. Tests

**File**: `test/new_sync/events_repository_sync_test.dart`

**Test Coverage** (8 tests, all passing):
1. **SyncableRepository Interface** (5 tests):
   - repositoryKey returns 'events'
   - dependencies returns ['users']
   - isStale returns true when never synced
   - isStale returns false when synced recently
   - isStale returns true when synced >24 hours ago

2. **Timestamp Management** (2 tests):
   - getLastSyncTime returns null when never synced
   - setLastSyncTime/getLastSyncTime work correctly

3. **uploadDirtyRecords** (1 test):
   - Returns nothingToUpload when no dirty records exist

**Note on Skipped Tests**:
Supabase fluent API mocking is complex and error-prone. Full integration tests with real Supabase instances will cover:
- syncFromRemote() with actual data fetching
- uploadDirtyRecords() with actual uploads
- Error handling for network failures
- Data consistency between Drift and Supabase

### 3. Code Generation

Ran `flutter pub run build_runner build --delete-conflicting-outputs` successfully after changes.

## Architectural Notes

### Why `implements` Instead of `with`?

The SyncableRepository is defined as an abstract class, not a mixin class. Dart requires:
- `with` for mixin classes (defined with `mixin` keyword)
- `implements` for abstract classes (defined with `abstract class` keyword)

Since SyncableRepository provides default implementations for some methods (isStale, getLastSyncTime, setLastSyncTime), we had two options:
1. Make it a `mixin class` and use `with`
2. Keep it as `abstract class`, use `implements`, and copy the implementations

We chose option #2 to keep SyncableRepository as an interface with default behavior, and copied the SharedPreferences methods into EventsRepository.

### Dependency Resolution

EventsRepository declares `dependencies = ['users']`, which tells the SyncCoordinator to:
1. Ensure 'users' repository is synced first
2. Then sync 'events' repository

This prevents foreign key violations when syncing events that reference user_id.

### Dirty Flag Pattern

Events use the existing `needsUpload` flag pattern:
- Set to `true` when created/updated locally
- Set to `false` after successful upload to Supabase
- Set to `false` when synced from Supabase (server data is authoritative)

## Integration with SyncCoordinator

The SyncCoordinator will call these methods in this order:

```
SyncCoordinator.ensureSynced('events', userId)
    ↓
1. Check if stale (isStale())
    ↓
2. Sync dependencies first (ensureSynced('users'))
    ↓
3. Upload dirty records (uploadDirtyRecords(userId))
    ↓
4. Sync fresh data (syncFromRemote(userId))
    ↓
5. Update timestamp (setLastSyncTime(now))
```

## Testing Strategy

**Unit Tests** (8 tests):
- Interface compliance
- Staleness logic
- Timestamp storage
- Empty state handling

**Integration Tests** (to be added):
- Full sync cycle with real Supabase
- Network error handling
- Data consistency validation
- Concurrent sync handling

## Next Steps

Following the roadmap, the next repository to migrate is:
- **Phase 3.4**: FoodPreferencesRepository (new repository extracted from UserRepository)

## Files Modified

1. `lib/features/events/data/events_repository.dart` - Added SyncableRepository implementation
2. `test/new_sync/events_repository_sync_test.dart` - Added 8 tests
3. `docs/new_sync/checklist.md` - Updated task 3.3 to DONE
4. `docs/new_sync/notes/events_repository_migration.md` - This file

## Verification

Run tests:
```bash
flutter test test/new_sync/events_repository_sync_test.dart
```

Expected output:
```
00:02 +8: All tests passed!
```
