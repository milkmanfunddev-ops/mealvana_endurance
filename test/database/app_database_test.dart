import 'package:flutter_test/flutter_test.dart';
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:mealvana_endurance/shared/database/app_database.dart';
import 'package:mealvana_endurance/features/auth/domain/user_preferences.dart' as domain;

void main() {
  late AppDatabase database;

  // Create an in-memory database for testing
  AppDatabase createTestDatabase() {
    return AppDatabase.memory();
  }

  setUp(() {
    database = createTestDatabase();
  });

  tearDown(() async {
    await database.executor.close();
  });

  group('AppDatabase Tests', () {
    group('UserProfile Operations', () {
      test('should save and retrieve a user profile', () async {
        // Arrange
        final testUser = domain.UserProfile(
          id: 'test_device_123',
          gender: domain.Gender.female,
          birthday: DateTime(1990, 5, 15),
          heightFeet: 5,
          heightInches: 6,
          weightPounds: 135.0,
          runsWithWaterBottle: true,
          gutTraining: domain.GutTraining.moderate,
          onboardingCompleted: true,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          appVersion: '1.0.0',
        );

        // Act
        await database.saveUserProfile(testUser);
        final retrievedUser = await database.getCurrentUserProfile();

        // Assert
        expect(retrievedUser, isNotNull);
        expect(retrievedUser!.id, equals('test_device_123'));
        expect(retrievedUser.gender, equals(domain.Gender.female));
        expect(retrievedUser.birthday, equals(DateTime(1990, 5, 15)));
        expect(retrievedUser.heightFeet, equals(5));
        expect(retrievedUser.heightInches, equals(6));
        expect(retrievedUser.weightPounds, equals(135.0));
        expect(retrievedUser.runsWithWaterBottle, isTrue);
        expect(retrievedUser.gutTraining, equals(domain.GutTraining.moderate));
        expect(retrievedUser.onboardingCompleted, isTrue);
        expect(retrievedUser.appVersion, equals('1.0.0'));
      });

      test('should update an existing user profile', () async {
        // Arrange
        final initialUser = domain.UserProfile(
          id: 'test_device_456',
          gender: domain.Gender.male,
          birthday: DateTime(1985, 8, 20),
          heightFeet: 6,
          heightInches: 1,
          weightPounds: 180.0,
          runsWithWaterBottle: false,
          gutTraining: domain.GutTraining.low,
          onboardingCompleted: false,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          appVersion: '1.0.0',
        );

        await database.saveUserProfile(initialUser);

        // Act - Update the user
        final updatedUser = initialUser.copyWith(
          weightPounds: 175.0,
          runsWithWaterBottle: true,
          gutTraining: domain.GutTraining.high,
          onboardingCompleted: true,
        );
        await database.updateUserProfile(updatedUser);

        // Assert
        final retrievedUser = await database.getCurrentUserProfile();
        expect(retrievedUser, isNotNull);
        expect(retrievedUser!.weightPounds, equals(175.0));
        expect(retrievedUser.runsWithWaterBottle, isTrue);
        expect(retrievedUser.gutTraining, equals(domain.GutTraining.high));
        expect(retrievedUser.onboardingCompleted, isTrue);
      });

      test('should delete a user profile', () async {
        // Arrange
        final testUser = domain.UserProfile(
          id: 'test_device_789',
          gender: domain.Gender.other,
          birthday: DateTime(2000, 1, 1),
          heightFeet: 5,
          heightInches: 8,
          weightPounds: 150.0,
          runsWithWaterBottle: true,
          gutTraining: domain.GutTraining.moderate,
          onboardingCompleted: true,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          appVersion: '1.0.0',
        );

        await database.saveUserProfile(testUser);
        
        // Verify user exists
        var user = await database.getCurrentUserProfile();
        expect(user, isNotNull);

        // Act
        final deleted = await database.deleteUserProfile('test_device_789');

        // Assert
        expect(deleted, isTrue);
        user = await database.getCurrentUserProfile();
        expect(user, isNull);
      });

      test('should handle Gender enum correctly', () async {
        // Test all gender options
        for (final gender in domain.Gender.values) {
          final testUser = domain.UserProfile(
            id: 'gender_test_${gender.name}',
            gender: gender,
            birthday: DateTime(1990, 1, 1),
            heightFeet: 5,
            heightInches: 6,
            weightPounds: 150.0,
            runsWithWaterBottle: false,
            gutTraining: domain.GutTraining.moderate,
            onboardingCompleted: false,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
            appVersion: '1.0.0',
          );

          await database.saveUserProfile(testUser);
          final retrievedUser = await database.getCurrentUserProfile();
          
          expect(retrievedUser!.gender, equals(gender));
          
          // Clean up for next iteration
          await database.deleteUserProfile(testUser.id);
        }
      });

      test('should handle GutTraining enum correctly', () async {
        // Test all gut training levels
        for (final gutTraining in domain.GutTraining.values) {
          final testUser = domain.UserProfile(
            id: 'gut_test_${gutTraining.name}',
            gender: domain.Gender.other,
            birthday: DateTime(1990, 1, 1),
            heightFeet: 5,
            heightInches: 6,
            weightPounds: 150.0,
            runsWithWaterBottle: false,
            gutTraining: gutTraining,
            onboardingCompleted: false,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
            appVersion: '1.0.0',
          );

          await database.saveUserProfile(testUser);
          final retrievedUser = await database.getCurrentUserProfile();
          
          expect(retrievedUser!.gutTraining, equals(gutTraining));
          
          // Clean up for next iteration
          await database.deleteUserProfile(testUser.id);
        }
      });
    });

    group('FoodPreferences Operations', () {
      test('should save and retrieve food preferences', () async {
        // Arrange
        const userId = 'test_user_food';
        final preferences = {
          'banana': domain.FoodPreference.like,
          'apple': domain.FoodPreference.like,
          'sports_drink': domain.FoodPreference.dislike,
          'energy_gel': domain.FoodPreference.willingToTry,
        };

        // Act
        await database.saveFoodPreferences(userId, preferences);
        final retrievedPrefs = await database.getUserFoodPreferences(userId);

        // Assert
        expect(retrievedPrefs, equals(preferences));
        expect(retrievedPrefs['banana'], equals(domain.FoodPreference.like));
        expect(retrievedPrefs['sports_drink'], equals(domain.FoodPreference.dislike));
        expect(retrievedPrefs['energy_gel'], equals(domain.FoodPreference.willingToTry));
      });

      test('should update existing food preferences', () async {
        // Arrange
        const userId = 'test_user_update';
        final initialPrefs = {
          'banana': domain.FoodPreference.like,
          'apple': domain.FoodPreference.dislike,
        };

        await database.saveFoodPreferences(userId, initialPrefs);

        // Act - Update preferences
        final updatedPrefs = {
          'banana': domain.FoodPreference.dislike, // Changed
          'apple': domain.FoodPreference.like,     // Changed
          'orange': domain.FoodPreference.willingToTry, // New
        };
        await database.saveFoodPreferences(userId, updatedPrefs);

        // Assert
        final retrievedPrefs = await database.getUserFoodPreferences(userId);
        expect(retrievedPrefs.length, equals(3));
        expect(retrievedPrefs['banana'], equals(domain.FoodPreference.dislike));
        expect(retrievedPrefs['apple'], equals(domain.FoodPreference.like));
        expect(retrievedPrefs['orange'], equals(domain.FoodPreference.willingToTry));
      });

      test('should get liked foods for a user', () async {
        // Arrange
        const userId = 'test_user_likes';
        final preferences = {
          'banana': domain.FoodPreference.like,
          'apple': domain.FoodPreference.like,
          'sports_drink': domain.FoodPreference.dislike,
          'energy_gel': domain.FoodPreference.willingToTry,
          'orange': domain.FoodPreference.like,
        };

        await database.saveFoodPreferences(userId, preferences);

        // Act
        final likedFoods = await database.getLikedFoods(userId);

        // Assert
        expect(likedFoods.length, equals(3));
        expect(likedFoods, containsAll(['banana', 'apple', 'orange']));
        expect(likedFoods, isNot(contains('sports_drink')));
        expect(likedFoods, isNot(contains('energy_gel')));
      });

      test('should get disliked foods for a user', () async {
        // Arrange
        const userId = 'test_user_dislikes';
        final preferences = {
          'banana': domain.FoodPreference.like,
          'apple': domain.FoodPreference.dislike,
          'sports_drink': domain.FoodPreference.dislike,
          'energy_gel': domain.FoodPreference.willingToTry,
        };

        await database.saveFoodPreferences(userId, preferences);

        // Act
        final dislikedFoods = await database.getDislikedFoods(userId);

        // Assert
        expect(dislikedFoods.length, equals(2));
        expect(dislikedFoods, containsAll(['apple', 'sports_drink']));
        expect(dislikedFoods, isNot(contains('banana')));
        expect(dislikedFoods, isNot(contains('energy_gel')));
      });

      test('should handle FoodPreference enum correctly', () async {
        // Test all preference types
        const userId = 'test_preference_types';
        final preferences = {
          'food_like': domain.FoodPreference.like,
          'food_dislike': domain.FoodPreference.dislike,
          'food_willing': domain.FoodPreference.willingToTry,
        };

        await database.saveFoodPreferences(userId, preferences);
        final retrievedPrefs = await database.getUserFoodPreferences(userId);

        expect(retrievedPrefs['food_like'], equals(domain.FoodPreference.like));
        expect(retrievedPrefs['food_dislike'], equals(domain.FoodPreference.dislike));
        expect(retrievedPrefs['food_willing'], equals(domain.FoodPreference.willingToTry));
      });
    });

    group('NutritionPlan Operations', () {
      test('should save and retrieve a nutrition plan', () async {
        // Arrange
        const planId = 'plan_123';
        const userId = 'user_123';
        const planData = '''
        {
          "id": "plan_123",
          "name": "10K Race Plan",
          "distance": 10.0,
          "pace": 8.5,
          "sections": [
            {
              "title": "Before Run",
              "items": ["banana", "water"]
            }
          ]
        }
        ''';

        // Act
        await database.saveNutritionPlan(planId, userId, planData);
        final retrievedPlan = await database.getLatestNutritionPlan(userId);

        // Assert
        expect(retrievedPlan, isNotNull);
        expect(retrievedPlan, contains('plan_123'));
        expect(retrievedPlan, contains('10K Race Plan'));
      });

      test('should get all nutrition plans for a user', () async {
        // Arrange
        const userId = 'user_456';
        final plans = [
          ('plan_1', '{"id": "plan_1", "name": "5K Plan"}'),
          ('plan_2', '{"id": "plan_2", "name": "10K Plan"}'),
          ('plan_3', '{"id": "plan_3", "name": "Half Marathon Plan"}'),
        ];

        // Act
        for (final (id, data) in plans) {
          await database.saveNutritionPlan(id, userId, data);
          // Add small delay to ensure different timestamps
          await Future.delayed(const Duration(milliseconds: 10));
        }

        final allPlans = await database.getAllNutritionPlans(userId);

        // Assert
        expect(allPlans.length, equals(3));
        // Plans should be ordered by updated_at DESC
        expect(allPlans[0], contains('Half Marathon Plan'));
        expect(allPlans[1], contains('10K Plan'));
        expect(allPlans[2], contains('5K Plan'));
      });

      test('should update an existing nutrition plan', () async {
        // Arrange
        const planId = 'plan_update';
        const userId = 'user_update';
        const initialData = '{"id": "plan_update", "version": 1}';
        const updatedData = '{"id": "plan_update", "version": 2, "updated": true}';

        await database.saveNutritionPlan(planId, userId, initialData);

        // Act
        await database.saveNutritionPlan(planId, userId, updatedData);

        // Assert
        final retrievedPlan = await database.getLatestNutritionPlan(userId);
        expect(retrievedPlan, contains('"version": 2'));
        expect(retrievedPlan, contains('"updated": true'));
      });

      test('should delete a nutrition plan', () async {
        // Arrange
        const planId = 'plan_delete';
        const userId = 'user_delete';
        const planData = '{"id": "plan_delete"}';

        await database.saveNutritionPlan(planId, userId, planData);
        
        // Verify plan exists
        var plans = await database.getAllNutritionPlans(userId);
        expect(plans.length, equals(1));

        // Act
        final deleted = await database.deleteNutritionPlan(planId);

        // Assert
        expect(deleted, isTrue);
        plans = await database.getAllNutritionPlans(userId);
        expect(plans.length, equals(0));
      });

      test('should get the latest plan when multiple exist', () async {
        // Arrange
        const userId = 'user_latest';
        final plans = [
          ('old_plan', '{"id": "old_plan", "created": "2024-01-01"}'),
          ('newer_plan', '{"id": "newer_plan", "created": "2024-06-01"}'),
          ('latest_plan', '{"id": "latest_plan", "created": "2024-12-01"}'),
        ];

        // Act - Save plans with delays to ensure different timestamps
        for (final (id, data) in plans) {
          await database.saveNutritionPlan(id, userId, data);
          await Future.delayed(const Duration(milliseconds: 10));
        }

        final latestPlan = await database.getLatestNutritionPlan(userId);

        // Assert
        expect(latestPlan, isNotNull);
        expect(latestPlan, contains('latest_plan'));
        expect(latestPlan, contains('2024-12-01'));
      });
    });

    group('Database Utility Operations', () {
      test('should clear all data', () async {
        // Arrange - Add data to all tables
        final testUser = domain.UserProfile(
          id: 'clear_test_user',
          gender: domain.Gender.female,
          birthday: DateTime(1990, 1, 1),
          heightFeet: 5,
          heightInches: 6,
          weightPounds: 135.0,
          runsWithWaterBottle: true,
          gutTraining: domain.GutTraining.moderate,
          onboardingCompleted: true,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          appVersion: '1.0.0',
        );

        await database.saveUserProfile(testUser);
        await database.saveFoodPreferences('clear_test_user', {
          'banana': domain.FoodPreference.like,
        });
        await database.saveNutritionPlan('plan_clear', 'clear_test_user', '{}');

        // Verify data exists
        var hasData = await database.hasUserData();
        expect(hasData, isTrue);

        // Act
        await database.clearAllData();

        // Assert
        hasData = await database.hasUserData();
        expect(hasData, isFalse);
        
        final user = await database.getCurrentUserProfile();
        expect(user, isNull);
        
        final prefs = await database.getUserFoodPreferences('clear_test_user');
        expect(prefs, isEmpty);
        
        final plans = await database.getAllNutritionPlans('clear_test_user');
        expect(plans, isEmpty);
      });

      test('should get database statistics', () async {
        // Arrange - Add varied data
        final user1 = domain.UserProfile(
          id: 'stats_user_1',
          gender: domain.Gender.male,
          birthday: DateTime(1990, 1, 1),
          heightFeet: 6,
          heightInches: 0,
          weightPounds: 180.0,
          runsWithWaterBottle: false,
          gutTraining: domain.GutTraining.high,
          onboardingCompleted: true,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          appVersion: '1.0.0',
        );

        await database.saveUserProfile(user1);
        
        await database.saveFoodPreferences('stats_user_1', {
          'food1': domain.FoodPreference.like,
          'food2': domain.FoodPreference.dislike,
        });
        
        await database.saveNutritionPlan('plan1', 'stats_user_1', '{}');
        await database.saveNutritionPlan('plan2', 'stats_user_1', '{}');

        // Act
        final stats = await database.getDatabaseStats();

        // Assert
        expect(stats['users'], equals(1));
        expect(stats['preferences'], greaterThanOrEqualTo(2)); // At least 2 preferences
        expect(stats['plans'], equals(2));
      });

      test('should check if database has user data', () async {
        // Initially should have no data
        var hasData = await database.hasUserData();
        expect(hasData, isFalse);

        // Add a user
        final testUser = domain.UserProfile(
          id: 'has_data_test',
          gender: domain.Gender.other,
          birthday: DateTime(1995, 1, 1),
          heightFeet: 5,
          heightInches: 10,
          weightPounds: 165.0,
          runsWithWaterBottle: true,
          gutTraining: domain.GutTraining.low,
          onboardingCompleted: false,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          appVersion: '1.0.0',
        );

        await database.saveUserProfile(testUser);

        // Now should have data
        hasData = await database.hasUserData();
        expect(hasData, isTrue);
      });
    });

    group('Edge Cases and Error Handling', () {
      test('should handle empty food preferences', () async {
        // Arrange
        const userId = 'empty_prefs_user';
        final emptyPrefs = <String, domain.FoodPreference>{};

        // Act
        await database.saveFoodPreferences(userId, emptyPrefs);
        final retrievedPrefs = await database.getUserFoodPreferences(userId);

        // Assert
        expect(retrievedPrefs, isEmpty);
      });

      test('should return null when no user exists', () async {
        // Act
        final user = await database.getCurrentUserProfile();

        // Assert
        expect(user, isNull);
      });

      test('should return empty lists when no data exists', () async {
        // Act
        final likedFoods = await database.getLikedFoods('nonexistent_user');
        final dislikedFoods = await database.getDislikedFoods('nonexistent_user');
        final plans = await database.getAllNutritionPlans('nonexistent_user');

        // Assert
        expect(likedFoods, isEmpty);
        expect(dislikedFoods, isEmpty);
        expect(plans, isEmpty);
      });

      test('should handle very long strings in nutrition plans', () async {
        // Arrange
        const planId = 'long_plan';
        const userId = 'long_user';
        final longData = '{"data": "${' ' * 10000}"}'; // Very long JSON

        // Act
        await database.saveNutritionPlan(planId, userId, longData);
        final retrievedPlan = await database.getLatestNutritionPlan(userId);

        // Assert
        expect(retrievedPlan, isNotNull);
        expect(retrievedPlan!.length, greaterThan(10000));
      });

      test('should handle special characters in IDs', () async {
        // Arrange
        final testUser = domain.UserProfile(
          id: 'test-device_123.456@special',
          gender: domain.Gender.female,
          birthday: DateTime(1990, 1, 1),
          heightFeet: 5,
          heightInches: 6,
          weightPounds: 135.0,
          runsWithWaterBottle: true,
          gutTraining: domain.GutTraining.moderate,
          onboardingCompleted: true,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          appVersion: '1.0.0-beta',
        );

        // Act
        await database.saveUserProfile(testUser);
        final retrievedUser = await database.getCurrentUserProfile();

        // Assert
        expect(retrievedUser, isNotNull);
        expect(retrievedUser!.id, equals('test-device_123.456@special'));
        expect(retrievedUser.appVersion, equals('1.0.0-beta'));
      });
    });
  });
}