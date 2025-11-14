import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../domain/user_preferences.dart';
import '../../../shared/services/app_external_deps.dart';
import '../../../shared/services/logging_service.dart';

/// Repository for auth operations using Supabase Edge Functions
/// Replaces direct database access with Edge Function calls
class AuthRepositoryEdge {
  AuthRepositoryEdge(this._supabase, this._logger);

  final SupabaseClient _supabase;
  final AppLogger _logger;

  /// Create a new user via Edge Function
  Future<CreateUserResult> createUser({
    required String deviceId,
    required Gender gender,
    required DateTime birthday,
    required int heightFeet,
    required int heightInches,
    required double weightPounds,
    required bool runsWithWaterBottle,
    required GutTrainingLevel gutTrainingLevel,
    required String appVersion,
    Map<String, FoodPreference>? foodPreferences,
  }) async {
    try {
      // Prepare request payload
      final requestBody = {
        'device_id': deviceId,
        'gender': gender.value,
        'birthday': birthday.toIso8601String().split('T')[0], // Date only
        'height_feet': heightFeet,
        'height_inches': heightInches,
        'weight_pounds': weightPounds,
        'runs_with_water_bottle': runsWithWaterBottle,
        'gut_training_level': gutTrainingLevel.value,
        'app_version': appVersion,
        if (foodPreferences != null)
          'food_preferences': foodPreferences.map(
            (key, value) => MapEntry(key, value.value),
          ),
      };

      // Call Edge Function
      final response = await _supabase.functions.invoke(
        'create-user',
        body: requestBody,
      );

      // Handle response
      if (response.status >= 200 && response.status < 300) {
        final data = response.data as Map<String, dynamic>;
        
        if (data['success'] == true) {
          return CreateUserResult(
            success: true,
            user: UserProfile.fromJson(data['user']),
            message: data['message'],
          );
        } else {
          return CreateUserResult(
            success: false,
            message: data['message'] ?? 'Unknown error occurred',
          );
        }
      } else {
        return CreateUserResult(
          success: false,
          message: 'Edge Function call failed with status ${response.status}',
        );
      }
    } catch (e) {
      _logger.error(
        'Error invoking create-user edge function',
        context: 'AUTH_EDGE',
        error: e,
      );

      // Handle 409 Conflict (user already exists) as success
      if (e is FunctionException && e.status == 409) {
        // Try to fetch the existing user
        final existingUser = await getUserByDeviceId(deviceId);
        if (existingUser != null) {
          return CreateUserResult(
            success: true,
            user: existingUser,
            message: 'User already exists',
          );
        }
      }

      return CreateUserResult(
        success: false,
        message: 'Failed to create user: $e',
      );
    }
  }

  /// Get user by device ID (direct database call since it's simple)
  Future<UserProfile?> getUserByDeviceId(String deviceId) async {
    try {
      final response = await _supabase
          .from('users')
          .select('*')
          .eq('device_id', deviceId)
          .maybeSingle();

      if (response != null) {
        return UserProfile.fromJson(response);
      }
      return null;
    } catch (e) {
      _logger.error(
        'Error fetching user by device ID',
        context: 'AUTH_EDGE',
        error: e,
        data: {'deviceId': deviceId},
      );
      return null;
    }
  }

  /// Get user food preferences (direct database call since it's simple)
  Future<Map<String, FoodPreference>> getFoodPreferences(String deviceId) async {
    try {
      final response = await _supabase
          .from('food_preferences')
          .select('food_name, preference')
          .eq('device_id', deviceId);

      final preferences = <String, FoodPreference>{};
      for (final row in response) {
        final preference = FoodPreference.values.firstWhere(
          (p) => p.value == row['preference'],
          orElse: () => FoodPreference.dislike,
        );
        preferences[row['food_name']] = preference;
      }

      return preferences;
    } catch (e) {
      _logger.error(
        'Error fetching food preferences',
        context: 'AUTH_EDGE',
        error: e,
        data: {'deviceId': deviceId},
      );
      return {};
    }
  }

  /// Update user profile (direct database call)
  Future<bool> updateUser(UserProfile user) async {
    try {
      await _supabase
          .from('users')
          .update({
            'gender': user.gender.value,
            'birthday': user.birthday.toIso8601String().split('T')[0],
            'height_feet': user.heightFeet,
            'height_inches': user.heightInches,
            'weight_pounds': user.weightPounds,
            'runs_with_water_bottle': user.runsWithWaterBottle,
            'gut_training_level': user.gutTraining.value,
            'onboarding_completed': user.onboardingCompleted,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('device_id', user.id);

      return true;
    } catch (e) {
      _logger.error(
        'Error updating user',
        context: 'AUTH_EDGE',
        error: e,
        data: {'deviceId': user.id},
      );
      return false;
    }
  }

  /// Save food preferences via Edge Function (preferred for onboarding)
  Future<SaveFoodPreferencesResult> saveFoodPreferences(String deviceId, Map<String, FoodPreference> preferences) async {
    try {
      // Prepare request payload
      final requestBody = {
        'device_id': deviceId,
        'food_preferences': preferences.map(
          (key, value) => MapEntry(key, value.value),
        ),
      };

      // Call Edge Function
      final response = await _supabase.functions.invoke(
        'save-food-preferences',
        body: requestBody,
      );

      // Handle response
      if (response.status >= 200 && response.status < 300) {
        final data = response.data as Map<String, dynamic>;
        
        if (data['success'] == true) {
          return SaveFoodPreferencesResult(
            success: true,
            message: data['message'],
            preferencesCount: data['preferences_count'],
            savedPreferences: data['saved_preferences'],
          );
        } else {
          return SaveFoodPreferencesResult(
            success: false,
            message: data['message'] ?? 'Unknown error occurred',
          );
        }
      } else {
        return SaveFoodPreferencesResult(
          success: false,
          message: 'Edge Function call failed with status ${response.status}',
        );
      }
    } catch (e) {
      _logger.error(
        'Error invoking save-food-preferences edge function',
        context: 'AUTH_EDGE',
        error: e,
        data: {'deviceId': deviceId},
      );
      return SaveFoodPreferencesResult(
        success: false,
        message: 'Failed to save food preferences: $e',
      );
    }
  }

  /// Update food preferences (direct database call using SQL function)
  Future<bool> updateFoodPreferences(String deviceId, Map<String, FoodPreference> preferences) async {
    try {
      final preferencesJson = preferences.map(
        (key, value) => MapEntry(key, value.value),
      );

      await _supabase.rpc('upsert_food_preferences', params: {
        'p_device_id': deviceId,
        'p_preferences': preferencesJson,
      });

      return true;
    } catch (e) {
      _logger.error(
        'Error updating food preferences',
        context: 'AUTH_EDGE',
        error: e,
        data: {'deviceId': deviceId},
      );
      return false;
    }
  }

  /// Delete user and all associated data
  Future<bool> deleteUser(String deviceId) async {
    try {
      // Delete user (cascade will handle food_preferences and activity-linked nutrition data)
      await _supabase
          .from('users')
          .delete()
          .eq('device_id', deviceId);

      return true;
    } catch (e) {
      _logger.error(
        'Error deleting user',
        context: 'AUTH_EDGE',
        error: e,
        data: {'deviceId': deviceId},
      );
      return false;
    }
  }
}

/// Result class for user creation
class CreateUserResult {
  final bool success;
  final UserProfile? user;
  final String? message;

  CreateUserResult({
    required this.success,
    this.user,
    this.message,
  });
}

/// Result class for saving food preferences
class SaveFoodPreferencesResult {
  final bool success;
  final String? message;
  final int? preferencesCount;
  final List<dynamic>? savedPreferences;

  SaveFoodPreferencesResult({
    required this.success,
    this.message,
    this.preferencesCount,
    this.savedPreferences,
  });
}

/// Riverpod provider for AuthRepositoryEdge
final authRepositoryEdgeProvider = Provider<AuthRepositoryEdge>((ref) {
  final externalDeps = ref.read(appExternalDepsProvider);
  return AuthRepositoryEdge(externalDeps.supabaseClient, externalDeps.logger);
});
