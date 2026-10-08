import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../features/auth/domain/user_preferences.dart';
import '../../../database/app_database.dart';
import '../../../database/database_provider.dart';
import '../../report/report.dart';

part 'user_sync_handler.g.dart';

@Riverpod(keepAlive: true)
UserSyncHandler userSyncHandler(Ref ref) {
  return UserSyncHandler(
    database: ref.read(appDatabaseProvider),
    supabase: Supabase.instance.client,
    report: ref.read(reportProvider),
  );
}

/// Handles sync operations for user profile entities.
class UserSyncHandler {
  const UserSyncHandler({
    required AppDatabase database,
    required SupabaseClient supabase,
    Report? report,
  }) : _database = database,
       _supabase = supabase,
       _report = report;

  final AppDatabase _database;
  final SupabaseClient _supabase;
  final Report? _report;

  /// Injected by the provider; tests may pass a `RecordingReport`.
  Report get _r => _report ?? SentryReport.global;

  /// Ensure user profile exists in Supabase before syncing dependent records.
  /// This prevents foreign key violations on activities, events, etc.
  ///
  /// MULTI-DEVICE FIX: If no local user profile exists but user is authenticated,
  /// fetch the profile from Supabase first (important for new device login).
  ///
  /// SIGN-BACK-IN FIX: If local user ID doesn't match the auth user ID,
  /// fetch the correct profile from Supabase (important for sign-out/sign-in flow).
  Future<void> syncUsers(String userId) async {
    try {
      // Get the current user profile from local database for this auth user
      var localUser = await _database.userDao.getCurrentUserProfile(
        currentAuthUserId: userId,
      );

      // SIGN-BACK-IN FIX: Check if local user ID matches the auth user ID
      // After sign-out, local DB has anonymous user, but we're syncing as OAuth user
      final needsRemoteFetch =
          localUser == null ||
          localUser.id.toLowerCase() != userId.toLowerCase();

      if (needsRemoteFetch) {
        final remoteUser = await _supabase
            .from('users')
            .select('*')
            .eq('id', userId)
            .maybeSingle();

        if (remoteUser != null) {
          // Save the remote profile to local database
          await saveRemoteUserProfile(remoteUser, userId);

          // Re-fetch the local user after saving
          localUser = await _database.userDao.getCurrentUserProfile(
            currentAuthUserId: userId,
          );
        } else {
          return; // No profile anywhere - user needs to onboard
        }
      }

      // At this point localUser should not be null
      if (localUser == null) {
        _r.degraded(
          const LoggedFault(
            'Failed to establish user profile after fetch attempt',
          ),
          area: 'sync',
          extra: {'userId': userId},
        );
        return;
      }

      // Serialize the FULL profile via the canonical domain mapping — the
      // same `toJson()` the dirty-record upload uses. The old hand-rolled
      // subset here omitted unit_system, sweat_rate, first/last name and
      // nutrition_target_overrides, so the FIRST server copy of a new user's
      // profile (this runs before dependent-record sync) was missing their
      // name, units and plan-reveal edits.
      // CRITICAL: Use userId (auth UUID) as the primary id, not localUser.id.
      // device_id is pinned to userId too: users.device_id carries a UNIQUE
      // index, and a migrated profile can still hold the anon uid as its
      // deviceId while the server keeps that same device_id under the anon
      // row — upserting it unpinned raises 23505, and this method's rethrow
      // then blocks EVERY downstream entity sync until the collision clears.
      final userData = localUser.toJson()
        ..['id'] = userId
        ..['device_id'] = userId
        ..['updated_at'] = DateTime.now().toUtc().toIso8601String();

      // Upsert user profile to Supabase
      await _supabase
          .from('users')
          .upsert(
            userData,
            onConflict: 'id', // Resolve on primary key
          );
    } catch (e) {
      // Re-throw to prevent syncing dependent records if user sync fails;
      // the caller reports. The breadcrumb names the FK consequence.
      _r.breadcrumb(
        'User profile sync failed; dependent records would violate FKs',
        category: 'sync',
        data: {'userId': userId, 'error': e.toString()},
      );
      rethrow;
    }
  }

  /// Save a remote user profile to the local Drift database.
  /// Used when logging into a new device with an existing account.
  ///
  /// DIRTY GUARD: if the local row for this user is marked `needs_upload`,
  /// the local copy is newer than the server's and must win — skip the
  /// overwrite and let the pending upload reconcile. Without this, the
  /// post-sign-in sync replaced a freshly-onboarded profile with the (often
  /// stale or stub) server row.
  ///
  /// Parses via [UserProfile.fromSupabaseRow] and saves via the DAO's
  /// canonical mapping. The old inline companion here listed only a subset of
  /// columns, so every field it didn't know about (unit_system, sweat_rate,
  /// nutrition_target_overrides, dietary preference, allergies) was reset to
  /// its table default by the full-row replace — and it hardcoded imperial
  /// pace/distance units for metric athletes.
  Future<void> saveRemoteUserProfile(
    Map<String, dynamic> remoteUser,
    String userId,
  ) async {
    try {
      final localRow = await (_database.select(
        _database.userProfilesTable,
      )..where((t) => t.id.equals(userId))).getSingleOrNull();

      if (localRow?.needsUpload == true) {
        _r.info(
          'Skipped remote profile overwrite — local row is dirty and wins',
          area: 'sync',
          data: {'userId': userId},
        );
        return;
      }

      final profile = UserProfile.fromSupabaseRow(
        remoteUser,
        fallbackId: userId,
      );

      // The row we just fetched came from an authenticated session, so this
      // is a real account regardless of what the (possibly legacy) row says.
      // deviceId is pinned to userId (unified-auth convention, matching the
      // old behavior) — using the remote row's device_id here could collide
      // with this device's still-dirty anonymous row and get it deleted by
      // the DAO's same-device cleanup.
      await _database.userDao.saveUserProfile(
        profile.copyWith(id: userId, deviceId: userId, isAnonymous: false),
        needsUpload: false,
      );
    } catch (e) {
      _r.breadcrumb(
        'Saving the remote user profile locally failed',
        category: 'sync',
        data: {'userId': userId, 'error': e.toString()},
      );
      rethrow;
    }
  }

  /// Upload user profile to Supabase.
  /// Uses direct upsert instead of edge function for simplicity.
  ///
  /// Serializes via the canonical DAO domain mapping + `toJson()` — the same
  /// payload as `UserRepository.uploadDirtyRecords`. This method is the FIRST
  /// server write for a brand-new user (called from `saveAllOnboardingData`
  /// before dependent-record sync), and its old hand-rolled map omitted
  /// first/last name, unit_system, sweat_rate and nutrition_target_overrides
  /// — so the initial server copy of a fresh onboarding was incomplete.
  Future<void> uploadUserProfile(UserProfileEntry profile) async {
    try {
      final userData = _database.userDao.toDomainProfile(profile).toJson()
        ..['updated_at'] = DateTime.now().toUtc().toIso8601String();

      // Upsert to Supabase using primary key (id) for conflict resolution
      await _supabase.from('users').upsert(userData, onConflict: 'id');

      // Mark as synced, unless a local write landed during the upload: that
      // row stays dirty for the next pass.
      await _database.userDao.clearNeedsUploadIfUnchanged(profile);
    } catch (e, stackTrace) {
      // Don't rethrow - allow other uploads to continue. The row stays
      // dirty for the next pass.
      await _r.fault(
        e,
        stackTrace: stackTrace,
        area: 'sync',
        message: 'Failed to upload user profile',
        tags: {'entity': 'users'},
        extra: {'userId': profile.id},
      );
    }
  }

  /// Upload food preferences to Supabase food_preferences table.
  /// Ensures the normalized table is synced (not just the JSONB in users table).
  Future<void> uploadFoodPreferences(String userId) async {
    try {
      // Get all food preference entries from local database
      final entries = await _database.foodPreferencesDao
          .getAllFoodPreferenceEntries(userId);

      if (entries.isEmpty) {
        return;
      }

      // Convert to Supabase format
      final rows = entries
          .map(
            (entry) => {
              'id': entry.id,
              'user_id': entry.userId,
              'food_name': entry.foodName,
              'preference': entry.preference,
              'preference_level': entry.preferenceLevel,
              'created_at': entry.createdAt.toUtc().toIso8601String(),
              'updated_at': entry.updatedAt.toUtc().toIso8601String(),
            },
          )
          .toList();

      // Upsert to Supabase food_preferences table
      await _supabase
          .from('food_preferences')
          .upsert(
            rows,
            onConflict: 'user_id,food_name', // Use composite unique key
          );
    } catch (e, stackTrace) {
      // Don't rethrow - allow other uploads to continue
      await _r.fault(
        e,
        stackTrace: stackTrace,
        area: 'sync',
        message: 'Failed to upload food preferences',
        tags: {'entity': 'food_preferences'},
        extra: {'userId': userId},
      );
    }
  }
}
