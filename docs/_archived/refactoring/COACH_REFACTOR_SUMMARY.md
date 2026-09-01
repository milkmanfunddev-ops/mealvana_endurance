# Coach Mode Refactoring Summary

## Overview
This document summarizes the refactoring to move from the `is_coach` boolean flag on the users table to a dedicated `coaches` table.

## Completed

### 1. Database Migration
**File**: `/supabase/migrations/20260107_create_coaches_table.sql`

Created the `coaches` table with the following schema:
- `id` (UUID, primary key)
- `user_id` (UUID, references users table)
- `first_name` (TEXT)
- `last_name` (TEXT)
- `email` (TEXT)
- `bio` (TEXT, nullable)
- `status` (TEXT: 'pending', 'approved', 'rejected')
- `reviewed_by` (TEXT, nullable)
- `reviewed_at` (TIMESTAMPTZ, nullable)
- `rejection_reason` (TEXT, nullable)
- `created_at` (TIMESTAMPTZ)
- `updated_at` (TIMESTAMPTZ)

### 2. Drift Table Definition
**File**: `/lib/shared/database/tables/coaches_table.dart`

Updated to match the Supabase schema with proper column names.

### 3. Domain Model
**File**: `/lib/features/coach_mode/domain/coach.dart`

Updated the `Coach` class to match the new table structure:
- Changed `applicationStatus` → `status`
- Removed `submittedAt` and `approvedAt`
- Added `reviewedBy`, `reviewedAt`, `rejectionReason`

## In Progress / To Do

### 4. Repository Updates
**File**: `/lib/features/coach_mode/data/coach_repository.dart`

**Add these new methods:**

```dart
/// Get coach record for a user (from coaches table)
Future<Coach?> getCoachByUserId(String userId) async {
  try {
    final result = await (_database.select(_database.coachesTable)
          ..where((t) => t.userId.equals(userId)))
        .getSingleOrNull();

    if (result == null) return null;
    return _mapToCoachDomain(result);
  } catch (e, stackTrace) {
    _logger.error('Failed to get coach by user ID', context: 'COACH_REPOSITORY', error: e, stackTrace: stackTrace);
    rethrow;
  }
}

/// Get all approved coaches (for directory)
Future<List<Coach>> getApprovedCoaches() async {
  try {
    final results = await (_database.select(_database.coachesTable)
          ..where((t) => t.status.equals('approved'))
          ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]))
        .get();

    return results.map(_mapToCoachDomain).toList();
  } catch (e, stackTrace) {
    _logger.error('Failed to get approved coaches', context: 'COACH_REPOSITORY', error: e, stackTrace: stackTrace);
    rethrow;
  }
}

/// Submit a new coach application
Future<Coach> submitCoachApplication({
  required String userId,
  required String firstName,
  required String lastName,
  required String email,
  String? bio,
}) async {
  try {
    final id = _uuid.v4();
    final now = DateTime.now();

    final companion = CoachesTableCompanion.insert(
      id: id,
      userId: userId,
      firstName: firstName,
      lastName: lastName,
      email: email,
      bio: Value(bio),
      createdAt: Value(now),
      updatedAt: Value(now),
    );

    await _database.into(_database.coachesTable).insert(companion);

    return Coach(
      id: id,
      userId: userId,
      firstName: firstName,
      lastName: lastName,
      email: email,
      bio: bio,
      status: 'pending',
      createdAt: now,
      updatedAt: now,
    );
  } catch (e, stackTrace) {
    _logger.error('Failed to submit coach application', context: 'COACH_REPOSITORY', error: e, stackTrace: stackTrace);
    rethrow;
  }
}
```

**Add helper method:**

```dart
/// Map Drift CoachEntry to domain
Coach _mapToCoachDomain(CoachEntry entry) {
  return Coach(
    id: entry.id,
    userId: entry.userId,
    firstName: entry.firstName,
    lastName: entry.lastName,
    email: entry.email,
    bio: entry.bio,
    status: entry.status,
    reviewedBy: entry.reviewedBy,
    reviewedAt: entry.reviewedAt,
    rejectionReason: entry.rejectionReason,
    createdAt: entry.createdAt,
    updatedAt: entry.updatedAt,
  );
}
```

**Remove these old methods:**
- `getCoachInfoByUserId()` (uses is_coach)
- `getActiveCoaches()` (uses is_coach, replaced by `getApprovedCoaches()`)
- `fetchIsCoachFromSupabase()`
- `updateLocalUserIsCoach()`

### 5. Service Refactoring
**File**: `/lib/features/coach_mode/application/coach_service.dart`

**Remove these methods:**
```dart
- isCurrentUserCoach() // Replace with isCurrentUserApprovedCoach()
- getCurrentCoachInfo() // Replace with getCoachForCurrentUser()
- syncIsCoachStatus() // Delete entirely
- inviteAthleteByCode() // Athletes find coaches now, not vice versa
- inviteAthlete() // Delete
```

**Add these new methods:**
```dart
/// Check if current user is an approved coach
Future<bool> isCurrentUserApprovedCoach() async {
  try {
    final profile = await _database.getCurrentUserProfile();
    if (profile == null) return false;

    final coach = await _repository.getCoachByUserId(profile.id);
    return coach?.isApproved ?? false;
  } catch (e, stackTrace) {
    _logger.error('Failed to check approved coach status', context: 'COACH_SERVICE', error: e, stackTrace: stackTrace);
    return false;
  }
}

/// Get Coach object for current user
Future<Coach?> getCoachForCurrentUser() async {
  try {
    final profile = await _database.getCurrentUserProfile();
    if (profile == null) return null;

    return await _repository.getCoachByUserId(profile.id);
  } catch (e, stackTrace) {
    _logger.error('Failed to get coach for current user', context: 'COACH_SERVICE', error: e, stackTrace: stackTrace);
    return null;
  }
}

/// Submit coach application
Future<Coach?> submitCoachApplication({
  required String firstName,
  required String lastName,
  required String email,
  String? bio,
}) async {
  try {
    final profile = await _database.getCurrentUserProfile();
    if (profile == null) {
      _logger.warning('Cannot submit coach application: no user profile', context: 'COACH_SERVICE');
      return null;
    }

    return await _repository.submitCoachApplication(
      userId: profile.id,
      firstName: firstName,
      lastName: lastName,
      email: email,
      bio: bio,
    );
  } catch (e, stackTrace) {
    _logger.error('Failed to submit coach application', context: 'COACH_SERVICE', error: e, stackTrace: stackTrace);
    rethrow;
  }
}

/// Get all approved coaches for directory
Future<List<Coach>> getApprovedCoaches() async {
  try {
    return await _repository.getApprovedCoaches();
  } catch (e, stackTrace) {
    _logger.error('Failed to get approved coaches', context: 'COACH_SERVICE', error: e, stackTrace: stackTrace);
    return [];
  }
}

/// Request coach connection (athlete requests to connect with coach)
Future<bool> requestCoachConnection(String coachUserId) async {
  try {
    final profile = await _database.getCurrentUserProfile();
    if (profile == null) {
      _logger.warning('Cannot request coach: no user profile', context: 'COACH_SERVICE');
      return false;
    }

    final relationship = await _repository.createRelationship(
      coachUserId: coachUserId,
      athleteUserId: profile.id,
      requestedBy: 'athlete',
    );

    return relationship != null;
  } catch (e, stackTrace) {
    _logger.error('Failed to request coach connection', context: 'COACH_SERVICE', error: e, stackTrace: stackTrace);
    return false;
  }
}
```

**Update existing method:**
```dart
/// Get all athletes for the current coach
Future<List<CoachAthleteRelationship>> getMyAthletes() async {
  try {
    final profile = await _database.getCurrentUserProfile();
    if (profile == null) return [];

    // Check coaches table instead of is_coach
    final coach = await _repository.getCoachByUserId(profile.id);
    if (coach == null || !coach.isApproved) return [];

    return await _repository.getActiveRelationshipsForCoach(profile.id);
  } catch (e, stackTrace) {
    _logger.error('Failed to get athletes', context: 'COACH_SERVICE', error: e, stackTrace: stackTrace);
    return [];
  }
}
```

### 6. UI Updates
**File**: `/lib/features/coach_mode/presentation/screens/coach_dashboard_screen.dart`

**Remove:**
- FloatingActionButton for "Invite Athlete" (lines 42-48)
- `_showInviteAthleteDialog()` method (lines 385-461)
- Import for invite_athlete_controller if present

**Update:**
- Change `isCoach` check to use `isCurrentUserApprovedCoach()`
- Update empty state text to remove "Invite Athlete" mention (line 297)

### 7. Delete Files
**Delete**: `/lib/features/coach_mode/presentation/providers/invite_athlete_controller.dart`

### 8. Code Generation
Run after all changes:
```bash
flutter pub run build_runner build --delete-conflicting-outputs
```

### 9. Database Migration
Run the Supabase migration:
```bash
# In Supabase dashboard or via CLI
supabase db push
```

## Migration Path

1. Run Supabase migration to create coaches table
2. (Optional) Migrate existing is_coach=true users to coaches table with status='approved'
3. Update code to use new coaches table
4. Run code generation
5. Test thoroughly
6. (Future) Remove is_coach column from users table

## Breaking Changes

- `CoachInfo` class removed, replaced with `Coach` class
- `isCurrentUserCoach()` → `isCurrentUserApprovedCoach()`
- `getCurrentCoachInfo()` → `getCoachForCurrentUser()`
- Coach invitation flow removed (athletes now find and request coaches)

## Notes

- The `is_coach` column on users table is NOT removed yet for backward compatibility
- Coaches table uses status='approved' to indicate active coaches
- Athletes initiate connections via `requestCoachConnection()`
- Coaches accept/decline athlete requests (existing functionality preserved)
