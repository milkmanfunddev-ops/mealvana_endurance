import 'dart:async';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mealvana_endurance/features/auth/data/user_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthUser, AuthException;
import 'package:device_info_plus/device_info_plus.dart';
import '../data/auth_repository_edge.dart';
import '../domain/user_preferences.dart';
import '../../../shared/services/app_external_deps.dart';
import '../../../shared/services/logging_service.dart';
import '../../../shared/services/sentry/sentry_reporter.dart';

/// Application service for managing user authentication and preferences
/// Follows the Andrea Bizzotto pattern with Ref for dependency injection
class AuthService {
  AuthService(this.ref);
  final Ref ref;

  /// Get the user repository (async)
  Future<UserRepository> get _userRepository async => await ref.read(userRepositoryProvider.future);
  
  /// Get the Edge Function auth repository
  AuthRepositoryEdge get _authRepositoryEdge => ref.read(authRepositoryEdgeProvider);

  AppLogger get _logger => ref.read(appExternalDepsProvider).logger;
  SentryReporter get _sentry => ref.read(appExternalDepsProvider).sentry;
  SupabaseClient get _supabase => ref.read(appExternalDepsProvider).supabaseClient;

  /// Create a new user profile during onboarding using Supabase Auth
  /// Uses anonymous auth session created during app startup
  ///
  /// Handles existing users transitioning to new auth sessions by checking
  /// if a user with the same device_id already exists and updating that row
  /// instead of creating a duplicate (which would violate the unique constraint).
  Future<UserProfile> createUser({
    required Gender gender,
    required DateTime birthday,
    required int heightFeet,
    required int heightInches,
    required double weightPounds,
    required bool runsWithWaterBottle,
    GutTraining? gutTraining,
    Map<String, FoodPreference>? foodPreferences,
  }) async {
    try {
      // Get Supabase auth session (should exist from app startup)
      final authUser = _supabase.auth.currentUser;
      if (authUser == null) {
        throw Exception('No Supabase auth session found - app startup may have failed');
      }

      // Get device ID for backwards compatibility and analytics
      final deviceId = await _getDeviceId();

      // Check if a user with this device_id already exists
      // This handles existing users who are transitioning to new auth sessions
      final existingUserResponse = await _supabase
          .from('users')
          .select('id')
          .eq('device_id', deviceId)
          .maybeSingle();

      final String effectiveUserId;
      final bool isExistingUser = existingUserResponse != null;

      if (isExistingUser) {
        // User exists - preserve their existing ID to maintain foreign key relationships
        effectiveUserId = existingUserResponse['id'] as String;
        _logger.info(
          'Existing user found for device, updating with new auth session',
          context: 'AUTH',
          data: {
            'device_id': deviceId,
            'existing_user_id': effectiveUserId,
            'new_auth_user_id': authUser.id,
          },
        );
      } else {
        // New user - use Supabase auth UUID as the canonical ID
        effectiveUserId = authUser.id;
        _logger.info(
          'Creating new user',
          context: 'AUTH',
          data: {
            'device_id': deviceId,
            'user_id': effectiveUserId,
          },
        );
      }

      // Get app version
      const appVersion = '1.0.0';

      // Create UserProfile with Supabase auth fields
      final now = DateTime.now();
      final userProfile = UserProfile(
        id: effectiveUserId, // Use existing ID or new auth ID
        deviceId: deviceId, // Keep for backwards compatibility
        authUserId: authUser.id, // Always update to current Supabase auth user ID
        authProvider: 'anonymous', // Anonymous auth
        isAnonymous: true, // Anonymous until linked to email/social
        gender: gender,
        birthday: birthday,
        heightFeet: heightFeet,
        heightInches: heightInches,
        weightPounds: weightPounds,
        runsWithWaterBottle: runsWithWaterBottle,
        gutTraining: gutTraining ?? GutTraining.high,
        onboardingCompleted: false,
        appVersion: appVersion,
        createdAt: isExistingUser ? now : now, // For existing users, this will be ignored by upsert
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
      );

      // Save to Supabase using device_id as conflict target
      // This ensures existing users get updated rather than causing a duplicate key error
      await _supabase.from('users').upsert(
        userProfile.toJson(),
        onConflict: 'device_id',
      );

      // Save locally for caching
      final userRepo = await _userRepository;
      await userRepo.saveUserProfile(userProfile);

      // Update Sentry user context with new user details
      await _sentry.setUserContext(
        deviceId: effectiveUserId, // Use effective user ID for Sentry
        appVersion: appVersion,
        onboardingCompleted: false,
        gutTrainingLevel: (gutTraining ?? GutTraining.high).name,
      );

      _sentry.addBreadcrumb(
        message: isExistingUser
            ? 'Existing user updated with new auth session'
            : 'New user created with Supabase Auth',
        category: 'user_lifecycle',
        data: {
          'user_id': effectiveUserId,
          'auth_user_id': authUser.id,
          'auth_provider': 'anonymous',
          'is_existing_user': isExistingUser.toString(),
          'gender': gender.name,
          'gut_training': (gutTraining ?? GutTraining.high).name,
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
  Future<String> _getDeviceId() async {
    try {
      final deviceInfo = DeviceInfoPlugin();
      
      if (Platform.isAndroid) {
        final androidInfo = await deviceInfo.androidInfo;
        final deviceId = androidInfo.id;
        
        // Fallback for devices that return empty Android ID
        if (deviceId.isEmpty) {
          final fallbackId = 'android-${androidInfo.fingerprint.hashCode.abs()}';
          return fallbackId;
        }
        return deviceId;
      } else if (Platform.isIOS) {
        final iosInfo = await deviceInfo.iosInfo;
        final deviceId = iosInfo.identifierForVendor;
        
        if (deviceId == null || deviceId.isEmpty) {
          final fallbackId = 'ios-${iosInfo.model.hashCode.abs()}';
          return fallbackId;
        }
        return deviceId;
      } else {
        return 'unknown-platform-${DateTime.now().millisecondsSinceEpoch}';
      }
    } catch (e) {
      // Ultimate fallback
      final emergencyId = 'emergency-${DateTime.now().millisecondsSinceEpoch}';
      return emergencyId;
    }
  }
  
  /// Update user profile
  Future<void> updateUserProfile(UserProfile profile) async {
    final userRepo = await _userRepository;
    await userRepo.updateUserProfile(profile);
  }

  /// Update sport preferences for a user
  Future<void> updateSportPreferences(
    String userId, {
    bool? giSensitivity,
    int? ftpWatts,
    int? typicalBikeBottles,
    bool? hasAeroBottle,
    bool? hasBentoBox,
    int? cssPacePer100mSeconds,
    bool? typicalWetsuit,
    String? typicalSwimCapType,
  }) async {
    // Get current user profile
    final currentUser = await getCurrentUser();
    if (currentUser == null) {
      throw Exception('No user found to update sport preferences');
    }

    // Update the user profile with sport preferences
    final updatedProfile = currentUser.copyWith(
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

    // Save to local database
    final userRepo = await _userRepository;
    await userRepo.updateUserProfile(updatedProfile);

    // TODO: Sync to Supabase when edge function is ready
  }

  /// Check if user has completed onboarding
  Future<bool> hasCompletedOnboarding() async {
    final user = await getCurrentUser();
    if (user == null) return false;
    
    // Check the onboardingCompleted flag from UserProfile
    return user.onboardingCompleted;
  }

  /// Save food preferences (typically during onboarding)
  /// Uses Edge Function for optimized multi-step operation (reduces network roundtrips)
  Future<void> saveFoodPreferences(
    String userId,
    Map<String, FoodPreference> preferences, {
    Map<String, int>? sliderLevels,
  }) async {
    // userId is Supabase auth UUID (from auth.currentUser.id)
    final deviceId = userId; // Keep variable name for backwards compatibility in logs

    final normalizedLevels = sliderLevels ??
        preferences.map((food, preference) =>
            MapEntry(food, sliderLevelForPreference(preference)));

    try {
      _logger.info(
        'Saving food preferences via edge function',
        context: 'AUTH',
        data: {'userId': userId, 'count': preferences.length},
      );

      // Call Edge Function - handles user check, preferences upsert, and onboarding flag in one operation
      // This reduces 3-5 network roundtrips to 1
      final result = await _authRepositoryEdge.saveFoodPreferences(
        userId,
        preferences,
        preferenceLevels: normalizedLevels,
      );

      if (!result.success) {
        _logger.error(
          'Edge function food preferences save failed',
          context: 'AUTH',
          data: {'userId': userId, 'error': result.message},
        );
        throw Exception(result.message ?? 'Failed to save food preferences');
      }

      _logger.info(
        'Food preferences saved successfully via edge function',
        context: 'AUTH',
        data: {'userId': userId, 'savedCount': result.preferencesCount},
      );

      // Save locally for offline access
      final userRepo = await _userRepository;
      await userRepo.saveFoodPreferences(
        userId,
        preferences,
        sliderLevels: normalizedLevels,
      );

      // Mark user as having completed onboarding locally
      final user = await getCurrentUser();
      if (user != null) {
        final updatedUser = user.copyWith(
          onboardingCompleted: true,
          updatedAt: DateTime.now(),
        );
        await userRepo.updateUserProfile(updatedUser);

        // Update Sentry user context (unawaited for performance)
        unawaited(_sentry.setUserContext(
          deviceId: userId,
          appVersion: '1.0.0',
          onboardingCompleted: true,
          gutTrainingLevel: user.gutTraining.name,
        ));

        _sentry.addBreadcrumb(
          message: 'Onboarding completed - food preferences saved',
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
      throw Exception('Failed to save food preferences. Please check your internet connection and try again.');
    }
  }

  /// Update a single food preference
  Future<void> updateFoodPreference(String userId, String foodId, FoodPreference preference) async {
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

  /// Get liked foods for a user
  Future<List<String>> getLikedFoods(String userId) async {
    try {
      final userRepo = await _userRepository;
      return await userRepo.getLikedFoods(userId);
    } catch (e) {
      return [];
    }
  }

  /// Get disliked foods for a user  
  Future<List<String>> getDislikedFoods(String userId) async {
    try {
      final userRepo = await _userRepository;
      return await userRepo.getDislikedFoods(userId);
    } catch (e) {
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
