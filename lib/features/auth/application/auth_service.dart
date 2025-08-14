import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/repositories/user_repository.dart';
import '../data/models/user_preferences.dart';

/// Application service for managing user authentication and preferences
/// Follows the Andrea Bizzotto pattern with Ref for dependency injection
class AuthService {
  AuthService(this.ref);
  final Ref ref;

  /// Get the user repository
  UserRepository get _userRepository => ref.read(userRepositoryProvider);

  /// Create a new user profile during onboarding
  Future<UserProfile> createUser({
    required Gender gender,
    required DateTime birthday,
    required int heightFeet,
    required int heightInches,
    required double weightPounds,
    required bool runsWithWaterBottle,
  }) async {
    final profile = UserProfile(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      gender: gender,
      birthday: birthday,
      heightFeet: heightFeet,
      heightInches: heightInches,
      weightPounds: weightPounds,
      runsWithWaterBottle: runsWithWaterBottle,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    await _userRepository.saveUserProfile(profile);
    return profile;
  }

  /// Get the current user profile
  UserProfile? getCurrentUser() {
    return _userRepository.getCurrentUser();
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

  /// Get foods user is willing to try
  List<String> getWillingToTryFoods(String userId) {
    return _userRepository.getWillingToTryFoods(userId);
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

/// Provider for UserRepository
final userRepositoryProvider = Provider<UserRepository>((ref) {
  // This will be overridden in main.dart after Hive initialization
  throw UnimplementedError('UserRepository not initialized');
});

/// Provider for current user profile
final currentUserProvider = Provider<UserProfile?>((ref) {
  final authService = ref.watch(authServiceProvider);
  return authService.getCurrentUser();
});