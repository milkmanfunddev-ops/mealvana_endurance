# UserFoodsRepository Implementation Notes

**Date**: 2026-01-18  
**Agent**: claude-sonnet-4.5-20260118-task3.5  
**Status**: ✅ Complete (8/8 tests passing)

## Overview

Created a new `UserFoodsRepository` by extracting user-created custom foods logic from `UserRepository`. This repository manages the user_foods table which stores custom foods that users have added or scanned.

## Implementation Details

### Repository Structure

**File**: `lib/features/user_foods/data/user_foods_repository.dart`

**Key Characteristics**:
- **Repository Key**: `'user_foods'`
- **Dependencies**: `['users']` (Level 1 repository)
- **Soft Delete Support**: Excludes records with `is_deleted = true`

### SyncableRepository Implementation

#### syncFromRemote(userId)
- Queries Supabase: `.from('user_foods').select('*').eq('user_id', userId).eq('is_deleted', false)`
- Uses existing `database.replaceUserFoods()` method for data insertion
- Updates last sync timestamp
- Returns `SyncResult` with count of synced records

#### uploadDirtyRecords(userId)
- Queries Drift for records with `needs_upload = true`
- Batch uploads to Supabase using `upsert()` with `onConflict: 'id'`
- Clears dirty flags in Drift database after successful upload
- Returns `UploadResult` with count of uploaded records

### Preserved Methods

Kept existing `syncUserFoodsFromSupabase(userId)` method for backward compatibility with current codebase. This method will be deprecated once controllers are migrated to use the new sync architecture.

## Database Schema

The user_foods table includes:
- Basic food info: id, name, display names, description
- Nutritional values: calories, carbs, protein, fat, sodium, fluids
- Metadata: categories, activity_types, product_type_id
- Sync tracking: needs_upload, local_updated_at
- Soft delete: is_deleted flag
- Barcode scanning: barcode field
- Client-side ID: client_food_id for offline sync

## Testing

**File**: `test/new_sync/user_foods_repository_test.dart`

**Test Coverage** (8 tests):
1. ✅ repositoryKey returns 'user_foods'
2. ✅ dependencies includes ['users']
3. ✅ isStale returns true when never synced
4. ✅ isStale returns false after recent sync
5. ✅ isStale returns true after 24 hours
6. ✅ getLastSyncTime persists and retrieves timestamp
7. ✅ getLastSyncTime returns null when never synced
8. ✅ uploadDirtyRecords returns nothingToUpload when no dirty records

**Test Pattern**: Following the simplified pattern from EventsRepository tests - focusing on SyncableRepository interface validation rather than complex Supabase mocking.

## Key Decisions

1. **Extract vs Modify**: Created new repository instead of modifying UserRepository to maintain single responsibility
2. **Soft Delete**: Respects `is_deleted` flag to prevent syncing deleted records
3. **Batch Upload**: Uses Drift's update().replace() for each dirty record to clear flags
4. **Backward Compatibility**: Preserved syncUserFoodsFromSupabase() method for existing code

## Next Steps

- [ ] Update SyncCoordinator dependency graph to include 'user_foods'
- [ ] Remove syncUserFoodsFromSupabase call from UserRepository once all controllers migrated
- [ ] Add integration tests with actual Supabase (if needed for edge cases)

## Notes

- user_foods table has a UNIQUE constraint on (device_id, client_food_id)
- Uses database.replaceUserFoods() which deletes all existing user_foods for userId before inserting new data
- This is a "replace" sync strategy rather than "merge" strategy
