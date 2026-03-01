import 'package:drift/drift.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../database/app_database.dart';
import '../../../database/database_provider.dart';
import '../../../utils/enum_parsers.dart';
import '../../logging_service.dart';

part 'user_sync_handler.g.dart';

@Riverpod(keepAlive: true)
UserSyncHandler userSyncHandler(Ref ref) {
  return UserSyncHandler(
    database: ref.read(appDatabaseProvider),
    logger: ref.read(appLoggerProvider),
    supabase: Supabase.instance.client,
  );
}

/// Handles sync operations for user profile entities.
class UserSyncHandler {
  const UserSyncHandler({
    required AppDatabase database,
    required AppLogger logger,
    required SupabaseClient supabase,
  })  : _database = database,
        _logger = logger,
        _supabase = supabase;

  final AppDatabase _database;
  final AppLogger _logger;
  final SupabaseClient _supabase;

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
      final needsRemoteFetch = localUser == null ||
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
        _logger.warning(
          'Failed to establish user profile after fetch attempt',
          context: 'USER_SYNC',
          data: {'userId': userId},
        );
        return;
      }

      // Sync ALL fields that exist in PRODUCTION schema (source of truth)
      // CRITICAL: Use userId (auth UUID) as the primary id, not localUser.id
      final userData = {
        'id': userId,
        'device_id': userId, // Keep for backward compatibility
        'gender': localUser.gender.name,
        'birthday': localUser.birthday.toIso8601String().split('T')[0],
        'height_feet': localUser.heightFeet,
        'height_inches': localUser.heightInches,
        'weight_pounds': localUser.weightPounds,
        'runs_with_water_bottle': localUser.runsWithWaterBottle,
        'gut_training_level': localUser.gutTraining.name,
        'onboarding_completed': localUser.onboardingCompleted,
        'app_version': localUser.appVersion,
        'created_at': localUser.createdAt.toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
        'cycling_ftp_watts': localUser.ftpWatts,
        'prefers_cycling_power': false,
        'swimming_css_seconds_per_100m': localUser.cssPacePer100mSeconds,
        'prefers_swimming_pace': false,
        'first_name': localUser.firstName,
        'last_name': localUser.lastName,
      };

      // Upsert user profile to Supabase
      await _supabase.from('users').upsert(
        userData,
        onConflict: 'id', // Resolve on primary key
      );
    } catch (e, stackTrace) {
      _logger.error(
        'Failed to sync user profile - this may cause FK violations',
        context: 'USER_SYNC',
        error: e,
        stackTrace: stackTrace,
      );
      // Re-throw to prevent syncing dependent records if user sync fails
      rethrow;
    }
  }

  /// Save a remote user profile to the local Drift database.
  /// Used when logging into a new device with an existing account.
  Future<void> saveRemoteUserProfile(
    Map<String, dynamic> remoteUser,
    String userId,
  ) async {
    try {
      final companion = UserProfilesTableCompanion.insert(
        id: userId,
        deviceId: userId, // In unified auth, deviceId == userId
        isAnonymous: const Value(false), // OAuth user = not anonymous
        authProvider: Value(remoteUser['auth_provider'] as String? ?? 'google'),
        gender: Value(EnumParsers.parseGender(remoteUser['gender'] as String?)),
        birthday: Value(DateTime.tryParse(remoteUser['birthday'] as String? ?? '') ??
            DateTime(1990, 1, 1)),
        heightFeet: Value(remoteUser['height_feet'] as int? ?? 5),
        heightInches: Value(remoteUser['height_inches'] as int? ?? 8),
        weightPounds: Value((remoteUser['weight_pounds'] as num?)?.toDouble() ?? 150.0),
        runsWithWaterBottle: Value(remoteUser['runs_with_water_bottle'] as bool? ?? true),
        preferredPaceUnit: const Value('minPerMile'),
        preferredDistanceUnit: const Value('miles'),
        gutTrainingLevel: Value(EnumParsers.parseGutTrainingLevel(
            remoteUser['gut_training_level'] as String?)),
        onboardingCompleted: Value(remoteUser['onboarding_completed'] as bool? ?? false),
        appVersion: Value(remoteUser['app_version'] as String?),
        createdAt: Value(DateTime.tryParse(remoteUser['created_at'] as String? ?? '') ??
            DateTime.now()),
        updatedAt: Value(DateTime.tryParse(remoteUser['updated_at'] as String? ?? '') ??
            DateTime.now()),
        firstName: Value(remoteUser['first_name'] as String?),
        lastName: Value(remoteUser['last_name'] as String?),
      );

      await _database
          .into(_database.userProfilesTable)
          .insert(companion, mode: InsertMode.insertOrReplace);
    } catch (e, stackTrace) {
      _logger.error(
        'Failed to save remote user profile locally',
        context: 'USER_SYNC',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Upload user profile to Supabase.
  /// Uses direct upsert instead of edge function for simplicity.
  Future<void> uploadUserProfile(UserProfileEntry profile) async {
    try {
      final userData = {
        'id': profile.id,
        'device_id': profile.deviceId,
        'auth_user_id': profile.authUserId,
        'auth_provider': profile.authProvider,
        'is_anonymous': profile.isAnonymous,
        'gender': profile.gender,
        'birthday': profile.birthday?.toIso8601String().split('T')[0],
        'height_feet': profile.heightFeet,
        'height_inches': profile.heightInches,
        'weight_pounds': profile.weightPounds,
        'runs_with_water_bottle': profile.runsWithWaterBottle,
        'food_preferences': profile.foodPreferences,
        'gut_training_level': profile.gutTrainingLevel,
        'onboarding_completed': profile.onboardingCompleted,
        'app_version': profile.appVersion,
        // Convert 'none' to null since Supabase dietary_preference_enum doesn't include 'none'
        'dietary_preference':
            profile.dietaryPreference == 'none' ? null : profile.dietaryPreference,
        'allergies': profile.allergies,
        'created_at': profile.createdAt.toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      };

      // Upsert to Supabase using primary key (id) for conflict resolution
      await _supabase.from('users').upsert(
        userData,
        onConflict: 'id',
      );

      // Mark as synced in local database
      await (_database.update(_database.userProfilesTable)
            ..where((tbl) => tbl.id.equals(profile.id)))
          .write(const UserProfilesTableCompanion(needsUpload: Value(false)));
    } catch (e, stackTrace) {
      _logger.error(
        'Failed to upload user profile',
        context: 'USER_SYNC',
        error: e,
        stackTrace: stackTrace,
        data: {'userId': profile.id},
      );
      // Don't rethrow - allow other uploads to continue
    }
  }

  /// Upload food preferences to Supabase food_preferences table.
  /// Ensures the normalized table is synced (not just the JSONB in users table).
  Future<void> uploadFoodPreferences(String userId) async {
    try {
      // Get all food preference entries from local database
      final entries = await _database.foodPreferencesDao.getAllFoodPreferenceEntries(userId);

      if (entries.isEmpty) {
        return;
      }

      // Convert to Supabase format
      final rows = entries
          .map((entry) => {
                'id': entry.id,
                'user_id': entry.userId,
                'food_name': entry.foodName,
                'preference': entry.preference,
                'preference_level': entry.preferenceLevel,
                'created_at': entry.createdAt.toIso8601String(),
                'updated_at': entry.updatedAt.toIso8601String(),
              })
          .toList();

      // Upsert to Supabase food_preferences table
      await _supabase.from('food_preferences').upsert(
        rows,
        onConflict: 'user_id,food_name', // Use composite unique key
      );
    } catch (e, stackTrace) {
      _logger.error(
        'Failed to upload food preferences',
        context: 'USER_SYNC',
        error: e,
        stackTrace: stackTrace,
        data: {'userId': userId},
      );
      // Don't rethrow - allow other uploads to continue
    }
  }
}
