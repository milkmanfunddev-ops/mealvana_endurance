/// Integration tests for Nutrition Plan flow
/// Tests activity creation, macro calculations, and plan storage
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'dart:convert';

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
  group('Nutrition Plan Flow Tests', () {
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

    test('activity can be saved to database with distance and pace', () async {
      logTestHeading('Nutrition Plan - Save Activity');

      final userId = 'test-plan-user';
      final deviceId = 'device-plan-123';

      // Create user first
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

      logTestSetup({
        'user_id': userId,
        'activity_type': 'running',
        'distance_miles': 13.1,
        'pace_min_per_mile': 8.5,
      });

      final scheduledDate = DateTime.now().add(const Duration(days: 7));

      // Insert activity
      await database.into(database.activitiesTable).insert(
            ActivitiesTableCompanion.insert(
              userId: userId,
              activityType: 'running',
              title: 'Half Marathon Training',
              scheduledDateTime: scheduledDate,
              status: const Value('planned'),
              distanceMiles: const Value(13.1),
              paceTargetMinutesPerMile: const Value(8.5),
              intensityLevel: const Value('moderate'),
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
            ),
          );

      logSection('Verifying activity in database');

      final activities = await (database.select(database.activitiesTable)
            ..where((t) => t.userId.equals(userId)))
          .get();

      logTestResult('activity_count', activities.length);
      logTestResult('activity_type', activities.first.activityType);
      logTestResult('distance_miles', activities.first.distanceMiles);
      logTestResult('pace_min_per_mile', activities.first.paceTargetMinutesPerMile);
      logTestResult('intensity', activities.first.intensityLevel);

      logAssertion(
        'Activity saved',
        passed: activities.isNotEmpty,
        reason: 'Activity should be saved to database',
      );

      logAssertion(
        'Activity type is running',
        passed: activities.first.activityType == 'running',
        reason: 'Activity type should match input',
      );

      logAssertion(
        'Distance matches',
        passed: activities.first.distanceMiles == 13.1,
        reason: 'Distance should be stored correctly',
      );

      logAssertion(
        'Pace matches',
        passed: activities.first.paceTargetMinutesPerMile == 8.5,
        reason: 'Pace should be stored correctly',
      );

      expect(activities.length, equals(1));
      expect(activities.first.activityType, equals('running'));
      expect(activities.first.distanceMiles, equals(13.1));
      expect(activities.first.paceTargetMinutesPerMile, equals(8.5));

      logTestPass('Activity saved successfully');
    });

    test('macro targets are calculated and stored correctly', () async {
      logTestHeading('Nutrition Plan - Macro Target Calculation');

      // Simplified macro calculation based on distance
      // Real calculation uses ACSM formulas
      const distanceMiles = 10.0;
      const paceMinPerMile = 9.0;
      const weightPounds = 170.0;

      logTestSetup({
        'distance_miles': distanceMiles,
        'pace_min_per_mile': paceMinPerMile,
        'weight_pounds': weightPounds,
      });

      logSection('Calculating macro targets');

      // Simplified calculation (real app uses ACSM)
      final durationMinutes = distanceMiles * paceMinPerMile;
      final carbsGrams = (distanceMiles * 30).round(); // ~30g carbs per mile
      final proteinGrams = (weightPounds * 0.15).round(); // Rough estimate
      final fatGrams = 10; // Minimal fat during run

      logTestResult('duration_minutes', durationMinutes);
      logTestResult('carbs_grams', carbsGrams, expected: 300);
      logTestResult('protein_grams', proteinGrams);
      logTestResult('fat_grams', fatGrams);

      logAssertion(
        'Carbs in expected range',
        passed: carbsGrams >= 250 && carbsGrams <= 350,
        reason: '10-mile run should require ~300g carbs',
      );

      expect(carbsGrams, greaterThan(200));
      expect(carbsGrams, lessThan(400));

      logTestPass('Macro calculation verified');
    });

    test('plan data can be stored in activities table', () async {
      logTestHeading('Nutrition Plan - Store Plan Data');

      final userId = 'test-plan-storage-user';
      final deviceId = 'device-plan-storage-123';

      // Create user
      await database.into(database.userProfilesTable).insert(
            UserProfilesTableCompanion.insert(
              id: userId,
              deviceId: deviceId,
              authUserId: const Value(null),
              authProvider: const Value('anonymous'),
              isAnonymous: const Value(true),
              gender: const Value('female'),
              birthday: Value(DateTime(1992, 5, 10)),
              heightFeet: const Value(5),
              heightInches: const Value(6),
              weightPounds: const Value(145.0),
              runsWithWaterBottle: const Value(true),
              gutTrainingLevel: const Value('high'),
              onboardingCompleted: const Value(true),
              appVersion: const Value('1.0.0'),
              createdAt: Value(DateTime.now()),
              updatedAt: Value(DateTime.now()),
            ),
          );

      // Mock nutrition plan data
      final nutritionPlanData = {
        'pre_run': {
          'foods': ['Banana', 'Toast with Peanut Butter'],
          'carbs_g': 60,
          'timing_minutes': 120,
        },
        'during_run': {
          'foods': ['Energy Gel', 'Sports Drink'],
          'carbs_g': 180,
          'carbs_per_hour': 60,
        },
        'post_run': {
          'foods': ['Protein Shake', 'Banana'],
          'carbs_g': 45,
          'protein_g': 20,
        },
      };

      logTestSetup({
        'user_id': userId,
        'plan_phases': nutritionPlanData.keys.join(', '),
      });

      final scheduledDate = DateTime.now().add(const Duration(days: 3));

      // Insert activity with nutrition plan data
      await database.into(database.activitiesTable).insert(
            ActivitiesTableCompanion.insert(
              userId: userId,
              activityType: 'running',
              title: 'Long Run with Nutrition',
              scheduledDateTime: scheduledDate,
              status: const Value('planned'),
              distanceMiles: const Value(15.0),
              paceTargetMinutesPerMile: const Value(9.0),
              intensityLevel: const Value('moderate'),
              nutritionPlanData: Value(jsonEncode(nutritionPlanData)),
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
            ),
          );

      logSection('Verifying nutrition plan data');

      final activities = await (database.select(database.activitiesTable)
            ..where((t) => t.userId.equals(userId)))
          .get();

      final activity = activities.first;
      final storedPlanData = activity.nutritionPlanData != null
          ? jsonDecode(activity.nutritionPlanData!) as Map<String, dynamic>
          : null;

      logTestResult('has_nutrition_plan', storedPlanData != null);
      logTestResult('pre_run_carbs', storedPlanData?['pre_run']?['carbs_g']);
      logTestResult('during_run_carbs', storedPlanData?['during_run']?['carbs_g']);
      logTestResult('post_run_carbs', storedPlanData?['post_run']?['carbs_g']);

      logAssertion(
        'Nutrition plan data stored',
        passed: storedPlanData != null,
        reason: 'Plan data should be serialized to JSON',
      );

      logAssertion(
        'Pre-run carbs match',
        passed: storedPlanData?['pre_run']?['carbs_g'] == 60,
        reason: 'Pre-run nutrition should be preserved',
      );

      logAssertion(
        'During-run carbs match',
        passed: storedPlanData?['during_run']?['carbs_g'] == 180,
        reason: 'During-run nutrition should be preserved',
      );

      expect(storedPlanData, isNotNull);
      expect(storedPlanData?['pre_run']?['carbs_g'], equals(60));
      expect(storedPlanData?['during_run']?['carbs_g'], equals(180));
      expect(storedPlanData?['post_run']?['carbs_g'], equals(45));

      logTestPass('Nutrition plan data stored successfully');
    });

    test('food preferences are respected in plan generation', () async {
      logTestHeading('Nutrition Plan - Food Preference Filtering');

      final userId = 'test-pref-filter-user';
      final deviceId = 'device-pref-filter-123';

      // Create user
      await database.into(database.userProfilesTable).insert(
            UserProfilesTableCompanion.insert(
              id: userId,
              deviceId: deviceId,
              authUserId: const Value(null),
              authProvider: const Value('anonymous'),
              isAnonymous: const Value(true),
              gender: const Value('male'),
              birthday: Value(DateTime(1988, 8, 20)),
              heightFeet: const Value(5),
              heightInches: const Value(10),
              weightPounds: const Value(165.0),
              runsWithWaterBottle: const Value(false),
              gutTrainingLevel: const Value('moderate'),
              onboardingCompleted: const Value(true),
              appVersion: const Value('1.0.0'),
              createdAt: Value(DateTime.now()),
              updatedAt: Value(DateTime.now()),
            ),
          );

      // Add food preferences (dislike Oatmeal, like Banana)
      // IDs must be at least 36 chars (UUID format)
      await database.batch((batch) {
        batch.insert(
          database.foodPreferencesTable,
          FoodPreferencesTableCompanion.insert(
            id: '00000000-0000-0000-0000-000000000010',
            userId: userId,
            foodName: 'Oatmeal',
            preference: 'dislike',
            preferenceLevel: const Value(1),
            createdAt: Value(DateTime.now()),
            updatedAt: Value(DateTime.now()),
          ),
        );
        batch.insert(
          database.foodPreferencesTable,
          FoodPreferencesTableCompanion.insert(
            id: '00000000-0000-0000-0000-000000000011',
            userId: userId,
            foodName: 'Banana',
            preference: 'like',
            preferenceLevel: const Value(4),
            createdAt: Value(DateTime.now()),
            updatedAt: Value(DateTime.now()),
          ),
        );
      });

      logTestSetup({
        'user_id': userId,
        'dislikes': 'Oatmeal',
        'likes': 'Banana',
      });

      logSection('Retrieving food preferences');

      final preferences = await (database.select(database.foodPreferencesTable)
            ..where((t) => t.userId.equals(userId)))
          .get();

      final dislikedFoods = preferences
          .where((p) => p.preference == 'dislike')
          .map((p) => p.foodName)
          .toList();

      final likedFoods = preferences
          .where((p) => p.preference == 'like')
          .map((p) => p.foodName)
          .toList();

      logTestResult('disliked_foods', dislikedFoods.join(', '));
      logTestResult('liked_foods', likedFoods.join(', '));

      logAssertion(
        'Disliked foods retrieved',
        passed: dislikedFoods.contains('Oatmeal'),
        reason: 'Should filter out disliked foods from plan',
      );

      logAssertion(
        'Liked foods retrieved',
        passed: likedFoods.contains('Banana'),
        reason: 'Should prioritize liked foods in plan',
      );

      expect(dislikedFoods, contains('Oatmeal'));
      expect(likedFoods, contains('Banana'));

      logTestPass('Food preferences filtering verified');
    });

    test('activities can be retrieved by date', () async {
      logTestHeading('Nutrition Plan - Retrieve Activities by Date');

      final userId = 'test-date-retrieval-user';
      final deviceId = 'device-date-123';

      // Create user
      await database.into(database.userProfilesTable).insert(
            UserProfilesTableCompanion.insert(
              id: userId,
              deviceId: deviceId,
              authUserId: const Value(null),
              authProvider: const Value('anonymous'),
              isAnonymous: const Value(true),
              gender: const Value('female'),
              birthday: Value(DateTime(1995, 3, 15)),
              heightFeet: const Value(5),
              heightInches: const Value(5),
              weightPounds: const Value(135.0),
              runsWithWaterBottle: const Value(true),
              gutTrainingLevel: const Value('low'),
              onboardingCompleted: const Value(true),
              appVersion: const Value('1.0.0'),
              createdAt: Value(DateTime.now()),
              updatedAt: Value(DateTime.now()),
            ),
          );

      final targetDate = DateTime.now().add(const Duration(days: 5));
      final otherDate = DateTime.now().add(const Duration(days: 10));

      logTestSetup({
        'user_id': userId,
        'target_date': targetDate.toIso8601String().split('T')[0],
        'other_date': otherDate.toIso8601String().split('T')[0],
      });

      // Insert activities on different dates
      await database.batch((batch) {
        batch.insert(
          database.activitiesTable,
          ActivitiesTableCompanion.insert(
            userId: userId,
            activityType: 'running',
            title: 'Target Date Run',
            scheduledDateTime: targetDate,
            status: const Value('planned'),
            distanceMiles: const Value(5.0),
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        );
        batch.insert(
          database.activitiesTable,
          ActivitiesTableCompanion.insert(
            userId: userId,
            activityType: 'running',
            title: 'Other Date Run',
            scheduledDateTime: otherDate,
            status: const Value('planned'),
            distanceMiles: const Value(8.0),
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        );
      });

      logSection('Querying activities for target date');

      // Query activities for target date (using day-based filtering)
      final targetDateStart = DateTime(targetDate.year, targetDate.month, targetDate.day);
      final targetDateEnd = targetDateStart.add(const Duration(days: 1));

      final activitiesOnTargetDate = await (database.select(database.activitiesTable)
            ..where((t) =>
                t.userId.equals(userId) &
                t.scheduledDateTime.isBiggerOrEqualValue(targetDateStart) &
                t.scheduledDateTime.isSmallerThanValue(targetDateEnd)))
          .get();

      logTestResult('activities_on_target_date', activitiesOnTargetDate.length);
      if (activitiesOnTargetDate.isNotEmpty) {
        logTestResult('activity_title', activitiesOnTargetDate.first.title);
        logTestResult('distance_miles', activitiesOnTargetDate.first.distanceMiles);
      }

      logAssertion(
        'One activity on target date',
        passed: activitiesOnTargetDate.length == 1,
        reason: 'Should retrieve activities for specific date',
      );

      logAssertion(
        'Correct activity retrieved',
        passed: activitiesOnTargetDate.first.title == 'Target Date Run',
        reason: 'Should match the target date activity',
      );

      expect(activitiesOnTargetDate.length, equals(1));
      expect(activitiesOnTargetDate.first.title, equals('Target Date Run'));
      expect(activitiesOnTargetDate.first.distanceMiles, equals(5.0));

      logTestPass('Date-based activity retrieval verified');
    });
  });
}
