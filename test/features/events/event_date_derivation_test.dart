// Ticket 65 (round develop-2026-10, Finding 50-004): an event's event_date is
// the date written in its start_time, derived on every write. These pin the
// one derivation (Event.dateFromStartTime) and the copy the repository applies
// (Event.withDerivedEventDate).
import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/features/events/application/events_service.dart';
import 'package:mealvana_endurance/features/events/domain/event.dart';
import 'package:mealvana_endurance/shared/domain/activity_type.dart';

Event _event({String? startTime, DateTime? eventDate}) => Event(
  id: 'e1',
  userId: 'u1',
  eventType: ActivityType.running,
  eventName: 'Test',
  startTime: startTime,
  eventDate: eventDate,
  createdAt: DateTime(2026, 6, 17),
  updatedAt: DateTime(2026, 6, 17),
);

void main() {
  group('Event.dateFromStartTime', () {
    test('a naive start_time gives its own date', () {
      expect(
        Event.dateFromStartTime('2026-06-20T08:58:00.000'),
        DateTime(2026, 6, 20),
      );
    });

    test('23:30 stays on the written day (no time-zone shift)', () {
      expect(
        Event.dateFromStartTime('2026-06-20T23:30:00.000'),
        DateTime(2026, 6, 20),
      );
    });

    test('00:15 stays on the written day', () {
      expect(
        Event.dateFromStartTime('2026-06-20T00:15:00.000'),
        DateTime(2026, 6, 20),
      );
    });

    test('a microsecond-precision server string (dev rows 11, 16)', () {
      expect(
        Event.dateFromStartTime('2025-12-25T21:28:44.539997'),
        DateTime(2025, 12, 25),
      );
    });

    test('null, empty and unparseable give null', () {
      expect(Event.dateFromStartTime(null), isNull);
      expect(Event.dateFromStartTime(''), isNull);
      expect(Event.dateFromStartTime('not-a-date'), isNull);
    });

    test('EventsService.eventDateFromStartTime forwards to it', () {
      expect(
        EventsService.eventDateFromStartTime('2026-06-20T08:58:00.000'),
        DateTime(2026, 6, 20),
      );
      expect(EventsService.eventDateFromStartTime(null), isNull);
    });
  });

  group('Event.withDerivedEventDate', () {
    test('replaces a stale event_date (the dev row: Jul 17 vs Jun 20)', () {
      final derived = _event(
        startTime: '2026-06-20T08:58:00.000',
        eventDate: DateTime(2026, 7, 17),
      ).withDerivedEventDate();
      expect(derived.eventDate, DateTime(2026, 6, 20));
      expect(derived.startTime, '2026-06-20T08:58:00.000');
    });

    test('drops a time of day carried in event_date', () {
      final derived = _event(
        startTime: '2026-10-17T00:00:00.000',
        eventDate: DateTime(2026, 10, 17, 9, 30),
      ).withDerivedEventDate();
      expect(derived.eventDate, DateTime(2026, 10, 17));
    });

    test('keeps the given event_date when start_time is null', () {
      final derived = _event(
        eventDate: DateTime(2025, 4, 21),
      ).withDerivedEventDate();
      expect(derived.eventDate, DateTime(2025, 4, 21));
    });

    test('keeps the given event_date when start_time is unparseable', () {
      final derived = _event(
        startTime: 'TBD',
        eventDate: DateTime(2025, 4, 21),
      ).withDerivedEventDate();
      expect(derived.eventDate, DateTime(2025, 4, 21));
    });
  });
}
