/// Integration tests for Food Management flow
/// Tests food preference updates, custom foods, and food retrieval
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;

import 'package:mealvana_endurance/shared/database/app_database.dart';
import 'package:mealvana_endurance/shared/database/database_provider.dart';
import 'package:mealvana_endurance/shared/services/analytics/analytics_tracker.dart';
import 'package:mealvana_endurance/shared/services/sentry/sentry_reporter.dart';
import 'package:mealvana_endurance/shared/services/logging_service.dart';

import '../../helpers/fakes/recording_analytics_tracker.dart';
import '../../helpers/fakes/recording_sentry_reporter.dart';
import '../../helpers/fakes/recording_app_logger.dart';
import '../../helpers/utils/console_logging.dart';

void main() {
  group('Food Management Flow Tests', () {
    late AppDatabase database;
    late RecordingAnalyticsTracker analytics;
    late RecordingSentryReporter sentry;
    late RecordingAppLogger logger;
    ProviderContainer? container;

    setUp(() {
      // Create in-memory database for each test
      database = AppDatabase.memory();

      // Create recording mocks
      analytics = RecordingAnalyticsTracker();
      sentry = RecordingSentryReporter();
      logger = RecordingAppLogger();
    });

    tearDown() async {
      // Clean up database
      await database.close();
      container?.dispose();

      // Clear mock data
      analytics.clear();
      sentry.clear();
      logger.clear();
    }

    /// Helper to create container with mocked dependencies
    ProviderContainer createTestContainer() {
      return ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(database),
          analyticsTrackerProvider.overrideWith((ref) => analytics),
          sentryReporterProvider.overrideWith((ref) => sentry),
          appLoggerProvider.overrideWith((ref) => logger),
        ],
      );
    }

    test('food preferences can be updated (like to dislike)', () async {
      logTestHeading('Food Management - Update Preference');

      final userId = 'test-update-pref-user';
      final deviceId = 'device-update-123';

      // Create user
      await database.into(database.userProfilesTable).insert(
            UserProfilesTableCompanion.insert(
              id: userId,
              deviceId: deviceId,
              authUserId: const Value(null),
              authProvider: const Value('anonymous'),
              isAnonymous: const Value(true),
              gender: const Value('male'),
              birthday: Value(DateTime(1990, 1, 1)),
              heightFeet: const Value(6),
              heightInches: const Value(0),
              weightPounds: const Value(180.0),
              runsWithWaterBottle: const Value(false),
              gutTrainingLevel: const Value('moderate'),
              onboardingCompleted: const Value(true),
              appVersion: const Value('1.0.0'),
              createdAt: Value(DateTime.now()),
              updatedAt: Value(DateTime.now()),
            ),
          );

      // IDs must be at least 36 chars (UUID format)
      final prefId = '00000000-0000-0000-0000-000000000020';

      // Insert initial preference (like)
      await database.into(database.foodPreferencesTable).insert(
            FoodPreferencesTableCompanion.insert(
              id: prefId,
              userId: userId,
              foodName: 'Energy Gel',
              preference: 'like',
              preferenceLevel: const Value(3),
              createdAt: Value(DateTime.now()),
              updatedAt: Value(DateTime.now()),
            ),
          );

      logTestSetup({
        'user_id': userId,
        'food': 'Energy Gel',
        'initial_preference': 'like',
        'updated_preference': 'dislike',
      });

      logSection('Updating preference from like to dislike');

      // Update preference
      await (database.update(database.foodPreferencesTable)
            ..where((t) => t.id.equals(prefId)))
          .write(
        FoodPreferencesTableCompanion(
          preference: const Value('dislike'),
          preferenceLevel: const Value(1),
          updatedAt: Value(DateTime.now()),
        ),
      );

      final updatedPref = await (database.select(database.foodPreferencesTable)
            ..where((t) => t.id.equals(prefId)))
          .getSingle();

      logTestResult('preference', updatedPref.preference);
      logTestResult('preference_level', updatedPref.preferenceLevel);

      logAssertion(
        'Preference updated to dislike',
        passed: updatedPref.preference == 'dislike',
        reason: 'User should be able to change food preference',
      );

      logAssertion(
        'Preference level updated',
        passed: updatedPref.preferenceLevel == 1,
        reason: 'Preference level should reflect new intensity',
      );

      expect(updatedPref.preference, equals('dislike'));
      expect(updatedPref.preferenceLevel, equals(1));

      logTestPass('Food preference updated successfully');
    });

    test('custom foods can be created by users', () async {
      logTestHeading('Food Management - Create Custom Food');

      final userId = 'test-custom-food-user';
      final deviceId = 'device-custom-123';
      // IDs must be at least 36 chars (UUID format)
      final foodId = '00000000-0000-0000-0000-000000000021';

      // Create user
      await database.into(database.userProfilesTable).insert(
            UserProfilesTableCompanion.insert(
              id: userId,
              deviceId: deviceId,
              authUserId: const Value(null),
              authProvider: const Value('anonymous'),
              isAnonymous: const Value(true),
              gender: const Value('female'),
              birthday: Value(DateTime(1993, 7, 12)),
              heightFeet: const Value(5),
              heightInches: const Value(7),
              weightPounds: const Value(140.0),
              runsWithWaterBottle: const Value(true),
              gutTrainingLevel: const Value('high'),
              onboardingCompleted: const Value(true),
              appVersion: const Value('1.0.0'),
              createdAt: Value(DateTime.now()),
              updatedAt: Value(DateTime.now()),
            ),
          );

      logTestSetup({
        'user_id': userId,
        'custom_food': 'Homemade Energy Balls',
        'carbs_per_serving': 25.0,
        'calories_per_serving': 120,
      });

      // Insert custom food
      await database.into(database.userFoodsTable).insert(
            UserFoodsTableCompanion.insert(
              id: foodId,
              deviceId: deviceId,
              userId: userId,
              name: 'Homemade Energy Balls',
              displayName: const Value('Homemade Energy Balls'),
              displayNamePlural: const Value('Homemade Energy Balls'),
              description: const Value('Custom energy snack with dates and nuts'),
              servingAmount: const Value(1.0),
              servingUnit: const Value('ball'),
              caloriesPerServing: const Value(120),
              carbsPerServing: const Value(25.0),
              proteinPerServing: const Value(3.0),
              fatPerServing: const Value(5.0),
              sodiumMg: const Value(10),
              createdAt: Value(DateTime.now()),
              updatedAt: Value(DateTime.now()),
            ),
          );

      logSection('Verifying custom food in database');

      final customFoods = await (database.select(database.userFoodsTable)
            ..where((t) => t.userId.equals(userId)))
          .get();

      logTestResult('custom_food_count', customFoods.length);
      logTestResult('food_name', customFoods.first.name);
      logTestResult('carbs_per_serving', customFoods.first.carbsPerServing);
      logTestResult('calories_per_serving', customFoods.first.caloriesPerServing);

      logAssertion(
        'Custom food created',
        passed: customFoods.isNotEmpty,
        reason: 'User should be able to create custom foods',
      );

      logAssertion(
        'Food name matches',
        passed: customFoods.first.name == 'Homemade Energy Balls',
        reason: 'Custom food name should be stored',
      );

      logAssertion(
        'Nutritional values stored',
        passed: customFoods.first.carbsPerServing == 25.0 &&
            customFoods.first.caloriesPerServing == 120,
        reason: 'Nutritional data should be preserved',
      );

      expect(customFoods.length, equals(1));
      expect(customFoods.first.name, equals('Homemade Energy Balls'));
      expect(customFoods.first.carbsPerServing, equals(25.0));
      expect(customFoods.first.caloriesPerServing, equals(120));

      logTestPass('Custom food created successfully');
    });

    test('user foods can be retrieved for food selection', () async {
      logTestHeading('Food Management - Retrieve User Foods');

      final userId = 'test-retrieve-foods-user';
      final deviceId = 'device-retrieve-123';

      // Create user
      await database.into(database.userProfilesTable).insert(
            UserProfilesTableCompanion.insert(
              id: userId,
              deviceId: deviceId,
              authUserId: const Value(null),
              authProvider: const Value('anonymous'),
              isAnonymous: const Value(true),
              gender: const Value('male'),
              birthday: Value(DateTime(1988, 4, 25)),
              heightFeet: const Value(5),
              heightInches: const Value(11),
              weightPounds: const Value(175.0),
              runsWithWaterBottle: const Value(false),
              gutTrainingLevel: const Value('moderate'),
              onboardingCompleted: const Value(true),
              appVersion: const Value('1.0.0'),
              createdAt: Value(DateTime.now()),
              updatedAt: Value(DateTime.now()),
            ),
          );

      logTestSetup({
        'user_id': userId,
        'food_count': 3,
      });

      // Insert multiple user foods (IDs must be at least 36 chars - UUID format)
      await database.batch((batch) {
        batch.insert(
          database.userFoodsTable,
          UserFoodsTableCompanion.insert(
            id: '00000000-0000-0000-0000-000000000030',
            deviceId: deviceId,
            userId: userId,
            name: 'Custom Protein Bar',
            carbsPerServing: const Value(30.0),
            proteinPerServing: const Value(15.0),
            caloriesPerServing: const Value(200),
            createdAt: Value(DateTime.now()),
            updatedAt: Value(DateTime.now()),
          ),
        );
        batch.insert(
          database.userFoodsTable,
          UserFoodsTableCompanion.insert(
            id: '00000000-0000-0000-0000-000000000031',
            deviceId: deviceId,
            userId: userId,
            name: 'Homemade Sports Drink',
            carbsPerServing: const Value(25.0),
            caloriesPerServing: const Value(100),
            createdAt: Value(DateTime.now()),
            updatedAt: Value(DateTime.now()),
          ),
        );
        batch.insert(
          database.userFoodsTable,
          UserFoodsTableCompanion.insert(
            id: '00000000-0000-0000-0000-000000000032',
            deviceId: deviceId,
            userId: userId,
            name: 'Trail Mix',
            carbsPerServing: const Value(20.0),
            proteinPerServing: const Value(8.0),
            fatPerServing: const Value(12.0),
            caloriesPerServing: const Value(180),
            createdAt: Value(DateTime.now()),
            updatedAt: Value(DateTime.now()),
          ),
        );
      });

      logSection('Retrieving all user foods');

      final userFoods = await (database.select(database.userFoodsTable)
            ..where((t) => t.userId.equals(userId)))
          .get();

      logTestResult('user_food_count', userFoods.length);
      logTestResult('food_names', userFoods.map((f) => f.name).join(', '));

      logAssertion(
        'Three foods retrieved',
        passed: userFoods.length == 3,
        reason: 'All user foods should be retrievable',
      );

      logAssertion(
        'Foods have nutritional data',
        passed: userFoods.every((f) => f.carbsPerServing != null),
        reason: 'Each food should have carb data',
      );

      expect(userFoods.length, equals(3));
      expect(userFoods.map((f) => f.name).toList(), containsAll([
        'Custom Protein Bar',
        'Homemade Sports Drink',
        'Trail Mix',
      ]));

      logTestPass('User foods retrieved successfully');
    });

    test('food preferences support willing_to_try status', () async {
      logTestHeading('Food Management - Willing To Try Status');

      final userId = 'test-willing-user';
      final deviceId = 'device-willing-123';

      // Create user
      await database.into(database.userProfilesTable).insert(
            UserProfilesTableCompanion.insert(
              id: userId,
              deviceId: deviceId,
              authUserId: const Value(null),
              authProvider: const Value('anonymous'),
              isAnonymous: const Value(true),
              gender: const Value('other'),
              birthday: Value(DateTime(1991, 11, 5)),
              heightFeet: const Value(5),
              heightInches: const Value(9),
              weightPounds: const Value(160.0),
              runsWithWaterBottle: const Value(true),
              gutTrainingLevel: const Value('low'),
              onboardingCompleted: const Value(true),
              appVersion: const Value('1.0.0'),
              createdAt: Value(DateTime.now()),
              updatedAt: Value(DateTime.now()),
            ),
          );

      logTestSetup({
        'user_id': userId,
        'preference': 'willing_to_try',
        'food': 'Energy Chews',
      });

      // Insert willing_to_try preference (ID must be at least 36 chars - UUID format)
      await database.into(database.foodPreferencesTable).insert(
            FoodPreferencesTableCompanion.insert(
              id: '00000000-0000-0000-0000-000000000040',
              userId: userId,
              foodName: 'Energy Chews',
              preference: 'willing_to_try',
              preferenceLevel: const Value(2),
              createdAt: Value(DateTime.now()),
              updatedAt: Value(DateTime.now()),
            ),
          );

      logSection('Verifying willing_to_try preference');

      final preference = await (database.select(database.foodPreferencesTable)
            ..where((t) => t.userId.equals(userId)))
          .getSingle();

      logTestResult('preference', preference.preference);
      logTestResult('preference_level', preference.preferenceLevel);

      logAssertion(
        'Willing_to_try preference stored',
        passed: preference.preference == 'willing_to_try',
        reason: 'System should support three preference states',
      );

      expect(preference.preference, equals('willing_to_try'));

      logTestPass('Willing_to_try preference verified');
    });

    test('multiple preferences for same user are uniquely stored', () async {
      logTestHeading('Food Management - Multiple Preferences');

      final userId = 'test-multi-pref-user';
      final deviceId = 'device-multi-123';

      // Create user
      await database.into(database.userProfilesTable).insert(
            UserProfilesTableCompanion.insert(
              id: userId,
              deviceId: deviceId,
              authUserId: const Value(null),
              authProvider: const Value('anonymous'),
              isAnonymous: const Value(true),
              gender: const Value('female'),
              birthday: Value(DateTime(1994, 2, 18)),
              heightFeet: const Value(5),
              heightInches: const Value(3),
              weightPounds: const Value(125.0),
              runsWithWaterBottle: const Value(false),
              gutTrainingLevel: const Value('high'),
              onboardingCompleted: const Value(true),
              appVersion: const Value('1.0.0'),
              createdAt: Value(DateTime.now()),
              updatedAt: Value(DateTime.now()),
            ),
          );

      logTestSetup({
        'user_id': userId,
        'preferences': 'Banana (like), Gel (dislike), Gatorade (like), Oatmeal (dislike)',
      });

      // Insert multiple preferences (IDs must be at least 36 chars - UUID format)
      await database.batch((batch) {
        batch.insert(
          database.foodPreferencesTable,
          FoodPreferencesTableCompanion.insert(
            id: '00000000-0000-0000-0000-000000000050',
            userId: userId,
            foodName: 'Banana',
            preference: 'like',
            preferenceLevel: const Value(4),
            createdAt: Value(DateTime.now()),
            updatedAt: Value(DateTime.now()),
          ),
        );
        batch.insert(
          database.foodPreferencesTable,
          FoodPreferencesTableCompanion.insert(
            id: '00000000-0000-0000-0000-000000000051',
            userId: userId,
            foodName: 'Energy Gel',
            preference: 'dislike',
            preferenceLevel: const Value(1),
            createdAt: Value(DateTime.now()),
            updatedAt: Value(DateTime.now()),
          ),
        );
        batch.insert(
          database.foodPreferencesTable,
          FoodPreferencesTableCompanion.insert(
            id: '00000000-0000-0000-0000-000000000052',
            userId: userId,
            foodName: 'Gatorade',
            preference: 'like',
            preferenceLevel: const Value(3),
            createdAt: Value(DateTime.now()),
            updatedAt: Value(DateTime.now()),
          ),
        );
        batch.insert(
          database.foodPreferencesTable,
          FoodPreferencesTableCompanion.insert(
            id: '00000000-0000-0000-0000-000000000053',
            userId: userId,
            foodName: 'Oatmeal',
            preference: 'dislike',
            preferenceLevel: const Value(2),
            createdAt: Value(DateTime.now()),
            updatedAt: Value(DateTime.now()),
          ),
        );
      });

      logSection('Retrieving all preferences');

      final allPreferences = await (database.select(database.foodPreferencesTable)
            ..where((t) => t.userId.equals(userId)))
          .get();

      final likedFoods =
          allPreferences.where((p) => p.preference == 'like').toList();
      final dislikedFoods =
          allPreferences.where((p) => p.preference == 'dislike').toList();

      logTestResult('total_preferences', allPreferences.length);
      logTestResult('liked_count', likedFoods.length);
      logTestResult('disliked_count', dislikedFoods.length);
      logTestResult('liked_foods', likedFoods.map((f) => f.foodName).join(', '));
      logTestResult('disliked_foods', dislikedFoods.map((f) => f.foodName).join(', '));

      logAssertion(
        'Four preferences stored',
        passed: allPreferences.length == 4,
        reason: 'All preferences should be uniquely stored',
      );

      logAssertion(
        'Two liked foods',
        passed: likedFoods.length == 2,
        reason: 'Multiple likes should be supported',
      );

      logAssertion(
        'Two disliked foods',
        passed: dislikedFoods.length == 2,
        reason: 'Multiple dislikes should be supported',
      );

      expect(allPreferences.length, equals(4));
      expect(likedFoods.length, equals(2));
      expect(dislikedFoods.length, equals(2));

      logTestPass('Multiple preferences stored successfully');
    });
  });
}
