/// User test fixtures for consistent test data
library;

import 'package:mealvana_endurance/features/auth/domain/user_preferences.dart';

/// User test fixtures
class UserFixtures {
  /// Fresh user (no onboarding completed)
  static UserProfile freshUser({
    String? id,
    String? deviceId,
    bool onboardingCompleted = false,
  }) {
    return UserProfile(
      id: id ?? 'test-user-fresh',
      deviceId: deviceId ?? 'device-fresh-123',
      authUserId: null,
      authProvider: 'anonymous',
      isAnonymous: true,
      gender: Gender.male,
      birthday: DateTime(1990, 1, 1),
      heightFeet: 5,
      heightInches: 10,
      weightPounds: 150.0,
      runsWithWaterBottle: true,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      gutTraining: GutTraining.moderate,
      onboardingCompleted: onboardingCompleted,
      appVersion: '1.1.0+8',
      swipeHintShown: false,
    );
  }

  /// Completed onboarding user
  static UserProfile completedUser({
    String? id,
    String? deviceId,
  }) {
    return UserProfile(
      id: id ?? 'test-user-completed',
      deviceId: deviceId ?? 'device-completed-456',
      authUserId: null,
      authProvider: 'anonymous',
      isAnonymous: true,
      gender: Gender.female,
      birthday: DateTime(1985, 6, 15),
      heightFeet: 5,
      heightInches: 6,
      weightPounds: 140.0,
      runsWithWaterBottle: false,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      gutTraining: GutTraining.high,
      onboardingCompleted: true,
      appVersion: '1.1.0+8',
      swipeHintShown: true,
    );
  }

  /// Beginner athlete (low gut training)
  static UserProfile beginner({
    String? id,
    String? deviceId,
    bool onboardingCompleted = true,
  }) {
    return UserProfile(
      id: id ?? 'test-user-beginner',
      deviceId: deviceId ?? 'device-beginner-789',
      authUserId: null,
      authProvider: 'anonymous',
      isAnonymous: true,
      gender: Gender.male,
      birthday: DateTime(1992, 3, 20),
      heightFeet: 5,
      heightInches: 9,
      weightPounds: 140.0,
      runsWithWaterBottle: true,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      gutTraining: GutTraining.low,
      onboardingCompleted: onboardingCompleted,
      appVersion: '1.1.0+8',
      swipeHintShown: false,
    );
  }

  /// Advanced athlete (high gut training)
  static UserProfile advanced({
    String? id,
    String? deviceId,
    bool onboardingCompleted = true,
  }) {
    return UserProfile(
      id: id ?? 'test-user-advanced',
      deviceId: deviceId ?? 'device-advanced-012',
      authUserId: null,
      authProvider: 'anonymous',
      isAnonymous: true,
      gender: Gender.female,
      birthday: DateTime(1988, 9, 10),
      heightFeet: 5,
      heightInches: 7,
      weightPounds: 155.0,
      runsWithWaterBottle: false,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      gutTraining: GutTraining.high,
      onboardingCompleted: onboardingCompleted,
      appVersion: '1.1.0+8',
      swipeHintShown: true,
    );
  }

  /// Heavy athlete (higher weight)
  static UserProfile heavyAthlete({
    String? id,
    String? deviceId,
    bool onboardingCompleted = true,
  }) {
    return UserProfile(
      id: id ?? 'test-user-heavy',
      deviceId: deviceId ?? 'device-heavy-345',
      authUserId: null,
      authProvider: 'anonymous',
      isAnonymous: true,
      gender: Gender.male,
      birthday: DateTime(1990, 5, 5),
      heightFeet: 6,
      heightInches: 2,
      weightPounds: 195.0,
      runsWithWaterBottle: true,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      gutTraining: GutTraining.moderate,
      onboardingCompleted: onboardingCompleted,
      appVersion: '1.1.0+8',
      swipeHintShown: false,
    );
  }

  /// Light athlete (lower weight)
  static UserProfile lightAthlete({
    String? id,
    String? deviceId,
    bool onboardingCompleted = true,
  }) {
    return UserProfile(
      id: id ?? 'test-user-light',
      deviceId: deviceId ?? 'device-light-678',
      authUserId: null,
      authProvider: 'anonymous',
      isAnonymous: true,
      gender: Gender.female,
      birthday: DateTime(1995, 11, 25),
      heightFeet: 5,
      heightInches: 4,
      weightPounds: 120.0,
      runsWithWaterBottle: true,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      gutTraining: GutTraining.moderate,
      onboardingCompleted: onboardingCompleted,
      appVersion: '1.1.0+8',
      swipeHintShown: false,
    );
  }

  /// Ultra runner (experienced endurance athlete)
  static UserProfile ultraRunner({
    String? id,
    String? deviceId,
    bool onboardingCompleted = true,
  }) {
    return UserProfile(
      id: id ?? 'test-user-ultra',
      deviceId: deviceId ?? 'device-ultra-901',
      authUserId: null,
      authProvider: 'anonymous',
      isAnonymous: true,
      gender: Gender.male,
      birthday: DateTime(1983, 7, 30),
      heightFeet: 5,
      heightInches: 11,
      weightPounds: 165.0,
      runsWithWaterBottle: true,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      gutTraining: GutTraining.high,
      onboardingCompleted: onboardingCompleted,
      appVersion: '1.1.0+8',
      swipeHintShown: true,
    );
  }

  /// User with OAuth authentication (non-anonymous)
  static UserProfile oauthUser({
    String? id,
    String? deviceId,
    String? authUserId,
    String authProvider = 'google',
    bool onboardingCompleted = true,
  }) {
    return UserProfile(
      id: id ?? 'test-user-oauth',
      deviceId: deviceId ?? 'device-oauth-234',
      authUserId: authUserId ?? 'auth-user-567',
      authProvider: authProvider,
      isAnonymous: false,
      gender: Gender.male,
      birthday: DateTime(1990, 4, 15),
      heightFeet: 5,
      heightInches: 10,
      weightPounds: 160.0,
      runsWithWaterBottle: true,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      gutTraining: GutTraining.moderate,
      onboardingCompleted: onboardingCompleted,
      appVersion: '1.1.0+8',
      swipeHintShown: false,
    );
  }
}

/// Helper functions for user fixtures
class UserHelpers {
  /// Calculate weight in kg from pounds
  static double getWeightKg(UserProfile user) {
    return user.weightPounds * 0.453592;
  }

  /// Get age from birthday
  static int getAge(UserProfile user) {
    return user.age;
  }

  /// Get total height in inches
  static int getTotalHeightInches(UserProfile user) {
    return user.totalHeightInches;
  }
}
