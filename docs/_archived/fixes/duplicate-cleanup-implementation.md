# Duplicate Record Cleanup Implementation

## Summary
Implemented client-side duplicate detection and cleanup in the Drift database to prevent upload-all-data edge function crashes.

## Problem
The edge function was crashing with errors:
- `ON CONFLICT DO UPDATE command cannot affect row a second time` - caused by duplicate IDs in the same payload
- `Could not find the 'local_updated_at' column of 'feature_survey_responses'` - schema mismatch
- `no such table: activities_table` - wrong SQLite table names in cleanup queries
- `date/time field value out of range: "1766333596825"` - timestamps sent as milliseconds instead of ISO 8601

## Solution

### 1. SQL Migration for feature_survey_responses

Run this SQL in Supabase SQL Editor:

```sql
-- Add sync tracking columns to feature_survey_responses
ALTER TABLE feature_survey_responses
  ADD COLUMN IF NOT EXISTS local_updated_at timestamp DEFAULT CURRENT_TIMESTAMP,
  ADD COLUMN IF NOT EXISTS needs_upload boolean DEFAULT false;

-- Create index for sync queries
CREATE INDEX IF NOT EXISTS idx_feature_survey_needs_upload
  ON feature_survey_responses(needs_upload)
  WHERE needs_upload = true;

-- Add trigger to update local_updated_at on updates
CREATE OR REPLACE FUNCTION update_feature_survey_timestamp()
RETURNS TRIGGER AS $$
BEGIN
  NEW.local_updated_at = CURRENT_TIMESTAMP;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER feature_survey_update_timestamp
  BEFORE UPDATE ON feature_survey_responses
  FOR EACH ROW
  EXECUTE FUNCTION update_feature_survey_timestamp();

-- Backfill existing records
UPDATE feature_survey_responses
SET
  local_updated_at = voted_at,
  needs_upload = false
WHERE local_updated_at IS NULL;
```

### 2. Client-Side Duplicate Cleanup

#### New Method: `_cleanDuplicatesFromDrift()`
- **When**: Called before collecting dirty records for upload
- **What**: Scans all sync tables for duplicate IDs
- **How**: Deletes duplicates, keeping the most recent record by `local_updated_at`

#### Supported Tables
- `activities_table`
- `events_table`
- `carb_loading_plans_table`
- `carb_loading_days_table`
- `user_foods`
- `feedback`
- `feature_survey_responses`

#### Implementation Details
**Location**: `/lib/shared/services/sync/data_sync_service.dart`

**Key Features**:
1. **Detects duplicates**: Queries for IDs that appear multiple times
2. **Keeps most recent**: Orders by `local_updated_at DESC`, keeps first record
3. **Deletes older records**: Permanently removes duplicates from Drift using `rowid`
4. **Comprehensive logging**: Logs each duplicate found and deleted
5. **Non-blocking**: If cleanup fails, sync continues (logged as error)

**Example Flow**:
```dart
// Before collecting records
await _cleanDuplicatesFromDrift(userId);

// If duplicates found:
// - activities: 2 records with id='act-123' (timestamps: 10:00, 10:05)
// - Keeps: 10:05 record
// - Deletes: 10:00 record (using rowid)
// - Logs: "Deleted duplicate record from activities_table"

// Then collect clean records
final dirtyActivities = await (_database.select(_database.activitiesTable)
      ..where((tbl) => tbl.needsUpload.equals(true)))
    .get();
```

## Expected Logs

### When Duplicates Are Found
```
💡 [DATA_SYNC] Scanning for duplicate records in Drift

⚠️  [DATA_SYNC] Found duplicate records in events_table
    id: event-123
    count: 3
    table: events_table

⚠️  [DATA_SYNC] Deleted duplicate record from events_table
    id: event-123
    rowid: 456
    local_updated_at: 2025-12-21T10:00:00.000
    kept_most_recent: true

⚠️  [DATA_SYNC] Deleted duplicate record from events_table
    id: event-123
    rowid: 789
    local_updated_at: 2025-12-21T10:02:00.000
    kept_most_recent: true

⚠️  [DATA_SYNC] Cleaned duplicates from events_table
    table: events_table
    duplicates_deleted: 2

⚠️  [DATA_SYNC] Cleaned duplicate records from Drift
    total_duplicates_deleted: 2
    user_id: uuid-1234
```

### When No Duplicates
```
💡 [DATA_SYNC] Scanning for duplicate records in Drift
💡 [DATA_SYNC] No duplicate records found in Drift
```

## Testing

### Test Duplicate Cleanup
```dart
// Create duplicate activities in Drift
final activity1 = Activity(
  id: 'test-dup-123',
  userId: userId,
  title: 'Activity Version 1',
  localUpdatedAt: DateTime.now().subtract(Duration(hours: 1)),
  needsUpload: true,
);

final activity2 = Activity(
  id: 'test-dup-123', // Same ID!
  userId: userId,
  title: 'Activity Version 2',
  localUpdatedAt: DateTime.now(), // More recent
  needsUpload: true,
);

await database.insert(activity1);
await database.insert(activity2);

// Trigger sync
await dataSyncService.syncAllData();

// Expected result:
// - Activity Version 2 kept (more recent)
// - Activity Version 1 deleted
// - Only 1 record uploaded to Supabase
```

### Verify in Database
```sql
-- Check for duplicates in Drift (should return nothing after cleanup)
SELECT id, COUNT(*) as count
FROM activities_table
GROUP BY id
HAVING COUNT(*) > 1;

-- Check what's uploaded to Supabase
SELECT id, title, updated_at
FROM activities
WHERE id = 'test-dup-123';
```

## Benefits

1. **✅ Prevents edge function crashes** - No more duplicate ID errors
2. **✅ Cleans local database** - Removes duplicates permanently from Drift
3. **✅ Keeps most recent data** - Uses `local_updated_at` to determine which record to keep
4. **✅ Comprehensive logging** - Easy to track and debug duplicate issues
5. **✅ Non-blocking** - Sync continues even if cleanup fails

## Next Steps

1. **Run SQL migration** in Supabase for `feature_survey_responses`
2. **Test sync** with current duplicate data - should see cleanup logs
3. **Monitor logs** to identify where duplicates are being created
4. **Investigate root cause** - Find why Drift is creating duplicate IDs

## Root Cause Investigation

Common scenarios causing duplicates:

### Scenario 1: Double-tap button
```dart
// User taps "Save" twice quickly
// First tap: INSERT activity with id='act-123'
// Second tap: INSERT another activity with id='act-123'
```

**Fix**: Add button debouncing or loading state

### Scenario 2: Failed sync retry
```dart
// Sync 1: Uploads activity, network glitch
// Client doesn't receive success response
// needs_upload stays true
// User modifies activity locally
// Drift creates new row with same ID (bug in upsert logic)
```

**Fix**: Review repository upsert implementations

### Scenario 3: Multi-device sync conflict
```dart
// Device A: Creates event with UUID collision
// Device B: Creates event with same UUID
```

**Fix**: Use UUID v7 (time-based) instead of v4

### 3. Fixed SQLite Table Names

**Problem**: Cleanup was querying `activities_table`, `events_table`, etc. but actual SQLite tables are `activities`, `events`.

**Fix**: Updated all table references in:
- `_cleanDuplicatesFromDrift()` - lines 1194-1230
- `_clearNeedsUploadFlag()` - lines 1370-1417

### 4. Fixed Feature Survey Timestamp Format

**Problem**: Drift stores timestamps as integer milliseconds, but PostgreSQL expects ISO 8601 strings.

**Fix**: Created `_featureSurveyToJson()` method (lines 1801-1819) that:
- Converts `voted_at` from int to ISO 8601
- Converts `local_updated_at` from int to ISO 8601
- Used at line 1099 instead of raw `row.data`

## Files Modified

- `/lib/shared/services/sync/data_sync_service.dart`
  - Added `_cleanDuplicatesFromDrift()` method (lines 1189-1253)
  - Added `_cleanTableDuplicates()` helper method (lines 1255-1365)
  - Integrated cleanup before collecting records (line 993)
  - Fixed table names in cleanup methods (lines 1194-1230)
  - Fixed table names in `_clearNeedsUploadFlag()` (lines 1370-1417)
  - Added `_featureSurveyToJson()` conversion method (lines 1801-1819)
  - Applied conversion at upload preparation (line 1099)

## Deployment

1. ✅ Code changes complete
2. ⏳ Run SQL migration in Supabase
3. ⏳ Test with duplicate data
4. ⏳ Deploy to production after verification

## Monitoring

Track these metrics after deployment:
- Number of duplicates deleted per sync
- Which tables have the most duplicates
- Frequency of duplicate detection
- Edge function success rate improvement

---

**Status**: ✅ Implementation complete, ready for testing
**Author**: Claude Code
**Date**: 2025-12-21
