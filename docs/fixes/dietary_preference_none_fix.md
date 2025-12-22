# Dietary Preference "No Preference" Database Constraint Fix

## Issue

When users selected "No Preference" for dietary preference, the app crashed with:

```
SqliteException(275): CHECK constraint failed: dietary_preference IN ('omnivore', 'vegetarian', 'pescatarian', 'vegan', 'mediterranean', 'paleo', 'keto', 'low_carb') OR dietary_preference IS NULL
```

## Root Cause

The database constraint only allows specific enum values OR `NULL`, but the app was trying to save the string `"none"`.

### Data Flow Before Fix

1. User selects "No Preference" in UI → `DietaryPreference.none`
2. Domain model has `dietaryPreference: DietaryPreference.none`
3. Save to database → `DietaryPreference.none.dbValue` returns `"none"` (via default case in enum)
4. Database INSERT/UPDATE with value `"none"` ❌ **CONSTRAINT VIOLATION**

## Solution

Map `DietaryPreference.none` to database `NULL` in both directions:

### Save Flow (Domain → Database)

**Domain**: `DietaryPreference.none` → **Database**: `NULL`

### Load Flow (Database → Domain)

**Database**: `NULL` → **Domain**: `DietaryPreference.none`

## Implementation

### Files Modified

1. **`app_database.dart`** - Database save/load conversions
2. **`user_repository.dart`** - Supabase sync conversions

### Changes in `app_database.dart`

**Save Methods** (`saveUserProfile()` and `updateUserProfile()`):

```dart
// BEFORE (BROKEN):
dietaryPreference: Value(profile.dietaryPreference?.dbValue),

// AFTER (FIXED):
dietaryPreference: Value(
  profile.dietaryPreference == null || profile.dietaryPreference == DietaryPreference.none
    ? null
    : profile.dietaryPreference!.dbValue
),
```

**Load Method** (`_convertToDomainUserProfile()`):

```dart
// BEFORE (INCOMPLETE):
dietaryPreference: DietaryPreference.fromDbValue(dbUser.dietaryPreference),
// Returns null when dbUser.dietaryPreference is null

// AFTER (COMPLETE):
dietaryPreference: DietaryPreference.fromDbValue(dbUser.dietaryPreference) ?? DietaryPreference.none,
// Returns DietaryPreference.none when dbUser.dietaryPreference is null
```

### Changes in `user_repository.dart`

**Supabase Sync** (`_parseUserFromSupabase()`):

```dart
// BEFORE (INCOMPLETE):
dietaryPreference: DietaryPreference.fromDbValue(userData['dietary_preference'] as String?),

// AFTER (COMPLETE):
dietaryPreference: DietaryPreference.fromDbValue(userData['dietary_preference'] as String?) ?? DietaryPreference.none,
```

## Why This Design?

### Option 1: Remove `DietaryPreference.none` from enum (rejected)
- Would break existing UI that uses `none` value
- Would require updating all UI components

### Option 2: Allow `"none"` in database constraint (rejected)
- Inconsistent with database design (null means "no preference" is more standard)
- Requires migration on production

### Option 3: Map `none` ↔ `NULL` (✅ chosen)
- No database migration needed
- No UI changes needed
- Follows SQL convention (NULL = no value)
- Minimal code changes

## Data Model Layers

```
┌─────────────────────────────────────────────────────────┐
│ UI Layer                                                │
│ - "No Preference" option                                │
│ - Represented as: DietaryPreference.none (enum value)   │
└─────────────────────────────────────────────────────────┘
                          ↕
┌─────────────────────────────────────────────────────────┐
│ Domain Layer (UserProfile)                              │
│ - Field: dietaryPreference: DietaryPreference?          │
│ - Value: DietaryPreference.none (never null in practice)│
└─────────────────────────────────────────────────────────┘
                          ↕
              Conversion happens here
    DietaryPreference.none ↔ NULL (database)
                          ↕
┌─────────────────────────────────────────────────────────┐
│ Database Layer (Drift SQLite / Supabase PostgreSQL)    │
│ - Column: dietary_preference TEXT                       │
│ - Value: NULL (or 'omnivore', 'vegetarian', etc.)      │
│ - Constraint: Enum values OR NULL only                  │
└─────────────────────────────────────────────────────────┘
```

## Testing

### Test Cases

1. **Save "No Preference"**:
   - Select "No Preference" in UI
   - Save → Database should have `NULL` (not `"none"`)
   - No constraint violation error

2. **Load "No Preference"**:
   - Database has `NULL` for dietary_preference
   - Load → Domain should have `DietaryPreference.none`
   - UI should show "No Preference" selected

3. **Round Trip**:
   - Save "No Preference" → Load → Should still be "No Preference"
   - Save "Vegetarian" → Load → Should still be "Vegetarian"

### Verification Query

```sql
-- Check that "No Preference" users have NULL, not "none"
SELECT id, dietary_preference
FROM users
WHERE dietary_preference IS NULL OR dietary_preference = 'none';

-- Expected: dietary_preference should be NULL for "no preference" users
-- If you see 'none', the fix isn't working
```

## Related Code

- **Enum Definition**: `/lib/features/onboarding/domain/dietary_preference.dart`
- **Database Schema**: `/lib/shared/database/tables/user_profiles.dart`
- **Domain Model**: `/lib/features/auth/domain/user_preferences.dart`
- **UI Screens**:
  - `/lib/features/onboarding/presentation/screens/dietary_preference_screen.dart`
  - `/lib/features/settings/presentation/screens/food_settings_consolidated_screen.dart`

## Prevention

To prevent similar issues in the future:

1. **Enum Design**: Avoid having both `null` and a `none` enum value - use one or the other
2. **Database Constraints**: Document which values are allowed in database
3. **Conversion Testing**: Add unit tests for enum ↔ database conversions
4. **Schema Validation**: Validate that enum values match database constraints

## Impact

- ✅ Users can now select "No Preference" without crashes
- ✅ Database constraint satisfied (NULL instead of invalid "none")
- ✅ No migration needed on production
- ✅ No UI changes needed
- ✅ Consistent with SQL conventions
