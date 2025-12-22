# Fix: Allergies Type Cast Error in User Repository

## Date
2025-12-19

## Issue
**Sentry Error**: `TypeError: type 'List<dynamic>' is not a subtype of type 'String?' in type cast`

**Location**: `lib/features/auth/data/user_repository.dart:677` in `UserRepository._parseUserFromSupabase`

**Scenario**: Error occurred during Google OAuth sign-in with user migration (consolidating anonymous user data to authenticated user)

## Root Cause

The migration `supabase/migrations/20251218_add_preferences_and_sports_columns.sql` changed the `allergies` column from a simple `text` type to a proper **PostgreSQL enum array**:

**Before**:
```sql
allergies text default '{}'::text
```

**After**:
```sql
allergies public.allergy_enum[] DEFAULT '{}'::public.allergy_enum[]
```

When Supabase returns PostgreSQL array columns, it serializes them as JSON arrays (`List<dynamic>`), NOT as string representations. The code was attempting to cast this to `String?`, causing the type error.

## Solution

Added a new helper method `_parseAllergiesFromSupabase()` that handles both formats:

1. **New format**: `List<dynamic>` from PostgreSQL enum array (current Supabase response)
2. **Legacy format**: `String` in PostgreSQL text format like `"{dairy,gluten}"` (backwards compatibility)

### Code Changes

**File**: `lib/features/auth/data/user_repository.dart`

**Changed line 677 from**:
```dart
allergies: Allergy.fromDbArray(userData['allergies'] as String?),
```

**To**:
```dart
allergies: _parseAllergiesFromSupabase(userData['allergies']),
```

**Added new helper method**:
```dart
/// Parse allergies from Supabase response, handling both formats:
/// - New format: `List<dynamic>` from PostgreSQL allergy_enum[] array
/// - Legacy format: String in PostgreSQL text format like "{dairy,gluten}"
List<Allergy> _parseAllergiesFromSupabase(dynamic value) {
  if (value == null) return [];

  // New format: List<dynamic> from PostgreSQL enum array
  // This is what Supabase returns after the 20251218 migration
  if (value is List) {
    return value
        .map((item) => Allergy.fromDbValue(item.toString()))
        .whereType<Allergy>()
        .toList();
  }

  // Legacy format: String in PostgreSQL text format
  // For backwards compatibility with old data
  if (value is String) {
    return Allergy.fromDbArray(value);
  }

  return [];
}
```

## Impact

- **Fixes**: Google OAuth sign-in crash during user migration
- **Backwards Compatible**: Still handles legacy string format from old data
- **No Breaking Changes**: Existing functionality preserved

## Testing Recommendations

1. Test Google OAuth sign-in with users who have allergies set
2. Test user migration scenarios (anonymous → authenticated)
3. Verify users with existing allergy data can still sign in
4. Test new users setting allergies during onboarding

## Related Files

- `lib/features/auth/data/user_repository.dart` - Main fix
- `lib/features/onboarding/domain/allergy.dart` - Allergy enum and parsing methods
- `supabase/migrations/20251218_add_preferences_and_sports_columns.sql` - Schema migration that caused the issue
