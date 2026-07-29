# Carb Loading Orphan Rows Bug Fix

## Problem
The `_clearAnonymousUserLocalData` function in `user_repository.dart` and `migrateAnonymousUserDataToOAuthUser` in `app_database.dart` were only deleting `carb_loading_plans`, leaving orphaned rows in child tables:
- `carb_loading_days_table`
- `carb_loading_day_meals_table`

This happened because Drift SQLite tables don't support foreign key cascades.

## Root Cause
Incorrect assumption that SQLite would automatically cascade deletes. The code had comments like:
```dart
// Note: carb_loading_days is a CHILD table with ON DELETE CASCADE,
// so deleting plans will automatically delete associated days
```

But Drift doesn't implement FK cascade constraints - manual cascade deletion is required.

## Solution
Implemented proper manual cascade deletion in three locations:

### 1. `lib/features/auth/data/user_repository.dart` (lines 1236-1262)
**Function**: `_clearAnonymousUserLocalData`

**Before** (buggy):
```dart
// Delete anonymous user's carb loading plans (cascades to days)
await database.customStatement(
  'DELETE FROM carb_loading_plans WHERE user_id = ?',
  [anonymousUserId],
);
```

**After** (fixed):
```dart
// Delete anonymous user's carb loading data (manual cascade - Drift doesn't have FK cascades)
// Delete child tables first (carb_loading_day_meals -> carb_loading_days -> carb_loading_plans)

// Step 1: Delete carb_loading_day_meals via carb_loading_days via carb_loading_plans
await database.customStatement('''
  DELETE FROM carb_loading_day_meals_table
  WHERE carb_loading_day_id IN (
    SELECT id FROM carb_loading_days_table
    WHERE carb_loading_plan_id IN (
      SELECT id FROM carb_loading_plans_table WHERE user_id = ?
    )
  )
''', [anonymousUserId]);

// Step 2: Delete carb_loading_days via carb_loading_plans
await database.customStatement('''
  DELETE FROM carb_loading_days_table
  WHERE carb_loading_plan_id IN (
    SELECT id FROM carb_loading_plans_table WHERE user_id = ?
  )
''', [anonymousUserId]);

// Step 3: Delete carb_loading_plans
await database.customStatement(
  'DELETE FROM carb_loading_plans_table WHERE user_id = ?',
  [anonymousUserId],
);
```

### 2. `lib/shared/database/app_database.dart` (lines 640-649)
**Function**: `clearAllUserData`

**Before** (buggy):
```dart
// carb_loading_day_meals (via carb_loading_plans.user_id)
await customStatement('''
  DELETE FROM carb_loading_day_meals_table
  WHERE carb_loading_plan_id IN (
    SELECT id FROM carb_loading_plans_table WHERE user_id = ?
  )
''', [userId]);
```

**After** (fixed):
```dart
// carb_loading_day_meals (via carb_loading_days via carb_loading_plans.user_id)
await customStatement('''
  DELETE FROM carb_loading_day_meals_table
  WHERE carb_loading_day_id IN (
    SELECT id FROM carb_loading_days_table
    WHERE carb_loading_plan_id IN (
      SELECT id FROM carb_loading_plans_table WHERE user_id = ?
    )
  )
''', [userId]);
```

### 3. `lib/shared/database/app_database.dart` (lines 760-787)
**Function**: `migrateAnonymousUserDataToOAuthUser`

**Before** (buggy):
```dart
// Delete OAuth user's old carb loading plans (if any)
// Note: carb_loading_days is a CHILD table with ON DELETE CASCADE,
// so deleting plans will automatically delete associated days
await customStatement(
  'DELETE FROM carb_loading_plans WHERE user_id = ?',
  [toUserId],
);
```

**After** (fixed):
```dart
// Delete OAuth user's old carb loading plans (if any)
// Note: Drift doesn't have FK cascades - must manually delete child tables first

// Step 1: Delete carb_loading_day_meals for OAuth user's plans
await customStatement('''
  DELETE FROM carb_loading_day_meals_table
  WHERE carb_loading_day_id IN (
    SELECT id FROM carb_loading_days_table
    WHERE carb_loading_plan_id IN (
      SELECT id FROM carb_loading_plans_table WHERE user_id = ?
    )
  )
''', [toUserId]);

// Step 2: Delete carb_loading_days for OAuth user's plans
await customStatement('''
  DELETE FROM carb_loading_days_table
  WHERE carb_loading_plan_id IN (
    SELECT id FROM carb_loading_plans_table WHERE user_id = ?
  )
''', [toUserId]);

// Step 3: Delete carb_loading_plans for OAuth user
await customStatement(
  'DELETE FROM carb_loading_plans_table WHERE user_id = ?',
  [toUserId],
);
```

## Foreign Key Relationships
The correct hierarchy is:
```
carb_loading_plans_table (user_id)
  └─ carb_loading_days_table (carb_loading_plan_id)
      └─ carb_loading_day_meals_table (carb_loading_day_id)
```

**Key Issue**: `carb_loading_day_meals_table` does NOT have a `carb_loading_plan_id` column. It only has `carb_loading_day_id`, which requires the nested subquery approach.

## Deletion Order
Must delete in reverse hierarchy order (children first):
1. `carb_loading_day_meals_table` (via `carb_loading_day_id`)
2. `carb_loading_days_table` (via `carb_loading_plan_id`)
3. `carb_loading_plans_table` (via `user_id`)

## Impact
- **Bug severity**: High - causes database bloat and potential data corruption
- **User impact**: Anonymous users converting to OAuth would leave orphaned rows
- **Data cleanup**: May need migration to clean up existing orphaned rows

## Files Modified
1. `/lib/features/auth/data/user_repository.dart` - Fixed `_clearAnonymousUserLocalData`
2. `/lib/shared/database/app_database.dart` - Fixed `clearAllUserData` and `migrateAnonymousUserDataToOAuthUser`

## Testing Recommendations
1. Test anonymous user data cleanup
2. Test OAuth migration with existing carb loading plans
3. Verify no orphaned rows remain after user data operations
4. Check database integrity after delete operations

## Related Documentation
- [Database Schema](/database_schemas/v2/README.md)
- [Drift Migration Guide](/docs/technical/drift-migration-guide.md)
