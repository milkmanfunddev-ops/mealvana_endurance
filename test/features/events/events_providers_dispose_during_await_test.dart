/// Ticket 18 (Sentry MEALVANA-ENDURANCE-CP / DEV-9D, and D1): `allEvents` and
/// `eventDetail` are auto-dispose. The screens that watch them often leave
/// while the user id is still loading; the provider is then disposed in the
/// middle of its build, and the old code went on to `ref.read` a service
/// after the await, which throws `UnmountedRefException` (96 prod events, 144
/// dev events). The build must finish quietly and its result be discarded.
///
/// Tested through the real providers in a `ProviderContainer`; a recording
/// observer catches any failure Riverpod sees.
library;

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/features/activities/application/activities_service.dart';
import 'package:mealvana_endurance/features/events/application/events_service.dart';
import 'package:mealvana_endurance/features/events/data/events_repository.dart';
import 'package:mealvana_endurance/features/events/domain/event.dart';
import 'package:mealvana_endurance/features/events/presentation/providers/events_controller.dart';
import 'package:mealvana_endurance/shared/data/syncable_repository.dart';
import 'package:mealvana_endurance/shared/domain/activity_type.dart';
import 'package:mealvana_endurance/shared/providers/user_id_provider.dart';
import 'package:mealvana_endurance/shared/services/report/report.dart';
import 'package:mealvana_endurance/shared/services/sync/sync_coordinator.dart';
import 'package:mocktail/mocktail.dart';
import 'package:riverpod/riverpod.dart';

import '../../helpers/fakes/recording_report.dart';

class _MockEventsService extends Mock implements EventsService {}

class _MockEventsRepository extends Mock implements EventsRepository {}

class _MockActivitiesService extends Mock implements ActivitiesService {}

class _NoopSyncCoordinator extends SyncCoordinator {
  @override
  SyncState build() => SyncState.idle;

  @override
  Future<void> ensureSynced(
    String repoKey,
    String userId, {
    SyncableRepository? repository,
  }) async {}
}

/// Every failure Riverpod reports, as the app's Sentry observer would see it.
final class _FailureLog extends ProviderObserver {
  final List<Object> errors = [];

  @override
  void providerDidFail(
    ProviderObserverContext context,
    Object error,
    StackTrace stackTrace,
  ) {
    errors.add(error);
  }
}

Event _event() => Event(
  id: 'e1',
  userId: 'u1',
  eventType: ActivityType.running,
  eventName: 'Ironman 70.3 Augusta',
  eventDate: DateTime(2026, 9, 28),
  createdAt: DateTime(2026, 9, 1),
  updatedAt: DateTime(2026, 9, 1),
);

void main() {
  late _MockEventsService service;
  late Completer<String> userId;
  late _FailureLog failures;
  late RecordingReport report;
  late ProviderContainer container;

  setUp(() {
    service = _MockEventsService();
    when(() => service.getAllEvents(any())).thenAnswer((_) async => [_event()]);
    when(
      () => service.getEventById(any(), any()),
    ).thenAnswer((_) async => _event());
    userId = Completer<String>();
    failures = _FailureLog();
    report = RecordingReport();
    container = ProviderContainer(
      observers: [failures],
      overrides: [
        eventsServiceProvider.overrideWithValue(service),
        eventsRepositoryProvider.overrideWithValue(_MockEventsRepository()),
        activitiesServiceProvider.overrideWithValue(_MockActivitiesService()),
        syncCoordinatorProvider.overrideWith(_NoopSyncCoordinator.new),
        reportProvider.overrideWithValue(report),
        userIdProvider.overrideWith((ref) => userId.future),
      ],
    );
    addTearDown(container.dispose);
  });

  test('allEvents disposed while awaiting the user id finishes without a '
      'throw and never runs its query', () async {
    final sub = container.listen(allEventsProvider, (_, _) {});
    await pumpEventQueue();
    sub.close();
    await container.pump();
    expect(container.exists(allEventsProvider), isFalse);

    userId.complete('u1');
    await pumpEventQueue();

    expect(failures.errors, isEmpty);
    expect(report.faults, isEmpty);
    verifyNever(() => service.getAllEvents(any()));
  });

  test('allEvents invalidated mid-await discards the stale build and serves '
      'the fresh one', () async {
    final seen = <List<Event>>[];
    container.listen(allEventsProvider, (_, next) {
      final value = next.value;
      if (value != null) seen.add(value);
    });
    await pumpEventQueue();
    container.invalidate(allEventsProvider);
    await pumpEventQueue();

    userId.complete('u1');
    final events = await container.read(allEventsProvider.future);
    await pumpEventQueue();

    expect(failures.errors, isEmpty);
    expect(events.single.id, 'e1');
    expect(seen, hasLength(1), reason: 'only the fresh build emits');
  });

  test('eventDetail disposed while awaiting the user id finishes without a '
      'throw and never reads the event', () async {
    final detail = eventDetailProvider('e1');
    final sub = container.listen(detail, (_, _) {});
    await pumpEventQueue();
    sub.close();
    await container.pump();
    expect(container.exists(detail), isFalse);

    userId.complete('u1');
    await pumpEventQueue();

    expect(failures.errors, isEmpty);
    expect(report.faults, isEmpty);
  });
}
