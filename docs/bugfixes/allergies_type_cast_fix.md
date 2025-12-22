# Allergies Type Cast Fix

**Status**: ✅ FIXED
**Date**: 2025-12-18
**Error**: `type 'List<dynamic>' is not a subtype of type 'String?' in type cast`

## Problem

When syncing user profiles from Supabase, the app crashed with:
```
type 'List<dynamic>' is not a subtype of type 'String?' in type cast
```

**Stack Trace**:
```
AuthRepositoryEdge.upsertUserProfile (lib/features/auth/data/auth_repository_edge.dart:396)
UserProfile.fromJson (lib/features/auth/domain/user_preferences.dart:138)
```

## Root Cause

PostgreSQL stores `allergies` as an array type (`allergy_enum[]`), which Supabase returns as a Dart `List<dynamic>`. However, the `UserProfile.fromJson()` method was casting it directly to `String?`:

```dart
// BROKEN (line 138):
allergies: Allergy.fromDbArray(json['allergies'] as String?),
//                                                  ^^^^^^^^ Type error!
```

This worked fine with Drift (local SQLite) which stores allergies as a string, but failed when loading from Supabase.

## Solution

Added a helper method `_parseAllergiesFromJson()` that handles both formats:

```dart
/// Parse allergies from JSON - handles both String and List formats
/// - PostgreSQL returns arrays as `List<dynamic>`
/// - Drift may return as String in legacy format
static List<Allergy> _parseAllergiesFromJson(dynamic allergiesData) {
  if (allergiesData == null) return [];

  // If it's a List (from Supabase PostgreSQL array)
  if (allergiesData is List) {
    return allergiesData
        .map((item) => Allergy.fromDbValue(item.toString()))
        .whereType<Allergy>()
        .toList();
  }

  // If it's a String (from Drift or legacy format)
  if (allergiesData is String) {
    return Allergy.fromDbArray(allergiesData);
  }

  return [];
}
```

**Updated fromJson (line 138)**:
```dart
// FIXED:
allergies: _parseAllergiesFromJson(json['allergies']),
```

## Why This Happened

The PostgreSQL migration added `allergies` as an array column:
```sql
ALTER TABLE public.users ADD COLUMN allergies public.allergy_enum[] DEFAULT '{}'::public.allergy_enum[];
```

When the Edge Function returns user data, PostgreSQL serializes this as a JSON array `["dairy", "gluten"]`, which Dart deserializes as `List<dynamic>`, not `String`.

## Data Flow

### Before Fix (BROKEN)
```
PostgreSQL: allergies = {dairy,gluten}
    ↓
Supabase Response: {"allergies": ["dairy", "gluten"]}
    ↓
Dart json['allergies']: List<dynamic> ["dairy", "gluten"]
    ↓
Cast to String?: ❌ TYPE ERROR
```

### After Fix (WORKING)
```
PostgreSQL: allergies = {dairy,gluten}
    ↓
Supabase Response: {"allergies": ["dairy", "gluten"]}
    ↓
Dart json['allergies']: List<dynamic> ["dairy", "gluten"]
    ↓
_parseAllergiesFromJson(): ✅ Handles List<dynamic>
    ↓
List<Allergy> [Allergy.dairy, Allergy.gluten]
```

## Files Modified

1. **lib/features/auth/domain/user_preferences.dart**
   - Added `_parseAllergiesFromJson()` helper method (lines 100-120)
   - Updated `UserProfile.fromJson()` to use helper (line 138)

## Testing

### Reproduction Steps (Before Fix)
1. Complete onboarding
2. Add allergies (e.g., "Dairy", "Gluten")
3. Proceed to next screen
4. ❌ App crashes with type cast error

### Verification Steps (After Fix)
1. Hot restart the app (`r` in terminal)
2. Complete onboarding
3. Add allergies
4. Proceed to next screen
5. ✅ No crash - allergies sync successfully
6. Check Supabase database:
   ```sql
   SELECT device_id, allergies FROM users WHERE allergies IS NOT NULL;
   ```
7. Should see: `{dairy,gluten}` in PostgreSQL

## Related Issues

This is the second type mismatch we've encountered with the PostgreSQL schema:

1. **Dietary Preference "none" fix** - Mapped `DietaryPreference.none` to `NULL`
2. **Allergies type cast fix** (this fix) - Handle PostgreSQL arrays as Dart lists

Both issues stem from differences between:
- **Drift (local)**: Stores as strings, deserializes as strings
- **Supabase (cloud)**: Stores as PostgreSQL types, deserializes as Dart native types

## Prevention

Future schema changes should consider:
1. **Test with both Drift and Supabase** - Ensure fromJson handles both formats
2. **Document type mappings** - PostgreSQL arrays → Dart lists, enums → strings
3. **Use dynamic typing** - Accept `dynamic` instead of explicit casts when Supabase types differ

## Impact

- ✅ Fixes 100% failure rate on user creation with allergies
- ✅ Fixes sport preferences sync errors
- ✅ Enables users to save dietary restrictions
- ✅ Backwards compatible with Drift string format
