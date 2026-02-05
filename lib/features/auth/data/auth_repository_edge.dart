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

  /// Upsert user profile via consolidated Edge Function
  /// This is the NEW consolidated method that handles ALL profile updates in one call:
  /// - Basic profile data (gender, birthday, height, weight, etc.)
  /// - Food preferences with preference levels
  /// - Dietary preference
  /// - Allergies
  /// - Sport preferences (cycling, swimming, running)
  ///
  /// Use this instead of multiple separate Edge Function calls to reduce network roundtrips
  ///
  /// **IMPORTANT**: The `deviceId` parameter is REQUIRED because the database has a NOT NULL constraint on device_id
  Future<UpsertUserProfileResult> upsertUserProfile(
    String userId, {
    required String deviceId, // REQUIRED - database NOT NULL constraint
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
  }) async {
    try {
      // Build request payload with only provided fields
      final requestBody = <String, dynamic>{
        'user_id': userId,
        'device_id': deviceId, // REQUIRED field
      };

      // Basic profile fields
      if (gender != null) requestBody['gender'] = gender;
      if (birthday != null) requestBody['birthday'] = birthday;
      if (heightFeet != null) requestBody['height_feet'] = heightFeet;
      if (heightInches != null) requestBody['height_inches'] = heightInches;
      if (weightPounds != null) requestBody['weight_pounds'] = weightPounds;
      if (runsWithWaterBottle != null) requestBody['runs_with_water_bottle'] = runsWithWaterBottle;
      if (gutTrainingLevel != null) requestBody['gut_training_level'] = gutTrainingLevel;

      // Food preferences
      if (foodPreferences != null) requestBody['food_preferences'] = foodPreferences;
      if (preferenceLevels != null) requestBody['preference_levels'] = preferenceLevels;

      // Dietary preference & allergies
      if (dietaryPreference != null) requestBody['dietary_preference'] = dietaryPreference;
      if (allergies != null) requestBody['allergies'] = allergies;

      // Sport preferences
      if (giSensitivity != null) requestBody['gi_sensitivity'] = giSensitivity;
      if (cyclingFtpWatts != null) requestBody['cycling_ftp_watts'] = cyclingFtpWatts;
      if (typicalBikeBottles != null) requestBody['typical_bike_bottles'] = typicalBikeBottles;
      if (hasAeroBottle != null) requestBody['has_aero_bottle'] = hasAeroBottle;
      if (hasBentoBox != null) requestBody['has_bento_box'] = hasBentoBox;
      if (swimmingCssSecondsPer100m != null) {
        requestBody['swimming_css_seconds_per_100m'] = swimmingCssSecondsPer100m;
      }
      if (typicalWetsuit != null) requestBody['typical_wetsuit'] = typicalWetsuit;
      if (typicalSwimCapType != null) requestBody['typical_swim_cap_type'] = typicalSwimCapType;

      // Metadata
      if (onboardingCompleted != null) requestBody['onboarding_completed'] = onboardingCompleted;
      if (appVersion != null) requestBody['app_version'] = appVersion;

      // Call consolidated Edge Function
      final response = await _supabase.functions.invoke(
        'upsert-user-profile',
        body: requestBody,
      );

      // Handle response
      if (response.status >= 200 && response.status < 300) {
        final data = response.data as Map<String, dynamic>;

        if (data['success'] == true) {
          return UpsertUserProfileResult(
            success: true,
            message: data['message'],
            user: data['user'] != null ? UserProfile.fromJson(data['user']) : null,
            preferencesCount: data['preferences_count'],
          );
        } else {
          _logger.warning(
            'Edge function returned failure',
            context: 'AUTH_EDGE',
            data: {'userId': userId, 'message': data['message']},
          );

          return UpsertUserProfileResult(
            success: false,
            message: data['message'] ?? 'Unknown error occurred',
          );
        }
      } else {
        _logger.error(
          'Edge function HTTP error',
          context: 'AUTH_EDGE',
          data: {'userId': userId, 'status': response.status},
        );

        return UpsertUserProfileResult(
          success: false,
          message: 'Edge Function call failed with status ${response.status}',
        );
      }
    } catch (e) {
      _logger.error(
        'Error invoking upsert-user-profile edge function',
        context: 'AUTH_EDGE',
        error: e,
        data: {'userId': userId},
      );
      return UpsertUserProfileResult(
        success: false,
        message: 'Failed to upsert user profile: $e',
      );
    }
  }

  /// Update user preferences (dietary preference, allergies, sport preferences) via Edge Function
  /// DEPRECATED: Use upsertUserProfile() instead for better consolidation
  /// Edge function handles validation and database update for all preference types
  Future<UpdateUserPreferencesResult> updateUserPreferences(
    String userId, {
    required String deviceId, // REQUIRED - database NOT NULL constraint
    String? dietaryPreference,
    List<String>? allergies,
    bool? giSensitivity,
    int? cyclingFtpWatts,
    int? typicalBikeBottles,
    bool? hasAeroBottle,
    bool? hasBentoBox,
    int? swimmingCssSecondsPer100m,
    bool? typicalWetsuit,
    String? typicalSwimCapType,
  }) async {
    // Route through new consolidated method
    final result = await upsertUserProfile(
      userId,
      deviceId: deviceId,
      dietaryPreference: dietaryPreference,
      allergies: allergies,
      giSensitivity: giSensitivity,
      cyclingFtpWatts: cyclingFtpWatts,
      typicalBikeBottles: typicalBikeBottles,
      hasAeroBottle: hasAeroBottle,
      hasBentoBox: hasBentoBox,
      swimmingCssSecondsPer100m: swimmingCssSecondsPer100m,
      typicalWetsuit: typicalWetsuit,
      typicalSwimCapType: typicalSwimCapType,
    );

    return UpdateUserPreferencesResult(
      success: result.success,
      message: result.message,
      user: result.user,
    );
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

/// Result class for updating user preferences
class UpdateUserPreferencesResult {
  final bool success;
  final String? message;
  final UserProfile? user;

  UpdateUserPreferencesResult({
    required this.success,
    this.message,
    this.user,
  });
}

/// Result class for upserting user profile (consolidated operation)
class UpsertUserProfileResult {
  final bool success;
  final String? message;
  final UserProfile? user;
  final int? preferencesCount;

  UpsertUserProfileResult({
    required this.success,
    this.message,
    this.user,
    this.preferencesCount,
  });
}

/// Riverpod provider for AuthRepositoryEdge
final authRepositoryEdgeProvider = Provider<AuthRepositoryEdge>((ref) {
  final externalDeps = ref.read(appExternalDepsProvider);
  return AuthRepositoryEdge(externalDeps.supabaseClient, externalDeps.logger);
});
