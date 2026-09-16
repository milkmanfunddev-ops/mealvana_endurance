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
import 'package:mealvana_endurance/features/events/domain/event.dart';
import 'package:mealvana_endurance/shared/database/app_database.dart'
    show AppDatabase;
import 'package:mealvana_endurance/shared/domain/activity_type.dart';
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

  setUpAll(() => registerFallbackValue(baseEvent()));

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
}
