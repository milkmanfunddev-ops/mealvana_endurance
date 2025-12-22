import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../domain/user_preferences.dart';
import '../../onboarding/domain/dietary_preference.dart';
import '../../onboarding/domain/allergy.dart';
import '../../../shared/database/app_database.dart';
import '../../../shared/database/database_provider.dart';
import '../../../shared/services/app_external_deps.dart';
import '../../../shared/services/sentry/sentry_reporter.dart';
import '../../../core/utils/debug_logger.dart';

part 'user_repository.g.dart';

/// Repository for managing user profile data in Drift database and Supabase
class UserRepository {
  UserRepository({
    required this.database,
    required this.supabase,
    required this.sentry,
  });

  final AppDatabase database;
  final SupabaseClient supabase;
  final SentryReporter sentry;

  /// Save user profile
  /// [needsUpload] - If true, marks profile for background upload to Supabase (for new registrations)
  Future<void> saveUserProfile(UserProfile profile, {bool needsUpload = false}) async {
    try {
      await database.saveUserProfile(profile, needsUpload: needsUpload);
      sentry.addBreadcrumb(
        message: 'User profile saved successfully',
        category: 'database',
        data: {'user_id': profile.id, 'needsUpload': needsUpload},
      );
    } catch (e, stackTrace) {
      await sentry.reportDatabaseError(
        e,
        operation: 'saveUserProfile',
        table: 'user_profiles',
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Get user profile by ID (optional for device-based identification)
  Future<UserProfile?> getUserProfile([String? userId]) async {
    try {
      // For device-based approach, we just get the current user
      return await getCurrentUser();
    } catch (e, stackTrace) {
      await sentry.reportDatabaseError(
        e,
        operation: 'getUserProfile',
        table: 'user_profiles',
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Get the current user profile (assumes single user for MVP)
  Future<UserProfile?> getCurrentUser() async {
    try {
      return await database.getCurrentUserProfile();
    } catch (e, stackTrace) {
      await sentry.reportDatabaseError(
        e,
        operation: 'getCurrentUser',
        table: 'user_profiles',
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Update user profile
  /// [needsUpload] - If true, marks profile for background upload to Supabase (for onboarding updates)
  Future<void> updateUserProfile(UserProfile profile, {bool needsUpload = false}) async {
    try {
      final updatedProfile = profile.copyWith(updatedAt: DateTime.now());
      await database.updateUserProfile(updatedProfile, needsUpload: needsUpload);

      // Skip immediate Supabase sync if marked for background upload
      if (!needsUpload) {
        await _syncUserProfileToSupabase(updatedProfile);
      }

      sentry.addBreadcrumb(
        message: 'User profile updated successfully',
        category: 'database',
        data: {'user_id': profile.id, 'needsUpload': needsUpload},
      );
    } catch (e, stackTrace) {
      await sentry.reportDatabaseError(
        e,
        operation: 'updateUserProfile',
        table: 'user_profiles',
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Update auth provider after account linking
  /// Called when user links Apple, Google, or Email account
  ///
  /// [authUserId] - Optional Supabase auth user ID to set (for email linking)
  Future<void> updateAuthProvider({
    required String authProvider,
    required bool isAnonymous,
    String? authUserId,
  }) async {
    try {
      // Get current user profile
      final currentUser = await getCurrentUser();
      if (currentUser == null) {
        throw Exception('No current user found to update auth provider');
      }

      // Update auth fields (including authUserId if provided)
      final updatedProfile = currentUser.copyWith(
        authProvider: authProvider,
        isAnonymous: isAnonymous,
        authUserId: authUserId ?? currentUser.authUserId,
        updatedAt: DateTime.now(),
      );

      // Save to local database
      await updateUserProfile(updatedProfile);

      // Sync to Supabase
      try {
        final updateData = {
          'auth_provider': authProvider,
          'is_anonymous': isAnonymous,
          'updated_at': updatedProfile.updatedAt.toIso8601String(),
        };

        // Only include auth_user_id if provided
        if (authUserId != null) {
          updateData['auth_user_id'] = authUserId;
        }

        await supabase
            .from('users')
            .update(updateData)
            .eq('id', currentUser.id);

        sentry.addBreadcrumb(
          message: 'Auth provider updated successfully',
          category: 'auth',
          data: {
            'user_id': currentUser.id,
            'auth_provider': authProvider,
            'is_anonymous': isAnonymous,
            'auth_user_id_updated': authUserId != null,
          },
        );
      } catch (e, stackTrace) {
        // Log but don't throw - local update succeeded
        await sentry.reportNetworkError(
          e,
          url: 'supabase:users:update',
          method: 'UPDATE',
          stackTrace: stackTrace,
        );
      }
    } catch (e, stackTrace) {
      await sentry.reportDatabaseError(
        e,
        operation: 'updateAuthProvider',
        table: 'user_profiles',
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Get profile by Supabase auth user ID (auth_user_id column)
  Future<UserProfile?> getUserProfileByAuthUserId(String authUserId) async {
    try {
      return await database.getUserProfileByAuthUserId(authUserId);
    } catch (e, stackTrace) {
      await sentry.reportDatabaseError(
        e,
        operation: 'getUserProfileByAuthUserId',
        table: 'user_profiles',
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Get profile by primary key/ID
  Future<UserProfile?> getUserProfileById(String userId) async {
    try {
      return await database.getUserProfileById(userId);
    } catch (e, stackTrace) {
      await sentry.reportDatabaseError(
        e,
        operation: 'getUserProfileById',
        table: 'user_profiles',
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Delete user profile
  Future<bool> deleteUserProfile(String userId) async {
    return await database.deleteUserProfile(userId);
  }

  /// Check if user exists
  Future<bool> userExists(String userId) async {
    final user = await database.getCurrentUserProfile();
    return user != null && user.id == userId;
  }

  /// Save food preferences for a user
  ///
  /// [mergeMode] - when true, merges with existing preferences instead of replacing all.
  /// Use mergeMode=true when syncing from server to avoid data loss.
  Future<void> saveFoodPreferences(
    String userId,
    Map<String, FoodPreference> preferences, {
    Map<String, int>? sliderLevels,
    bool mergeMode = false,
  }) async {
    await database.saveFoodPreferences(
      userId,
      preferences,
      sliderLevels: sliderLevels,
      mergeMode: mergeMode,
    );
    // Remote sync is handled via the edge function in AuthService; avoid direct Supabase client writes here.
  }

  /// Get food preferences for a user
  Future<Map<String, FoodPreference>> getFoodPreferences(String userId) async {
    return await database.getUserFoodPreferences(userId);
  }

  /// Get stored slider levels for each food preference
  Future<Map<String, int>> getFoodPreferenceLevels(String userId) async {
    return await database.getUserFoodPreferenceLevels(userId);
  }

  /// Update a single food preference
  Future<void> updateFoodPreference(
    String userId,
    String foodId,
    FoodPreference preference,
  ) async {
    final existingPreferences = await getFoodPreferences(userId);
    existingPreferences[foodId] = preference;
    final levels = await getFoodPreferenceLevels(userId);
    await saveFoodPreferences(
      userId,
      existingPreferences,
      sliderLevels: levels,
    );
  }

  /// Get liked foods for a user
  Future<List<String>> getLikedFoods(String userId) async {
    return await database.getLikedFoods(userId);
  }

  /// Get disliked foods for a user
  Future<List<String>> getDislikedFoods(String userId) async {
    return await database.getDislikedFoods(userId);
  }

  /// Pull custom foods from Supabase and cache locally
  Future<void> syncUserFoodsFromSupabase(String userId) async {
    try {
      final response = await supabase
          .from('user_foods')
          .select()
          .eq('user_id', userId)
          .eq('is_deleted', false);

      await database.replaceUserFoods(userId, List<Map<String, dynamic>>.from(response));
    } catch (e, stackTrace) {
      await sentry.reportNetworkError(
        e,
        url: 'supabase:user_foods:select',
        method: 'SELECT',
        stackTrace: stackTrace,
      );
    }
  }

  /// Clear all user data (for testing/reset)
  Future<void> clearAllData() async {
    await database.clearAllData();
  }

  /// Reset to new anonymous user after sign-out
  /// Preserves food preferences, clears biometric data
  /// Returns the new anonymous user ID
  Future<String> resetToAnonymousAfterSignOut({
    required String newAnonymousUserId,
    String? oldUserId,
  }) async {
    try {
      // Get current user's food preferences if available
      Map<String, FoodPreference>? foodPreferences;
      Map<String, int>? foodPreferenceLevels;
      if (oldUserId != null) {
        try {
          foodPreferences = await getFoodPreferences(oldUserId);
          foodPreferenceLevels = await getFoodPreferenceLevels(oldUserId);
        } catch (e) {
          // Ignore - user may not have food preferences yet
          foodPreferences = null;
          foodPreferenceLevels = null;
        }
      }

      // Clear all persisted user-scoped data before creating the new profile
      // NOTE: With Option B (offline-first), we keep data on logout by default
      // This method is currently unused but if re-enabled, it should use forceDelete
      // await database.clearUserScopedData(userId: oldUserId, forceDelete: true);

      // Create new anonymous user profile with minimal data
      final newProfile = UserProfile(
        id: newAnonymousUserId,
        deviceId: newAnonymousUserId, // Use Supabase user ID as device ID
        authUserId: null,
        authProvider: 'anonymous',
        isAnonymous: true,
        // Clear biometric data - use default values
        gender: Gender.other,
        birthday: DateTime.now().subtract(
          const Duration(days: 365 * 30),
        ), // Default 30 years old
        heightFeet: 5,
        heightInches: 8,
        weightPounds: 150.0,
        runsWithWaterBottle: false,
        gutTraining: GutTraining.moderate,
        onboardingCompleted: false, // User needs to complete onboarding again
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        appVersion: '1.0.0',
      );

      // Save new profile to local database
      await saveUserProfile(newProfile);

      // Transfer food preferences to new user if available
      if (foodPreferences != null && foodPreferences.isNotEmpty) {
        await saveFoodPreferences(
          newAnonymousUserId,
          foodPreferences,
          sliderLevels: foodPreferenceLevels,
        );
      }

      // Sync to Supabase (best effort - don't throw on failure)
      try {
        await supabase.from('users').upsert({
          'id': newAnonymousUserId,
          'device_id': newAnonymousUserId,
          'auth_provider': 'anonymous',
          'is_anonymous': true,
          'gender': newProfile.gender.name,
          'birthday': newProfile.birthday.toIso8601String().split('T')[0],
          'height_feet': newProfile.heightFeet,
          'height_inches': newProfile.heightInches,
          'weight_pounds': newProfile.weightPounds,
          'runs_with_water_bottle': newProfile.runsWithWaterBottle,
          'gut_training_level': newProfile.gutTraining.name,
          'onboarding_completed': newProfile.onboardingCompleted,
          'created_at': newProfile.createdAt.toIso8601String(),
          'updated_at': newProfile.updatedAt.toIso8601String(),
        });
      } catch (e, stackTrace) {
        // Log but don't throw - local save succeeded
        await sentry.reportNetworkError(
          e,
          url: 'supabase:users:upsert',
          method: 'UPSERT',
          stackTrace: stackTrace,
        );
      }

      sentry.addBreadcrumb(
        message: 'Reset to new anonymous user after sign-out',
        category: 'auth',
        data: {
          'new_user_id': newAnonymousUserId,
          'old_user_id': oldUserId,
          'transferred_food_preferences': foodPreferences?.length ?? 0,
        },
      );

      return newAnonymousUserId;
    } catch (e, stackTrace) {
      await sentry.reportDatabaseError(
        e,
        operation: 'resetToAnonymousAfterSignOut',
        table: 'user_profiles',
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  // SUPABASE SYNC METHODS

  /// Sync local user data with Supabase and return updated user
  Future<UserProfile> syncUserWithSupabase(
    String deviceId,
    UserProfile localUser,
  ) async {
    try {
      // Convert user profile to JSON for Supabase
      final userData = {
        'gender': localUser.gender.name,
        'birthday': localUser.birthday.toIso8601String().split(
          'T',
        )[0], // Date only
        'height_feet': localUser.heightFeet,
        'height_inches': localUser.heightInches,
        'weight_pounds': localUser.weightPounds,
        'runs_with_water_bottle': localUser.runsWithWaterBottle,
        'food_preferences': {}, // TODO: Implement food preferences sync
        'gut_training_level': localUser.gutTraining.name,
        'onboarding_completed': true,
        'app_version': '1.0.0', // TODO: Get from package info
      };

      // Use the upsert function from SQL script
      final response = await supabase.rpc(
        'upsert_user_by_device_id',
        params: {'p_device_id': deviceId, 'p_user_data': userData},
      );

      if (response != null) {
        // Convert response back to UserProfile
        final updatedUser = _parseUserFromSupabase(response, deviceId);

        // Update local cache
        await saveUserProfile(updatedUser);

        return updatedUser;
      } else {
        return localUser;
      }
    } catch (e, stackTrace) {
      // Log error but don't throw - continue with local data
      await sentry.reportNetworkError(
        e,
        url: 'supabase:upsert_user_by_device_id',
        method: 'RPC',
        stackTrace: stackTrace,
      );
      return localUser;
    }
  }

  /// Get user from Supabase by device ID
  Future<UserProfile?> getUserFromSupabase(String deviceId) async {
    try {
      final response = await supabase.rpc(
        'get_user_by_device_id',
        params: {'p_device_id': deviceId},
      );

      if (response != null) {
        return _parseUserFromSupabase(response, deviceId);
      } else {
        return null;
      }
    } catch (e, stackTrace) {
      await sentry.reportNetworkError(
        e,
        url: 'supabase:get_user_by_device_id',
        method: 'RPC',
        stackTrace: stackTrace,
      );
      return null;
    }
  }

  /// Fetch user profile from Supabase by ID and save to local DB
  /// Used when signing in to an existing account to sync profile
  Future<UserProfile?> fetchAndSaveRemoteProfile(String userId) async {
    try {
      final response = await supabase
          .from('users')
          .select()
          .eq('id', userId)
          .maybeSingle();

      if (response != null) {
        final user = _parseUserFromSupabase(response, userId);
        await saveUserProfile(user);
        return user;
      }
      return null;
    } catch (e, stackTrace) {
      await sentry.reportNetworkError(
        e,
        url: 'supabase:users:select',
        method: 'SELECT',
        stackTrace: stackTrace,
      );
      return null;
    }
  }

  /// Fetch remote food preferences for the current user and cache locally
  Future<Map<String, FoodPreference>> fetchAndCacheRemoteFoodPreferences(
    String userId,
  ) async {
    try {
      final response = await supabase
          .from('food_preferences')
          .select('food_name, preference, preference_level')
          .eq('user_id', userId);

      final userResponse = await supabase
          .from('users')
          .select('food_preferences')
          .eq('id', userId)
          .maybeSingle();

      final preferences = <String, FoodPreference>{};
      final sliderLevels = <String, int>{};
      for (final row in response) {
        final foodName = row['food_name'] as String?;
        final preferenceValue = row['preference'] as String?;
        if (foodName == null || preferenceValue == null) continue;

        final parsedPreference = FoodPreference.values.firstWhere(
          (pref) => pref.value == preferenceValue,
          orElse: () => FoodPreference.dislike,
        );
        preferences[foodName] = parsedPreference;

        final level = row['preference_level'];
        if (level is num) {
          sliderLevels[foodName] = level.toInt().clamp(0, 4);
        }
      }

      if (sliderLevels.isEmpty &&
          userResponse != null &&
          userResponse['food_preferences'] is Map<String, dynamic>) {
        final metadata =
            Map<String, dynamic>.from(userResponse['food_preferences']);
        metadata.forEach((foodName, raw) {
          if (raw is Map<String, dynamic>) {
            final slider = raw['slider_level'];
            if (slider is num) {
              sliderLevels[foodName] = slider.toInt().clamp(0, 4);
            }
          }
        });
      }

      // SAFETY CHECK: Don't wipe local data if server returned empty
      // This prevents data loss from RLS issues, network problems, or timing issues
      if (preferences.isEmpty) {
        final localPrefs = await database.getUserFoodPreferences(userId);
        if (localPrefs.isNotEmpty) {
          DebugLogger.warning(
            'Server returned empty food_preferences but local has ${localPrefs.length} items - keeping local data',
          );
          return localPrefs;
        }
      }

      // Use mergeMode to preserve local preferences that server doesn't have
      // This prevents data loss when server has stale or incomplete data
      await saveFoodPreferences(
        userId,
        preferences,
        sliderLevels: sliderLevels.isEmpty ? null : sliderLevels,
        mergeMode: true, // Merge with existing local data instead of replacing
      );
      return preferences;
    } catch (e, stackTrace) {
      await sentry.reportNetworkError(
        e,
        url: 'supabase:food_preferences:select',
        method: 'SELECT',
        stackTrace: stackTrace,
      );
      return {};
    }
  }

  /// Create new user in Supabase (called after onboarding)
  Future<UserProfile> createUserInSupabase(
    String deviceId,
    UserProfile userProfile,
  ) async {
    try {
      final userData = {
        'gender': userProfile.gender.name,
        'birthday': userProfile.birthday.toIso8601String().split('T')[0],
        'height_feet': userProfile.heightFeet,
        'height_inches': userProfile.heightInches,
        'weight_pounds': userProfile.weightPounds,
        'runs_with_water_bottle': userProfile.runsWithWaterBottle,
        'food_preferences': {}, // TODO: Add food preferences
        'gut_training_level': userProfile.gutTraining.name,
        'onboarding_completed': true,
        'app_version': '1.0.0',
      };

      final response = await supabase.rpc(
        'upsert_user_by_device_id',
        params: {'p_device_id': deviceId, 'p_user_data': userData},
      );

      if (response != null) {
        final createdUser = _parseUserFromSupabase(response, deviceId);
        await saveUserProfile(createdUser);
        return createdUser;
      } else {
        // Fallback to local save if Supabase fails
        await saveUserProfile(userProfile);
        return userProfile;
      }
    } catch (e, stackTrace) {
      await sentry.reportNetworkError(
        e,
        url: 'supabase:upsert_user_by_device_id',
        method: 'RPC',
        stackTrace: stackTrace,
      );
      // Fallback to local save
      await saveUserProfile(userProfile);
      return userProfile;
    }
  }

  /// Parse user data from Supabase response
  UserProfile _parseUserFromSupabase(dynamic response, String deviceId) {
    // Handle both single object and array responses
    final userData = response is List ? response.first : response;

    return UserProfile(
      id: userData['id'] ?? deviceId,
      deviceId: userData['device_id'] ?? deviceId,
      authUserId: userData['auth_user_id'] as String?,
      authProvider: userData['auth_provider'] as String? ?? 'anonymous',
      isAnonymous: userData['is_anonymous'] as bool? ?? true,
      gender: Gender.values.firstWhere(
        (e) => e.name == userData['gender'],
        orElse: () => Gender.other,
      ),
      birthday: DateTime.parse(
        userData['birthday'] ?? DateTime.now().toIso8601String(),
      ),
      heightFeet: userData['height_feet'] ?? 5,
      heightInches: userData['height_inches'] ?? 8,
      weightPounds: (userData['weight_pounds'] as num?)?.toDouble() ?? 150.0,
      runsWithWaterBottle: userData['runs_with_water_bottle'] ?? false,
      gutTraining: GutTraining.values.firstWhere(
        (e) => e.name == userData['gut_training_level'],
        orElse: () => GutTraining.moderate,
      ),
      onboardingCompleted: userData['onboarding_completed'] ?? false,
      createdAt: DateTime.parse(
        userData['created_at'] ?? DateTime.now().toIso8601String(),
      ),
      updatedAt: DateTime.parse(
        userData['updated_at'] ?? DateTime.now().toIso8601String(),
      ),
      appVersion: userData['app_version'] ?? '1.0.0',
      giSensitivity: userData['gi_sensitivity'] as bool?,
      ftpWatts: userData['cycling_ftp_watts'] as int?,
      typicalBikeBottles: userData['typical_bike_bottles'] as int?,
      hasAeroBottle: userData['has_aero_bottle'] as bool?,
      hasBentoBox: userData['has_bento_box'] as bool?,
      cssPacePer100mSeconds: userData['swimming_css_seconds_per_100m'] as int?,
      typicalWetsuit: userData['typical_wetsuit'] as bool?,
      typicalSwimCapType: userData['typical_swim_cap_type'] as String?,
      // Dietary preference and allergies (already parsed by UserProfile.fromJson in some paths)
      // Convert null to DietaryPreference.none for consistency (database stores null, domain uses none)
      dietaryPreference: DietaryPreference.fromDbValue(userData['dietary_preference'] as String?) ?? DietaryPreference.none,
      allergies: _parseAllergiesFromSupabase(userData['allergies']),
    );
  }

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

  Future<void> _syncUserProfileToSupabase(UserProfile profile) async {
    try {
      await supabase.from('users').upsert(profile.toJson());
    } catch (e, stackTrace) {
      await sentry.reportNetworkError(
        e,
        url: 'supabase:users:upsert',
        method: 'UPSERT',
        stackTrace: stackTrace,
      );
    }
  }

  /// Check if a user has any data worth migrating (activities, events, etc.)
  /// This is used to prevent unnecessary migration when signing back into an existing account
  /// after sign-out (where a new empty anonymous user is created)
  Future<bool> checkUserHasData(String userId) async {
    try {
      // Check Supabase for any user data
      // We check activities and events as the most common user-created data
      final activitiesResponse = await supabase
          .from('activities')
          .select('id')
          .eq('user_id', userId)
          .limit(1);

      if ((activitiesResponse as List).isNotEmpty) {
        return true;
      }

      final eventsResponse = await supabase
          .from('events')
          .select('id')
          .eq('user_id', userId)
          .limit(1);

      if ((eventsResponse as List).isNotEmpty) {
        return true;
      }

      // Note: We only check Supabase here since the purpose is to prevent
      // migration that would DELETE data from Supabase. Local-only data
      // wouldn't be affected by the migration deletion.

      return false;
    } catch (e, stackTrace) {
      // FAIL SAFE: Don't assume - let caller handle retry logic
      // Returning false on network errors could cause data loss by skipping migration
      // and triggering _handleFreshLogin, which may overwrite existing server data
      await sentry.reportNetworkError(
        e,
        url: 'supabase:checkUserHasData',
        method: 'GET',
        stackTrace: stackTrace,
      );
      rethrow;  // Let caller decide how to handle this error
    }
  }

  /// Migrate all data from anonymous user to OAuth user when signing into existing account
  /// This is called when account linking fails (account already exists) and user chooses to sign in
  /// The anonymous user's data is merged into the existing OAuth user's account
  Future<void> migrateAnonymousUserData({
    required String fromAnonymousUserId,
    required String toOAuthUserId,
    String authProvider = 'google',
  }) async {
    try {
      // Get the anonymous user's profile to preserve their data
      final anonymousProfile = await getUserProfileById(fromAnonymousUserId);
      if (anonymousProfile == null) {
        sentry.addBreadcrumb(
          message: 'No anonymous profile found to migrate',
          category: 'auth',
          data: {'from_user_id': fromAnonymousUserId},
        );
        return;
      }

      // CRITICAL FIX: Check if OAuth user has existing data on server
      // If they do, we should KEEP their existing data, not replace it with anonymous onboarding data
      final oauthUserExistsOnServer = await _checkUserExistsInSupabase(toOAuthUserId);

      if (oauthUserExistsOnServer) {
        // SCENARIO A: EXISTING OAuth user signing in on new device
        // - OAuth user has historical data on server (e.g., 50 activities from last year)
        // - Anonymous user has test/onboarding data from new device (e.g., 1 test activity)
        // - CORRECT BEHAVIOR: Keep OAuth data, discard anonymous data
        sentry.addBreadcrumb(
          message: 'OAuth user exists on server - preserving existing data, discarding anonymous data',
          category: 'auth',
          data: {
            'oauth_user_id': toOAuthUserId,
            'anonymous_user_id': fromAnonymousUserId,
          },
        );

        // Delete anonymous user's local data (will be replaced by server data on next sync)
        await _clearAnonymousUserLocalData(fromAnonymousUserId);

        // Update local user profile to OAuth user
        final oauthProfile = anonymousProfile.copyWith(
          id: toOAuthUserId,
          authUserId: toOAuthUserId,
          authProvider: authProvider,
          isAnonymous: false,
          updatedAt: DateTime.now(),
        );
        await saveUserProfile(oauthProfile);

        sentry.addBreadcrumb(
          message: 'Cleared anonymous data - OAuth user data will sync from server',
          category: 'auth',
          data: {
            'oauth_user_id': toOAuthUserId,
            'anonymous_user_id': fromAnonymousUserId,
          },
        );
      } else {
        // SCENARIO B: NEW OAuth account (never used the app before)
        // - OAuth user has NO data on server
        // - Anonymous user has fresh onboarding data from this device
        // - CORRECT BEHAVIOR: Keep anonymous data, migrate it to OAuth user
        sentry.addBreadcrumb(
          message: 'New OAuth account - migrating anonymous user data',
          category: 'auth',
          data: {
            'oauth_user_id': toOAuthUserId,
            'anonymous_user_id': fromAnonymousUserId,
          },
        );

        // STEP 1: Migrate all user-scoped data in Supabase (child tables first)
        // This must happen BEFORE deleting the anonymous user due to foreign key constraints
        await _migrateSupabaseData(
          fromUserId: fromAnonymousUserId,
          toUserId: toOAuthUserId,
        );

        // STEP 2: Delete anonymous user from Supabase BEFORE creating OAuth user
        // This frees up the device_id for the OAuth user
        await _deleteAnonymousUserFromSupabase(fromAnonymousUserId);

        // STEP 3: Create or update OAuth user in Supabase public.users
        // UPSERT handles both new and existing users automatically
        await _upsertOAuthUserFromAnonymousProfile(
          oauthUserId: toOAuthUserId,
          anonymousProfile: anonymousProfile,
          authProvider: authProvider,
        );

        // STEP 4: Update local database with OAuth user ID
        await _migrateLocalData(
          fromUserId: fromAnonymousUserId,
          toUserId: toOAuthUserId,
          anonymousProfile: anonymousProfile,
          authProvider: authProvider,
        );

        sentry.addBreadcrumb(
          message: 'Successfully migrated anonymous user data to new OAuth user',
          category: 'auth',
          data: {
            'from_user_id': fromAnonymousUserId,
            'to_user_id': toOAuthUserId,
          },
        );
      }
    } catch (e, stackTrace) {
      await sentry.reportDatabaseError(
        e,
        operation: 'migrateAnonymousUserData',
        table: 'multiple',
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Check if user exists in Supabase public.users table
  Future<bool> _checkUserExistsInSupabase(String userId) async {
    try {
      final response = await supabase
          .from('users')
          .select('id')
          .eq('id', userId)
          .maybeSingle();
      return response != null;
    } catch (e) {
      // FAIL SAFE: Assume user exists to prevent data loss
      // If we can't verify, it's safer to skip deletion than to delete existing data
      // sentry.addBreadcrumb(
      //   Breadcrumb(
      //     message: 'Error checking OAuth user existence - assuming exists to prevent data loss',
      //     category: 'auth',
      //     data: {
      //       'user_id': userId,
      //       'error': e.toString(),
      //       'fail_safe_action': 'returning_true_to_prevent_deletion',
      //     },
      //     level: SentryLevel.warning,
      //   ),
      // );
      return true; // Conservative: preserve existing data on network errors
    }
  }

  /// Delete anonymous user from Supabase public.users table
  /// This must be called AFTER migrating child table data to free up the device_id
  Future<void> _deleteAnonymousUserFromSupabase(String anonymousUserId) async {
    try {
      await supabase
          .from('users')
          .delete()
          .eq('id', anonymousUserId);

      sentry.addBreadcrumb(
        message: 'Deleted anonymous user from Supabase',
        category: 'auth',
        data: {'anonymous_user_id': anonymousUserId},
      );
    } catch (e, stackTrace) {
      // Log but don't throw - user may not exist in Supabase
      sentry.addBreadcrumb(
        message: 'Failed to delete anonymous user from Supabase (may not exist)',
        category: 'auth',
        data: {'error': e.toString()},
      );
      await sentry.reportNetworkError(
        e,
        url: 'supabase:users:delete',
        method: 'DELETE',
        stackTrace: stackTrace,
      );
    }
  }

  /// Update existing OAuth user in Supabase with anonymous user's profile data
  /// Called when OAuth user already exists but we want to update their device_id and merge profile
  /// UNIFIED: Create or update OAuth user in Supabase using anonymous user's profile data
  /// Uses UPSERT to handle both new and existing OAuth users
  Future<void> _upsertOAuthUserFromAnonymousProfile({
    required String oauthUserId,
    required UserProfile anonymousProfile,
    required String authProvider,
  }) async {
    try {
      // UPSERT user record with OAuth user ID and anonymous user's data
      // This works whether the OAuth user exists or not
      await supabase.from('users').upsert({
        'id': oauthUserId,
        'device_id': anonymousProfile.deviceId,
        'auth_user_id': oauthUserId,
        'auth_provider': authProvider, // ✅ Uses parameter (apple, google, email)
        'is_anonymous': false, // ✅ Always set to false for OAuth users
        'gender': anonymousProfile.gender.name,
        'birthday': anonymousProfile.birthday.toIso8601String().split('T')[0],
        'height_feet': anonymousProfile.heightFeet,
        'height_inches': anonymousProfile.heightInches,
        'weight_pounds': anonymousProfile.weightPounds,
        'runs_with_water_bottle': anonymousProfile.runsWithWaterBottle,
        'gut_training_level': anonymousProfile.gutTraining.name,
        'onboarding_completed': anonymousProfile.onboardingCompleted,
        'app_version': anonymousProfile.appVersion,
        'gi_sensitivity': anonymousProfile.giSensitivity,
        'cycling_ftp_watts': anonymousProfile.ftpWatts,
        'typical_bike_bottles': anonymousProfile.typicalBikeBottles,
        'has_aero_bottle': anonymousProfile.hasAeroBottle,
        'has_bento_box': anonymousProfile.hasBentoBox,
        'swimming_css_seconds_per_100m': anonymousProfile.cssPacePer100mSeconds,
        'typical_wetsuit': anonymousProfile.typicalWetsuit,
        'typical_swim_cap_type': anonymousProfile.typicalSwimCapType,
        'updated_at': DateTime.now().toIso8601String(),
      }, onConflict: 'id');

      sentry.addBreadcrumb(
        message: 'Upserted OAuth user in Supabase with anonymous profile data',
        category: 'auth',
        data: {
          'oauth_user_id': oauthUserId,
          'auth_provider': authProvider,
        },
      );
    } catch (e, stackTrace) {
      await sentry.reportNetworkError(
        e,
        url: 'supabase:users:upsert',
        method: 'UPSERT',
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Migrate data in Supabase from anonymous user to OAuth user
  /// Strategy: DELETE OAuth user's existing data first, then UPDATE anonymous user's data
  /// This prevents UNIQUE constraint violations when OAuth user already has data
  Future<void> _migrateSupabaseData({
    required String fromUserId,
    required String toUserId,
  }) async {
    // ============ EVENTS ============
    // Events have UNIQUE constraint on (user_id, event_date, event_name) - delete OAuth's first
    try {
      await supabase
          .from('events')
          .delete()
          .eq('user_id', toUserId);
    } catch (e) {
      sentry.addBreadcrumb(
        message: 'Failed to delete OAuth user events (may not exist)',
        category: 'auth',
        data: {'error': e.toString()},
      );
    }
    try {
      await supabase
          .from('events')
          .update({'user_id': toUserId})
          .eq('user_id', fromUserId);
    } catch (e) {
      sentry.addBreadcrumb(
        message: 'Failed to migrate events (may not exist)',
        category: 'auth',
        data: {'error': e.toString()},
      );
    }

    // ============ ACTIVITIES ============
    // Activities have UNIQUE constraint on (user_id, scheduled_date) - delete OAuth's first
    try {
      await supabase
          .from('activities')
          .delete()
          .eq('user_id', toUserId);
    } catch (e) {
      sentry.addBreadcrumb(
        message: 'Failed to delete OAuth user activities (may not exist)',
        category: 'auth',
        data: {'error': e.toString()},
      );
    }
    try {
      await supabase
          .from('activities')
          .update({'user_id': toUserId})
          .eq('user_id', fromUserId);
    } catch (e) {
      sentry.addBreadcrumb(
        message: 'Failed to migrate activities (may not exist)',
        category: 'auth',
        data: {'error': e.toString()},
      );
    }

    // ============ FOOD PREFERENCES ============
    // Food preferences have UNIQUE constraint on (user_id, food_name) - delete OAuth's first
    try {
      await supabase
          .from('food_preferences')
          .delete()
          .eq('user_id', toUserId);
    } catch (e) {
      sentry.addBreadcrumb(
        message: 'Failed to delete OAuth user food_preferences (may not exist)',
        category: 'auth',
        data: {'error': e.toString()},
      );
    }
    try {
      await supabase
          .from('food_preferences')
          .update({'user_id': toUserId})
          .eq('user_id', fromUserId);
    } catch (e) {
      sentry.addBreadcrumb(
        message: 'Failed to migrate food_preferences (may not exist)',
        category: 'auth',
        data: {'error': e.toString()},
      );
    }

    // ============ USER FOODS ============
    // User foods have UNIQUE constraint on (user_id, food_name) - delete OAuth's first
    try {
      await supabase
          .from('user_foods')
          .delete()
          .eq('user_id', toUserId);
    } catch (e) {
      sentry.addBreadcrumb(
        message: 'Failed to delete OAuth user user_foods (may not exist)',
        category: 'auth',
        data: {'error': e.toString()},
      );
    }
    try {
      await supabase
          .from('user_foods')
          .update({'user_id': toUserId})
          .eq('user_id', fromUserId);
    } catch (e) {
      sentry.addBreadcrumb(
        message: 'Failed to migrate user_foods (may not exist)',
        category: 'auth',
        data: {'error': e.toString()},
      );
    }

    // ============ CARB LOADING PLANS ============
    // Delete OAuth user's carb loading plans first to prevent conflicts
    // Note: carb_loading_days is a CHILD table with ON DELETE CASCADE in Supabase,
    // so deleting plans will automatically delete associated days
    try {
      await supabase
          .from('carb_loading_plans')
          .delete()
          .eq('user_id', toUserId);
    } catch (e) {
      sentry.addBreadcrumb(
        message: 'Failed to delete OAuth user carb_loading_plans (may not exist)',
        category: 'auth',
        data: {'error': e.toString()},
      );
    }
    // Migrate anonymous user's carb loading plans to OAuth user
    // Note: carb_loading_days does NOT have user_id column - it inherits
    // user ownership through carb_loading_plan_id foreign key
    try {
      await supabase
          .from('carb_loading_plans')
          .update({'user_id': toUserId})
          .eq('user_id', fromUserId);
    } catch (e) {
      sentry.addBreadcrumb(
        message: 'Failed to migrate carb_loading_plans (may not exist)',
        category: 'auth',
        data: {'error': e.toString()},
      );
    }

    // ============ FEEDBACK ============
    // Note: feedback table uses device_id, NOT user_id
    // Feedback stays with the device, not migrated with user account
    // No migration needed here

    // ============ FEATURE SURVEY RESPONSES ============
    // Note: feature_survey_responses table uses device_id, NOT user_id
    // Survey responses stay with the device (like feedback), not migrated with user account
    // The device_id is inherited from anonymous user to OAuth user via users.device_id
    // No migration needed here
  }

  /// Migrate local Drift database data
  Future<void> _migrateLocalData({
    required String fromUserId,
    required String toUserId,
    required UserProfile anonymousProfile,
    required String authProvider,
  }) async {
    // STEP 1: Update user_id in all local child tables (activities, events, etc.)
    // This must happen BEFORE deleting the anonymous user profile
    await database.migrateUserData(fromUserId, toUserId);

    // Note: migrateUserData already deletes the anonymous user profile from the local DB
    // Now we just need to create/update the OAuth user profile

    // STEP 2: Create new profile with OAuth user ID
    final migratedProfile = anonymousProfile.copyWith(
      id: toUserId,
      authUserId: toUserId,
      authProvider: authProvider,
      isAnonymous: false,
      updatedAt: DateTime.now(),
    );

    // STEP 3: Save the migrated OAuth user profile
    await saveUserProfile(migratedProfile);
  }

  /// Clear anonymous user's local data when OAuth user has existing data on server
  /// This prevents data loss - OAuth user's server data will be downloaded on next sync
  Future<void> _clearAnonymousUserLocalData(String anonymousUserId) async {
    await database.transaction(() async {
      // Delete anonymous user's activities
      await database.customStatement(
        'DELETE FROM activities WHERE user_id = ?',
        [anonymousUserId],
      );

      // Delete anonymous user's events
      await database.customStatement(
        'DELETE FROM events WHERE user_id = ?',
        [anonymousUserId],
      );

      // Delete anonymous user's food preferences
      await database.customStatement(
        'DELETE FROM food_preferences_table WHERE user_id = ?',
        [anonymousUserId],
      );

      // Delete anonymous user's custom foods
      await database.customStatement(
        'DELETE FROM user_foods WHERE user_id = ?',
        [anonymousUserId],
      );

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

      // Delete anonymous user's carb loading user foods
      await database.customStatement(
        'DELETE FROM carb_loading_user_foods WHERE user_id = ?',
        [anonymousUserId],
      );

      // Note: feature_survey_responses uses device_id, not user_id
      // Since we're deleting the user profile which has the device_id,
      // we need to get the device_id first to delete survey responses
      final anonymousProfile = await getUserProfileById(anonymousUserId);
      if (anonymousProfile != null) {
        await database.customStatement(
          'DELETE FROM feature_survey_responses WHERE device_id = ?',
          [anonymousProfile.deviceId],
        );
      }

      // Delete anonymous user profile
      await database.customStatement(
        'DELETE FROM users WHERE id = ?',
        [anonymousUserId],
      );
    });

    sentry.addBreadcrumb(
      message: 'Cleared anonymous user local data',
      category: 'auth',
      data: {'anonymous_user_id': anonymousUserId},
    );
  }

  /// ✨ UNIFIED: Complete authentication for ANY provider (Apple, Google, Email)
  /// This is the single entry point for all post-authentication logic.
  ///
  /// Handles three scenarios:
  /// 1. Account Linking (preservedUserId=true): User ID stays same, just updates provider
  /// 2. Sign-In with Migration (ID changed + wasAnonymous): Migrates data from anonymous user
  /// 3. Fresh Login (no previous user): Fetches/creates profile
  ///
  /// @param previousUserId - User ID before authentication (null if fresh install)
  /// @param wasAnonymous - Whether previous user was anonymous
  /// @param newUserId - User ID after authentication
  /// @param authProvider - 'apple', 'google', or 'email'
  /// @param preservedUserId - true for account linking, false for sign-in
  ///
  /// Returns true if data was migrated, false otherwise
  Future<bool> completeAuthentication({
    required String? previousUserId,
    required bool wasAnonymous,
    required String newUserId,
    required String authProvider,
    bool preservedUserId = false,
  }) async {
    try {
      bool dataMigrated = false;

      // Determine if we need to migrate data
      final needsMigration = previousUserId != null &&
          previousUserId != newUserId &&
          wasAnonymous &&
          !preservedUserId;

      if (needsMigration) {
        // SCENARIO 1: Sign-In with Migration (user ID changed)
        sentry.addBreadcrumb(
          message: 'Auth complete - migrating anonymous user data',
          category: 'auth',
          data: {
            'scenario': 'migration',
            'from_user_id': previousUserId,
            'to_user_id': newUserId,
            'auth_provider': authProvider,
          },
        );

        final hasDataToMigrate = await checkUserHasData(previousUserId);
        if (hasDataToMigrate) {
          await migrateAnonymousUserData(
            fromAnonymousUserId: previousUserId,
            toOAuthUserId: newUserId,
            authProvider: authProvider,
          );
          dataMigrated = true;
        } else {
          await _handleFreshLogin(newUserId, authProvider);
        }
      } else if (preservedUserId) {
        // SCENARIO 2: Account Linking (user ID preserved)
        sentry.addBreadcrumb(
          message: 'Auth complete - account linked',
          category: 'auth',
          data: {
            'scenario': 'linking',
            'user_id': newUserId,
            'auth_provider': authProvider,
          },
        );

        // Update both local and remote database
        // CRITICAL: Set authUserId to newUserId for email linking
        // This ensures userIdProvider can find the profile by authUserId
        await updateAuthProvider(
          authProvider: authProvider,
          isAnonymous: false,
          authUserId: newUserId,
        );
      } else {
        // SCENARIO 3: Fresh Login (no migration needed)
        sentry.addBreadcrumb(
          message: 'Auth complete - fresh login',
          category: 'auth',
          data: {
            'scenario': 'fresh_login',
            'user_id': newUserId,
            'auth_provider': authProvider,
          },
        );

        await _handleFreshLogin(newUserId, authProvider);
      }

      return dataMigrated;
    } catch (e, stackTrace) {
      await sentry.reportDatabaseError(
        e,
        operation: 'completeAuthentication',
        table: 'user_profiles',
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// DEPRECATED: Use completeAuthentication() instead
  /// Handle post-sign-in completion for all auth methods (Google, Apple, Email)
  /// This consolidates the common logic that must run after any sign-in:
  /// 1. Migrate data if coming from anonymous user with data
  /// 2. Update auth provider and isAnonymous flag
  ///
  /// Note: Sync should be triggered by the caller after this method completes
  /// since UserRepository doesn't have access to Riverpod ref.
  ///
  /// Returns true if data was migrated, false if just auth provider was updated
  Future<bool> handleSignInCompletion({
    required String? previousUserId,
    required bool wasAnonymous,
    required String newUserId,
    required String authProvider,
  }) async {
    try {
      bool dataMigrated = false;

      // Check if we need to migrate data from anonymous user
      final needsMigration = previousUserId != null &&
          previousUserId != newUserId &&
          wasAnonymous;

      if (needsMigration) {
        // Check if the anonymous user actually has data worth migrating
        final hasDataToMigrate = await checkUserHasData(previousUserId);

        if (hasDataToMigrate) {
          sentry.addBreadcrumb(
            message: 'Migrating anonymous user data during sign-in',
            category: 'auth',
            data: {
              'from_user_id': previousUserId,
              'to_user_id': newUserId,
              'auth_provider': authProvider,
            },
          );

          await migrateAnonymousUserData(
            fromAnonymousUserId: previousUserId,
            toOAuthUserId: newUserId,
            authProvider: authProvider,
          );
          dataMigrated = true;
        } else {
          sentry.addBreadcrumb(
            message: 'Skipping migration - anonymous user has no data',
            category: 'auth',
            data: {
              'anonymous_user_id': previousUserId,
              'new_user_id': newUserId,
            },
          );
          // Try to update auth provider, but fallback if user is missing
          // This handles race conditions where AppStartupService might have cleared the anonymous user
          try {
            await updateAuthProvider(
              authProvider: authProvider,
              isAnonymous: false,
            );
          } catch (e) {
            if (e.toString().contains('No current user found')) {
              sentry.addBreadcrumb(
                message: 'User missing during auth update - treating as fresh login',
                category: 'auth',
              );
              await _handleFreshLogin(newUserId, authProvider);
            } else {
              rethrow;
            }
          }
        }
      } else {
        // No migration needed - fetch/create user profile then update auth provider
        // This handles:
        // - User signing back into their existing account
        // - User was not anonymous before sign-in
        sentry.addBreadcrumb(
          message: 'Updating auth provider (no migration needed)',
          category: 'auth',
          data: {
            'user_id': newUserId,
            'auth_provider': authProvider,
            'previous_user_id': previousUserId,
            'was_anonymous': wasAnonymous,
          },
        );

        await _handleFreshLogin(newUserId, authProvider);
      }

      return dataMigrated;
    } catch (e, stackTrace) {
      await sentry.reportDatabaseError(
        e,
        operation: 'handleSignInCompletion',
        table: 'user_profiles',
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Handle fresh login (fetch remote profile or create new in Supabase)
  Future<void> _handleFreshLogin(String userId, String authProvider) async {
    // Fetch user profile from Supabase (for existing accounts)
    final remoteProfile = await fetchAndSaveRemoteProfile(userId);

    if (remoteProfile != null) {
      // User exists in Supabase - update auth provider locally
      sentry.addBreadcrumb(
        message: 'Fresh login - profile found in Supabase',
        category: 'auth',
        data: {
          'user_id': userId,
          'onboarding_completed': remoteProfile.onboardingCompleted,
        },
      );

      await updateAuthProvider(
        authProvider: authProvider,
        isAnonymous: false,
      );
    } else {
      // 🚨 CRITICAL: Profile not found in Supabase - create it NOW
      // This happens when user signs in for first time or after local DB wipe
      sentry.addBreadcrumb(
        message: 'Fresh login - profile NOT found in Supabase, creating it',
        category: 'auth',
        data: {'user_id': userId, 'auth_provider': authProvider},
      );

      final now = DateTime.now();
      final newProfile = UserProfile(
        id: userId,
        deviceId: userId, // Use user ID as device ID for OAuth users
        authUserId: userId,
        authProvider: authProvider,
        isAnonymous: false,
        // Default values for required fields
        gender: Gender.other,
        birthday: DateTime(1990, 1, 1), // Default birthday
        heightFeet: 5,
        heightInches: 8,
        weightPounds: 150.0,
        runsWithWaterBottle: false,
        gutTraining: GutTraining.moderate,
        onboardingCompleted: false, // Will need to complete onboarding
        createdAt: now,
        updatedAt: now,
        appVersion: '1.0.0',
      );

      // Save to local database first
      await saveUserProfile(newProfile);

      // 🔧 FIX: Also create profile in Supabase to ensure sync works
      try {
        await supabase.from('users').upsert(
          newProfile.toJson(),
          onConflict: 'id',
        );

        sentry.addBreadcrumb(
          message: 'Created user profile in Supabase for fresh login',
          category: 'auth',
          data: {'user_id': userId},
        );
      } catch (e, stackTrace) {
        // Log but don't throw - local profile exists, user can continue
        await sentry.reportNetworkError(
          e,
          url: 'supabase:users:upsert',
          method: 'UPSERT',
          stackTrace: stackTrace,
        );
      }
    }
  }
}

/// Repository provider following Andrea's pattern
@riverpod
Future<UserRepository> userRepository(Ref ref) async {
  // Get the database instance
  final database = ref.watch(appDatabaseProvider);
  final sentry = ref.watch(sentryReporterProvider);
  final supabase = ref.watch(appExternalDepsProvider).supabaseClient;

  return UserRepository(database: database, supabase: supabase, sentry: sentry);
}
