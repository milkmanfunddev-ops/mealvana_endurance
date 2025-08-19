import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mealvana_endurance/features/auth/data/user_repository.dart';
import '../data/auth_repository_edge.dart';
import '../domain/user_preferences.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:io';

/// Application service for managing user authentication and preferences
/// Follows the Andrea Bizzotto pattern with Ref for dependency injection
class AuthService {
  AuthService(this.ref);
  final Ref ref;

  /// Get the user repository
  UserRepository get _userRepository => ref.read(userRepositoryProvider);
  
  /// Get the Edge Function auth repository
  AuthRepositoryEdge get _authRepositoryEdge => ref.read(authRepositoryEdgeProvider);

  /// Create a new user profile during onboarding using Edge Function
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
    // Get device ID
    final deviceId = await _getDeviceId();
    
    // Get app version (simplified for now)
    const appVersion = '1.0.0';
    
    // Convert gut training to level
    final gutTrainingLevel = _convertGutTrainingToLevel(gutTraining ?? GutTraining.high);
    
    // Call Edge Function to create user
    final result = await _authRepositoryEdge.createUser(
      deviceId: deviceId,
      gender: gender,
      birthday: birthday,
      heightFeet: heightFeet,
      heightInches: heightInches,
      weightPounds: weightPounds,
      runsWithWaterBottle: runsWithWaterBottle,
      gutTrainingLevel: gutTrainingLevel,
      appVersion: appVersion,
      foodPreferences: foodPreferences,
    );
    
    if (result.success && result.user != null) {
      // Save locally for caching
      await _userRepository.saveUserProfile(result.user!);
      return result.user!;
    } else {
      throw Exception(result.message ?? 'Failed to create user');
    }
  }

  /// Get the current user profile
  UserProfile? getCurrentUser() {
    return _userRepository.getCurrentUser();
  }
  
  /// Get device ID for user identification
  Future<String> _getDeviceId() async {
    final deviceInfo = DeviceInfoPlugin();
    
    if (Platform.isAndroid) {
      final androidInfo = await deviceInfo.androidInfo;
      return androidInfo.id;
    } else if (Platform.isIOS) {
      final iosInfo = await deviceInfo.iosInfo;
      return iosInfo.identifierForVendor ?? 'ios-unknown';
    } else {
      return 'unknown-platform';
    }
  }
  
  /// Convert GutTraining enum to GutTrainingLevel enum
  GutTrainingLevel _convertGutTrainingToLevel(GutTraining gutTraining) {
    switch (gutTraining) {
      case GutTraining.low:
        return GutTrainingLevel.low;
      case GutTraining.moderate:
        return GutTrainingLevel.moderate;
      case GutTraining.high:
        return GutTrainingLevel.high;
    }
  }

  /// Update user profile
  Future<void> updateUserProfile(UserProfile profile) async {
    await _userRepository.updateUserProfile(profile);
  }

  /// Check if user has completed onboarding
  bool hasCompletedOnboarding() {
    final user = getCurrentUser();
    if (user == null) return false;
    
    final preferences = _userRepository.getFoodPreferences(user.id);
    return preferences != null && preferences.preferences.isNotEmpty;
  }

  /// Save food preferences (typically during onboarding)
  Future<void> saveFoodPreferences(String userId, Map<String, FoodPreference> preferences) async {
    final foodPreferences = FoodPreferences(
      userId: userId,
      preferences: preferences,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    await _userRepository.saveFoodPreferences(foodPreferences);
  }

  /// Update a single food preference
  Future<void> updateFoodPreference(String userId, String foodId, FoodPreference preference) async {
    await _userRepository.updateFoodPreference(userId, foodId, preference);
  }

  /// Get food preferences for a user
  FoodPreferences? getFoodPreferences(String userId) {
    return _userRepository.getFoodPreferences(userId);
  }

  /// Get liked foods for a user
  List<String> getLikedFoods(String userId) {
    return _userRepository.getLikedFoods(userId);
  }

  /// Get disliked foods for a user  
  List<String> getDislikedFoods(String userId) {
    return _userRepository.getDislikedFoods(userId);
  }


  /// Reset all user data (for testing or re-onboarding)
  Future<void> resetUserData() async {
    await _userRepository.clearAllData();
  }

  /// Get user profile summary for other features
  Map<String, dynamic>? getUserSummary() {
    final user = getCurrentUser();
    if (user == null) return null;

    final preferences = getFoodPreferences(user.id);
    
    return {
      'id': user.id,
      'age': user.age,
      'gender': user.gender.toString().split('.').last,
      'weightPounds': user.weightPounds,
      'heightInches': user.totalHeightInches,
      'runsWithWaterBottle': user.runsWithWaterBottle,
      'hasPreferences': preferences != null,
      'preferredFoodCount': preferences?.preferences.length ?? 0,
    };
  }
}

/// Provider for AuthService
final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService(ref);
});

/// Provider for current user profile
final currentUserProvider = Provider<UserProfile?>((ref) {
  final authService = ref.watch(authServiceProvider);
  return authService.getCurrentUser();
});

/// Provider for AuthRepositoryEdge
final authRepositoryEdgeProvider = Provider<AuthRepositoryEdge>((ref) {
  final supabase = Supabase.instance.client;
  return AuthRepositoryEdge(supabase);
});