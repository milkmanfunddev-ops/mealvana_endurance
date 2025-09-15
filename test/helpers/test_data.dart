/// Shared test data fixtures for Mealvana Endurance tests
/// 
/// This file contains reusable test data that follows the actual app data models
/// and represents realistic user scenarios for integration testing.

import 'package:mealvana_endurance/shared/database/app_database.dart';

class TestData {
  // Device IDs for different test scenarios
  static const deviceId1 = 'test-device-123';
  static const deviceId2 = 'test-device-456';  
  static const deviceId3 = 'test-device-789';
  static const testDeviceIdPrefix = 'test-device-';

  /// Standard test user profile for a 30-year-old male runner
  static final testUserProfile = UserProfileEntry(
    id: deviceId1,
    gender: 'male',
    birthday: DateTime(1994, 1, 1), // 30 years old
    heightFeet: 5,
    heightInches: 11, // ~180cm
    weightPounds: 165.0, // ~75kg
    runsWithWaterBottle: true,
    gutTraining: 'moderate',
    onboardingCompleted: true,
    createdAt: DateTime(2024, 1, 1, 12, 0, 0),
    updatedAt: DateTime(2024, 1, 1, 12, 0, 0),
    appVersion: '1.0.0',
    notificationsEnabled: false,
    defaultReminderDay: 4,
    defaultReminderHour: 17,
    defaultReminderMinute: 0,
    defaultReminderRecurring: false,
    tempPlanData: null,
    swipeHintShown: false,
  );

  /// Lightweight female runner profile
  static final testUserProfileFemale = UserProfileEntry(
    id: deviceId2,
    gender: 'female',
    birthday: DateTime(1999, 1, 1), // 25 years old
    heightFeet: 5,
    heightInches: 5, // ~165cm
    weightPounds: 143.0, // ~65kg
    runsWithWaterBottle: false,
    gutTraining: 'beginner',
    onboardingCompleted: true,
    createdAt: DateTime(2024, 1, 1, 12, 0, 0),
    updatedAt: DateTime(2024, 1, 1, 12, 0, 0),
    appVersion: '1.0.0',
    notificationsEnabled: false,
    defaultReminderDay: 4,
    defaultReminderHour: 17,
    defaultReminderMinute: 0,
    defaultReminderRecurring: false,
    tempPlanData: null,
    swipeHintShown: false,
  );

  /// Standard macro targets for testing (user-adjusted values)
  static const testMacroTargets = {
    'pre_run': {
      'carbs_g': 75.0,      // User adjusted from original 65.0
      'protein_g': 25.0,    // User adjusted from original 20.0
      'fat_g': 15.0,
      'water_ml': 600.0,    // User adjusted from original 500.0
      'sodium_mg': 400.0,   // User adjusted from original 300.0
    },
    'during_run': {
      'carbs_total_g': 45.0,     // User adjusted from original 35.0
      'sodium_total_mg': 800.0,  // User adjusted from original 650.0
      'water_total_ml': 750.0,   // User adjusted from original 600.0
    },
    'post_run': {
      'carbs_g': 80.0,      // User adjusted from original 70.0
      'protein_g': 35.0,    // User adjusted from original 30.0
      'fat_g': 20.0,
      'water_ml': 700.0,    // User adjusted from original 600.0
      'sodium_mg': 500.0,   // User adjusted from original 400.0
    },
  };

  /// Test food preferences
  static final testFoodPreferences = [
    FoodPreferenceEntry(
      userId: deviceId1,
      foodId: 'banana',
      preference: 'like',
      createdAt: DateTime(2024, 1, 1, 12, 0, 0),
      updatedAt: DateTime(2024, 1, 1, 12, 0, 0),
    ),
    FoodPreferenceEntry(
      userId: deviceId1,
      foodId: 'oatmeal',
      preference: 'like',
      createdAt: DateTime(2024, 1, 1, 12, 0, 0),
      updatedAt: DateTime(2024, 1, 1, 12, 0, 0),
    ),
    FoodPreferenceEntry(
      userId: deviceId1,
      foodId: 'gels',
      preference: 'like',
      createdAt: DateTime(2024, 1, 1, 12, 0, 0),
      updatedAt: DateTime(2024, 1, 1, 12, 0, 0),
    ),
    FoodPreferenceEntry(
      userId: deviceId1,
      foodId: 'protein_shake',
      preference: 'like',
      createdAt: DateTime(2024, 1, 1, 12, 0, 0),
      updatedAt: DateTime(2024, 1, 1, 12, 0, 0),
    ),
    FoodPreferenceEntry(
      userId: deviceId1,
      foodId: 'pizza',
      preference: 'dislike',
      createdAt: DateTime(2024, 1, 1, 12, 0, 0),
      updatedAt: DateTime(2024, 1, 1, 12, 0, 0),
    ),
    FoodPreferenceEntry(
      userId: deviceId1,
      foodId: 'broccoli',
      preference: 'dislike',
      createdAt: DateTime(2024, 1, 1, 12, 0, 0),
      updatedAt: DateTime(2024, 1, 1, 12, 0, 0),
    ),
  ];

  /// Sample nutrition plan request (for 10K run)
  static const testNutritionPlanRequest = {
    'device_id': deviceId1,
    'distance_miles': 6.2, // 10K
    'duration_minutes': 55,
    'pace_min_per_mile': 8.5,
    'age': 30,
    'gender': 'male',
    'weight_kg': 75.0,
    'height_cm': 180.0,
    'gut_training_level': 'moderate',
    'has_water_bottle': true,
    'liked_foods': ['banana', 'oatmeal', 'gels', 'protein_shake'],
    'disliked_foods': ['pizza', 'broccoli'],
    'macro_targets': testMacroTargets,
  };

  /// Half marathon test request
  static const testHalfMarathonRequest = {
    'device_id': deviceId1,
    'distance_miles': 13.1,
    'duration_minutes': 120,
    'pace_min_per_mile': 9.2,
    'age': 30,
    'gender': 'male',
    'weight_kg': 75.0,
    'height_cm': 180.0,
    'gut_training_level': 'moderate',
    'has_water_bottle': true,
    'liked_foods': ['banana', 'oatmeal', 'gels', 'protein_shake'],
    'disliked_foods': ['pizza', 'broccoli'],
    'macro_targets': testMacroTargets,
  };

  /// 5K test request (short distance)
  static const test5KRequest = {
    'device_id': deviceId1,
    'distance_miles': 3.1,
    'duration_minutes': 25,
    'pace_min_per_mile': 8.0,
    'age': 30,
    'gender': 'male',
    'weight_kg': 75.0,
    'height_cm': 180.0,
    'gut_training_level': 'moderate',
    'has_water_bottle': true,
    'liked_foods': ['banana', 'oatmeal', 'gels', 'protein_shake'],
    'disliked_foods': ['pizza', 'broccoli'],
    'macro_targets': testMacroTargets,
  };

  // Food categorization for phase-specific testing
  
  /// Foods that are appropriate for pre-run phase only
  static const preRunOnlyFoods = [
    'oatmeal',
    'banana',
    'toast',
    'coffee',
    'waffle',
    'yogurt',
    'granola',
  ];

  /// Foods that are suitable during runs
  static const duringRunSuitableFoods = [
    'gels',
    'sports_drink',
    'banana_slice',
    'dates',
    'sports_chews',
  ];

  /// Foods for post-run recovery
  static const postRunFoods = [
    'protein_shake',
    'chocolate_milk',
    'recovery_bar',
    'smoothie',
    'turkey_sandwich',
  ];

  /// Foods that should NEVER appear during runs (safety critical)
  static const duringRunForbiddenFoods = [
    'oatmeal',
    'waffle',
    'pizza',
    'burger',
    'salad',
    'soup',
    'pasta',
    'steak',
  ];

  /// Sample app content for content management testing
  static const testAppContent = {
    'ui_text': {
      'welcome_title': 'Welcome to Mealvana',
      'plan_generation_started': 'Generating your nutrition plan...',
      'macro_targets_title': 'Your Macro Targets',
    },
    'algorithm': {
      'energy': {
        'met_running': 12.0,
        'efficiency_factor': 0.25,
      },
      'pre_run': {
        'carbs_multiplier': 1.0,
        'protein_multiplier': 0.3,
      },
      'during_run': {
        'carbs_per_hour': 30.0,
        'sodium_per_hour': 200.0,
      },
    },
  };
}