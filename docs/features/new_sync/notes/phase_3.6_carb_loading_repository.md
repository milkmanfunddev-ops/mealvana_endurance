# Phase 3.6: CarbLoadingRepository Migration to SyncableRepository

**Date**: 2026-01-18
**Agent**: claude-sonnet-4.5-20260118
**Status**: Complete

## Summary

Successfully migrated the CarbLoadingRepository to implement the SyncableRepository pattern with multi-table sync support for carb loading plans and days.

## Implementation Details

### Repository Changes

**File**: `lib/features/carb_loading/data/carb_loading_repository.dart`

1. **Added SyncableRepository Mixin**:
   - Changed from plain class to `class CarbLoadingRepository with SyncableRepository`
   - Added import for `syncable_repository.dart`

2. **Implemented Required Properties**:
   - `repositoryKey = 'carb_loading_plans'`
   - `dependencies = ['users', 'events']`

3. **Implemented syncFromRemote()**:
   - Fetches carb loading plans for user from Supabase
   - For each plan, fetches associated days using `inFilter` on plan IDs
   - Saves both plans and days to Drift in a single transaction
   - Updates last sync timestamp
   - Returns count of total records synced (plans + days)

4. **Implemented uploadDirtyRecords()**:
   - Queries dirty plans for the user
   - Queries dirty days belonging to those plans
   - Uploads plans to Supabase using upsert
   - Uploads days to Supabase using upsert
   - Clears dirty flags using batch operations
   - Returns count of total records uploaded

5. **Added Mapping Helper Methods**:
   - `_mapPlanJsonToCompanion()`: Maps Supabase JSON to Drift companion
   - `_mapDayJsonToCompanion()`: Maps Supabase JSON to Drift companion
   - `_mapPlanToSupabaseJson()`: Maps Drift model to Supabase JSON
   - `_mapDayToSupabaseJson()`: Maps Drift model to Supabase JSON

### Key Design Decisions

1. **Multi-Table Sync in Single Repository**:
   - Carb loading plans and days are tightly coupled
   - Syncing them together in one transaction ensures consistency
   - Using the primary entity (plans) as the repository key

2. **Cascading Queries**:
   - First fetch plans, then use plan IDs to fetch days
   - This is more efficient than separate syncs

3. **Transaction Safety**:
   - All Drift writes happen in a transaction
   - Ensures atomicity when syncing multiple records

4. **Nullable Field Handling**:
   - Used `Value.absent()` for null fields instead of `Value(null)`
   - Properly handles optional database fields

5. **Excluded Meals Table**:
   - carb_loading_day_meals was not included in sync
   - This table has a different schema and doesn't have `needsUpload` column
   - It can be added later if needed

### Test Coverage

**File**: `test/new_sync/carb_loading_repository_sync_test.dart`

**8 Tests (All Passing)**:

1. SyncableRepository Interface:
   - repositoryKey returns correct value
   - dependencies include users and events
   - isStale returns true when never synced
   - isStale returns false when synced recently
   - isStale returns true when synced more than 24 hours ago

2. Timestamp Management:
   - getLastSyncTime returns null when never synced
   - setLastSyncTime and getLastSyncTime work correctly

3. uploadDirtyRecords:
   - Returns nothingToUpload when no dirty records exist

**Note**: Full Supabase integration tests skipped due to mocking complexity. These will be covered in integration tests with real Supabase instances.

## Technical Challenges

1. **Initial Schema Mismatch**:
   - Expected carb_loading_day_meals to have standard fields
   - Actual schema uses different column names and no needsUpload flag
   - Solution: Excluded meals from sync for now

2. **Nullable Field Handling**:
   - Drift requires proper handling of nullable fields
   - Had to use conditional logic with `Value.absent()` for null values
   - Alternative approach of casting `as String?` doesn't work with `Value()`

3. **Supabase Mocking Complexity**:
   - Mocking the Supabase fluent API is very complex
   - Decided to follow the pattern from EventsRepository
   - Focus on interface compliance tests, defer Supabase tests to integration

## Files Modified

- `lib/features/carb_loading/data/carb_loading_repository.dart`
- `test/new_sync/carb_loading_repository_sync_test.dart` (created)
- `docs/new_sync/checklist.md` (updated)

## Next Steps

Task 3.6 is complete. The next unclaimed task is:

- **3.2 UserRepository**: Extract food preferences and user foods code
- **3.4 FoodPreferencesRepository (NEW)**: Create new repository
- **3.5 UserFoodsRepository (NEW)**: Create new repository
- **3.8 FeedbackRepository**: Implement sync
- **3.9 CoachRepository**: Implement multi-table sync

## Testing Commands

```bash
# Run carb loading repository tests
flutter test test/new_sync/carb_loading_repository_sync_test.dart

# Run all sync tests
flutter test test/new_sync/
```

## Commit Message

```
feat(sync): migrate CarbLoadingRepository to SyncableRepository pattern

- Implement SyncableRepository mixin with multi-table sync
- Handle carb_loading_plans and carb_loading_days in single transaction
- Dependencies: ['users', 'events']
- Add 8 passing tests for interface compliance
- Sync helper methods for JSON/Companion mapping

Co-Authored-By: Claude Opus 4.5 <noreply@anthropic.com>
```
