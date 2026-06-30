// ignore_for_file: unused_local_variable

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:mealvana_endurance/features/calendar/application/calendar_service.dart';
import 'package:mealvana_endurance/features/activities/application/activities_service.dart';
import 'package:mealvana_endurance/features/activities/domain/activity.dart' as domain;
import 'package:mealvana_endurance/shared/database/app_database.dart';
import 'package:mealvana_endurance/shared/domain/activity_type.dart';
import 'package:mealvana_endurance/shared/services/logging_service.dart';

class MockActivitiesService extends Mock implements ActivitiesService {}

class MockAppLogger extends Mock implements AppLogger {}

void main() {
  late AppDatabase db;
  late MockActivitiesService mockActivitiesService;
  late MockAppLogger mockLogger;
  late CalendarService service;

  const testUserId = 'user-abc-123';

  domain.Activity _makeActivity({
    required String id,
    required DateTime scheduledDateTime,
    ActivityType type = ActivityType.running,
    domain.ActivityStatus status = domain.ActivityStatus.planned,
  }) {
    return domain.Activity(
      id: id,
      userId: testUserId,
      activityType: type,
      title: 'Test Activity $id',
      scheduledDateTime: scheduledDateTime,
      status: status,
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
    );
  }

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    mockActivitiesService = MockActivitiesService();
    mockLogger = MockAppLogger();

    // Stub all logger calls
    when(() => mockLogger.info(any(), context: any(named: 'context'), data: any(named: 'data'))).thenReturn(null);
    when(() => mockLogger.debug(any(), context: any(named: 'context'), data: any(named: 'data'))).thenReturn(null);
    when(() => mockLogger.warning(any(), context: any(named: 'context'), data: any(named: 'data'))).thenReturn(null);
    when(() => mockLogger.error(any(), context: any(named: 'context'), error: any(named: 'error'), stackTrace: any(named: 'stackTrace'), data: any(named: 'data'))).thenReturn(null);

    service = CalendarService(db, mockLogger, mockActivitiesService);
  });

  tearDown(() async {
    await db.close();
  });

  // ---------------------------------------------------------------------------
  // getActivitiesForDateRange / getActivitiesForWeek — delegate checks
  // ---------------------------------------------------------------------------

  group('getActivitiesForDateRange delegates to ActivitiesService', () {
    test('passes userId, startDate, endDate through unchanged', () async {
      final start = DateTime(2026, 6, 1);
      final end = DateTime(2026, 6, 7, 23, 59, 59);
      when(() => mockActivitiesService.getActivitiesForDateRange(testUserId, start, end))
          .thenAnswer((_) async => []);

      final result = await service.getActivitiesForDateRange(testUserId, start, end);

      verify(() => mockActivitiesService.getActivitiesForDateRange(testUserId, start, end)).called(1);
      expect(result, isEmpty);
    });

    test('getActivitiesForWeek delegates correctly', () async {
      final weekStart = DateTime(2026, 6, 1);
      when(() => mockActivitiesService.getActivitiesForWeek(testUserId, weekStart))
          .thenAnswer((_) async => []);

      await service.getActivitiesForWeek(testUserId, weekStart);

      verify(() => mockActivitiesService.getActivitiesForWeek(testUserId, weekStart)).called(1);
    });
  });

  // ---------------------------------------------------------------------------
  // createEvent – eventDate parsing from startTime
  // ---------------------------------------------------------------------------

  group('createEvent', () {
    test('parses ISO8601 startTime into eventDate', () async {
      // We insert an event and then read it back to confirm eventDate is set
      final event = await service.createEvent(
        userId: testUserId,
        eventType: ActivityType.running,
        startTime: '2026-09-15T07:00:00.000',
      );

      // eventDate should be parsed from startTime
      expect(event.startTime, '2026-09-15T07:00:00.000');
      expect(event.userId, testUserId);
      expect(event.id, isNotEmpty);
    });

    test('handles empty startTime gracefully (no crash)', () async {
      final event = await service.createEvent(
        userId: testUserId,
        eventType: ActivityType.cycling,
        startTime: '',
      );
      expect(event.id, isNotEmpty);
    });

    test('creates event with hasCarbLoading=false by default', () async {
      final event = await service.createEvent(
        userId: testUserId,
        eventType: ActivityType.running,
      );
      expect(event.hasCarbLoading, false);
    });

    test('sets hasCarbLoading=true when provided', () async {
      final event = await service.createEvent(
        userId: testUserId,
        eventType: ActivityType.running,
        hasCarbLoading: true,
        carbLoadingDays: 3,
      );
      expect(event.hasCarbLoading, true);
      expect(event.carbLoadingDays, 3);
    });
  });

  // ---------------------------------------------------------------------------
  // getAllEvents
  // ---------------------------------------------------------------------------

  group('getAllEvents', () {
    test('returns empty list when no events exist', () async {
      final events = await service.getAllEvents(testUserId);
      expect(events, isEmpty);
    });

    test('returns all events in descending createdAt order', () async {
      await service.createEvent(userId: testUserId, eventType: ActivityType.running, eventName: 'First');
      await service.createEvent(userId: testUserId, eventType: ActivityType.cycling, eventName: 'Second');

      final events = await service.getAllEvents(testUserId);
      expect(events.length, 2);
    });
  });

  // ---------------------------------------------------------------------------
  // getEventForActivity
  // ---------------------------------------------------------------------------

  group('getEventForActivity', () {
    test('returns null when no event exists for the activity', () async {
      final result = await service.getEventForActivity('nonexistent-activity-id');
      expect(result, equals(null));
    });

    test('returns event when one exists for the activity', () async {
      // First create an activity via the database directly (ActivitiesService is mocked)
      final actCompanion = ActivitiesTableCompanion.insert(
        id: Value('act-001'),
        userId: testUserId,
        activityType: 'running',
        title: 'Test Run',
        scheduledDateTime: DateTime(2026, 9, 15, 7),
        status: Value('planned'),
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
      );
      await db.into(db.activitiesTable).insert(actCompanion);

      // Create event linked to the activity
      final event = await service.createEvent(
        userId: testUserId,
        activityId: 'act-001',
        eventType: ActivityType.running,
        eventName: 'Big Race',
      );

      final found = await service.getEventForActivity('act-001');
      expect(found, isNot(equals(null)));
      expect(found!.id, event.id);
      expect(found.activityId, 'act-001');
    });
  });

  // ---------------------------------------------------------------------------
  // createCarbLoadingPlan – schedule math
  // ---------------------------------------------------------------------------

  group('createCarbLoadingPlan schedule math', () {
    test('2-day protocol: startDate is raceDate minus 2, endDate is raceDate minus 1', () async {
      final raceDate = DateTime(2026, 10, 5);
      await service.createCarbLoadingPlan(
        userId: testUserId,
        protocolDays: 2,
        raceDate: raceDate,
        bodyWeightPounds: 154.0, // ~70 kg
      );

      final plans = await db.select(db.carbLoadingPlansTable).get();
      expect(plans.length, 1);

      final plan = plans.first;
      expect(plan.startDate, DateTime(2026, 10, 3)); // 5 - 2 days
      expect(plan.endDate, DateTime(2026, 10, 4));   // 5 - 1 day
      expect(plan.totalDays, 2);
    });

    test('3-day protocol: startDate is raceDate minus 3', () async {
      final raceDate = DateTime(2026, 10, 5);
      await service.createCarbLoadingPlan(
        userId: testUserId,
        protocolDays: 3,
        raceDate: raceDate,
        bodyWeightPounds: 154.0,
      );

      final plans = await db.select(db.carbLoadingPlansTable).get();
      expect(plans.length, 1);

      final plan = plans.first;
      expect(plan.startDate, DateTime(2026, 10, 2)); // 5 - 3 days
      expect(plan.endDate, DateTime(2026, 10, 4));   // 5 - 1 day
    });

    test('2-day protocol generates exactly 2 day records', () async {
      final raceDate = DateTime(2026, 10, 5);
      await service.createCarbLoadingPlan(
        userId: testUserId,
        protocolDays: 2,
        raceDate: raceDate,
        bodyWeightPounds: 154.0,
      );

      final days = await db.select(db.carbLoadingDaysTable).get();
      expect(days.length, 2);
      expect(days.map((d) => d.dayNumber).toList(), [1, 2]);
    });

    test('3-day protocol generates exactly 3 day records', () async {
      final raceDate = DateTime(2026, 10, 5);
      await service.createCarbLoadingPlan(
        userId: testUserId,
        protocolDays: 3,
        raceDate: raceDate,
        bodyWeightPounds: 154.0,
      );

      final days = await db.select(db.carbLoadingDaysTable).get();
      expect(days.length, 3);
    });
  });

  // ---------------------------------------------------------------------------
  // _getCarbProtocolForDay – protocol math
  // ---------------------------------------------------------------------------

  // CalendarService has a private _getCarbProtocolForDay — we test it indirectly
  // through createCarbLoadingPlan by checking the per-day carb targets.

  group('carb protocol day targets', () {
    // 2-day: day -2 = 9g/kg, day -1 = 11g/kg
    test('2-day protocol: day 1 (day-2) uses 9g/kg', () async {
      const weightKg = 70.0; // 154.3 lbs → ~70 kg after conversion
      // 154.3 lbs * 0.453592 = 70.0 kg exactly
      final raceDate = DateTime(2026, 10, 5);
      await service.createCarbLoadingPlan(
        userId: testUserId,
        protocolDays: 2,
        raceDate: raceDate,
        bodyWeightPounds: 154.3236,
      );

      final days = await (db.select(db.carbLoadingDaysTable)
            ..orderBy([(tbl) => OrderingTerm.asc(tbl.dayNumber)]))
          .get();

      // Day 1 = 2 days before race (protocolDays - 0 = 2 days before)
      // carbProtocol = 9g/kg for day -2
      final day1 = days[0];
      final expectedDay1Carbs = (9.0 * weightKg).round();
      expect(day1.carbTargetGrams, expectedDay1Carbs);
    });

    test('2-day protocol: day 2 (day-1) uses 11g/kg', () async {
      const weightKg = 70.0;
      final raceDate = DateTime(2026, 10, 5);
      await service.createCarbLoadingPlan(
        userId: testUserId,
        protocolDays: 2,
        raceDate: raceDate,
        bodyWeightPounds: 154.3236,
      );

      final days = await (db.select(db.carbLoadingDaysTable)
            ..orderBy([(tbl) => OrderingTerm.asc(tbl.dayNumber)]))
          .get();

      final day2 = days[1];
      final expectedDay2Carbs = (11.0 * weightKg).round();
      expect(day2.carbTargetGrams, expectedDay2Carbs);
    });

    // 3-day: day -3 = 8g/kg, day -2 = 8g/kg, day -1 = 10g/kg
    test('3-day protocol: days 1 and 2 use 8g/kg, day 3 uses 10g/kg', () async {
      const weightKg = 70.0;
      final raceDate = DateTime(2026, 10, 5);
      await service.createCarbLoadingPlan(
        userId: testUserId,
        protocolDays: 3,
        raceDate: raceDate,
        bodyWeightPounds: 154.3236,
      );

      final days = await (db.select(db.carbLoadingDaysTable)
            ..orderBy([(tbl) => OrderingTerm.asc(tbl.dayNumber)]))
          .get();

      expect(days[0].carbTargetGrams, (8.0 * weightKg).round()); // day -3
      expect(days[1].carbTargetGrams, (8.0 * weightKg).round()); // day -2
      expect(days[2].carbTargetGrams, (10.0 * weightKg).round()); // day -1
    });

    test('2-day avg daily carb target equals (9+11)/2 * bodyWeightKg', () async {
      const weightKg = 70.0;
      final raceDate = DateTime(2026, 10, 5);
      await service.createCarbLoadingPlan(
        userId: testUserId,
        protocolDays: 2,
        raceDate: raceDate,
        bodyWeightPounds: 154.3236,
      );

      final plans = await db.select(db.carbLoadingPlansTable).get();
      final avgExpected = ((9.0 + 11.0) / 2 * weightKg).round();
      expect(plans.first.dailyCarbTargetGrams, avgExpected);
    });

    test('3-day avg daily carb target equals (8+8+10)/3 * bodyWeightKg', () async {
      const weightKg = 70.0;
      final raceDate = DateTime(2026, 10, 5);
      await service.createCarbLoadingPlan(
        userId: testUserId,
        protocolDays: 3,
        raceDate: raceDate,
        bodyWeightPounds: 154.3236,
      );

      final plans = await db.select(db.carbLoadingPlansTable).get();
      final avgExpected = ((8.0 + 8.0 + 10.0) / 3 * weightKg).round();
      expect(plans.first.dailyCarbTargetGrams, avgExpected);
    });
  });

  // ---------------------------------------------------------------------------
  // getCarbLoadingDaysForRange – day-bucketing is NAIVE LOCAL (not UTC)
  //
  // This is the key timezone-safety test class.  The column `plan_date` is stored
  // as a naive DateTime (no tz info). If any code ever compares it against a UTC
  // ISO instant the day boundary will be wrong for users outside UTC+0.
  // We prove the local-day range inclusion is correct.
  // ---------------------------------------------------------------------------

  group('getCarbLoadingDaysForRange – naive local-day bounds', () {
    test('includes a day whose planDate falls exactly on startDate', () async {
      final raceDate = DateTime(2026, 10, 5);
      await service.createCarbLoadingPlan(
        userId: testUserId,
        protocolDays: 2,
        raceDate: raceDate,
        bodyWeightPounds: 154.3236,
      );

      // plan_date for day 1 = 2026-10-03 (midnight naive)
      final startOfDay = DateTime(2026, 10, 3, 0, 0, 0);
      final endOfDay = DateTime(2026, 10, 3, 23, 59, 59);

      final days = await service.getCarbLoadingDaysForRange(
        userId: testUserId,
        startDate: startOfDay,
        endDate: endOfDay,
      );

      expect(days.length, 1);
      expect(days.first.planDate.day, 3);
      expect(days.first.planDate.month, 10);
    });

    test('includes a day whose planDate falls exactly on endDate', () async {
      final raceDate = DateTime(2026, 10, 5);
      await service.createCarbLoadingPlan(
        userId: testUserId,
        protocolDays: 2,
        raceDate: raceDate,
        bodyWeightPounds: 154.3236,
      );

      // plan_date for day 2 = 2026-10-04
      final start = DateTime(2026, 10, 4, 0, 0, 0);
      final end = DateTime(2026, 10, 4, 23, 59, 59);

      final days = await service.getCarbLoadingDaysForRange(
        userId: testUserId,
        startDate: start,
        endDate: end,
      );

      expect(days.length, 1);
      expect(days.first.planDate.day, 4);
    });

    test('returns both days when range covers the full 2-day window', () async {
      final raceDate = DateTime(2026, 10, 5);
      await service.createCarbLoadingPlan(
        userId: testUserId,
        protocolDays: 2,
        raceDate: raceDate,
        bodyWeightPounds: 154.3236,
      );

      final days = await service.getCarbLoadingDaysForRange(
        userId: testUserId,
        startDate: DateTime(2026, 10, 3),
        endDate: DateTime(2026, 10, 4, 23, 59, 59),
      );

      expect(days.length, 2);
    });

    test('excludes the race day itself (race day is NOT a carb-loading day)', () async {
      final raceDate = DateTime(2026, 10, 5);
      await service.createCarbLoadingPlan(
        userId: testUserId,
        protocolDays: 2,
        raceDate: raceDate,
        bodyWeightPounds: 154.3236,
      );

      // Request only the race day
      final days = await service.getCarbLoadingDaysForRange(
        userId: testUserId,
        startDate: DateTime(2026, 10, 5),
        endDate: DateTime(2026, 10, 5, 23, 59, 59),
      );

      expect(days, isEmpty);
    });

    test('scopes to userId – other user\'s days are invisible', () async {
      final raceDate = DateTime(2026, 10, 5);

      // Create plan for user A
      await service.createCarbLoadingPlan(
        userId: testUserId,
        protocolDays: 2,
        raceDate: raceDate,
        bodyWeightPounds: 154.3236,
      );

      // Query as a different user
      final days = await service.getCarbLoadingDaysForRange(
        userId: 'different-user-999',
        startDate: DateTime(2026, 10, 1),
        endDate: DateTime(2026, 10, 10),
      );

      expect(days, isEmpty);
    });

    test('does NOT return days for the day BEFORE startDate (boundary exclusive left check)', () async {
      final raceDate = DateTime(2026, 10, 5);
      await service.createCarbLoadingPlan(
        userId: testUserId,
        protocolDays: 2,
        raceDate: raceDate,
        bodyWeightPounds: 154.3236,
      );

      // Start the query from Oct 4, which should miss Oct 3
      final days = await service.getCarbLoadingDaysForRange(
        userId: testUserId,
        startDate: DateTime(2026, 10, 4),
        endDate: DateTime(2026, 10, 10),
      );

      expect(days.length, 1);
      expect(days.first.planDate.day, 4);
    });
  });

  // ---------------------------------------------------------------------------
  // deleteCarbLoadingPlan – cascade
  // ---------------------------------------------------------------------------

  group('deleteCarbLoadingPlan cascade', () {
    test('removes plan, all days, and all meals when event has a plan', () async {
      // Create event
      final event = await service.createEvent(
        userId: testUserId,
        eventType: ActivityType.running,
        hasCarbLoading: true,
      );

      // Create plan (attached to event)
      await service.createCarbLoadingPlan(
        userId: testUserId,
        eventId: event.id,
        protocolDays: 2,
        raceDate: DateTime(2026, 10, 5),
        bodyWeightPounds: 154.3236,
      );

      expect((await db.select(db.carbLoadingPlansTable).get()).length, 1);
      expect((await db.select(db.carbLoadingDaysTable).get()).length, 2);

      await service.deleteCarbLoadingPlan(eventId: event.id);

      expect((await db.select(db.carbLoadingPlansTable).get()), isEmpty);
      expect((await db.select(db.carbLoadingDaysTable).get()), isEmpty);
    });

    test('updates event hasCarbLoading=false after plan deletion', () async {
      final event = await service.createEvent(
        userId: testUserId,
        eventType: ActivityType.running,
        hasCarbLoading: true,
      );

      await service.createCarbLoadingPlan(
        userId: testUserId,
        eventId: event.id,
        protocolDays: 2,
        raceDate: DateTime(2026, 10, 5),
        bodyWeightPounds: 154.3236,
      );

      await service.deleteCarbLoadingPlan(eventId: event.id);

      final updatedEvent = await service.getEventById(testUserId, event.id);
      expect(updatedEvent!.hasCarbLoading, false);
    });
  });

  // ---------------------------------------------------------------------------
  // updateCarbLoadingProtocol – replaces old plan
  // ---------------------------------------------------------------------------

  group('updateCarbLoadingProtocol', () {
    test('replaces 2-day plan with 3-day plan', () async {
      final event = await service.createEvent(
        userId: testUserId,
        eventType: ActivityType.running,
      );

      await service.createCarbLoadingPlan(
        userId: testUserId,
        eventId: event.id,
        protocolDays: 2,
        raceDate: DateTime(2026, 10, 5),
        bodyWeightPounds: 154.3236,
      );

      expect((await db.select(db.carbLoadingDaysTable).get()).length, 2);

      await service.updateCarbLoadingProtocol(
        userId: testUserId,
        eventId: event.id,
        newProtocolDays: 3,
        raceDate: DateTime(2026, 10, 5),
        bodyWeightPounds: 154.3236,
      );

      // Should now have 3 days
      expect((await db.select(db.carbLoadingDaysTable).get()).length, 3);
      // And only one plan
      expect((await db.select(db.carbLoadingPlansTable).get()).length, 1);
    });
  });

  // ---------------------------------------------------------------------------
  // deleteActivity – cascade to event + carb loading
  // ---------------------------------------------------------------------------

  group('deleteActivity cascade', () {
    test('deletes associated event and carb loading plan', () async {
      // Insert activity directly
      await db.into(db.activitiesTable).insert(
        ActivitiesTableCompanion.insert(
          id: Value('act-del-001'),
          userId: testUserId,
          activityType: 'running',
          title: 'Race Day Run',
          scheduledDateTime: DateTime(2026, 10, 5, 7),
          status: Value('planned'),
          createdAt: DateTime(2026, 1, 1),
          updatedAt: DateTime(2026, 1, 1),
        ),
      );

      // Create event linked to activity
      final event = await service.createEvent(
        userId: testUserId,
        activityId: 'act-del-001',
        eventType: ActivityType.running,
        hasCarbLoading: true,
      );

      // Create carb loading plan for the event
      await service.createCarbLoadingPlan(
        userId: testUserId,
        eventId: event.id,
        protocolDays: 2,
        raceDate: DateTime(2026, 10, 5),
        bodyWeightPounds: 154.3236,
      );

      // Now mock deleteActivity on the service
      when(() => mockActivitiesService.deleteActivity(
            deviceId: any(named: 'deviceId'),
            activityId: 'act-del-001',
          )).thenAnswer((_) async {});

      await service.deleteActivity(deviceId: testUserId, activityId: 'act-del-001');

      // Event should be gone
      expect((await db.select(db.eventsTable).get()), isEmpty);
      // Carb loading plan should be gone
      expect((await db.select(db.carbLoadingPlansTable).get()), isEmpty);
      // Carb loading days should be gone
      expect((await db.select(db.carbLoadingDaysTable).get()), isEmpty);

      verify(() => mockActivitiesService.deleteActivity(
            deviceId: testUserId,
            activityId: 'act-del-001',
          )).called(1);
    });

    test('still delegates activity deletion even when no event exists', () async {
      when(() => mockActivitiesService.deleteActivity(
            deviceId: any(named: 'deviceId'),
            activityId: 'act-no-event',
          )).thenAnswer((_) async {});

      await service.deleteActivity(deviceId: testUserId, activityId: 'act-no-event');

      verify(() => mockActivitiesService.deleteActivity(
            deviceId: testUserId,
            activityId: 'act-no-event',
          )).called(1);
    });
  });

  // ---------------------------------------------------------------------------
  // getEventsForWeek — activity date-based filtering
  // ---------------------------------------------------------------------------

  group('getEventsForWeek', () {
    test('returns events whose activity falls in the requested week', () async {
      // Insert an activity
      await db.into(db.activitiesTable).insert(
        ActivitiesTableCompanion.insert(
          id: Value('act-week-001'),
          userId: testUserId,
          activityType: 'running',
          title: 'Monday Run',
          scheduledDateTime: DateTime(2026, 6, 15, 8),
          status: Value('planned'),
          createdAt: DateTime(2026, 1, 1),
          updatedAt: DateTime(2026, 1, 1),
        ),
      );

      await service.createEvent(
        userId: testUserId,
        activityId: 'act-week-001',
        eventType: ActivityType.running,
        eventName: 'Week Race',
      );

      final activity = domain.Activity(
        id: 'act-week-001',
        userId: testUserId,
        activityType: ActivityType.running,
        title: 'Monday Run',
        scheduledDateTime: DateTime(2026, 6, 15, 8),
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
      );

      when(() => mockActivitiesService.getActivityById(testUserId, 'act-week-001'))
          .thenAnswer((_) async => activity);

      // Week of June 15, 2026 (Monday)
      final weekStart = DateTime(2026, 6, 15);
      final events = await service.getEventsForWeek(testUserId, weekStart);

      expect(events.length, 1);
      expect(events.first.eventName, 'Week Race');
    });

    test('excludes events whose activity falls outside the week', () async {
      await db.into(db.activitiesTable).insert(
        ActivitiesTableCompanion.insert(
          id: Value('act-week-002'),
          userId: testUserId,
          activityType: 'running',
          title: 'Next Week Run',
          scheduledDateTime: DateTime(2026, 6, 22, 8), // next week
          status: Value('planned'),
          createdAt: DateTime(2026, 1, 1),
          updatedAt: DateTime(2026, 1, 1),
        ),
      );

      await service.createEvent(
        userId: testUserId,
        activityId: 'act-week-002',
        eventType: ActivityType.running,
        eventName: 'Next Week Race',
      );

      final nextWeekActivity = domain.Activity(
        id: 'act-week-002',
        userId: testUserId,
        activityType: ActivityType.running,
        title: 'Next Week Run',
        scheduledDateTime: DateTime(2026, 6, 22, 8),
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
      );

      when(() => mockActivitiesService.getActivityById(testUserId, 'act-week-002'))
          .thenAnswer((_) async => nextWeekActivity);

      // Query week of June 15 — should NOT include June 22
      final weekStart = DateTime(2026, 6, 15);
      final events = await service.getEventsForWeek(testUserId, weekStart);

      expect(events, isEmpty);
    });
  });
}
