/// A lapsed account cannot write events (mp-457 §4, mp-491, ticket 12).
///
/// Through the real EventsController: each write path asks the write guard
/// first; refused, it opens the paywall once and never constructs the
/// events service or repository, so nothing is written or queued.
library;

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/features/events/application/events_service.dart';
import 'package:mealvana_endurance/features/events/data/events_repository.dart';
import 'package:mealvana_endurance/features/events/domain/event.dart';
import 'package:mealvana_endurance/features/events/presentation/providers/events_controller.dart';
import 'package:mealvana_endurance/shared/domain/activity_type.dart';

import '../../helpers/write_access.dart';

class _FakeEvent extends Fake implements Event {}

class _SeededEvents extends EventsController {
  @override
  FutureOr<List<Event>> build() => const [];
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
        eventsServiceProvider.overrideWith(untouched('eventsService')),
        eventsRepositoryProvider.overrideWith(untouched('eventsRepository')),
        eventsControllerProvider.overrideWith(_SeededEvents.new),
      ],
    );
    addTearDown(container.dispose);
  });

  EventsController ctrl() => container.read(eventsControllerProvider.notifier);
  final paths = <String, Future<Object?> Function()>{
    'createEvent': () => ctrl().createEvent(eventType: ActivityType.running),
    'updateEvent': () => ctrl().updateEvent(_FakeEvent()),
    'deleteEvent': () => ctrl().deleteEvent('e1'),
  };
  for (final entry in paths.entries) {
    test('lapsed: ${entry.key} opens the paywall and writes nothing', () async {
      await expectWriteRefused(opens, entry.value);
      expect(container.read(eventsControllerProvider).value, isEmpty);
    });
  }
}
