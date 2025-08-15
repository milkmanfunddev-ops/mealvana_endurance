import 'package:hive/hive.dart';
import 'package:mealvana_endurance/features/auth/domain/user_preferences.dart';

/// Repository for managing user profile data in Hive
class UserRepository {
  static const String _boxName = 'user_profiles';
  static const String _preferencesBoxName = 'food_preferences';
  
  late Box<UserProfile> _userBox;
  late Box<FoodPreferences> _preferencesBox;
  
  /// Initialize the repository and open Hive boxes
  Future<void> init() async {
    _userBox = await Hive.openBox<UserProfile>(_boxName);
    _preferencesBox = await Hive.openBox<FoodPreferences>(_preferencesBoxName);
  }

  /// Save user profile
  Future<void> saveUserProfile(UserProfile profile) async {
    await _userBox.put(profile.id, profile);
  }

  /// Get user profile by ID
  UserProfile? getUserProfile(String userId) {
    return _userBox.get(userId);
  }

  /// Get the current user profile (assumes single user for MVP)
  UserProfile? getCurrentUser() {
    if (_userBox.isEmpty) return null;
    return _userBox.values.first;
  }

  /// Update user profile
  Future<void> updateUserProfile(UserProfile profile) async {
    final updatedProfile = profile.copyWith(updatedAt: DateTime.now());
    await _userBox.put(profile.id, updatedProfile);
  }

  /// Delete user profile
  Future<void> deleteUserProfile(String userId) async {
    await _userBox.delete(userId);
  }

  /// Check if user exists
  bool userExists(String userId) {
    return _userBox.containsKey(userId);
  }

  /// Get all user profiles (for future multi-user support)
  List<UserProfile> getAllUsers() {
    return _userBox.values.toList();
  }

  /// Save food preferences for a user
  Future<void> saveFoodPreferences(FoodPreferences preferences) async {
    await _preferencesBox.put(preferences.userId, preferences);
  }

  /// Get food preferences for a user
  FoodPreferences? getFoodPreferences(String userId) {
    return _preferencesBox.get(userId);
  }

  /// Update food preferences
  Future<void> updateFoodPreferences(FoodPreferences preferences) async {
    final updatedPreferences = FoodPreferences(
      userId: preferences.userId,
      preferences: preferences.preferences,
      createdAt: preferences.createdAt,
      updatedAt: DateTime.now(),
    );
    await _preferencesBox.put(preferences.userId, updatedPreferences);
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
    await _userBox.clear();
    await _preferencesBox.clear();
  }

  /// Close the repository and Hive boxes
  Future<void> close() async {
    await _userBox.close();
    await _preferencesBox.close();
  }
}