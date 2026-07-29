# Critical Bugs & Issues

> **Last Updated**: December 2024
> **Priority**: IMMEDIATE - Fix before production scale

## Table of Contents

1. [Bug #1: Race Condition in User Foods Save](#bug-1-race-condition-in-user-foods-save)
2. [Bug #2: Same Issue in Feedback Save](#bug-2-same-issue-in-feedback-save)
3. [Bug #3: Nullable needsUpload Inconsistency](#bug-3-nullable-needsupload-inconsistency)
4. [Additional Issues](#additional-issues)
5. [Fix Implementation Guide](#fix-implementation-guide)

---

## Bug #1: Race Condition in User Foods Save

### Severity: 🔴 CRITICAL

### Location
`lib/shared/database/app_database.dart` lines 894-928

### Problem Description

User foods are saved in **TWO SEPARATE database operations**:

```dart
// Step 1: Insert record (needsUpload defaults to false)
await into(userFoodsTable).insert(companion);

// Step 2: Update dirty flag (SEPARATE operation)
await customStatement('UPDATE user_foods SET needs_upload = 1, local_updated_at = ? WHERE id = ?', [...]);
```

### Race Condition Scenario

```
Timeline:
─────────────────────────────────────────────────────────────────
T1: User scans barcode
T2: INSERT record (needs_upload = false by default)
T3: ❌ APP CRASHES / SYNC RUNS / APP KILLED
T4: UPDATE needs_upload = 1 (NEVER EXECUTES)
─────────────────────────────────────────────────────────────────

Result: Record exists in database with needs_upload = false
        → Record NEVER gets uploaded to Supabase
        → User loses their custom food on re-install
```

### Current Vulnerable Code

```dart
// File: lib/shared/database/app_database.dart
// Lines: 894-928

Future<void> saveUserFood(UserFood food) async {
  final companion = UserFoodsTableCompanion.insert(
    id: food.id,
    userId: food.userId,
    // ... other fields
    // ⚠️ NO needsUpload field here!
  );

  // Step 1: Insert (needsUpload defaults to schema default: false)
  await into(userFoodsTable).insert(
    companion,
    mode: InsertMode.insertOrReplace,
  );

  // Step 2: SEPARATE update for dirty flag
  // ⚠️ If app crashes before this line, record is never marked for upload!
  await customStatement(
    'UPDATE user_foods SET needs_upload = 1, local_updated_at = ? WHERE id = ?',
    [DateTime.now().millisecondsSinceEpoch, food.id],
  );
}
```

### Affected Operations

| Method | Location | Risk |
|--------|----------|------|
| `saveUserFood()` | Line 926 | User-created foods lost |
| `updateUserFood()` | Line 978 | Food edits lost |
| `deleteUserFood()` | Line 1056 | Soft deletes not synced |

### Impact

- **Data Loss**: User creates custom food via barcode scan → app crashes → food exists locally but never syncs
- **Inconsistency**: User reinstalls app → custom food is gone (never made it to Supabase)
- **Silent Failure**: No error logged, no indication to user

---

## Bug #2: Same Issue in Feedback Save

### Severity: 🔴 CRITICAL

### Location
`lib/shared/database/app_database.dart` lines 766-793

### Problem Description

Identical two-step pattern vulnerability:

```dart
// Step 1: Insert feedback (needsUpload defaults to false)
await into(feedbackTable).insertOnConflictUpdate(companion);

// Step 2: SEPARATE update for dirty flag
await customStatement('UPDATE feedback SET needs_upload = 1, local_updated_at = ? WHERE id = ?', [...]);
```

### Current Vulnerable Code

```dart
// File: lib/shared/database/app_database.dart
// Lines: 766-793

Future<void> saveFeedback(Feedback feedback) async {
  final companion = FeedbackTableCompanion.insert(
    id: feedback.id,
    satisfactionLevel: feedback.satisfactionLevel,
    // ... other fields
    // ⚠️ NO needsUpload field here!
  );

  // Step 1: Insert
  await into(feedbackTable).insertOnConflictUpdate(companion);

  // Step 2: SEPARATE update - RACE CONDITION!
  await customStatement(
    'UPDATE feedback SET needs_upload = 1, local_updated_at = ? WHERE id = ?',
    [DateTime.now().millisecondsSinceEpoch, feedback.id],
  );
}
```

### Impact

- **Lost Feedback**: User submits satisfaction survey → app crashes → feedback never syncs
- **Analytics Gap**: Business metrics incomplete
- **Lower Priority than Bug #1**: Feedback is less critical than user's custom foods

---

## Bug #3: Nullable needsUpload Inconsistency

### Severity: 🟠 HIGH

### Location
`lib/shared/database/tables/activities_table.dart` line 44

### Problem Description

Activities and Events use **nullable** `needsUpload`, while other tables use **non-nullable with default**:

```dart
// Activities/Events (INCONSISTENT - nullable)
BoolColumn get needsUpload => boolean().nullable().named('needs_upload')();

// Carb Loading Plans (CORRECT - non-nullable with default)
BoolColumn get needsUpload => boolean().withDefault(const Constant(false)).named('needs_upload')();
```

### The Three States Problem

| Value | Meaning (Intended) | Potential Misinterpretation |
|-------|-------------------|----------------------------|
| `true` | Needs upload | Correct |
| `false` | Already synced | Correct |
| `null` | ??? | Could be "never set" OR "synced" |

### Current Handling (Inconsistent)

```dart
// In data_sync_service.dart line 442
if (existingActivity != null && (existingActivity.needsUpload ?? false)) {
  return; // Treats null as FALSE (clean)
}

// In activities_repository.dart line 290
Value(activity.needsUpload ?? false)  // Treats null as FALSE
```

### Risk Scenarios

1. **Missed Uploads**: New records with `null` treated as "already synced"
2. **Double Uploads**: Older code treating `null` as "needs sync"
3. **Query Inconsistency**: `WHERE needs_upload = true` won't match `null` records

### Tables Affected

| Table | Current Definition | Status |
|-------|-------------------|--------|
| `activities_table.dart` | `nullable()` | ⚠️ INCONSISTENT |
| `events_table.dart` | `nullable()` | ⚠️ INCONSISTENT |
| `carb_loading_plans_table.dart` | `withDefault(false)` | ✅ CORRECT |
| `carb_loading_days_table.dart` | `withDefault(false)` | ✅ CORRECT |
| `user_foods_table.dart` | Custom SQL | ⚠️ NEEDS REVIEW |
| `feedback.dart` | Custom SQL | ⚠️ NEEDS REVIEW |

---

## Additional Issues

### Issue #4: Download Can Overwrite Dirty Records (Mitigated)

**Location**: `lib/shared/services/sync/data_sync_service.dart` line 442

**Current Protection**:
```dart
if (existingActivity != null && (existingActivity.needsUpload ?? false)) {
  return; // Keep local version with pending changes
}
```

**Status**: ✅ Protected by dirty flag check

**Remaining Risk**: Only checks `needsUpload`, doesn't check `localUpdatedAt` timestamp. If background upload fails silently AND clears flag prematurely, local changes could be lost.

### Issue #5: No Retry Count Tracking

**Location**: All synced tables

**Problem**: No way to track how many times a record has failed to upload

**Impact**:
- Can't identify "stuck" records
- Can't implement exponential backoff
- Can't alert on permanently failing records

### Issue #6: No Upload Error Message Storage

**Location**: All synced tables

**Problem**: When upload fails, error message is logged but not stored

**Impact**:
- Can't show user why sync failed
- Can't differentiate retryable vs permanent failures
- Can't build sync status UI

---

## Fix Implementation Guide

### Fix for Bug #1 & #2: Atomic Dirty Flag Setting

**Before (Vulnerable)**:
```dart
// TWO operations - race condition risk
await into(userFoodsTable).insert(companion);
await customStatement('UPDATE user_foods SET needs_upload = 1...');
```

**After (Safe)**:
```dart
// SINGLE operation - atomic
final companion = UserFoodsTableCompanion.insert(
  id: food.id,
  userId: food.userId,
  // ... other fields
  needsUpload: const Value(true),  // ✅ Set in same operation
  localUpdatedAt: Value(DateTime.now()),
);

await into(userFoodsTable).insert(
  companion,
  mode: InsertMode.insertOrReplace,
);
```

### Fix for Bug #3: Standardize Nullable Columns

**Step 1**: Update table definitions

```dart
// File: lib/shared/database/tables/activities_table.dart

// Before (WRONG)
BoolColumn get needsUpload => boolean().nullable().named('needs_upload')();

// After (CORRECT)
BoolColumn get needsUpload => boolean().withDefault(const Constant(false)).named('needs_upload')();
```

**Step 2**: Run code generation

```bash
dart run build_runner build --delete-conflicting-outputs
```

**Step 3**: Add migration for existing data

```dart
// In database migration
await customStatement('UPDATE activities SET needs_upload = 0 WHERE needs_upload IS NULL');
await customStatement('UPDATE events SET needs_upload = 0 WHERE needs_upload IS NULL');
```

### Implementation Priority

| Bug | Priority | Effort | Risk if Unfixed |
|-----|----------|--------|-----------------|
| Bug #1 (User Foods) | P0 | 2 hours | Data loss |
| Bug #2 (Feedback) | P1 | 1 hour | Analytics gap |
| Bug #3 (Nullable) | P1 | 4 hours | Query inconsistency |
| Issue #5 (Retry Count) | P2 | 1 day | Can't implement backoff |
| Issue #6 (Error Message) | P2 | 4 hours | Can't show sync status |

### Testing Checklist

After fixes, verify:

- [ ] Create user food → immediate app kill → reopen → `needs_upload = true`
- [ ] Submit feedback → immediate app kill → reopen → `needs_upload = true`
- [ ] Create activity → check `needs_upload` is `false` not `null`
- [ ] Query `WHERE needs_upload = true` returns newly created records
- [ ] Existing `null` records migrated to `false`

---

## Related Files

| File | Lines | Issue |
|------|-------|-------|
| `lib/shared/database/app_database.dart` | 894-928 | Bug #1 |
| `lib/shared/database/app_database.dart` | 766-793 | Bug #2 |
| `lib/shared/database/tables/activities_table.dart` | 44 | Bug #3 |
| `lib/shared/database/tables/events_table.dart` | ~40 | Bug #3 |
| `lib/shared/services/sync/data_sync_service.dart` | 442 | Issue #4 |
