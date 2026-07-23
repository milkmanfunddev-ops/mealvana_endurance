import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../domain/user_preferences.dart';
import '../../onboarding/domain/dietary_preference.dart';
import '../../onboarding/domain/allergy.dart';
import '../../nutrition_plan/domain/nutrition_target_overrides.dart';
import '../../../shared/database/app_database.dart';
import '../../../shared/database/database_provider.dart';
import '../../../shared/services/app_external_deps.dart';
import '../../../shared/services/sync/sync_dependency_graph.dart';
import '../../../shared/services/sentry/sentry_reporter.dart';
import '../../../core/utils/debug_logger.dart';
import '../../../shared/data/syncable_repository.dart';

part 'user_repository.g.dart';

/// Repository for managing user profile data in Drift database and Supabase
/// Level 0 repository (no dependencies) - must sync first in the sync hierarchy
class UserRepository with SyncableRepository {
  UserRepository({
    required this.database,
    required this.supabase,
    required this.sentry,
  });

  final AppDatabase database;
  final SupabaseClient supabase;
  final SentryReporter sentry;

  // ========== SyncableRepository Implementation ==========

  @override
  String get repositoryKey => 'users';

  @override
  List<String> get dependencies =>
      SyncDependencyGraph.dependenciesFor(repositoryKey);

  @override
  Future<SyncResult> syncFromRemote(String userId) async {
    try {
      // Query Supabase for this user's profile
      final response = await supabase
          .from('users')
          .select('*')
          .eq('id', userId)
          .maybeSingle();

      if (response == null) {
        // User doesn't exist on server - nothing to sync
        return SyncResult.successful(0);
      }

      // Parse user profile from Supabase response
      final userProfile = _parseUserFromSupabase(response, userId);

      final localProfile = await (database.select(
        database.userProfilesTable,
      )..where((t) => t.id.equals(userId))).getSingleOrNull();
      if (localProfile?.needsUpload == true) {
        sentry.addBreadcrumb(
          message: 'Skipped remote user overwrite for dirty local profile',
          category: 'sync',
          data: {'user_id': userId},
        );
        return SyncResult.successful(0);
      }

      // Save to local Drift database
      await saveUserProfile(userProfile);

      // Update last sync timestamp
      await setLastSyncTime(DateTime.now());

      sentry.addBreadcrumb(
        message: 'User profile synced from Supabase',
        category: 'sync',
        data: {'user_id': userId, 'repository': repositoryKey},
      );

      return SyncResult.successful(1);
    } catch (e, stackTrace) {
      await sentry.reportNetworkError(
        e,
        url: 'supabase:users:sync',
        method: 'SELECT',
        stackTrace: stackTrace,
      );
      return SyncResult.failed(e.toString());
    }
  }

  @override
  Future<UploadResult> uploadDirtyRecords(String userId) async {
    try {
      // Query Drift for user profile with needs_upload = true
      // Use multiple where clauses (Drift AND logic)
      final dirtyUser =
          await (database.select(database.userProfilesTable)
                ..where((t) => t.id.equals(userId))
                ..where((t) => t.needsUpload.equals(true)))
              .getSingleOrNull();

      if (dirtyUser == null) {
        // No dirty records to upload
        return UploadResult.nothingToUpload();
      }

      // Convert to UserProfile domain object using UserDao's helper
      final userProfile = _convertToDomainUserProfile(dirtyUser);

      // Upload to Supabase
      await supabase
          .from('users')
          .upsert(userProfile.toJson(), onConflict: 'id');

      // Clear dirty flag in local database
      await database
          .update(database.userProfilesTable)
          .replace(dirtyUser.copyWith(needsUpload: false));

      sentry.addBreadcrumb(
        message: 'Uploaded dirty user profile to Supabase',
        category: 'sync',
        data: {'user_id': userId, 'repository': repositoryKey},
      );

      return UploadResult.successful(1);
    } catch (e, stackTrace) {
      await sentry.reportNetworkError(
        e,
        url: 'supabase:users:upload',
        method: 'UPSERT',
        stackTrace: stackTrace,
      );
      return UploadResult.failed(e.toString());
    }
  }

  /// Convert database entry to domain model
  /// Same as UserDao._convertToDomainUserProfile but accessible here
  UserProfile _convertToDomainUserProfile(UserProfileEntry dbUser) {
    return UserProfile(
      id: dbUser.id,
      deviceId: dbUser.deviceId,
      authUserId: dbUser.authUserId,
      authProvider: dbUser.authProvider,
      isAnonymous: dbUser.isAnonymous,
      gender: Gender.values.firstWhere(
        (g) => g.name == dbUser.gender,
        orElse: () => Gender.other,
      ),
      birthday: dbUser.birthday ?? DateTime.now(),
      heightFeet: dbUser.heightFeet ?? 0,
      heightInches: dbUser.heightInches ?? 0,
      weightPounds: dbUser.weightPounds ?? 0.0,
      runsWithWaterBottle: dbUser.runsWithWaterBottle,
      gutTraining: GutTraining.values.firstWhere(
        (g) => g.name == dbUser.gutTrainingLevel,
        orElse: () => GutTraining.moderate,
      ),
      onboardingCompleted: dbUser.onboardingCompleted,
      createdAt: dbUser.createdAt,
      updatedAt: dbUser.updatedAt,
      appVersion: dbUser.appVersion ?? '',
      swipeHintShown: dbUser.swipeHintShown,
      // Dietary preference and allergies (onboarding revamp)
      // Convert null to DietaryPreference.none for UI
      dietaryPreference:
          DietaryPreference.fromDbValue(dbUser.dietaryPreference) ??
          DietaryPreference.none,
      allergies: Allergy.fromDbArray(dbUser.allergies),
      // Optional name fields for coach mode athlete identification
      firstName: dbUser.firstName,
      lastName: dbUser.lastName,
      // Contact information
      email: dbUser.email,
      // Sweat profile fields
      sweatSodium: SweatSodiumCat.fromDbValue(dbUser.sweatSodium),
      knownSweatRateMlPerHour: dbUser.knownSweatRateMlPerHour,
      knownSodiumConcentrationMgPerLiter:
          dbUser.knownSodiumConcentrationMgPerLiter,
      sweatTestDate: dbUser.sweatTestDate,
      sweatTestSource: dbUser.sweatTestSource,
      // Garmin precedence timestamps
      weightPoundsUpdatedAt: dbUser.weightPoundsUpdatedAt,
      bodyFatPctUpdatedAt: dbUser.bodyFatPctUpdatedAt,
    );
  }

  // ========== End SyncableRepository Implementation ==========

  /// Save user profile
  /// [needsUpload] - If true, marks profile for background upload to Supabase (for new registrations)
  Future<void> saveUserProfile(
    UserProfile profile, {
    bool needsUpload = false,
  }) async {
    try {
      await database.userDao.saveUserProfile(profile, needsUpload: needsUpload);
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

  /// Get the current user profile based on the current Supabase auth session
  Future<UserProfile?> getCurrentUser() async {
    try {
      // Get the current auth user ID from Supabase session
      final currentAuthUserId = supabase.auth.currentUser?.id;

      // Pass the auth user ID to find the matching profile
      // Without this, the database returns null (by design for logout scenarios)
      return await database.userDao.getCurrentUserProfile(
        currentAuthUserId: currentAuthUserId,
      );
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
  Future<void> updateUserProfile(
    UserProfile profile, {
    bool needsUpload = false,
  }) async {
    try {
      final updatedProfile = profile.copyWith(updatedAt: DateTime.now());
      await database.userDao.updateUserProfile(
        updatedProfile,
        needsUpload: needsUpload,
      );

      // Skip immediate Supabase sync if explicitly marked for background upload.
      // Otherwise: write-through to Supabase now, and ONLY if that fails (e.g.
      // a connection issue) flip the local record to needsUpload=true so the
      // background sync retries it later. Previously the failure was swallowed
      // WITHOUT marking the record dirty, so a failed save never reached
      // Supabase and was never retried.
      if (!needsUpload) {
        try {
          await _upsertUserProfileToSupabase(updatedProfile);
        } catch (e, stackTrace) {
          // Mark dirty so uploadDirtyRecords() retries this on the next sync.
          await database.userDao.updateUserProfile(
            updatedProfile,
            needsUpload: true,
          );
          sentry.addBreadcrumb(
            message: 'Immediate upload failed; record marked dirty for retry',
            category: 'sync',
            data: {
              'operation': 'update_profile',
              'recordId': updatedProfile.id,
            },
          );
          await sentry.reportNetworkError(
            e,
            url: 'supabase:users:update_profile',
            method: 'UPSERT',
            stackTrace: stackTrace,
          );
        }
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

      // Sync to Supabase (best effort; local update already succeeded)
      final updateData = {
        'auth_provider': authProvider,
        'is_anonymous': isAnonymous,
        'updated_at': updatedProfile.updatedAt.toIso8601String(),
      };

      // Only include auth_user_id if provided
      if (authUserId != null) {
        updateData['auth_user_id'] = authUserId;
      }

      try {
        await supabase
            .from('users')
            .update(updateData)
            .eq('id', currentUser.id);
      } catch (e, stackTrace) {
        sentry.addBreadcrumb(
          message: 'Immediate upload failed; record stays dirty for retry',
          category: 'sync',
          data: {
            'operation': 'update_auth_provider',
            'recordId': currentUser.id,
          },
        );
        await sentry.reportNetworkError(
          e,
          url: 'supabase:users:update_auth_provider',
          method: 'UPDATE',
          stackTrace: stackTrace,
        );
      }

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
      return await database.userDao.getUserProfileByAuthUserId(authUserId);
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
      return await database.userDao.getUserProfileById(userId);
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
    return await database.userDao.deleteUserProfile(userId);
  }

  /// Check if user exists
  Future<bool> userExists(String userId) async {
    final user = await database.userDao.getCurrentUserProfile();
    return user != null && user.id == userId;
  }

  /// Save food preferences for a user
  ///
  /// [mergeMode] - when true, merges with existing preferences instead of replacing all.
  /// Use mergeMode=true when syncing from server to avoid data loss.
  /// [source] identifies the origin of the preference:
  /// - 'manual': User explicitly set this preference (default)
  /// - 'allergy:{name}': Auto-set due to an allergy (e.g., 'allergy:gluten')
  /// - 'dietary:{name}': Auto-set due to dietary preference (e.g., 'dietary:vegan')
  Future<void> saveFoodPreferences(
    String userId,
    Map<String, FoodPreference> preferences, {
    Map<String, int>? sliderLevels,
    bool mergeMode = false,
    String source = 'manual',
  }) async {
    await database.foodPreferencesDao.saveFoodPreferences(
      userId,
      preferences,
      sliderLevels: sliderLevels,
      mergeMode: mergeMode,
      source: source,
    );
    // Remote sync is handled via the edge function in AuthService; avoid direct Supabase client writes here.
  }

  /// Remove food preferences by source
  /// Used when allergies or dietary preferences are removed to undo auto-avoids
  /// Returns the number of preferences removed
  Future<int> removeFoodPreferencesBySource(
    String userId,
    String source,
  ) async {
    return await database.foodPreferencesDao.removeFoodPreferencesBySource(
      userId,
      source,
    );
  }

  /// Get food preferences with their sources for a user
  Future<Map<String, String>> getFoodPreferenceSources(String userId) async {
    return await database.foodPreferencesDao.getFoodPreferenceSources(userId);
  }

  /// Get food preferences for a user
  Future<Map<String, FoodPreference>> getFoodPreferences(String userId) async {
    return await database.foodPreferencesDao.getUserFoodPreferences(userId);
  }

  /// Get stored slider levels for each food preference
  Future<Map<String, int>> getFoodPreferenceLevels(String userId) async {
    return await database.foodPreferencesDao.getUserFoodPreferenceLevels(
      userId,
    );
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

  /// In-memory throttle so a burst of preference reads during a single plan
  /// generation (liked + willing + disliked, sometimes across services)
  /// triggers at most one remote reconcile per user.
  final Map<String, DateTime> _prefsReconciledAt = {};
  static const Duration _prefsReconcileTtl = Duration(seconds: 15);

  /// Make the LOCAL food-preference cache mirror the server before a read.
  ///
  /// Historically these getters were local-first and only hit the server when
  /// Drift was empty, with a merge-only hydrate. That let STALE local rows
  /// (e.g. a food the user later changed to "like" remotely, or an avoid set
  /// from an earlier app version) survive forever and be shipped to the plan
  /// edge function — producing a disliked list that contradicts the user's own
  /// likes and collapses the candidate pool to an empty/under-fuelled plan.
  ///
  /// We now reconcile from the server (authoritative full snapshot, see
  /// [fetchAndCacheRemoteFoodPreferences] which REPLACES local on a confirmed
  /// non-empty fetch). Best-effort: offline / network failure leaves the local
  /// cache untouched and the read falls back to whatever is cached. Throttled
  /// to one network round-trip per [_prefsReconcileTtl] per user.
  Future<void> _reconcileFoodPreferencesIfStale(String userId) async {
    final last = _prefsReconciledAt[userId];
    if (last != null && DateTime.now().difference(last) < _prefsReconcileTtl) {
      return;
    }
    // Stamp first so concurrent/sequential reads in the same plan generation
    // don't each fire a fetch; clear on failure so a later read can retry.
    _prefsReconciledAt[userId] = DateTime.now();
    try {
      await fetchAndCacheRemoteFoodPreferences(userId);
    } catch (_) {
      _prefsReconciledAt.remove(userId);
      // Reported by fetchAndCacheRemoteFoodPreferences via SentryReporter.
    }
  }

  /// Get liked foods for a user.
  ///
  /// Reconciles the local cache against the server first (see
  /// [_reconcileFoodPreferencesIfStale]) so the plan pipeline never receives a
  /// stale preference set. Falls back to the local cache when offline.
  Future<List<String>> getLikedFoods(String userId) async {
    await _reconcileFoodPreferencesIfStale(userId);
    return await database.foodPreferencesDao.getLikedFoods(userId);
  }

  /// Get disliked foods for a user. Same reconcile-then-read policy as
  /// [getLikedFoods].
  Future<List<String>> getDislikedFoods(String userId) async {
    await _reconcileFoodPreferencesIfStale(userId);
    return await database.foodPreferencesDao.getDislikedFoods(userId);
  }

  /// Get willing-to-try foods for a user. Same reconcile-then-read policy as
  /// [getLikedFoods]. (Previously unfetched anywhere, so willing-to-try foods
  /// never reached the plan edge function.)
  Future<List<String>> getWillingToTryFoods(String userId) async {
    await _reconcileFoodPreferencesIfStale(userId);
    return await database.foodPreferencesDao.getWillingToTryFoods(userId);
  }

  /// Force a reconcile of the local food-preference cache from the server,
  /// bypassing the throttle. Useful after the user edits preferences.
  Future<void> reconcileFoodPreferencesFromRemote(String userId) async {
    _prefsReconciledAt.remove(userId);
    await _reconcileFoodPreferencesIfStale(userId);
  }

  /// Pull custom foods from Supabase and cache locally
  Future<void> syncUserFoodsFromSupabase(String userId) async {
    try {
      final response = await supabase
          .from('user_foods')
          .select()
          .eq('user_id', userId)
          .eq('is_deleted', false);

      await database.foodsDao.replaceUserFoods(
        userId,
        List<Map<String, dynamic>>.from(response),
      );
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
    await database.diagnosticDao.clearAllData();
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
        sentry.addBreadcrumb(
          message: 'Immediate upload failed; record stays dirty for retry',
          category: 'sync',
          data: {
            'operation': 'reset_anonymous_user',
            'recordId': newAnonymousUserId,
          },
        );
        await sentry.reportNetworkError(
          e,
          url: 'supabase:users:reset_anonymous_user',
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
        final localProfile = await (database.select(
          database.userProfilesTable,
        )..where((t) => t.id.equals(userId))).getSingleOrNull();
        if (localProfile?.needsUpload == true) {
          sentry.addBreadcrumb(
            message: 'Skipped remote user overwrite for dirty local profile',
            category: 'sync',
            data: {'user_id': userId},
          );
          return _convertToDomainUserProfile(localProfile!);
        }

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
        final metadata = Map<String, dynamic>.from(
          userResponse['food_preferences'],
        );
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
        final localPrefs = await database.foodPreferencesDao
            .getUserFoodPreferences(userId);
        if (localPrefs.isNotEmpty) {
          DebugLogger.warning(
            'Server returned empty food_preferences but local has ${localPrefs.length} items - keeping local data',
          );
          return localPrefs;
        }
      }

      // REPLACE local with the server snapshot (mergeMode: false). The server
      // is authoritative here, and merging was the bug: it left stale local
      // rows (e.g. a food now "liked" remotely but still "dislike" locally, or
      // an avoid set from an older app version) in place, so the plan pipeline
      // kept shipping a disliked list that contradicted the user's own likes.
      // The empty-guard above already protects against wiping local when the
      // server returns nothing due to an RLS/network/timing issue, so reaching
      // here means we have a real, non-empty server snapshot to mirror.
      await saveFoodPreferences(
        userId,
        preferences,
        sliderLevels: sliderLevels.isEmpty ? null : sliderLevels,
        mergeMode:
            false, // Replace local cache with the authoritative server set
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

  /// Create/sync a user row in Supabase (called after onboarding and on fresh
  /// login).
  ///
  /// Writes directly to the `users` table via [UserProfile.toJson()] — the
  /// same path used by [_upsertUserProfileToSupabase]. The legacy
  /// `upsert_user_by_device_id` RPC this used to call never existed in the
  /// deployed schema, so every call threw PGRST202 and silently fell back to a
  /// local-only save — meaning fresh-login profiles were never persisted
  /// remotely. See Sentry MEALVANA-ENDURANCE-3W.
  Future<UserProfile> createUserInSupabase(
    String deviceId,
    UserProfile userProfile,
  ) async {
    try {
      await supabase.from('users').upsert(userProfile.toJson());
      await saveUserProfile(userProfile);
      return userProfile;
    } catch (e, stackTrace) {
      await sentry.reportNetworkError(
        e,
        url: 'supabase:users.upsert',
        method: 'UPSERT',
        stackTrace: stackTrace,
      );
      // Fallback to local save so onboarding/login still completes offline.
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
      dietaryPreference:
          DietaryPreference.fromDbValue(
            userData['dietary_preference'] as String?,
          ) ??
          DietaryPreference.none,
      allergies: _parseAllergiesFromSupabase(userData['allergies']),
      // Nutrition target overrides
      nutritionTargetOverrides: userData['nutrition_target_overrides'] != null
          ? NutritionTargetOverrides.fromJson(
              userData['nutrition_target_overrides'] as Map<String, dynamic>,
            )
          : null,
      // User identity
      firstName: userData['first_name'] as String?,
      lastName: userData['last_name'] as String?,
      // Contact information
      email: userData['email'] as String?,
      // Garmin precedence timestamps
      weightPoundsUpdatedAt: userData['weight_pounds_updated_at'] != null
          ? DateTime.tryParse(userData['weight_pounds_updated_at'] as String)
          : null,
      bodyFatPctUpdatedAt: userData['body_fat_pct_updated_at'] != null
          ? DateTime.tryParse(userData['body_fat_pct_updated_at'] as String)
          : null,
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

  Future<void> _upsertUserProfileToSupabase(UserProfile profile) async {
    await supabase.from('users').upsert(profile.toJson());
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

      final foodPreferencesResponse = await supabase
          .from('food_preferences')
          .select('id')
          .eq('user_id', userId)
          .limit(1);

      if ((foodPreferencesResponse as List).isNotEmpty) {
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
      rethrow; // Let caller decide how to handle this error
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
