// Claudia bug (2026-09-10): editing an event's date was accepted but not saved —
// the calendar kept the old date. Root cause: EventsService.updateEvent passed
// the stale event.eventDate straight through, while createEvent derived it from
// startTime. Both now derive via eventDateFromStartTime, so an edited date
// actually persists.
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:mealvana_endurance/features/activities/application/activities_service.dart';
import 'package:mealvana_endurance/features/coach_mode/data/coach_repository.dart';
import 'package:mealvana_endurance/features/events/application/events_service.dart';
import 'package:mealvana_endurance/features/events/data/events_repository.dart';
import 'package:mealvana_endurance/features/activities/domain/activity.dart';
import 'package:mealvana_endurance/features/events/domain/event.dart';
import 'package:mealvana_endurance/shared/database/app_database.dart'
    show AppDatabase;
import 'package:mealvana_endurance/shared/domain/activity_type.dart';
import 'package:mealvana_endurance/shared/domain/write_consistency.dart';
import 'package:mealvana_endurance/shared/services/logging_service.dart';

class _MockDb extends Mock implements AppDatabase {}

class _MockEventsRepo extends Mock implements EventsRepository {}

class _MockActivitiesService extends Mock implements ActivitiesService {}

class _MockCoachRepo extends Mock implements CoachRepository {}

void main() {
  Event baseEvent() => Event(
    id: 'e1',
    userId: 'u1',
    eventType: ActivityType.running,
    eventName: 'Marathon',
    startTime: '2026-10-01T07:00:00.000',
    eventDate: DateTime(2026, 10, 1),
    createdAt: DateTime(2026, 9, 1),
    updatedAt: DateTime(2026, 9, 1),
  );

  setUpAll(() {
    registerFallbackValue(baseEvent());
    registerFallbackValue(
      Activity(
        id: 'fallback',
        userId: 'u1',
        activityType: ActivityType.running,
        title: 'fallback',
        scheduledDateTime: DateTime(2026, 1, 1),
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
      ),
    );
    registerFallbackValue(WriteConsistency.offlineFirst);
  });

  group('eventDateFromStartTime (shared derivation)', () {
    test('extracts the date portion', () {
      expect(
        EventsService.eventDateFromStartTime('2026-12-25T09:30:00.000'),
        DateTime(2026, 12, 25),
      );
    });
    test('null / empty / unparseable → null', () {
      expect(EventsService.eventDateFromStartTime(null), isNull);
      expect(EventsService.eventDateFromStartTime(''), isNull);
      expect(EventsService.eventDateFromStartTime('not-a-date'), isNull);
    });
  });

  test('updateEvent re-derives eventDate from the edited startTime', () async {
    final repo = _MockEventsRepo();
    when(
      () => repo.updateEvent(
        deviceId: any(named: 'deviceId'),
        event: any(named: 'event'),
        requireRemoteAck: any(named: 'requireRemoteAck'),
      ),
    ).thenAnswer((inv) async => inv.namedArguments[#event] as Event);

    final service = EventsService(
      _MockDb(),
      NoopAppLogger(),
      repo,
      _MockActivitiesService(),
      _MockCoachRepo(),
    );

    // The form changed the date to Dec 25 (startTime moved) but copyWith left
    // eventDate at the OLD Oct 1 — exactly the shape that reproduced the bug.
    final edited = baseEvent().copyWith(startTime: '2026-12-25T09:00:00.000');
    expect(edited.eventDate, DateTime(2026, 10, 1), reason: 'stale by design');

    await service.updateEvent(deviceId: 'device', event: edited);

    final sent =
        verify(
              () => repo.updateEvent(
                deviceId: any(named: 'deviceId'),
                event: captureAny(named: 'event'),
                requireRemoteAck: any(named: 'requireRemoteAck'),
              ),
            ).captured.single
            as Event;
    expect(
      sent.eventDate,
      DateTime(2026, 12, 25),
      reason: 'the persisted eventDate must follow the edited startTime',
    );
  });

  // Second half of the same Claudia report (bug 2026-09-16): the event row moved
  // but its LINKED ACTIVITY stayed on the old day. The events list renders
  // activity.scheduledDateTime in preference to the event's own date, and the
  // activity is the fueling unit — so the edit looked unfixed AND race-day fuel
  // sat a day behind the race. Verified in prod on Xuan's own two events.
  group('linked activity follows the event', () {
    Activity linkedActivity({
      String? syncedFromProvider,
      DateTime? plannedTime,
      DateTime? actualTime,
    }) => Activity(
      id: 'a1',
      userId: 'u1',
      activityType: ActivityType.running,
      title: 'Marathon',
      scheduledDateTime: DateTime(2026, 10, 1, 7),
      createdAt: DateTime(2026, 9, 1),
      updatedAt: DateTime(2026, 9, 1),
      plannedTime: plannedTime,
      actualTime: actualTime,
      syncedFromProvider: syncedFromProvider,
    );

    late _MockEventsRepo repo;
    late _MockActivitiesService activities;
    late EventsService service;

    setUp(() {
      repo = _MockEventsRepo();
      activities = _MockActivitiesService();
      when(
        () => repo.updateEvent(
          deviceId: any(named: 'deviceId'),
          event: any(named: 'event'),
          requireRemoteAck: any(named: 'requireRemoteAck'),
        ),
      ).thenAnswer((inv) async => inv.namedArguments[#event] as Event);
      when(
        () => activities.updateActivity(
          deviceId: any(named: 'deviceId'),
          activity: any(named: 'activity'),
          currentUserId: any(named: 'currentUserId'),
          consistency: any(named: 'consistency'),
        ),
      ).thenAnswer((inv) async => inv.namedArguments[#activity] as Activity);
      service = EventsService(
        _MockDb(),
        NoopAppLogger(),
        repo,
        activities,
        _MockCoachRepo(),
      );
    });

    Future<void> moveEventToDec25() => service.updateEvent(
      deviceId: 'device',
      event: baseEvent().copyWith(
        activityId: 'a1',
        startTime: '2026-12-25T09:00:00.000',
      ),
    );

    test('manual activity is moved to the new date, time included', () async {
      when(
        () => activities.getActivityById(any(), any()),
      ).thenAnswer((_) async => linkedActivity());

      await moveEventToDec25();

      final moved =
          verify(
                () => activities.updateActivity(
                  deviceId: any(named: 'deviceId'),
                  activity: captureAny(named: 'activity'),
                  currentUserId: any(named: 'currentUserId'),
                  consistency: any(named: 'consistency'),
                ),
              ).captured.single
              as Activity;
      expect(moved.scheduledDateTime, DateTime(2026, 12, 25, 9));
    });

    test('plannedTime follows too when set (displayTime prefers it)', () async {
      when(() => activities.getActivityById(any(), any())).thenAnswer(
        (_) async => linkedActivity(plannedTime: DateTime(2026, 10, 1, 7)),
      );

      await moveEventToDec25();

      final moved =
          verify(
                () => activities.updateActivity(
                  deviceId: any(named: 'deviceId'),
                  activity: captureAny(named: 'activity'),
                  currentUserId: any(named: 'currentUserId'),
                  consistency: any(named: 'consistency'),
                ),
              ).captured.single
              as Activity;
      expect(moved.plannedTime, DateTime(2026, 12, 25, 9));
      expect(moved.displayTime, DateTime(2026, 12, 25, 9));
    });

    test('provider-synced activity is left alone (unruled, D-2c analogue)',
        () async {
      when(() => activities.getActivityById(any(), any())).thenAnswer(
        (_) async => linkedActivity(syncedFromProvider: 'training_peaks'),
      );

      await moveEventToDec25();

      verifyNever(
        () => activities.updateActivity(
          deviceId: any(named: 'deviceId'),
          activity: any(named: 'activity'),
          currentUserId: any(named: 'currentUserId'),
          consistency: any(named: 'consistency'),
        ),
      );
    });

    test('an activity that already happened is never rescheduled', () async {
      when(() => activities.getActivityById(any(), any())).thenAnswer(
        (_) async => linkedActivity(actualTime: DateTime(2026, 10, 1, 7, 12)),
      );

      await moveEventToDec25();

      verifyNever(
        () => activities.updateActivity(
          deviceId: any(named: 'deviceId'),
          activity: any(named: 'activity'),
          currentUserId: any(named: 'currentUserId'),
          consistency: any(named: 'consistency'),
        ),
      );
    });

    test('an event with no linked activity touches nothing', () async {
      await service.updateEvent(
        deviceId: 'device',
        event: baseEvent().copyWith(startTime: '2026-12-25T09:00:00.000'),
      );

      verifyNever(() => activities.getActivityById(any(), any()));
    });

    test('the event still saves when the activity move fails', () async {
      when(
        () => activities.getActivityById(any(), any()),
      ).thenThrow(Exception('offline'));

      await moveEventToDec25();

      verify(
        () => repo.updateEvent(
          deviceId: any(named: 'deviceId'),
          event: any(named: 'event'),
          requireRemoteAck: any(named: 'requireRemoteAck'),
        ),
      ).called(1);
    });
  });
}
