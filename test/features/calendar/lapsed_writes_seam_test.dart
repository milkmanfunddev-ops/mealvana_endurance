/// A lapsed account cannot write from the calendar (mp-457 §4, mp-491,
/// ticket 12).
///
/// Through the real CalendarController: each write path asks the write
/// guard first; refused, it opens the paywall once and never constructs the
/// calendar or activities service, the events repository or the auth
/// service, so nothing is written or queued.
library;

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/features/activities/application/activities_service.dart';
import 'package:mealvana_endurance/features/activities/domain/activity.dart';
import 'package:mealvana_endurance/features/auth/application/auth_service.dart';
import 'package:mealvana_endurance/features/calendar/application/calendar_service.dart';
import 'package:mealvana_endurance/features/calendar/presentation/providers/calendar_controller.dart';
import 'package:mealvana_endurance/features/events/data/events_repository.dart';
import 'package:mealvana_endurance/features/events/domain/event.dart';
import 'package:mealvana_endurance/shared/domain/activity_type.dart';

import '../../helpers/write_access.dart';

class _FakeActivity extends Fake implements Activity {}

class _FakeEvent extends Fake implements Event {}

class _SeededCalendar extends CalendarController {
  @override
  FutureOr<CalendarState> build() => const CalendarState();
}

void main() {
  late PaywallOpens opens;
  late ProviderContainer container;

  setUp(() {
    opens = PaywallOpens();
    container = ProviderContainer(
      overrides: [
        writesRefused(),
        opens.override,
        calendarServiceProvider.overrideWith(untouched('calendarService')),
        activitiesServiceProvider.overrideWith(untouched('activitiesService')),
        eventsRepositoryProvider.overrideWith(untouched('eventsRepository')),
        authServiceProvider.overrideWith(untouched('authService')),
        calendarControllerProvider.overrideWith(_SeededCalendar.new),
      ],
    );
    addTearDown(container.dispose);
  });

  CalendarController ctrl() =>
      container.read(calendarControllerProvider.notifier);
  final raceDate = DateTime(2026, 10, 4);
  final paths = <String, Future<Object?> Function()>{
    'createActivity': () => ctrl().createActivity(
      title: 'Run',
      scheduledDateTime: DateTime(2026, 9, 22, 7),
    ),
    'updateActivity': () => ctrl().updateActivity(_FakeActivity()),
    'updateEvent': () => ctrl().updateEvent(_FakeEvent()),
    'deleteActivity': () => ctrl().deleteActivity('a1'),
    'deleteCarbLoadingDay': () => ctrl().deleteCarbLoadingDay('d1'),
    'createEvent': () => ctrl().createEvent(eventType: ActivityType.running),
    'createCarbLoadingPlan': () => ctrl().createCarbLoadingPlan(
      eventId: 'e1',
      protocolDays: 3,
      raceDate: raceDate,
      bodyWeightPounds: 160,
    ),
    'updateCarbLoadingProtocol': () => ctrl().updateCarbLoadingProtocol(
      eventId: 'e1',
      newProtocolDays: 2,
      raceDate: raceDate,
      bodyWeightPounds: 160,
    ),
  };
  for (final entry in paths.entries) {
    test('lapsed: ${entry.key} opens the paywall and writes nothing', () async {
      await expectWriteRefused(opens, entry.value);
      final state = container.read(calendarControllerProvider).value!;
      expect(state.activities, isEmpty);
      expect(state.events, isEmpty);
      expect(state.error, isNull);
    });
  }
}
