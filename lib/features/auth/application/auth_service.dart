import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mealvana_endurance/features/auth/data/user_repository.dart';
import '../data/auth_repository_edge.dart';
import '../domain/user_preferences.dart';
import '../../../shared/services/sentry_service.dart';
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
  
  /// Get the Sentry service
  SentryService get _sentryService => ref.read(sentryServiceProvider);

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
    print('🔑 Creating user with device ID: $deviceId');
    
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
      
      // Update Sentry user context with new user details
      await _sentryService.setUserContext(
        deviceId: deviceId,
        appVersion: appVersion,
        onboardingCompleted: false, // User just created, onboarding in progress
        gutTrainingLevel: gutTrainingLevel.name,
      );
      
      _sentryService.addBreadcrumb(
        message: 'User created successfully',
        category: 'user_lifecycle',
        data: {
          'user_id': result.user!.id,
          'gender': gender.name,
          'gut_training': gutTrainingLevel.name,
        },
      );
      
      return result.user!;
    } else if (result.message?.contains('already exists') == true) {
      // User already exists - fetch existing user from Supabase
      final existingUser = await _authRepositoryEdge.getUserByDeviceId(deviceId);
      if (existingUser != null) {
        // Save locally for caching
        final userRepo = await _userRepository;
        await userRepo.saveUserProfile(existingUser);
        
        // Update Sentry user context for existing user
        await _sentryService.setUserContext(
          deviceId: deviceId,
          appVersion: appVersion,
          onboardingCompleted: existingUser.onboardingCompleted,
          gutTrainingLevel: existingUser.gutTraining.name,
        );
        
        _sentryService.addBreadcrumb(
          message: 'Existing user restored',
          category: 'user_lifecycle',
          data: {
            'user_id': existingUser.id,
            'onboarding_completed': existingUser.onboardingCompleted.toString(),
          },
        );
        
        return existingUser;
      }
      // Critical: User exists but couldn't be retrieved
      final error = Exception('User already exists but could not retrieve existing user');
      await _sentryService.reportCriticalError(
        error,
        context: 'user_creation_conflict',
        tags: {
          'device_id': deviceId,
          'error_type': 'user_retrieval_failure',
          'operation': 'create_user',
        },
      );
      throw error;
    } else {
      // Critical: User creation failed completely
      final error = Exception(result.message ?? 'Failed to create user');
      await _sentryService.reportCriticalError(
        error,
        context: 'user_creation_failure',
        tags: {
          'device_id': deviceId,
          'error_type': 'edge_function_failure',
          'operation': 'create_user',
          'edge_function_message': result.message ?? 'unknown',
        },
      );
      throw error;
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
      await _sentryService.reportCriticalError(
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
      // Critical: Food preferences save failure blocks onboarding completion
      final error = Exception(result.message ?? 'Failed to save food preferences to server');
      await _sentryService.reportCriticalError(
        error,
        context: 'food_preferences_save_failure',
        tags: {
          'device_id': deviceId,
          'error_type': 'edge_function_failure',
          'operation': 'save_food_preferences',
          'preferences_count': preferences.length.toString(),
          'edge_function_message': result.message ?? 'unknown',
        },
      );
      throw error;
    }
    
    // Then save locally for caching
    final userRepo = await _userRepository;
    await userRepo.saveFoodPreferences(userId, preferences);
    
    // Mark user as having completed onboarding locally
    final user = await getCurrentUser();
    if (user != null) {
      final updatedUser = user.copyWith(
        onboardingCompleted: true,
        updatedAt: DateTime.now(),
      );
      await userRepo.updateUserProfile(updatedUser);
      
      // Update Sentry user context to reflect onboarding completion
      await _sentryService.setUserContext(
        deviceId: userId,
        appVersion: '1.0.0',
        onboardingCompleted: true,
        gutTrainingLevel: user.gutTraining.name,
      );
      
      _sentryService.addBreadcrumb(
        message: 'Onboarding completed - food preferences saved',
        category: 'user_lifecycle',
        data: {
          'user_id': userId,
          'food_preferences_count': preferences.length.toString(),
        },
      );
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
  final supabase = Supabase.instance.client;
  return AuthRepositoryEdge(supabase);
});