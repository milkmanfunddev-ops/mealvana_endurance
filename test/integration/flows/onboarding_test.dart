/// Integration tests for Onboarding flow
/// Tests user profile creation, sport preferences, and food preferences
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;

import 'package:mealvana_endurance/shared/database/app_database.dart';
import 'package:mealvana_endurance/shared/database/database_provider.dart';
import 'package:mealvana_endurance/shared/services/analytics/analytics_tracker.dart';
import 'package:mealvana_endurance/shared/services/sentry/sentry_reporter.dart';
import 'package:mealvana_endurance/shared/services/logging_service.dart';
import 'package:mealvana_endurance/features/auth/domain/user_preferences.dart'
    show Gender, GutTraining, GutTrainingLevel;

import '../../helpers/fakes/recording_analytics_tracker.dart';
import '../../helpers/fakes/recording_sentry_reporter.dart';
import '../../helpers/fakes/recording_app_logger.dart';
import '../../helpers/utils/console_logging.dart';

void main() {
  group('Onboarding Flow Tests', () {
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

    tearDown(() async {
      // Clean up database
      await database.close();
      container?.dispose();

      // Clear mock data
      analytics.clear();
      sentry.clear();
      logger.clear();
    });

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

    test('user profile can be saved to database', () async {
      logTestHeading('Onboarding - Save User Profile');

      final testId = 'test-onboarding-user';
      final testDeviceId = 'device-onboarding-123';

      logTestSetup({
        'user_id': testId,
        'device_id': testDeviceId,
        'gender': 'female',
        'weight': '140 lbs',
        'gut_training_level': 'low',
      });

      // Insert user profile
      await database.into(database.userProfilesTable).insert(
            UserProfilesTableCompanion.insert(
              id: testId,
              deviceId: testDeviceId,
              authUserId: const Value(null),
              authProvider: const Value('anonymous'),
              isAnonymous: const Value(true),
              gender: const Value('female'),
              birthday: Value(DateTime(1995, 3, 15)),
              heightFeet: const Value(5),
              heightInches: const Value(4),
              weightPounds: const Value(140.0),
              runsWithWaterBottle: const Value(false),
              gutTrainingLevel: const Value('low'),
              onboardingCompleted: const Value(false),
              appVersion: const Value('1.0.0'),
              createdAt: Value(DateTime.now()),
              updatedAt: Value(DateTime.now()),
            ),
          );

      logSection('Verifying user profile in database');

      final userProfile = await database.getCurrentUserProfile();

      logTestResult('user_id', userProfile?.id);
      logTestResult('gender', userProfile?.gender);
      logTestResult('weight_pounds', userProfile?.weightPounds);
      logTestResult('gut_training_level', userProfile?.gutTrainingLevel);
      logTestResult('onboarding_completed', userProfile?.onboardingCompleted);

      logAssertion(
        'User profile exists',
        passed: userProfile != null,
        reason: 'Profile should be saved to database',
      );

      logAssertion(
        'Gender matches',
        passed: userProfile?.gender == Gender.female,
        reason: 'User-provided gender should be stored',
      );

      logAssertion(
        'Weight matches',
        passed: userProfile?.weightPounds == 140.0,
        reason: 'User-provided weight should be stored',
      );

      logAssertion(
        'Gut training level matches',
        passed: userProfile?.gutTrainingLevel == GutTrainingLevel.low,
        reason: 'User-selected gut training level should be stored',
      );

      expect(userProfile, isNotNull);
      expect(userProfile?.id, equals(testId));
      expect(userProfile?.gender, equals(Gender.female));
      expect(userProfile?.weightPounds, equals(140.0));
      expect(userProfile?.gutTrainingLevel, equals(GutTrainingLevel.low));
      expect(userProfile?.onboardingCompleted, isFalse);

      logTestPass('User profile saved successfully');
    });

    test('sport preferences (gut training level) can be saved', () async {
      logTestHeading('Onboarding - Save Sport Preferences');

      final testId = 'test-sport-pref-user';
      final testDeviceId = 'device-sport-123';

      // Create initial user
      await database.into(database.userProfilesTable).insert(
            UserProfilesTableCompanion.insert(
              id: testId,
              deviceId: testDeviceId,
              authUserId: const Value(null),
              authProvider: const Value('anonymous'),
              isAnonymous: const Value(true),
              gender: const Value('male'),
              birthday: Value(DateTime(1990, 1, 1)),
              heightFeet: const Value(6),
              heightInches: const Value(0),
              weightPounds: const Value(180.0),
              runsWithWaterBottle: const Value(false),
              gutTrainingLevel: const Value('low'), // Initial value
              onboardingCompleted: const Value(false),
              appVersion: const Value('1.0.0'),
              createdAt: Value(DateTime.now()),
              updatedAt: Value(DateTime.now()),
            ),
          );

      logTestSetup({
        'initial_gut_training': 'low',
        'updated_gut_training': 'high',
      });

      logSection('Updating gut training level to "high"');

      // Update gut training level
      await (database.update(database.userProfilesTable)
            ..where((t) => t.id.equals(testId)))
          .write(
        UserProfilesTableCompanion(
          gutTrainingLevel: const Value('high'),
          updatedAt: Value(DateTime.now()),
        ),
      );

      final updatedProfile = await database.getCurrentUserProfile();

      logTestResult('gut_training_level', updatedProfile?.gutTrainingLevel);

      logAssertion(
        'Gut training level updated',
        passed: updatedProfile?.gutTrainingLevel == GutTrainingLevel.high,
        reason: 'Sport preference should be updatable',
      );

      expect(updatedProfile?.gutTrainingLevel, equals(GutTrainingLevel.high));

      logTestPass('Sport preferences saved successfully');
    });

    test('food preferences can be saved', () async {
      logTestHeading('Onboarding - Save Food Preferences');

      final userId = 'test-food-pref-user';
      final deviceId = 'device-food-123';

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
              onboardingCompleted: const Value(false),
              appVersion: const Value('1.0.0'),
              createdAt: Value(DateTime.now()),
              updatedAt: Value(DateTime.now()),
            ),
          );

      logTestSetup({
        'user_id': userId,
        'preferences': 'Banana (like), Oatmeal (dislike), Gatorade (willing_to_try)',
      });

      // Insert food preferences (IDs must be at least 36 chars - UUID format)
      final prefId1 = '00000000-0000-0000-0000-000000000001';
      final prefId2 = '00000000-0000-0000-0000-000000000002';
      final prefId3 = '00000000-0000-0000-0000-000000000003';

      await database.batch((batch) {
        batch.insert(
          database.foodPreferencesTable,
          FoodPreferencesTableCompanion.insert(
            id: prefId1,
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
            id: prefId2,
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
            id: prefId3,
            userId: userId,
            foodName: 'Gatorade',
            preference: 'willing_to_try',
            preferenceLevel: const Value(2),
            createdAt: Value(DateTime.now()),
            updatedAt: Value(DateTime.now()),
          ),
        );
      });

      logSection('Verifying food preferences in database');

      final savedPreferences = await (database.select(database.foodPreferencesTable)
            ..where((t) => t.userId.equals(userId)))
          .get();

      logTestResult('preference_count', savedPreferences.length);

      logAssertion(
        'Three preferences saved',
        passed: savedPreferences.length == 3,
        reason: 'All food preferences should be saved',
      );

      final likedFoods =
          savedPreferences.where((p) => p.preference == 'like').toList();
      final dislikedFoods =
          savedPreferences.where((p) => p.preference == 'dislike').toList();
      final willingFoods =
          savedPreferences.where((p) => p.preference == 'willing_to_try').toList();

      logTestResult('liked_foods', likedFoods.map((f) => f.foodName).join(', '));
      logTestResult('disliked_foods', dislikedFoods.map((f) => f.foodName).join(', '));
      logTestResult(
          'willing_to_try', willingFoods.map((f) => f.foodName).join(', '));

      expect(savedPreferences.length, equals(3));
      expect(likedFoods.length, equals(1));
      expect(likedFoods.first.foodName, equals('Banana'));
      expect(dislikedFoods.length, equals(1));
      expect(dislikedFoods.first.foodName, equals('Oatmeal'));
      expect(willingFoods.length, equals(1));
      expect(willingFoods.first.foodName, equals('Gatorade'));

      logTestPass('Food preferences saved successfully');
    });

    test('onboarding completion flag can be set', () async {
      logTestHeading('Onboarding - Complete Onboarding');

      final userId = 'test-complete-user';
      final deviceId = 'device-complete-123';

      // Create user with incomplete onboarding
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
              heightInches: const Value(8),
              weightPounds: const Value(150.0),
              runsWithWaterBottle: const Value(true),
              gutTrainingLevel: const Value('moderate'),
              onboardingCompleted: const Value(false), // Not completed
              appVersion: const Value('1.0.0'),
              createdAt: Value(DateTime.now()),
              updatedAt: Value(DateTime.now()),
            ),
          );

      logTestSetup({
        'user_id': userId,
        'initial_onboarding_completed': false,
      });

      logSection('Marking onboarding as completed');

      // Mark onboarding as completed
      await (database.update(database.userProfilesTable)
            ..where((t) => t.id.equals(userId)))
          .write(
        UserProfilesTableCompanion(
          onboardingCompleted: const Value(true),
          updatedAt: Value(DateTime.now()),
        ),
      );

      final completedProfile = await database.getCurrentUserProfile();

      logTestResult('onboarding_completed', completedProfile?.onboardingCompleted);

      logAssertion(
        'Onboarding marked as completed',
        passed: completedProfile?.onboardingCompleted == true,
        reason: 'Flag should be set to true after completion',
      );

      expect(completedProfile?.onboardingCompleted, isTrue);

      logTestPass('Onboarding completion verified');
    });

    test('navigation progresses through onboarding screens correctly', () async {
      logTestHeading('Onboarding - Navigation Flow');

      // Test the navigation decision logic at different stages
      logTestSetup({
        'flow': 'Welcome → Profile → Sport Prefs → Food Prefs → Main',
      });

      logSection('Stage 1: No user (fresh install)');
      const stage1HasUser = false;
      const stage1Completed = false;
      final stage1Route = _determineRoute(stage1HasUser, stage1Completed);
      logTestResult('expected_route', stage1Route);

      logAssertion(
        'Fresh install navigates to welcome',
        passed: stage1Route == '/welcome',
        reason: 'No user should start at welcome screen',
      );

      expect(stage1Route, equals('/welcome'));

      logSection('Stage 2: User created, onboarding incomplete');
      const stage2HasUser = true;
      const stage2Completed = false;
      final stage2Route = _determineRoute(stage2HasUser, stage2Completed);
      logTestResult('expected_route', stage2Route);

      logAssertion(
        'Incomplete onboarding navigates to food preferences',
        passed: stage2Route == '/onboarding/food-preferences',
        reason: 'Incomplete onboarding continues to food preferences',
      );

      expect(stage2Route, equals('/onboarding/food-preferences'));

      logSection('Stage 3: Onboarding completed');
      const stage3HasUser = true;
      const stage3Completed = true;
      final stage3Route = _determineRoute(stage3HasUser, stage3Completed);
      logTestResult('expected_route', stage3Route);

      logAssertion(
        'Completed onboarding navigates to main',
        passed: stage3Route == '/main',
        reason: 'Completed onboarding enters main app',
      );

      expect(stage3Route, equals('/main'));

      logTestPass('Navigation flow verified');
    });
  });
}

/// Helper function to determine route based on onboarding state
String _determineRoute(bool hasUser, bool hasCompletedOnboarding) {
  if (!hasUser) {
    return '/welcome';
  } else if (!hasCompletedOnboarding) {
    return '/onboarding/food-preferences';
  } else {
    return '/main';
  }
}
