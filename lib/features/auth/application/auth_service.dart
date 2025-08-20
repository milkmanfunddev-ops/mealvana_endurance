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

  /// Get the user repository (async)
  Future<UserRepository> get _userRepository async => await ref.read(userRepositoryProvider.future);
  
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
      final userRepo = await _userRepository;
      await userRepo.saveUserProfile(result.user!);
      return result.user!;
    } else if (result.message?.contains('already exists') == true) {
      // User already exists - fetch existing user from Supabase
      final existingUser = await _authRepositoryEdge.getUserByDeviceId(deviceId);
      if (existingUser != null) {
        // Save locally for caching
        final userRepo = await _userRepository;
        await userRepo.saveUserProfile(existingUser);
        return existingUser;
      }
      throw Exception('User already exists but could not retrieve existing user');
    } else {
      throw Exception(result.message ?? 'Failed to create user');
    }
  }

  /// Get the current user profile (async - waits for repository to be ready)
  Future<UserProfile?> getCurrentUser() async {
    try {
      final userRepo = await ref.read(userRepositoryProvider.future);
      return userRepo.getCurrentUser();
    } catch (e) {
      print('⚠️ Error getting current user: $e');
      return null;
    }
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
    final userRepo = await _userRepository;
    await userRepo.updateUserProfile(profile);
  }

  /// Check if user has completed onboarding
  Future<bool> hasCompletedOnboarding() async {
    final user = await getCurrentUser();
    if (user == null) return false;
    
    // Check the onboardingCompleted flag from UserProfile
    return user.onboardingCompleted;
  }

  /// Save food preferences (typically during onboarding)
  Future<void> saveFoodPreferences(String userId, Map<String, FoodPreference> preferences) async {
    // Get device ID (userId is actually deviceId in our system)
    final deviceId = userId;
    
    // First, save to Supabase via Edge Function
    final result = await _authRepositoryEdge.saveFoodPreferences(deviceId, preferences);
    
    if (!result.success) {
      throw Exception(result.message ?? 'Failed to save food preferences to server');
    }
    
    // Then save locally for caching
    final foodPreferences = FoodPreferences(
      userId: userId,
      preferences: preferences,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    final userRepo = await _userRepository;
    await userRepo.saveFoodPreferences(foodPreferences);
    
    // Mark user as having completed onboarding locally
    final user = await getCurrentUser();
    if (user != null) {
      final updatedUser = user.copyWith(
        onboardingCompleted: true,
        updatedAt: DateTime.now(),
      );
      await userRepo.updateUserProfile(updatedUser);
    }
  }

  /// Update a single food preference
  Future<void> updateFoodPreference(String userId, String foodId, FoodPreference preference) async {
    final userRepo = await _userRepository;
    await userRepo.updateFoodPreference(userId, foodId, preference);
  }

  /// Get food preferences for a user
  FoodPreferences? getFoodPreferences(String userId) {
    try {
      final userRepo = ref.read(userRepositoryProvider).valueOrNull;
      return userRepo?.getFoodPreferences(userId);
    } catch (e) {
      return null;
    }
  }

  /// Get liked foods for a user
  List<String> getLikedFoods(String userId) {
    try {
      final userRepo = ref.read(userRepositoryProvider).valueOrNull;
      return userRepo?.getLikedFoods(userId) ?? [];
    } catch (e) {
      return [];
    }
  }

  /// Get disliked foods for a user  
  List<String> getDislikedFoods(String userId) {
    try {
      final userRepo = ref.read(userRepositoryProvider).valueOrNull;
      return userRepo?.getDislikedFoods(userId) ?? [];
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

/// Provider for current user profile (async-aware)
final currentUserProvider = FutureProvider<UserProfile?>((ref) async {
  final authService = ref.watch(authServiceProvider);
  return await authService.getCurrentUser();
});

/// Provider for AuthRepositoryEdge
final authRepositoryEdgeProvider = Provider<AuthRepositoryEdge>((ref) {
  final supabase = Supabase.instance.client;
  return AuthRepositoryEdge(supabase);
});