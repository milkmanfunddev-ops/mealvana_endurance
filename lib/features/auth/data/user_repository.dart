import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../domain/user_preferences.dart';

part 'user_repository.g.dart';

/// Repository for managing user profile data in Hive and Supabase
class UserRepository {
  UserRepository({
    required this.userBox,
    required this.preferencesBox,
    required this.supabase,
  });
  
  static const String boxName = 'user_profiles';
  static const String preferencesBoxName = 'food_preferences';
  
  final Box<UserProfile> userBox;
  final Box<FoodPreferences> preferencesBox;
  final SupabaseClient supabase;

  /// Save user profile
  Future<void> saveUserProfile(UserProfile profile) async {
    await userBox.put(profile.id, profile);
  }

  /// Get user profile by ID (optional for device-based identification)
  UserProfile? getUserProfile([String? userId]) {
    if (userId != null) {
      return userBox.get(userId);
    }
    // If no userId provided, return current user (device-based)
    return getCurrentUser();
  }

  /// Get the current user profile (assumes single user for MVP)
  UserProfile? getCurrentUser() {
    if (userBox.isEmpty) return null;
    return userBox.values.first;
  }


  /// Update user profile
  Future<void> updateUserProfile(UserProfile profile) async {
    final updatedProfile = profile.copyWith(updatedAt: DateTime.now());
    await userBox.put(profile.id, updatedProfile);
  }

  /// Delete user profile
  Future<void> deleteUserProfile(String userId) async {
    await userBox.delete(userId);
  }

  /// Check if user exists
  bool userExists(String userId) {
    return userBox.containsKey(userId);
  }

  /// Get all user profiles (for future multi-user support)
  List<UserProfile> getAllUsers() {
    return userBox.values.toList();
  }

  /// Save food preferences for a user
  Future<void> saveFoodPreferences(FoodPreferences preferences) async {
    await preferencesBox.put(preferences.userId, preferences);
  }

  /// Get food preferences for a user
  FoodPreferences? getFoodPreferences(String userId) {
    return preferencesBox.get(userId);
  }

  /// Update food preferences
  Future<void> updateFoodPreferences(FoodPreferences preferences) async {
    final updatedPreferences = FoodPreferences(
      userId: preferences.userId,
      preferences: preferences.preferences,
      createdAt: preferences.createdAt,
      updatedAt: DateTime.now(),
    );
    await preferencesBox.put(preferences.userId, updatedPreferences);
  }

  /// Update a single food preference
  Future<void> updateFoodPreference(String userId, String foodId, FoodPreference preference) async {
    final existingPreferences = getFoodPreferences(userId);
    
    if (existingPreferences != null) {
      final updated = existingPreferences.updatePreference(foodId, preference);
      await updateFoodPreferences(updated);
    } else {
      // Create new preferences if none exist
      final newPreferences = FoodPreferences(
        userId: userId,
        preferences: {foodId: preference},
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await saveFoodPreferences(newPreferences);
    }
  }

  /// Get liked foods for a user
  List<String> getLikedFoods(String userId) {
    final preferences = getFoodPreferences(userId);
    return preferences?.likedFoods ?? [];
  }

  /// Get disliked foods for a user
  List<String> getDislikedFoods(String userId) {
    final preferences = getFoodPreferences(userId);
    return preferences?.dislikedFoods ?? [];
  }


  /// Clear all user data (for testing/reset)
  Future<void> clearAllData() async {
    await userBox.clear();
    await preferencesBox.clear();
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
    } catch (e) {
      // Log error but don't throw - continue with local data
      print('Failed to sync user with Supabase: $e');
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
    } catch (e) {
      print('Failed to get user from Supabase: $e');
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
    } catch (e) {
      print('Failed to create user in Supabase: $e');
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
      createdAt: DateTime.parse(userData['created_at'] ?? DateTime.now().toIso8601String()),
      updatedAt: DateTime.parse(userData['updated_at'] ?? DateTime.now().toIso8601String()),
      appVersion: userData['app_version'] ?? '1.0.0',
    );
  }

  /// Close the repository and Hive boxes
  Future<void> close() async {
    await userBox.close();
    await preferencesBox.close();
  }
}

/// User box provider
@Riverpod(keepAlive: true)
Future<Box<UserProfile>> userBox(Ref ref) async {
  return await Hive.openBox<UserProfile>(UserRepository.boxName);
}

/// Preferences box provider  
@Riverpod(keepAlive: true)
Future<Box<FoodPreferences>> preferencesBox(Ref ref) async {
  return await Hive.openBox<FoodPreferences>(UserRepository.preferencesBoxName);
}

/// Repository provider following Andrea's pattern
@riverpod
UserRepository userRepository(Ref ref) {
  // Use requireValue since boxes should be initialized by app startup
  final userBoxInstance = ref.watch(userBoxProvider).requireValue;
  final prefsBoxInstance = ref.watch(preferencesBoxProvider).requireValue;
  
  return UserRepository(
    userBox: userBoxInstance,
    preferencesBox: prefsBoxInstance,
    supabase: Supabase.instance.client,
  );
}