# Consolidated User Profile Edge Function

## Overview
This document describes the consolidated approach for managing user profiles via the `upsert-user-profile` Edge Function (currently using the existing `update-user-preferences` endpoint).

## Problem Statement
Previously, we had multiple Edge Functions for user profile operations:
- `create-user` - Create new user profiles
- `save-food-preferences` - Save food preferences during onboarding
- `update-user-preferences` - Update dietary preferences, allergies, and sport preferences

This led to:
- Multiple network roundtrips during onboarding
- Duplicated validation logic across Edge Functions
- Inconsistent error handling
- Higher maintenance overhead

## Solution: Consolidated Edge Function

### New Approach
A single `upsertUserProfile()` method in `AuthRepositoryEdge` that handles ALL user profile operations:
- Basic profile data (gender, birthday, height, weight, etc.)
- Food preferences with preference levels
- Dietary preference
- Allergies
- Sport preferences (cycling, swimming, running)
- Metadata (onboarding_completed, app_version)

### Benefits
1. **Reduced Network Calls**: Single call instead of 3-5 separate calls
2. **Atomic Operations**: All updates in one transaction
3. **Consistent Error Handling**: Single code path for all profile updates
4. **Better Offline Support**: Save locally first, sync to Supabase second
5. **Easier Maintenance**: One Edge Function to maintain instead of three

## Implementation

### Client-Side Changes

#### 1. AuthRepositoryEdge (`/lib/features/auth/data/auth_repository_edge.dart`)

**New Method:**
```dart
Future<UpsertUserProfileResult> upsertUserProfile(
  String userId, {
  // Basic profile fields
  String? gender,
  String? birthday,
  int? heightFeet,
  int? heightInches,
  double? weightPounds,
  bool? runsWithWaterBottle,
  String? gutTrainingLevel,
  // Food preferences
  Map<String, String>? foodPreferences,
  Map<String, int>? preferenceLevels,
  // Dietary preference & allergies
  String? dietaryPreference,
  List<String>? allergies,
  // Sport preferences
  bool? giSensitivity,
  int? cyclingFtpWatts,
  int? typicalBikeBottles,
  bool? hasAeroBottle,
  bool? hasBentoBox,
  int? swimmingCssSecondsPer100m,
  bool? typicalWetsuit,
  String? typicalSwimCapType,
  // Metadata
  bool? onboardingCompleted,
  String? appVersion,
})
```

**Deprecated Methods:**
- `updateUserPreferences()` - Now routes through `upsertUserProfile()`
- These are kept for backward compatibility but marked as deprecated

#### 2. AuthService (`/lib/features/auth/application/auth_service.dart`)

**Updated Methods:**
All methods now use the consolidated `upsertUserProfile()`:

1. **`createUser()`** - Creates initial user profile
   - Saves locally first (offline-first)
   - Syncs to Supabase via `upsertUserProfile()`
   - Includes basic profile fields + app_version

2. **`updateSportPreferences()`** - Updates cycling/swimming/running preferences
   - Saves locally first
   - Syncs via `upsertUserProfile()` with only sport fields

3. **`updateDietaryPreference()`** - Updates dietary preference
   - Saves locally first
   - Syncs via `upsertUserProfile()` with only dietary_preference

4. **`updateAllergies()`** - Updates allergies list
   - Saves locally first
   - Syncs via `upsertUserProfile()` with only allergies

5. **`saveFoodPreferences()`** - Saves food preferences during onboarding
   - Saves locally first
   - Syncs via `upsertUserProfile()` with food_preferences + preference_levels + onboarding_completed

### Offline-First Pattern

All methods follow the same pattern:
```dart
// 1. Save locally first (works offline)
final userRepo = await _userRepository;
await userRepo.updateUserProfile(updatedProfile);

// 2. Sync to Supabase (graceful degradation if offline)
try {
  final result = await _authRepositoryEdge.upsertUserProfile(
    userId,
    // only the fields being updated
  );
  
  if (!result.success) {
    _logger.warning('Failed to sync to Supabase');
    // Don't throw - local save succeeded
  }
} catch (e) {
  _logger.error('Error syncing to Supabase');
  // Don't throw - local save succeeded
}
```

### Error Handling

- **Local Save Fails**: Throw exception (critical - user data not saved)
- **Supabase Sync Fails**: Log warning but don't throw (local save succeeded, can retry later)
- **Edge Function Returns Failure**: Log warning but don't throw (local save succeeded)

This ensures the app works offline and degrades gracefully when Supabase is unavailable.

## Server-Side Changes (To Do)

### Current State
Currently using the existing `update-user-preferences` Edge Function, which supports:
- dietary_preference
- allergies
- gi_sensitivity
- Sport-specific fields (cycling, swimming)

### Required Updates
The Edge Function needs to be enhanced to support:
1. **Food Preferences**: Accept `food_preferences` and `preference_levels` maps
2. **Basic Profile Fields**: Accept gender, birthday, height, weight, gut_training_level
3. **Metadata**: Accept onboarding_completed, app_version
4. **Upsert Logic**: Use `upsert()` instead of `update()` to handle create + update

### Migration Strategy
1. **Phase 1 (Current)**: Client code updated to use consolidated method
2. **Phase 2**: Update Edge Function to support all fields
3. **Phase 3**: Remove old deprecated Edge Functions (create-user, save-food-preferences)

## Testing

### Manual Testing Checklist
- [ ] Create new user during onboarding
- [ ] Update sport preferences (cycling, swimming)
- [ ] Update dietary preference
- [ ] Update allergies
- [ ] Save food preferences during onboarding
- [ ] Test offline mode (all operations should save locally)
- [ ] Test sync when coming back online

### Edge Cases
- [ ] User already exists (should update, not create duplicate)
- [ ] Partial field updates (only some fields provided)
- [ ] Empty arrays (allergies = [], food_preferences = {})
- [ ] Null values (dietary_preference = null to clear)

## Migration Notes

### Backward Compatibility
- Old Edge Functions remain in place during transition
- `updateUserPreferences()` method deprecated but still works
- Can deploy client changes before server changes (degrades gracefully)

### Rollback Plan
If issues arise:
1. Revert client changes (use old methods)
2. Old Edge Functions still exist and work
3. No database schema changes required

## Future Enhancements

1. **Batch Operations**: Support updating multiple users at once
2. **Diff Detection**: Only send changed fields to reduce payload size
3. **Optimistic Updates**: Update UI immediately, sync in background
4. **Conflict Resolution**: Handle concurrent updates from multiple devices

## Related Documentation
- [Fat Backend Architecture](/docs/technical/fat-backend-architecture.md)
- [FOA Architecture](/docs/technical/foa-architecture.md)
- [Drift Database](/docs/database/drift/README.md)

---

**Last Updated**: 2025-12-18
**Author**: Claude Code Assistant
**Status**: Phase 1 Complete (Client-Side)
