/// Integration tests for Settings flow
/// Tests profile updates, preference management, and settings persistence
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
  group('Settings Flow Tests', () {
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

    test('profile updates are saved correctly', () async {
      logTestHeading('Settings - Update Profile');

      final userId = 'test-update-profile-user';
      final deviceId = 'device-update-profile-123';

      // Create initial user
      await database
          .into(database.userProfilesTable)
          .insert(
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
        'initial_weight': '180 lbs',
        'updated_weight': '175 lbs',
        'initial_water_bottle': false,
        'updated_water_bottle': true,
      });

      logSection('Updating profile settings');

      // Update weight and water bottle preference
      await (database.update(
        database.userProfilesTable,
      )..where((t) => t.id.equals(userId))).write(
        UserProfilesTableCompanion(
          weightPounds: const Value(175.0),
          runsWithWaterBottle: const Value(true),
          updatedAt: Value(DateTime.now()),
        ),
      );

      final updatedProfile = await (database.select(
        database.userProfilesTable,
      )..where((t) => t.id.equals(userId))).getSingle();

      logTestResult('weight_pounds', updatedProfile.weightPounds);
      logTestResult(
        'runs_with_water_bottle',
        updatedProfile.runsWithWaterBottle,
      );

      logAssertion(
        'Weight updated',
        passed: updatedProfile.weightPounds == 175.0,
        reason: 'Profile weight should be updatable',
      );

      logAssertion(
        'Water bottle preference updated',
        passed: updatedProfile.runsWithWaterBottle == true,
        reason: 'Water bottle preference should be updatable',
      );

      expect(updatedProfile.weightPounds, equals(175.0));
      expect(updatedProfile.runsWithWaterBottle, isTrue);

      logTestPass('Profile updated successfully');
    });

    test('gut training level can be changed', () async {
      logTestHeading('Settings - Change Gut Training Level');

      final userId = 'test-gut-level-user';
      final deviceId = 'device-gut-level-123';

      // Create user with low gut training
      await database
          .into(database.userProfilesTable)
          .insert(
            UserProfilesTableCompanion.insert(
              id: userId,
              deviceId: deviceId,
              authUserId: const Value(null),
              authProvider: const Value('anonymous'),
              isAnonymous: const Value(true),
              gender: const Value('female'),
              birthday: Value(DateTime(1992, 6, 15)),
              heightFeet: const Value(5),
              heightInches: const Value(6),
              weightPounds: const Value(140.0),
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
        'initial_gut_training': 'low',
        'progression': 'low → moderate → high',
      });

      logSection('Updating to moderate');

      // Update to moderate
      await (database.update(
        database.userProfilesTable,
      )..where((t) => t.id.equals(userId))).write(
        UserProfilesTableCompanion(
          gutTrainingLevel: const Value('moderate'),
          updatedAt: Value(DateTime.now()),
        ),
      );

      var profile = await (database.select(
        database.userProfilesTable,
      )..where((t) => t.id.equals(userId))).getSingle();
      logTestResult('gut_training_level', profile.gutTrainingLevel);

      expect(profile.gutTrainingLevel, equals('moderate'));

      logSection('Updating to high');

      // Update to high
      await (database.update(
        database.userProfilesTable,
      )..where((t) => t.id.equals(userId))).write(
        UserProfilesTableCompanion(
          gutTrainingLevel: const Value('high'),
          updatedAt: Value(DateTime.now()),
        ),
      );

      profile = await (database.select(
        database.userProfilesTable,
      )..where((t) => t.id.equals(userId))).getSingle();
      logTestResult('gut_training_level', profile.gutTrainingLevel);

      logAssertion(
        'Gut training level updated to high',
        passed: profile.gutTrainingLevel == 'high',
        reason: 'Users should be able to progress gut training levels',
      );

      expect(profile.gutTrainingLevel, equals('high'));

      logTestPass('Gut training level progression verified');
    });

    test('distance and pace unit preferences are saved', () async {
      logTestHeading('Settings - Unit Preferences');

      final userId = 'test-units-user';
      final deviceId = 'device-units-123';

      // Create user with default units (miles)
      await database
          .into(database.userProfilesTable)
          .insert(
            UserProfilesTableCompanion.insert(
              id: userId,
              deviceId: deviceId,
              authUserId: const Value(null),
              authProvider: const Value('anonymous'),
              isAnonymous: const Value(true),
              gender: const Value('male'),
              birthday: Value(DateTime(1985, 3, 20)),
              heightFeet: const Value(5),
              heightInches: const Value(10),
              weightPounds: const Value(170.0),
              runsWithWaterBottle: const Value(false),
              gutTrainingLevel: const Value('moderate'),
              onboardingCompleted: const Value(true),
              preferredDistanceUnit: const Value('miles'),
              preferredPaceUnit: const Value('minPerMile'),
              appVersion: const Value('1.0.0'),
              createdAt: Value(DateTime.now()),
              updatedAt: Value(DateTime.now()),
            ),
          );

      logTestSetup({
        'user_id': userId,
        'initial_distance_unit': 'miles',
        'initial_pace_unit': 'minPerMile',
        'updated_distance_unit': 'kilometers',
        'updated_pace_unit': 'minPerKm',
      });

      logSection('Updating to metric units');

      // Update to kilometers
      await (database.update(
        database.userProfilesTable,
      )..where((t) => t.id.equals(userId))).write(
        UserProfilesTableCompanion(
          preferredDistanceUnit: const Value('kilometers'),
          preferredPaceUnit: const Value('minPerKm'),
          updatedAt: Value(DateTime.now()),
        ),
      );

      final profileEntries = await (database.select(
        database.userProfilesTable,
      )..where((t) => t.id.equals(userId))).get();
      final profile = profileEntries.first;

      logTestResult('preferred_distance_unit', profile.preferredDistanceUnit);
      logTestResult('preferred_pace_unit', profile.preferredPaceUnit);

      logAssertion(
        'Distance unit updated to kilometers',
        passed: profile.preferredDistanceUnit == 'kilometers',
        reason: 'System should support metric units',
      );

      logAssertion(
        'Pace unit updated to minPerKm',
        passed: profile.preferredPaceUnit == 'minPerKm',
        reason: 'Pace unit should match distance unit',
      );

      expect(profile.preferredDistanceUnit, equals('kilometers'));
      expect(profile.preferredPaceUnit, equals('minPerKm'));

      logTestPass('Unit preferences updated successfully');
    });

    test('calendar preferences are saved', () async {
      logTestHeading('Settings - Calendar Preferences');

      final userId = 'test-calendar-user';
      final deviceId = 'device-calendar-123';

      // Create user with default calendar settings
      await database
          .into(database.userProfilesTable)
          .insert(
            UserProfilesTableCompanion.insert(
              id: userId,
              deviceId: deviceId,
              authUserId: const Value(null),
              authProvider: const Value('anonymous'),
              isAnonymous: const Value(true),
              gender: const Value('other'),
              birthday: Value(DateTime(1991, 9, 8)),
              heightFeet: const Value(5),
              heightInches: const Value(8),
              weightPounds: const Value(155.0),
              runsWithWaterBottle: const Value(true),
              gutTrainingLevel: const Value('low'),
              onboardingCompleted: const Value(true),
              calendarWeekStart: const Value('monday'),
              defaultActivityDay: const Value('saturday'),
              defaultActivityTime: const Value('07:00:00'),
              autoGenerateNutrition: const Value(true),
              completionReminders: const Value(true),
              appVersion: const Value('1.0.0'),
              createdAt: Value(DateTime.now()),
              updatedAt: Value(DateTime.now()),
            ),
          );

      logTestSetup({
        'user_id': userId,
        'initial_week_start': 'monday',
        'updated_week_start': 'sunday',
        'initial_activity_day': 'saturday',
        'updated_activity_day': 'friday',
      });

      logSection('Updating calendar preferences');

      // Update calendar settings
      await (database.update(
        database.userProfilesTable,
      )..where((t) => t.id.equals(userId))).write(
        UserProfilesTableCompanion(
          calendarWeekStart: const Value('sunday'),
          defaultActivityDay: const Value('friday'),
          defaultActivityTime: const Value('06:00:00'),
          autoGenerateNutrition: const Value(false),
          updatedAt: Value(DateTime.now()),
        ),
      );

      final profileEntries = await (database.select(
        database.userProfilesTable,
      )..where((t) => t.id.equals(userId))).get();
      final profile = profileEntries.first;

      logTestResult('calendar_week_start', profile.calendarWeekStart);
      logTestResult('default_activity_day', profile.defaultActivityDay);
      logTestResult('default_activity_time', profile.defaultActivityTime);
      logTestResult('auto_generate_nutrition', profile.autoGenerateNutrition);

      logAssertion(
        'Week start updated to sunday',
        passed: profile.calendarWeekStart == 'sunday',
        reason: 'Calendar week start should be customizable',
      );

      logAssertion(
        'Default activity day updated to friday',
        passed: profile.defaultActivityDay == 'friday',
        reason: 'Default activity day should be customizable',
      );

      logAssertion(
        'Auto-generate nutrition disabled',
        passed: profile.autoGenerateNutrition == false,
        reason: 'Auto-generation should be toggleable',
      );

      expect(profile.calendarWeekStart, equals('sunday'));
      expect(profile.defaultActivityDay, equals('friday'));
      expect(profile.defaultActivityTime, equals('06:00:00'));
      expect(profile.autoGenerateNutrition, isFalse);

      logTestPass('Calendar preferences updated successfully');
    });

    test('notification preferences can be configured', () async {
      logTestHeading('Settings - Notification Preferences');

      final userId = 'test-notif-user';
      final deviceId = 'device-notif-123';

      // Create user with default notification settings
      await database
          .into(database.userProfilesTable)
          .insert(
            UserProfilesTableCompanion.insert(
              id: userId,
              deviceId: deviceId,
              authUserId: const Value(null),
              authProvider: const Value('anonymous'),
              isAnonymous: const Value(true),
              gender: const Value('female'),
              birthday: Value(DateTime(1993, 12, 3)),
              heightFeet: const Value(5),
              heightInches: const Value(4),
              weightPounds: const Value(130.0),
              runsWithWaterBottle: const Value(false),
              gutTrainingLevel: const Value('moderate'),
              onboardingCompleted: const Value(true),
              notificationsEnabled: const Value(false),
              defaultReminderDay: const Value(4), // Thursday
              defaultReminderHour: const Value(17), // 5 PM
              defaultReminderMinute: const Value(0),
              defaultReminderRecurring: const Value(false),
              appVersion: const Value('1.0.0'),
              createdAt: Value(DateTime.now()),
              updatedAt: Value(DateTime.now()),
            ),
          );

      logTestSetup({
        'user_id': userId,
        'initial_notifications_enabled': false,
        'updated_notifications_enabled': true,
        'reminder_day': 'Friday (5)',
        'reminder_time': '18:30',
      });

      logSection('Enabling notifications with custom reminder');

      // Enable notifications and set custom reminder
      await (database.update(
        database.userProfilesTable,
      )..where((t) => t.id.equals(userId))).write(
        UserProfilesTableCompanion(
          notificationsEnabled: const Value(true),
          defaultReminderDay: const Value(5), // Friday
          defaultReminderHour: const Value(18),
          defaultReminderMinute: const Value(30),
          defaultReminderRecurring: const Value(true),
          updatedAt: Value(DateTime.now()),
        ),
      );

      final profileEntries = await (database.select(
        database.userProfilesTable,
      )..where((t) => t.id.equals(userId))).get();
      final profile = profileEntries.first;

      logTestResult('notifications_enabled', profile.notificationsEnabled);
      logTestResult('default_reminder_day', profile.defaultReminderDay);
      logTestResult('default_reminder_hour', profile.defaultReminderHour);
      logTestResult('default_reminder_minute', profile.defaultReminderMinute);
      logTestResult(
        'default_reminder_recurring',
        profile.defaultReminderRecurring,
      );

      logAssertion(
        'Notifications enabled',
        passed: profile.notificationsEnabled == true,
        reason: 'Notifications should be toggleable',
      );

      logAssertion(
        'Reminder day set to Friday',
        passed: profile.defaultReminderDay == 5,
        reason: 'Reminder day should be customizable',
      );

      logAssertion(
        'Reminder time set correctly',
        passed:
            profile.defaultReminderHour == 18 &&
            profile.defaultReminderMinute == 30,
        reason: 'Reminder time should be customizable',
      );

      logAssertion(
        'Recurring reminders enabled',
        passed: profile.defaultReminderRecurring == true,
        reason: 'Recurring option should be configurable',
      );

      expect(profile.notificationsEnabled, isTrue);
      expect(profile.defaultReminderDay, equals(5));
      expect(profile.defaultReminderHour, equals(18));
      expect(profile.defaultReminderMinute, equals(30));
      expect(profile.defaultReminderRecurring, isTrue);

      logTestPass('Notification preferences updated successfully');
    });

    test('multiple settings can be updated atomically', () async {
      logTestHeading('Settings - Atomic Multi-Setting Update');

      final userId = 'test-atomic-user';
      final deviceId = 'device-atomic-123';

      // Create user
      await database
          .into(database.userProfilesTable)
          .insert(
            UserProfilesTableCompanion.insert(
              id: userId,
              deviceId: deviceId,
              authUserId: const Value(null),
              authProvider: const Value('anonymous'),
              isAnonymous: const Value(true),
              gender: const Value('male'),
              birthday: Value(DateTime(1987, 7, 22)),
              heightFeet: const Value(6),
              heightInches: const Value(1),
              weightPounds: const Value(185.0),
              runsWithWaterBottle: const Value(false),
              gutTrainingLevel: const Value('low'),
              onboardingCompleted: const Value(true),
              preferredDistanceUnit: const Value('miles'),
              notificationsEnabled: const Value(false),
              appVersion: const Value('1.0.0'),
              createdAt: Value(DateTime.now()),
              updatedAt: Value(DateTime.now()),
            ),
          );

      logTestSetup({
        'user_id': userId,
        'updates': 'weight, gut_training, distance_unit, notifications',
      });

      logSection('Performing atomic update of multiple settings');

      // Update multiple settings in one transaction
      await (database.update(
        database.userProfilesTable,
      )..where((t) => t.id.equals(userId))).write(
        UserProfilesTableCompanion(
          weightPounds: const Value(180.0),
          gutTrainingLevel: const Value('moderate'),
          preferredDistanceUnit: const Value('kilometers'),
          preferredPaceUnit: const Value('minPerKm'),
          notificationsEnabled: const Value(true),
          runsWithWaterBottle: const Value(true),
          updatedAt: Value(DateTime.now()),
        ),
      );

      final profileEntries = await (database.select(
        database.userProfilesTable,
      )..where((t) => t.id.equals(userId))).get();
      final profile = profileEntries.first;

      logTestResult('weight_pounds', profile.weightPounds);
      logTestResult('gut_training_level', profile.gutTrainingLevel);
      logTestResult('preferred_distance_unit', profile.preferredDistanceUnit);
      logTestResult('notifications_enabled', profile.notificationsEnabled);
      logTestResult('runs_with_water_bottle', profile.runsWithWaterBottle);

      logAssertion(
        'All settings updated',
        passed:
            profile.weightPounds == 180.0 &&
            profile.gutTrainingLevel == 'moderate' &&
            profile.preferredDistanceUnit == 'kilometers' &&
            profile.notificationsEnabled == true &&
            profile.runsWithWaterBottle == true,
        reason: 'Multiple settings should update atomically',
      );

      expect(profile.weightPounds, equals(180.0));
      expect(profile.gutTrainingLevel, equals('moderate'));
      expect(profile.preferredDistanceUnit, equals('kilometers'));
      expect(profile.preferredPaceUnit, equals('minPerKm'));
      expect(profile.notificationsEnabled, isTrue);
      expect(profile.runsWithWaterBottle, isTrue);

      logTestPass('Atomic multi-setting update verified');
    });
  });
}
