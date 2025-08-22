import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../domain/user_preferences.dart';
import '../../../shared/database/app_database.dart';
import '../../../shared/database/database_provider.dart';
import '../../../shared/services/sentry_service.dart';

part 'user_repository.g.dart';

/// Repository for managing user profile data in Drift database and Supabase
class UserRepository {
  UserRepository({
    required this.database,
    required this.supabase,
    required this.sentryService,
  });
  
  final AppDatabase database;
  final SupabaseClient supabase;
  final SentryService sentryService;

  /// Save user profile
  Future<void> saveUserProfile(UserProfile profile) async {
    try {
      await database.saveUserProfile(profile);
      sentryService.addBreadcrumb(
        message: 'User profile saved successfully',
        category: 'database',
        data: {'user_id': profile.id},
      );
    } catch (e, stackTrace) {
      await sentryService.reportDatabaseError(
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
      await sentryService.reportDatabaseError(
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
      await sentryService.reportDatabaseError(
        e,
        operation: 'getCurrentUser',
        table: 'user_profiles',
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Update user profile
  Future<void> updateUserProfile(UserProfile profile) async {
    try {
      final updatedProfile = profile.copyWith(updatedAt: DateTime.now());
      await database.updateUserProfile(updatedProfile);
      sentryService.addBreadcrumb(
        message: 'User profile updated successfully',
        category: 'database',
        data: {'user_id': profile.id},
      );
    } catch (e, stackTrace) {
      await sentryService.reportDatabaseError(
        e,
        operation: 'updateUserProfile',
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
  Future<void> saveFoodPreferences(String userId, Map<String, FoodPreference> preferences) async {
    await database.saveFoodPreferences(userId, preferences);
  }

  /// Get food preferences for a user
  Future<Map<String, FoodPreference>> getFoodPreferences(String userId) async {
    return await database.getUserFoodPreferences(userId);
  }

  /// Update a single food preference
  Future<void> updateFoodPreference(String userId, String foodId, FoodPreference preference) async {
    final existingPreferences = await getFoodPreferences(userId);
    existingPreferences[foodId] = preference;
    await saveFoodPreferences(userId, existingPreferences);
  }

  /// Get liked foods for a user
  Future<List<String>> getLikedFoods(String userId) async {
    return await database.getLikedFoods(userId);
  }

  /// Get disliked foods for a user
  Future<List<String>> getDislikedFoods(String userId) async {
    return await database.getDislikedFoods(userId);
  }

  /// Clear all user data (for testing/reset)
  Future<void> clearAllData() async {
    await database.clearAllData();
  }

  // SUPABASE SYNC METHODS

  /// Sync local user data with Supabase and return updated user
  Future<UserProfile> syncUserWithSupabase(String deviceId, UserProfile localUser) async {
    try {
      // Convert user profile to JSON for Supabase
      final userData = {
        'gender': localUser.gender.name,
        'birthday': localUser.birthday.toIso8601String().split('T')[0], // Date only
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
      final response = await supabase.rpc('upsert_user_by_device_id', params: {
        'p_device_id': deviceId,
        'p_user_data': userData,
      });

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
      await sentryService.reportNetworkError(
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
      final response = await supabase.rpc('get_user_by_device_id', params: {
        'p_device_id': deviceId,
      });

      if (response != null) {
        return _parseUserFromSupabase(response, deviceId);
      } else {
        return null;
      }
    } catch (e, stackTrace) {
      await sentryService.reportNetworkError(
        e,
        url: 'supabase:get_user_by_device_id',
        method: 'RPC',
        stackTrace: stackTrace,
      );
      return null;
    }
  }

  /// Create new user in Supabase (called after onboarding)
  Future<UserProfile> createUserInSupabase(String deviceId, UserProfile userProfile) async {
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

      final response = await supabase.rpc('upsert_user_by_device_id', params: {
        'p_device_id': deviceId,
        'p_user_data': userData,
      });

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
      await sentryService.reportNetworkError(
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
      id: deviceId, // Use device ID as the local user ID
      gender: Gender.values.firstWhere(
        (e) => e.name == userData['gender'],
        orElse: () => Gender.other,
      ),
      birthday: DateTime.parse(userData['birthday'] ?? DateTime.now().toIso8601String()),
      heightFeet: userData['height_feet'] ?? 5,
      heightInches: userData['height_inches'] ?? 8,
      weightPounds: (userData['weight_pounds'] as num?)?.toDouble() ?? 150.0,
      runsWithWaterBottle: userData['runs_with_water_bottle'] ?? false,
      gutTraining: GutTraining.values.firstWhere(
        (e) => e.name == userData['gut_training_level'],
        orElse: () => GutTraining.moderate,
      ),
      onboardingCompleted: userData['onboarding_completed'] ?? false,
      createdAt: DateTime.parse(userData['created_at'] ?? DateTime.now().toIso8601String()),
      updatedAt: DateTime.parse(userData['updated_at'] ?? DateTime.now().toIso8601String()),
      appVersion: userData['app_version'] ?? '1.0.0',
    );
  }
}

/// Repository provider following Andrea's pattern
@riverpod
Future<UserRepository> userRepository(Ref ref) async {
  // Get the database instance
  final database = await ref.watch(databaseProvider.future);
  final sentryService = ref.watch(sentryServiceProvider);
  
  return UserRepository(
    database: database,
    supabase: Supabase.instance.client,
    sentryService: sentryService,
  );
}