/// Integration tests for Carb Loading event management
/// Tests event creation, carb loading calculations, and event retrieval
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;

import 'package:mealvana_endurance/shared/database/app_database.dart';
import 'package:mealvana_endurance/shared/database/database_provider.dart';
import 'package:mealvana_endurance/shared/services/analytics/analytics_tracker.dart';
import 'package:mealvana_endurance/shared/services/sentry/sentry_reporter.dart';
import 'package:mealvana_endurance/shared/services/logging_service.dart';

import '../helpers/fakes/recording_analytics_tracker.dart';
import '../helpers/fakes/recording_sentry_reporter.dart';
import '../helpers/fakes/recording_app_logger.dart';
import '../helpers/utils/console_logging.dart';

void main() {
  group('Carb Loading Event Tests', () {
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

    test('events can be created with basic information', () async {
      logTestHeading('Carb Loading - Create Event');

      final userId = 'test-event-user';
      final deviceId = 'device-event-123';

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
              birthday: Value(DateTime(1988, 5, 10)),
              heightFeet: const Value(5),
              heightInches: const Value(11),
              weightPounds: const Value(170.0),
              runsWithWaterBottle: const Value(false),
              gutTrainingLevel: const Value('moderate'),
              onboardingCompleted: const Value(true),
              appVersion: const Value('1.0.0'),
              createdAt: Value(DateTime.now()),
              updatedAt: Value(DateTime.now()),
            ),
          );

      final eventDate = DateTime.now().add(const Duration(days: 30));

      logTestSetup({
        'user_id': userId,
        'event_type': 'running',
        'event_subtype': 'marathon',
        'event_date': eventDate.toIso8601String().split('T')[0],
      });

      // Insert event
      await database
          .into(database.eventsTable)
          .insert(
            EventsTableCompanion.insert(
              userId: userId,
              eventType: 'running',
              eventSubtype: const Value('marathon'),
              eventName: const Value('Chicago Marathon'),
              location: const Value('Chicago, IL'),
              eventDate: Value(eventDate),
              goalTimeMinutes: const Value(240), // 4 hours
              goalPaceMinutesPerMile: const Value(9.09),
              hasCarbLoading: const Value(false),
              hasNutritionPlan: const Value(
                false,
              ), // OBSOLETE: kept for test compatibility
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
            ),
          );

      logSection('Verifying event in database');

      final events = await (database.select(
        database.eventsTable,
      )..where((t) => t.userId.equals(userId))).get();

      logTestResult('event_count', events.length);
      logTestResult('event_type', events.first.eventType);
      logTestResult('event_subtype', events.first.eventSubtype);
      logTestResult('event_name', events.first.eventName);
      logTestResult('goal_time_minutes', events.first.goalTimeMinutes);

      logAssertion(
        'Event created',
        passed: events.isNotEmpty,
        reason: 'Event should be saved to database',
      );

      logAssertion(
        'Event type is running',
        passed: events.first.eventType == 'running',
        reason: 'Event type should match input',
      );

      logAssertion(
        'Event subtype is marathon',
        passed: events.first.eventSubtype == 'marathon',
        reason: 'Event subtype should be stored',
      );

      expect(events.length, equals(1));
      expect(events.first.eventType, equals('running'));
      expect(events.first.eventSubtype, equals('marathon'));
      expect(events.first.eventName, equals('Chicago Marathon'));
      expect(events.first.goalTimeMinutes, equals(240));

      logTestPass('Event created successfully');
    });

    test('events have proper carb loading date calculations', () async {
      logTestHeading('Carb Loading - Date Calculations');

      final userId = 'test-carb-calc-user';
      final deviceId = 'device-carb-calc-123';

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
              gender: const Value('female'),
              birthday: Value(DateTime(1990, 8, 15)),
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

      final eventDate = DateTime(2025, 4, 15, 7, 0, 0); // Race day at 7 AM

      logTestSetup({
        'user_id': userId,
        'event_date': eventDate.toIso8601String(),
        'carb_loading_days': 3,
      });

      logSection('Calculating carb loading start date');

      // Calculate carb loading start date (3 days before event)
      final carbLoadingStartDate = eventDate.subtract(const Duration(days: 3));

      logTestResult('event_date', eventDate.toIso8601String().split('T')[0]);
      logTestResult(
        'carb_loading_start',
        carbLoadingStartDate.toIso8601String().split('T')[0],
      );

      // Insert event with carb loading
      await database
          .into(database.eventsTable)
          .insert(
            EventsTableCompanion.insert(
              userId: userId,
              eventType: 'running',
              eventSubtype: const Value('half_marathon'),
              eventName: const Value('Spring Half Marathon'),
              eventDate: Value(eventDate),
              hasCarbLoading: const Value(true),
              carbLoadingDays: const Value(3),
              carbLoadingStartDate: Value(carbLoadingStartDate),
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
            ),
          );

      logSection('Verifying carb loading dates');

      final event = await (database.select(
        database.eventsTable,
      )..where((t) => t.userId.equals(userId))).getSingle();

      logTestResult('has_carb_loading', event.hasCarbLoading);
      logTestResult('carb_loading_days', event.carbLoadingDays);
      logTestResult(
        'carb_loading_start_date',
        event.carbLoadingStartDate?.toIso8601String().split('T')[0],
      );

      final daysBeforeEvent = eventDate
          .difference(event.carbLoadingStartDate!)
          .inDays;

      logTestResult('days_before_event', daysBeforeEvent);

      logAssertion(
        'Carb loading enabled',
        passed: event.hasCarbLoading == true,
        reason: 'Carb loading flag should be set',
      );

      logAssertion(
        'Carb loading duration is 3 days',
        passed: event.carbLoadingDays == 3,
        reason: 'Carb loading duration should match input',
      );

      logAssertion(
        'Start date is 3 days before event',
        passed: daysBeforeEvent == 3,
        reason: 'Start date should be calculated correctly',
      );

      expect(event.hasCarbLoading, isTrue);
      expect(event.carbLoadingDays, equals(3));
      expect(daysBeforeEvent, equals(3));

      logTestPass('Carb loading date calculations verified');
    });

    test('events can be retrieved for upcoming races', () async {
      logTestHeading('Carb Loading - Retrieve Upcoming Events');

      final userId = 'test-upcoming-user';
      final deviceId = 'device-upcoming-123';

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
              birthday: Value(DateTime(1985, 3, 20)),
              heightFeet: const Value(6),
              heightInches: const Value(0),
              weightPounds: const Value(175.0),
              runsWithWaterBottle: const Value(false),
              gutTrainingLevel: const Value('moderate'),
              onboardingCompleted: const Value(true),
              appVersion: const Value('1.0.0'),
              createdAt: Value(DateTime.now()),
              updatedAt: Value(DateTime.now()),
            ),
          );

      final today = DateTime.now();
      final futureEvent1 = today.add(const Duration(days: 14));
      final futureEvent2 = today.add(const Duration(days: 45));
      final pastEvent = today.subtract(const Duration(days: 7));

      logTestSetup({'user_id': userId, 'future_events': 2, 'past_events': 1});

      // Insert multiple events
      await database.batch((batch) {
        batch.insert(
          database.eventsTable,
          EventsTableCompanion.insert(
            userId: userId,
            eventType: 'running',
            eventSubtype: const Value('10k'),
            eventName: const Value('Spring 10K'),
            eventDate: Value(futureEvent1),
            hasCarbLoading: const Value(false),
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        );
        batch.insert(
          database.eventsTable,
          EventsTableCompanion.insert(
            userId: userId,
            eventType: 'running',
            eventSubtype: const Value('marathon'),
            eventName: const Value('Boston Marathon'),
            eventDate: Value(futureEvent2),
            hasCarbLoading: const Value(true),
            carbLoadingDays: const Value(3),
            hasNutritionPlan: const Value(
              false,
            ), // OBSOLETE: kept for test compatibility
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        );
        batch.insert(
          database.eventsTable,
          EventsTableCompanion.insert(
            userId: userId,
            eventType: 'running',
            eventSubtype: const Value('5k'),
            eventName: const Value('Past 5K'),
            eventDate: Value(pastEvent),
            hasCarbLoading: const Value(false),
            hasNutritionPlan: const Value(false),
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        );
      });

      logSection('Querying upcoming events');

      // Query only future events
      final upcomingEvents =
          await (database.select(database.eventsTable)
                ..where(
                  (t) =>
                      t.userId.equals(userId) &
                      t.eventDate.isBiggerOrEqualValue(today),
                )
                ..orderBy([(t) => OrderingTerm(expression: t.eventDate)]))
              .get();

      logTestResult('upcoming_event_count', upcomingEvents.length);
      if (upcomingEvents.isNotEmpty) {
        logTestResult('first_event', upcomingEvents.first.eventName);
        logTestResult(
          'first_event_days_away',
          upcomingEvents.first.eventDate!.difference(today).inDays,
        );
      }

      logAssertion(
        'Two upcoming events',
        passed: upcomingEvents.length == 2,
        reason: 'Should retrieve only future events',
      );

      logAssertion(
        'Events sorted by date',
        passed:
            upcomingEvents.length >= 2 &&
            upcomingEvents[0].eventDate!.isBefore(upcomingEvents[1].eventDate!),
        reason: 'Events should be ordered by date ascending',
      );

      expect(upcomingEvents.length, equals(2));
      expect(
        upcomingEvents.map((e) => e.eventName).toList(),
        containsAll(['Spring 10K', 'Boston Marathon']),
      );

      logTestPass('Upcoming events retrieved successfully');
    });

    test('event supports multiple carb loading durations', () async {
      logTestHeading('Carb Loading - Multiple Durations');

      final userId = 'test-duration-user';
      final deviceId = 'device-duration-123';

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
              gender: const Value('female'),
              birthday: Value(DateTime(1992, 11, 5)),
              heightFeet: const Value(5),
              heightInches: const Value(4),
              weightPounds: const Value(132.0),
              runsWithWaterBottle: const Value(true),
              gutTrainingLevel: const Value('moderate'),
              onboardingCompleted: const Value(true),
              appVersion: const Value('1.0.0'),
              createdAt: Value(DateTime.now()),
              updatedAt: Value(DateTime.now()),
            ),
          );

      final eventDate = DateTime.now().add(const Duration(days: 60));

      logTestSetup({'user_id': userId, 'valid_durations': '1, 2, 3, 7 days'});

      // Test 1-day carb loading
      await database
          .into(database.eventsTable)
          .insert(
            EventsTableCompanion.insert(
              userId: userId,
              eventType: 'running',
              eventSubtype: const Value('half_marathon'),
              eventName: const Value('1-Day Carb Load Event'),
              eventDate: Value(eventDate),
              hasCarbLoading: const Value(true),
              carbLoadingDays: const Value(1),
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
            ),
          );

      // Test 7-day carb loading
      await database
          .into(database.eventsTable)
          .insert(
            EventsTableCompanion.insert(
              userId: userId,
              eventType: 'running',
              eventSubtype: const Value('ultra_50k'),
              eventName: const Value('7-Day Carb Load Event'),
              eventDate: Value(eventDate.add(const Duration(days: 7))),
              hasCarbLoading: const Value(true),
              carbLoadingDays: const Value(7),
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
            ),
          );

      logSection('Verifying carb loading durations');

      final events = await (database.select(
        database.eventsTable,
      )..where((t) => t.userId.equals(userId))).get();

      final event1Day = events.firstWhere((e) => e.carbLoadingDays == 1);
      final event7Day = events.firstWhere((e) => e.carbLoadingDays == 7);

      logTestResult('1_day_carb_loading', event1Day.carbLoadingDays);
      logTestResult('7_day_carb_loading', event7Day.carbLoadingDays);

      logAssertion(
        '1-day duration supported',
        passed: event1Day.carbLoadingDays == 1,
        reason: 'System should support 1-day carb loading',
      );

      logAssertion(
        '7-day duration supported',
        passed: event7Day.carbLoadingDays == 7,
        reason: 'System should support 7-day carb loading',
      );

      expect(event1Day.carbLoadingDays, equals(1));
      expect(event7Day.carbLoadingDays, equals(7));

      logTestPass('Multiple carb loading durations verified');
    });

    test('events can store goal times and predicted finish times', () async {
      logTestHeading('Carb Loading - Goal and Predicted Times');

      final userId = 'test-times-user';
      final deviceId = 'device-times-123';

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
              birthday: Value(DateTime(1987, 6, 30)),
              heightFeet: const Value(5),
              heightInches: const Value(10),
              weightPounds: const Value(168.0),
              runsWithWaterBottle: const Value(false),
              gutTrainingLevel: const Value('high'),
              onboardingCompleted: const Value(true),
              appVersion: const Value('1.0.0'),
              createdAt: Value(DateTime.now()),
              updatedAt: Value(DateTime.now()),
            ),
          );

      final eventDate = DateTime.now().add(const Duration(days: 90));

      logTestSetup({
        'user_id': userId,
        'goal_time': '3:30:00 (210 minutes)',
        'predicted_time': '3:45:00 (225 minutes)',
        'goal_pace': '8:00 min/mile',
      });

      // Insert event with time goals
      await database
          .into(database.eventsTable)
          .insert(
            EventsTableCompanion.insert(
              userId: userId,
              eventType: 'running',
              eventSubtype: const Value('marathon'),
              eventName: const Value('Target Time Marathon'),
              eventDate: Value(eventDate),
              goalTimeMinutes: const Value(210), // 3:30:00
              goalPaceMinutesPerMile: const Value(8.0),
              predictedFinishTimeMinutes: const Value(
                225,
              ), // 3:45:00 (realistic)
              hasCarbLoading: const Value(true),
              carbLoadingDays: const Value(3),
              hasNutritionPlan: const Value(true),
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
            ),
          );

      logSection('Verifying time goals');

      final event = await (database.select(
        database.eventsTable,
      )..where((t) => t.userId.equals(userId))).getSingle();

      logTestResult('goal_time_minutes', event.goalTimeMinutes);
      logTestResult('goal_pace_min_per_mile', event.goalPaceMinutesPerMile);
      logTestResult(
        'predicted_finish_minutes',
        event.predictedFinishTimeMinutes,
      );

      final goalHours = event.goalTimeMinutes! ~/ 60;
      final goalMinutes = event.goalTimeMinutes! % 60;
      final predictedHours = event.predictedFinishTimeMinutes! ~/ 60;
      final predictedMinutes = event.predictedFinishTimeMinutes! % 60;

      logTestResult(
        'goal_time_formatted',
        '$goalHours:${goalMinutes.toString().padLeft(2, '0')}',
      );
      logTestResult(
        'predicted_time_formatted',
        '$predictedHours:${predictedMinutes.toString().padLeft(2, '0')}',
      );

      logAssertion(
        'Goal time stored',
        passed: event.goalTimeMinutes == 210,
        reason: 'Goal time should be stored in minutes',
      );

      logAssertion(
        'Predicted time stored',
        passed: event.predictedFinishTimeMinutes == 225,
        reason: 'Predicted finish time should be stored',
      );

      logAssertion(
        'Goal pace stored',
        passed: event.goalPaceMinutesPerMile == 8.0,
        reason: 'Target pace should be stored',
      );

      expect(event.goalTimeMinutes, equals(210));
      expect(event.goalPaceMinutesPerMile, equals(8.0));
      expect(event.predictedFinishTimeMinutes, equals(225));

      logTestPass('Time goals stored successfully');
    });
  });
}
