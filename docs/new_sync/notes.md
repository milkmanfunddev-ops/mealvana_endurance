# New Sync Implementation Notes

**Purpose**: Working document for agents to record discoveries, decisions, and issues.

---

## How to Use This Document

- Add dated entries for any important findings
- Document decisions made during implementation
- Record issues encountered and how they were resolved
- Note any deviations from the roadmap

---

## Decisions Log

### 2026-01-18 - Initial Planning

**Decision**: Use 24-hour staleness threshold
- Rationale: Balance between data freshness and network efficiency
- Alternative considered: On-demand sync (rejected - too many network calls)

**Decision**: SharedPreferences for sync timestamps
- Rationale: Simple, fast, persists across restarts
- Alternative considered: Dedicated Drift table (rejected - adds complexity)

**Decision**: App Support directory for dirty record backups
- Rationale: Hidden from user, persists across updates, survives iOS offload
- Alternative considered: Documents directory (rejected - visible to user)

**Decision**: Block app on version check failure (schema mismatch)
- Rationale: Data integrity is critical for nutrition planning
- Alternative considered: Graceful degradation (rejected - risk of data corruption)

---

## Implementation Notes

### Phase 1 Notes

#### 2026-01-18 - app_config Migration Created (claude-sync-agent-20260118)

**Migration File Created**: `supabase/migrations/20260118_create_app_config_table.sql`

**Implementation Details**:
- Created app_config table with id, key, value, description, updated_at columns
- Added UNIQUE constraint on key column for integrity
- Added index on key column for performance (idx_app_config_key)
- Implemented RLS policies:
  - Public read access for all users (anon, authenticated)
  - Service role only for insert/update/delete operations
- Initial config values:
  - min_app_version: '1.12.0'
  - current_schema_version: '3'
  - maintenance_mode: 'false'
  - force_resync_before: '' (empty, for future use)
- Added trigger to auto-update updated_at timestamp on row updates
- Used `ON CONFLICT (key) DO NOTHING` for idempotency
- Added table and column comments for documentation

**Test File Created**: `test/new_sync/app_config_migration_test.dart`

**Test Coverage**:
- Migration file existence check
- Required SQL statements verification (CREATE TABLE, RLS, policies, trigger)
- Initial values validation
- Best practices verification (IF NOT EXISTS, indexes, comments)

**All tests pass successfully** (4/4 tests green)

**Next Steps**:
- Human needs to test migration with `supabase db reset` to verify it runs correctly in dev environment
- Migration ready for deployment once tested

#### 2026-01-18 - Core Models Created (claude-sync-agent-20260118)

**Files Created**:
- `lib/shared/models/sync_result.dart`
- `lib/shared/models/version_check_result.dart`
- `test/new_sync/sync_models_test.dart`

**Implementation Details - SyncResult**:
- Factory constructors: `success(count)`, `failure(error, stackTrace, message)`, `nothingToSync()`
- Immutable class with private constructor
- Status enum: success, failure, nothingToSync
- Fields: status, count, errorMessage, error, stackTrace
- Convenience getters: isSuccess, isFailure, isNothingToSync
- Proper equality implementation (compares status, count, errorMessage)
- Custom toString() for debugging

**Implementation Details - VersionCheckResult**:
- Sealed class pattern for type-safe exhaustive matching
- Three subtypes:
  - VersionCheckOk: Normal startup (all versions compatible)
  - VersionCheckUpdateRequired: App version below minimum (force upgrade)
  - VersionCheckResyncRequired: Schema version mismatch (database resync needed)
- Each subtype has immutable fields with proper equality
- Convenience getters: isOk, isUpdateRequired, isResyncRequired
- Custom toString() for each subtype

**Test Coverage**:
- 29 tests total, all passing
- SyncResult: Factory constructors, equality, immutability, toString
- VersionCheckResult: Factory constructors, type checks, equality, immutability, toString
- Edge cases: Different counts, different error messages, different versions

**Design Decisions**:
- Used sealed class for VersionCheckResult (better than enum - can carry data)
- Used enum for SyncStatus (simple discriminator, no data needed)
- Error and stackTrace stored separately for flexibility (can log stackTrace but show user-friendly message)
- Equality based on semantic values, not object identity

**All tests pass successfully** (29/29 tests green)

---

### Phase 2 Notes

#### 2026-01-18 - Task 2.1: SyncableRepository Base Class (claude-opus-4.5-20260118)

**Files Created**:
- `lib/shared/data/syncable_repository.dart`
- `test/new_sync/syncable_repository_test.dart`

**Implementation Details:**
- Created abstract base class `SyncableRepository`
- Included inline placeholder types `SyncResult` and `UploadResult` (to be refactored to use shared/models when integration happens)
- Used SharedPreferences with key pattern: `{repositoryKey}_last_sync`
- Timestamps stored as ISO8601 strings for human readability
- 24-hour staleness threshold defined as static const `staleDuration`

**Key Design Decisions:**
1. Made `repositoryKey` abstract getter (not field) for flexibility in implementations
2. Made `dependencies` default to empty list to reduce boilerplate for leaf repositories (users, foods)
3. Implemented `isStale()` as concrete method (reusable logic - no need to override)
4. Stored timestamps in SharedPreferences vs Drift table (simpler, faster, no FK dependencies)
5. Created inline SyncResult/UploadResult as placeholders (these match the design from task 1.2 but are simplified)

**Testing:**
- 21 tests total, all passing
- Test coverage:
  - Staleness logic (never synced, recently synced, 23 hours old, >24 hours old)
  - Timestamp storage (null when never synced, persistence across instances)
  - Invalid data handling (gracefully returns null for malformed timestamps)
  - SharedPreferences key pattern verification
  - Multiple repositories using different keys
  - SyncResult and UploadResult factory constructors
- Created parameterized `MockSyncableRepository` for easy testing

**Integration Notes:**
1. **Task 1.2 Integration**: When SyncResult from shared/models is ready, remove inline placeholder types
2. **Task 2.2 Integration**: SyncCoordinator v2 will use the `dependencies` field for dependency graph resolution
3. **Future Repository Migrations**: All repositories (tasks 3.1-3.9) should extend this base class

**All tests pass successfully** (21/21 tests green)

---

### Phase 3 Notes

*(Agents: Add notes here as you work on Phase 3)*

---

### Phase 4 Notes

*(Agents: Add notes here as you work on Phase 4)*

---

### Phase 5 Notes

*(Agents: Add notes here as you work on Phase 5)*

---

### Phase 6 Notes

*(Agents: Add notes here as you work on Phase 6)*

---

## Issues Encountered

### Template:
```
### Issue: [Brief description]
**Date**: YYYY-MM-DD
**Agent**: [Agent ID]
**Status**: Open | Resolved
**Description**: [Detailed description]
**Resolution**: [How it was resolved, if applicable]
```

---

## Code Patterns Discovered

*(Document any patterns found in existing code that are useful)*

### Existing Dirty Flag Pattern
```dart
// Found in activities_repository.dart
final activityWithDirtyFlag = activity.copyWith(
  needsUpload: true,
  localUpdatedAt: DateTime.now(),
);
await _saveToDrift(activityWithDirtyFlag);
unawaited(_uploadActivityToSupabase(deviceId, activityWithDirtyFlag, 'update'));
```

### Existing Supabase Query Pattern
```dart
// Found in user_repository.dart
final response = await supabase
    .from('users')
    .select()
    .eq('id', userId)
    .maybeSingle();
```

---

## Questions for Lee

*(Add questions here that need human input)*

1. *(None yet)*

---

## Agent Activity Log

| Date | Agent ID | Task | Status | Notes |
|------|----------|------|--------|-------|
| 2026-01-18 | claude-sync-agent-20260118 | Phase 1.1 - app_config table migration | Complete | Created migration and tests, all tests pass |
| 2026-01-18 | claude-sync-agent-20260118 | Phase 1.2 - Core Models | Complete | Created SyncResult and VersionCheckResult with 29 passing tests |
| 2026-01-18 | claude-opus-4.5-20260118 | Phase 2.1 - SyncableRepository Base Class | Complete | Created abstract base class with 21 passing tests |

| 2026-01-18 | claude-sonnet-4.5-20260118 | Phase 2.3 DirtyRecordBackupService | Complete | Created backup service, models, tests. All 16 tests passing. |

---

*Last updated*: 2026-01-18

## 2026-01-18 - Phase 2.2: SyncCoordinator v2 Implementation

**Agent**: claude-sonnet-4.5-20260118
**Status**: DONE
**Tests**: 11/11 passing

### Changes Made

1. **Added to SyncCoordinator**:
   - Static dependency graph map (`_dependencies`) with all 13 repository keys
   - `_syncingNow` Set to prevent infinite loops during recursive sync
   - `_lastSyncTimes` Map for in-memory staleness tracking
   - `ensureSynced(String repoKey, String userId, {SyncableRepository? repository})` method

2. **ensureSynced Implementation**:
   - Returns immediately if repository is already syncing (loop prevention)
   - Returns immediately if data is not stale (<24h since last sync)
   - Recursively syncs dependencies first
   - Uploads dirty records (if repository provided)
   - Syncs fresh data from Supabase (if repository provided)
   - Updates timestamp in both in-memory cache and SharedPreferences
   - Catches and logs errors without rethrowing (best-effort sync)

3. **_isStale Helper**:
   - Delegates to `repository.isStale()` if repository instance provided (checks SharedPreferences)
   - Falls back to in-memory `_lastSyncTimes` cache for Phase 2 (before repos implement SyncableRepository)
   - 24-hour staleness threshold

4. **Backwards Compatibility**:
   - Existing `sync()` method preserved unchanged
   - Marked as "LEGACY" in comments

### Test Coverage

Created `test/new_sync/sync_coordinator_v2_test.dart` with 11 tests:

1. Should return immediately if data is not stale
2. Should sync if data is stale
3. Should sync dependencies before syncing repository
4. Should prevent infinite loops with circular dependencies
5. Should handle sync errors gracefully
6. Should handle upload errors gracefully
7. Should sync if never synced before
8. Should work without repository instance (in-memory cache)
9. Should handle complex dependency chains
10. Should update timestamp after successful sync
11. Should preserve legacy `sync()` method

### Dependency Graph

Complete dependency graph with 13 repository keys:
- Level 0: users, foods, carb_loading_foods (no dependencies)
- Level 1: activities, events, food_preferences, user_foods, coaches (depend on users/foods)
- Level 2: coach_athlete_relationships, carb_loading_plans
- Level 3: carb_loading_days
- Level 4: carb_loading_day_meals
- Level 5: coach_messages

### Design Decisions

1. **Optional repository parameter**: Allows Phase 2 to work without repository instances (uses in-memory cache). Phase 3 will pass actual repositories.

2. **In-memory fallback**: `_lastSyncTimes` map provides staleness tracking before repositories implement SyncableRepository interface.

3. **Best-effort sync**: Errors are logged but not propagated - sync continues even if individual repos fail.

4. **Recursive dependency resolution**: Each call to `ensureSynced` automatically syncs dependencies first, ensuring correct order.

5. **Loop prevention**: `_syncingNow` set prevents calling `ensureSynced` on the same repo while it's already syncing.

### Integration Notes

- Controllers will call `await syncCoordinator.ensureSynced('activities', userId)` in their `build()` methods
- No changes needed to existing code - new pattern is opt-in
- Legacy `sync()` method continues to work for existing features

### Next Steps

Phase 2 is now complete:
- ✅ 2.1 SyncableRepository abstract class
- ✅ 2.2 SyncCoordinator v2 with ensureSynced
- ✅ 2.3 DirtyRecordBackupService
- ⏳ 2.4 Recovery Dialog (next task)

After Phase 2.4, Phase 3 will migrate all repositories to implement SyncableRepository.


## 2026-01-18 - Phase 2.4 Recovery Dialog Complete

**Completed by**: claude-sonnet-4.5-20260118-2

**What was done:**

1. **Created DirtyRecordRecoveryDialog widget**
   - Location: `lib/features/app_startup/presentation/widgets/dirty_record_recovery_dialog.dart`
   - Shows backup metadata (timestamp, record count, repositories)
   - Two action buttons: "Upload Now" (primary) and "Discard" (secondary)
   - Returns RecoveryChoice enum (upload/discard)
   - Uses SingleChildScrollView for proper overflow handling
   - Follows existing AppTheme patterns and ScreenUtil for responsive sizing
   - Not dismissible by tapping outside (barrierDismissible: false)

2. **Integrated recovery flow into AppStartupService**
   - Added `checkAndHandleDirtyRecordBackup(BuildContext)` method
   - Checks for backup on startup
   - Shows dialog if backup exists
   - Handles user choice (upload or discard)
   - Deletes backup file after handling
   - Added `_uploadBackupRecords()` helper to upload dirty records per repository
   - Added `_getTableNameFromRepositoryKey()` helper to map repository keys to Supabase tables
   - Full error handling and analytics tracking

3. **Created comprehensive tests**
   - Location: `test/new_sync/recovery_dialog_test.dart`
   - 9 tests, all passing
   - Tests dialog display, metadata formatting, button interactions, and choices
   - Uses ScreenUtilInit wrapper for proper responsive testing
   - Tests overflow handling (SingleChildScrollView)

**Key Design Decisions:**

1. **Dialog Design**: Used AlertDialog pattern with custom styling matching AppTheme
2. **User-friendly names**: Repository keys converted to readable names (e.g., "activities" → "Activities")
3. **Relative timestamps**: Backup time shown as "30 minutes ago" for better UX
4. **Forced choice**: Dialog cannot be dismissed without choosing upload or discard
5. **Scrollable content**: SingleChildScrollView prevents overflow on smaller screens

**Next Steps:**

- Phase 2.4 is DONE (7/12 Phase 2 tasks complete)
- Can integrate into actual app startup flow when needed
- Method `checkAndHandleDirtyRecordBackup(context)` is ready to be called from AppStartupWidget or AppStartupProvider

**Testing:**

```bash
flutter test test/new_sync/recovery_dialog_test.dart
# 00:09 +9: All tests passed!
```

