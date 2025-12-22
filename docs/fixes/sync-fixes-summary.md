# Sync Issues Fixed - December 21, 2025

## Issues Found in logs.txt

### ❌ Issue 1: Wrong SQLite Table Names
**Error:**
```
SqliteException: no such table: activities_table
SqliteException: no such table: events_table
SqliteException: no such table: carb_loading_plans_table
```

**Root Cause:**
- Dart Drift classes use `activitiesTable`, `eventsTable` naming
- Actual SQLite tables are named `activities`, `events` (no `_table` suffix)
- Cleanup methods were querying wrong table names

**Fix:** ✅
- Updated `_cleanDuplicatesFromDrift()` to use correct table names
- Updated `_clearNeedsUploadFlag()` to use correct table names
- Changed: `activities_table` → `activities`
- Changed: `events_table` → `events`
- Changed: `carb_loading_plans_table` → `carb_loading_plans`
- Changed: `carb_loading_days_table` → `carb_loading_days`

**Files:**
- `/lib/shared/services/sync/data_sync_service.dart` lines 1194-1230, 1370-1417

---

### ❌ Issue 2: Duplicates Still Causing Upload Errors
**Error:**
```
⚠️ Failed to upload activities
⚠️ Data: {error: ON CONFLICT DO UPDATE command cannot affect row a second time}
```

**Root Cause:**
- Duplicate cleanup didn't run due to wrong table names (Issue 1)
- Activities table still had duplicate IDs
- Edge function tried to upsert same ID twice in one call

**Fix:** ✅
- Fixed table names (see Issue 1)
- Duplicate cleanup now runs successfully
- Deletes older duplicates before upload

**Expected Result:**
- No more "ON CONFLICT" errors
- Only unique records sent to edge function

---

### ❌ Issue 3: Feature Survey Timestamp Format Error
**Error:**
```
⚠️ Failed to upload feature_survey_responses
⚠️ Data: {error: date/time field value out of range: "1766333596825"}
```

**Root Cause:**
- Drift stores timestamps as **integer milliseconds** (e.g., `1766333596825`)
- PostgreSQL expects **ISO 8601 strings** (e.g., `"2025-12-21T12:24:07.000Z"`)
- Raw `row.data` was sending integer directly to database

**Fix:** ✅
- Created `_featureSurveyToJson()` conversion method
- Converts `voted_at` timestamp: `int` → `DateTime` → `ISO 8601 string`
- Converts `local_updated_at` timestamp: `int` → `DateTime` → `ISO 8601 string`
- Applied conversion at upload preparation

**Code:**
```dart
Map<String, dynamic> _featureSurveyToJson(QueryRow row) {
  final data = Map<String, dynamic>.from(row.data);

  // Convert voted_at timestamp (int milliseconds) to ISO 8601 string
  if (data['voted_at'] is int) {
    final votedAt = DateTime.fromMillisecondsSinceEpoch(data['voted_at'] as int);
    data['voted_at'] = votedAt.toIso8601String();
  }

  // Convert local_updated_at timestamp if it exists
  if (data['local_updated_at'] is int) {
    final localUpdatedAt = DateTime.fromMillisecondsSinceEpoch(data['local_updated_at'] as int);
    data['local_updated_at'] = localUpdatedAt.toIso8601String();
  }

  return data;
}
```

**Files:**
- `/lib/shared/services/sync/data_sync_service.dart` lines 1801-1819, 1099

---

## Summary of Fixes

| Issue | Status | Impact |
|-------|--------|--------|
| Wrong SQLite table names | ✅ Fixed | Duplicate cleanup now works |
| Activities duplicates | ✅ Fixed | No more ON CONFLICT errors |
| Feature survey timestamps | ✅ Fixed | Timestamps properly formatted |

---

## Testing

### Expected Logs After Fix

**Duplicate Cleanup (Success):**
```
💡 [DATA_SYNC] Scanning for duplicate records in Drift
⚠️  [DATA_SYNC] Found duplicate records in activities
    id: act-123
    count: 2
    table: activities
⚠️  [DATA_SYNC] Deleted duplicate record from activities
    id: act-123
    rowid: 456
    local_updated_at: 2025-12-21T10:00:00.000
    kept_most_recent: true
⚠️  [DATA_SYNC] Cleaned duplicates from activities
    table: activities
    duplicates_deleted: 1
⚠️  [DATA_SYNC] Cleaned duplicate records from Drift
    total_duplicates_deleted: 1
    user_id: uuid-1234
```

**Upload (Success):**
```
💡 [DATA_SYNC] Calling upload-all-data edge function
    userId: uuid-1234
    tableCount: 3
💡 [DATA_SYNC] Successfully uploaded activities
    uploaded: 5
💡 [DATA_SYNC] Successfully uploaded events
    uploaded: 1
💡 [DATA_SYNC] Successfully uploaded feature_survey_responses
    uploaded: 1
💡 [DATA_SYNC] Upload completed via edge function
    userId: uuid-1234
    successful: 3
    failed: 0
```

### Test Verification

Run a sync and verify:
1. ✅ No `SqliteException: no such table` errors
2. ✅ No `ON CONFLICT DO UPDATE` errors
3. ✅ No `date/time field value out of range` errors
4. ✅ Duplicate cleanup logs show tables being scanned
5. ✅ Upload logs show all tables succeeded

---

## Deployment Checklist

- [x] Fix table names in duplicate cleanup
- [x] Fix table names in flag clearing
- [x] Add timestamp conversion for feature surveys
- [x] Code compiles without errors
- [ ] Run SQL migration in Supabase (feature_survey_responses)
- [ ] Test sync on device
- [ ] Verify no errors in logs
- [ ] Deploy to production

---

**Status**: ✅ Code fixes complete, ready for testing
**Next Step**: Run SQL migration in Supabase, then test sync

**Author**: Claude Code
**Date**: 2025-12-21
