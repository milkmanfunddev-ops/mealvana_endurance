import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mealvana_endurance/features/auth/data/user_repository.dart';
import 'package:mealvana_endurance/features/nutrition_plan/domain/run_parameters.dart';
import 'package:supabase_flutter/supabase_flutter.dart'
    hide AuthUser, AuthException;
import '../../../shared/services/device_info_service.dart';
import '../data/auth_repository_edge.dart';
import '../domain/user_preferences.dart';
import '../../onboarding/domain/dietary_preference.dart';
import '../../onboarding/domain/allergy.dart';
import '../../../shared/services/app_external_deps.dart';
import '../../../shared/services/logging_service.dart';
import '../../../shared/services/sentry/sentry_reporter.dart';

/// Application service for managing user authentication and preferences
/// Follows the Andrea Bizzotto pattern with Ref for dependency injection
class AuthService {
  AuthService(this.ref);
  final Ref ref;

  /// Get the user repository (async)
  Future<UserRepository> get _userRepository async =>
      await ref.read(userRepositoryProvider.future);

  /// Get the Edge Function auth repository
  AuthRepositoryEdge get _authRepositoryEdge =>
      ref.read(authRepositoryEdgeProvider);

  AppLogger get _logger => ref.read(appExternalDepsProvider).logger;
  SentryReporter get _sentry => ref.read(appExternalDepsProvider).sentry;
  SupabaseClient get _supabase =>
      ref.read(appExternalDepsProvider).supabaseClient;

  /// Create a new user profile during onboarding using Supabase Auth
  /// Uses anonymous auth session created during app startup
  ///
  /// IMPORTANT: Each new registration creates a completely fresh user profile.
  /// Multiple users can share the same device_id (family members, account switching).
  /// The auth user ID is always used as the primary identifier for new profiles.
  Future<UserProfile> createUser({
    required Gender gender,
    required DateTime birthday,
    required int heightFeet,
    required int heightInches,
    required double weightPounds,
    required bool runsWithWaterBottle,
    GutTraining? gutTraining,
    UnitSystem unitSystem = UnitSystem.imperial,
    Map<String, FoodPreference>? foodPreferences,
    String authProvider =
        'anonymous', // 'anonymous', 'email', 'google', 'apple'
    bool isAnonymous = true, // false when user signs up with email/OAuth
    String? firstName,
    String? lastName,
    String? email,
  }) async {
    try {
      // Get or create Supabase auth session
      // Session may not exist if user logged out and is starting fresh
      var authUser = _supabase.auth.currentUser;
      if (authUser == null) {
        _logger.info(
          'No auth session found, creating anonymous session for new user',
          context: 'AUTH',
        );
        final response = await _supabase.auth.signInAnonymously();
        authUser = response.user;
        if (authUser == null) {
          throw Exception('Failed to create anonymous session');
        }
      }

      // Get device ID for analytics and backwards compatibility
      // NOTE: device_id is NOT used to look up existing users - each new registration
      // creates a fresh user profile with the auth user's UUID as the primary ID
      final deviceId = await _getDeviceId();

      // ALWAYS use auth user ID for new registrations
      // This ensures each registration creates a fresh user profile
      final String effectiveUserId = authUser.id;

      _logger.info(
        'Creating new user with Supabase auth ID',
        context: 'AUTH',
        data: {'device_id': deviceId, 'user_id': effectiveUserId},
      );

      // Get app version
      const appVersion = '1.0.0';

      // Create UserProfile with Supabase auth fields
      final now = DateTime.now();
      final userProfile = UserProfile(
        id: effectiveUserId, // Always use auth user ID for new registrations
        deviceId: deviceId, // Keep for analytics and backwards compatibility
        authUserId: authUser.id, // Supabase auth user ID
        authProvider: authProvider, // 'anonymous', 'email', 'google', 'apple'
        isAnonymous: isAnonymous, // false when user signs up with email/OAuth
        gender: gender,
        birthday: birthday,
        heightFeet: heightFeet,
        heightInches: heightInches,
        weightPounds: weightPounds,
        runsWithWaterBottle: runsWithWaterBottle,
        gutTraining: gutTraining ?? GutTraining.moderate,
        unitSystem: unitSystem,
        onboardingCompleted:
            true, // Set true immediately so user can proceed even if later steps fail
        appVersion: appVersion,
        createdAt: now,
        updatedAt: now,
        // Optional fields default to null
        giSensitivity: null,
        ftpWatts: null,
        typicalBikeBottles: null,
        hasAeroBottle: null,
        hasBentoBox: null,
        cssPacePer100mSeconds: null,
        typicalWetsuit: null,
        typicalSwimCapType: null,
        // Optional name fields for coach mode athlete identification
        firstName: firstName,
        lastName: lastName,
        // Contact information (auto-captured from auth or manual entry)
        email: email,
      );

      // Save locally first (offline-first) and mark for background upload
      // IMPORTANT: needsUpload=true triggers background sync via DataSyncService
      final userRepo = await _userRepository;
      await userRepo.saveUserProfile(userProfile, needsUpload: true);

      _logger.info(
        'User profile saved locally and marked for background upload',
        context: 'AUTH',
        data: {'userId': effectiveUserId},
      );

      // NOTE: Supabase upload is now handled by background sync (DataSyncService)
      // This allows instant navigation after registration while data syncs in background

      // Update Sentry user context with new user details
      await _sentry.setUserContext(
        deviceId: effectiveUserId, // Use effective user ID for Sentry
        appVersion: appVersion,
        onboardingCompleted: true,
        gutTrainingLevel: (gutTraining ?? GutTraining.moderate).name,
      );

      _sentry.addBreadcrumb(
        message: 'New user created with Supabase Auth',
        category: 'user_lifecycle',
        data: {
          'user_id': effectiveUserId,
          'auth_user_id': authUser.id,
          'auth_provider': authProvider,
          'gender': gender.name,
          'gut_training': (gutTraining ?? GutTraining.moderate).name,
        },
      );

      return userProfile;
    } catch (e, stackTrace) {
      // Critical: User creation failed
      await _sentry.reportCriticalError(
        e,
        stackTrace: stackTrace,
        context: 'user_creation_failure',
        tags: {
          'error_type': 'supabase_auth_user_creation_failure',
          'operation': 'create_user',
        },
      );
      rethrow;
    }
  }

  /// Get the current user profile (async - waits for repository to be ready)
  Future<UserProfile?> getCurrentUser() async {
    try {
      final userRepo = await ref.read(userRepositoryProvider.future);
      final user = await userRepo.getCurrentUser();

      // Check if user exists but has empty device ID - fix it
      if (user != null && (user.id.isEmpty || user.id.trim().isEmpty)) {
        // Generate a new device ID
        final newDeviceId = await _getDeviceId();

        // Update the user with the new device ID
        final updatedUser = user.copyWith(
          id: newDeviceId,
          updatedAt: DateTime.now(),
        );

        // Save the updated user locally
        await userRepo.updateUserProfile(updatedUser);

        // Also update in Supabase if the user exists there
        try {
          await _authRepositoryEdge.updateUser(updatedUser);
        } catch (e) {
          // Continue anyway since local update succeeded
        }

        return updatedUser;
      }

      return user;
    } catch (e, stackTrace) {
      // Critical: Can't get current user - this affects the entire app
      await _sentry.reportCriticalError(
        e,
        stackTrace: stackTrace,
        context: 'get_current_user_failure',
        tags: {
          'error_type': 'user_retrieval_critical',
          'operation': 'get_current_user',
          'impact': 'app_functionality',
        },
      );
      return null;
    }
  }

  /// Get device ID for user identification
  /// Uses the shared DeviceInfoService to prevent concurrent DeviceInfoPlugin calls
  Future<String> _getDeviceId() async {
    // Ensure device info is initialized
    if (!DeviceInfoService.instance.isInitialized) {
      await DeviceInfoService.instance.initialize();
    }
    return DeviceInfoService.instance.deviceId;
  }

  /// Update user profile
  Future<void> updateUserProfile(UserProfile profile) async {
    final userRepo = await _userRepository;
    await userRepo.updateUserProfile(profile);
  }

  /// Update sport preferences for a user
  Future<void> updateSportPreferences(
    String userId, {
    UserProfile? currentUser,
    bool? giSensitivity,
    int? ftpWatts,
    int? typicalBikeBottles,
    bool? hasAeroBottle,
    bool? hasBentoBox,
    int? cssPacePer100mSeconds,
    bool? typicalWetsuit,
    String? typicalSwimCapType,
  }) async {
    // Get current user profile (use provided one to avoid redundant DB read)
    final user = currentUser ?? await getCurrentUser();
    if (user == null) {
      throw Exception('No user found to update sport preferences');
    }

    // Update the user profile with sport preferences
    final updatedProfile = user.copyWith(
      giSensitivity: giSensitivity,
      ftpWatts: ftpWatts,
      typicalBikeBottles: typicalBikeBottles,
      hasAeroBottle: hasAeroBottle,
      hasBentoBox: hasBentoBox,
      cssPacePer100mSeconds: cssPacePer100mSeconds,
      typicalWetsuit: typicalWetsuit,
      typicalSwimCapType: typicalSwimCapType,
      updatedAt: DateTime.now(),
    );

    // Save to local database and mark for background upload
    // NOTE: Background sync via DataSyncService will upload the complete user profile
    final userRepo = await _userRepository;
    await userRepo.updateUserProfile(updatedProfile, needsUpload: true);

    _logger.info(
      'Sport preferences saved locally and marked for background upload',
      context: 'AUTH',
      data: {'userId': userId},
    );
  }

  /// Update dietary preference for a user
  Future<void> updateDietaryPreference(
    String userId,
    DietaryPreference? dietaryPreference,
  ) async {
    // Get current user profile
    final currentUser = await getCurrentUser();
    if (currentUser == null) {
      throw Exception('No user found to update dietary preference');
    }

    // Update the user profile with dietary preference
    final updatedProfile = currentUser.copyWith(
      dietaryPreference: dietaryPreference,
      updatedAt: DateTime.now(),
    );

    // Save to local database and mark for background upload
    // NOTE: Background sync via DataSyncService will upload the complete user profile
    final userRepo = await _userRepository;
    await userRepo.updateUserProfile(updatedProfile, needsUpload: true);

    _logger.info(
      'Dietary preference saved locally and marked for background upload',
      context: 'AUTH',
      data: {'userId': userId},
    );
  }

  /// Update allergies for a user
  Future<void> updateAllergies(String userId, List<Allergy> allergies) async {
    // Get current user profile
    final currentUser = await getCurrentUser();
    if (currentUser == null) {
      throw Exception('No user found to update allergies');
    }

    // Update the user profile with allergies
    final updatedProfile = currentUser.copyWith(
      allergies: allergies,
      updatedAt: DateTime.now(),
    );

    // Save to local database and mark for background upload
    // NOTE: Background sync via DataSyncService will upload the complete user profile
    final userRepo = await _userRepository;
    await userRepo.updateUserProfile(updatedProfile, needsUpload: true);

    _logger.info(
      'Allergies saved locally and marked for background upload',
      context: 'AUTH',
      data: {'userId': userId},
    );
  }

  /// Check if user has completed onboarding
  Future<bool> hasCompletedOnboarding() async {
    final user = await getCurrentUser();
    if (user == null) return false;

    // Check the onboardingCompleted flag from UserProfile
    return user.onboardingCompleted;
  }

  /// Save food preferences (typically during onboarding)
  /// Uses consolidated Edge Function for optimized multi-step operation (reduces network roundtrips)
  /// [source] identifies the origin of the preference:
  /// - 'manual': User explicitly set this preference (default)
  /// - 'allergy:{name}': Auto-set due to an allergy (e.g., 'allergy:gluten')
  /// - 'dietary:{name}': Auto-set due to dietary preference (e.g., 'dietary:vegan')
  Future<void> saveFoodPreferences(
    String userId,
    Map<String, FoodPreference> preferences, {
    Map<String, int>? sliderLevels,
    String source = 'manual',
  }) async {
    // userId is Supabase auth UUID (from auth.currentUser.id)
    final deviceId =
        userId; // Keep variable name for backwards compatibility in logs

    final normalizedLevels =
        sliderLevels ??
        preferences.map(
          (food, preference) =>
              MapEntry(food, sliderLevelForPreference(preference)),
        );

    try {
      _logger.info(
        'Saving food preferences via consolidated edge function',
        context: 'AUTH',
        data: {'userId': userId, 'count': preferences.length},
      );

      // Save locally first (offline-first)
      final userRepo = await _userRepository;
      await userRepo.saveFoodPreferences(
        userId,
        preferences,
        sliderLevels: normalizedLevels,
        source: source,
      );

      // Mark user profile for background upload (onboardingCompleted already set in createUser)
      final user = await getCurrentUser();
      if (user != null) {
        final updatedUser = user.copyWith(updatedAt: DateTime.now());
        // Mark for background upload - DataSyncService will sync user profile + food preferences
        await userRepo.updateUserProfile(updatedUser, needsUpload: true);

        _logger.info(
          'Food preferences saved locally and marked for background upload',
          context: 'AUTH',
          data: {'userId': userId, 'foodPreferencesCount': preferences.length},
        );

        _sentry.addBreadcrumb(
          message: 'Food preferences saved locally',
          category: 'user_lifecycle',
          data: {
            'user_id': userId,
            'food_preferences_count': preferences.length.toString(),
          },
        );
      }
    } catch (e, stackTrace) {
      // Critical: Food preferences save failure blocks onboarding completion
      await _sentry.reportCriticalError(
        e,
        stackTrace: stackTrace,
        context: 'food_preferences_save_failure',
        tags: {
          'device_id': deviceId,
          'error_type': 'edge_function_failure',
          'operation': 'save_food_preferences',
          'preferences_count': preferences.length.toString(),
        },
      );
      throw Exception(
        'Failed to save food preferences. Please check your internet connection and try again.',
      );
    }
  }

  /// Update a single food preference
  Future<void> updateFoodPreference(
    String userId,
    String foodId,
    FoodPreference preference,
  ) async {
    final userRepo = await _userRepository;
    await userRepo.updateFoodPreference(userId, foodId, preference);
  }

  /// Get food preferences for a user
  Future<Map<String, FoodPreference>?> getFoodPreferences(String userId) async {
    try {
      final userRepo = await _userRepository;
      return await userRepo.getFoodPreferences(userId);
    } catch (e) {
      return null;
    }
  }

  /// Get slider levels for food preferences
  Future<Map<String, int>> getFoodPreferenceLevels(String userId) async {
    try {
      final userRepo = await _userRepository;
      return await userRepo.getFoodPreferenceLevels(userId);
    } catch (e) {
      return {};
    }
  }

  /// Remove food preferences by source
  /// Used when allergies or dietary preferences are removed to undo auto-avoids
  /// [source] - The source to match (e.g., 'allergy:gluten', 'dietary:vegan')
  /// Returns the number of preferences removed
  Future<int> removeFoodPreferencesBySource(
    String userId,
    String source,
  ) async {
    try {
      final userRepo = await _userRepository;
      final removedCount = await userRepo.removeFoodPreferencesBySource(
        userId,
        source,
      );
      _logger.info(
        'Removed $removedCount food preferences with source: $source',
        context: 'AUTH',
        data: {
          'userId': userId,
          'source': source,
          'removedCount': removedCount,
        },
      );
      return removedCount;
    } catch (e) {
      _logger.warning(
        'Failed to remove food preferences by source: $e',
        context: 'AUTH',
        data: {'userId': userId, 'source': source},
      );
      return 0;
    }
  }

  /// Get food preferences with their sources for a user
  /// Returns a map of food name -> preference source
  Future<Map<String, String>> getFoodPreferenceSources(String userId) async {
    try {
      final userRepo = await _userRepository;
      return await userRepo.getFoodPreferenceSources(userId);
    } catch (e) {
      return {};
    }
  }

  /// Get liked foods for a user.
  ///
  /// Errors are reported to Sentry instead of being silently swallowed so the
  /// "no dislikes/likes reach the edge function" failure mode in #23 surfaces
  /// in observability. We still return [] on failure to keep the caller
  /// non-fatal (plan generation continues without the preference filter
  /// rather than crashing).
  Future<List<String>> getLikedFoods(String userId) async {
    try {
      final userRepo = await _userRepository;
      return await userRepo.getLikedFoods(userId);
    } catch (e, stackTrace) {
      await _sentry.reportDatabaseError(
        e,
        operation: 'getLikedFoods',
        table: 'food_preferences',
        stackTrace: stackTrace,
      );
      return [];
    }
  }

  /// Get disliked foods for a user. See [getLikedFoods] for error handling. (#23)
  Future<List<String>> getDislikedFoods(String userId) async {
    try {
      final userRepo = await _userRepository;
      return await userRepo.getDislikedFoods(userId);
    } catch (e, stackTrace) {
      await _sentry.reportDatabaseError(
        e,
        operation: 'getDislikedFoods',
        table: 'food_preferences',
        stackTrace: stackTrace,
      );
      return [];
    }
  }

  /// Get willing-to-try foods for a user. See [getLikedFoods] for error
  /// handling. These were previously never fetched, so the plan edge
  /// function's `willing_to_try_foods` input was always empty.
  Future<List<String>> getWillingToTryFoods(String userId) async {
    try {
      final userRepo = await _userRepository;
      return await userRepo.getWillingToTryFoods(userId);
    } catch (e, stackTrace) {
      await _sentry.reportDatabaseError(
        e,
        operation: 'getWillingToTryFoods',
        table: 'food_preferences',
        stackTrace: stackTrace,
      );
      return [];
    }
  }

  /// Reset all user data (for testing or re-onboarding)
  Future<void> resetUserData() async {
    final userRepo = await _userRepository;
    await userRepo.clearAllData();
  }

  /// Get user profile summary for other features
  Future<Map<String, dynamic>?> getUserSummary() async {
    final user = await getCurrentUser();
    if (user == null) return null;

    final preferences = await getFoodPreferences(user.id);

    return {
      'id': user.id,
      'age': user.age,
      'gender': user.gender.toString().split('.').last,
      'weightPounds': user.weightPounds,
      'heightInches': user.totalHeightInches,
      'runsWithWaterBottle': user.runsWithWaterBottle,
      'hasPreferences': preferences != null,
      'preferredFoodCount': preferences?.length ?? 0,
    };
  }
}

/// Provider for AuthService
final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService(ref);
});

/// Provider for current user profile (async-aware)
final currentUserProvider = FutureProvider<UserProfile?>((ref) async {
  final authService = ref.watch(authServiceProvider);
  return await authService.getCurrentUser();
});

/// Provider for AuthRepositoryEdge
final authRepositoryEdgeProvider = Provider<AuthRepositoryEdge>((ref) {
  final externalDeps = ref.read(appExternalDepsProvider);
  return AuthRepositoryEdge(externalDeps.supabaseClient, externalDeps.logger);
});
