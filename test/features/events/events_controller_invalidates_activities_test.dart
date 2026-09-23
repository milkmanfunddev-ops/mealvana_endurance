/// Layer 3 of Claudia's event-date bug (2026-09-16): `updateEvent` can MOVE the
/// event's linked activity, and the events list renders
/// `activity.scheduledDateTime` in preference to the event's own date — so
/// unless the activities cache is invalidated too, the database is correct
/// while the screen keeps painting the pre-move date. Verified in prod:
/// activity rows moved at 08:38:50, the list still showed the old day.
///
/// Tested through the REAL notifier (CLAUDE.md: every controller write path
/// gets one test through the real notifier).
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/features/activities/domain/activity.dart';
import 'package:mealvana_endurance/features/activities/presentation/providers/activities_controller.dart';
import 'package:mealvana_endurance/features/events/application/events_service.dart';
import 'package:mealvana_endurance/features/events/data/events_repository.dart';
import 'package:mealvana_endurance/features/events/domain/event.dart';
import 'package:mealvana_endurance/features/events/presentation/providers/events_controller.dart';
import 'package:mealvana_endurance/shared/data/syncable_repository.dart';
import 'package:mealvana_endurance/shared/domain/activity_type.dart';
import 'package:mealvana_endurance/shared/providers/user_id_provider.dart';
import 'package:mealvana_endurance/shared/services/logging_service.dart';
import 'package:mealvana_endurance/shared/services/sync/sync_coordinator.dart';
import 'package:mocktail/mocktail.dart';
import 'package:riverpod/riverpod.dart';

class _MockEventsService extends Mock implements EventsService {}

class _MockEventsRepository extends Mock implements EventsRepository {}

/// `EventsController.build` fires `_backgroundSync` and reads the coordinator
/// outside its try block, so the test has to supply a real (inert) one.
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

/// Counts builds instead of touching the real activity stack (which needs app
/// config, auth and sync). A rebuild here is what makes the events list re-read
/// the linked activity's date.
class _CountingActivitiesController extends ActivitiesController {
  _CountingActivitiesController(this.onBuild);
  final void Function() onBuild;

  @override
  Future<List<Activity>> build() async {
    onBuild();
    return const [];
  }
}

Event _event() => Event(
  id: 'e1',
  userId: 'u1',
  eventType: ActivityType.running,
  eventName: 'Ironman 70.3 Augusta',
  activityId: 'a1',
  startTime: '2026-09-28T07:30:00.000',
  eventDate: DateTime(2026, 9, 28),
  createdAt: DateTime(2026, 9, 1),
  updatedAt: DateTime(2026, 9, 1),
);

void main() {
  setUpAll(() => registerFallbackValue(_event()));

  test(
    'updateEvent invalidates the activities cache the list renders from',
    () async {
      final service = _MockEventsService();
      when(
        () => service.getAllEvents(any()),
      ).thenAnswer((_) async => [_event()]);

      // `build()`'s fire-and-forget background sync must find something inert;
      // fresh data means it never invalidates itself behind the assertion.
      final repository = _MockEventsRepository();
      when(repository.isStale).thenAnswer((_) async => false);
      when(
        () => service.updateEvent(
          deviceId: any(named: 'deviceId'),
          event: any(named: 'event'),
          currentUserId: any(named: 'currentUserId'),
          consistency: any(named: 'consistency'),
        ),
      ).thenAnswer((_) async {});

      // Count how many times the activities provider is (re)built. The events
      // list watches this provider, so a rebuild here IS the screen refreshing.
      var activityBuilds = 0;

      final container = ProviderContainer(
        overrides: [
          eventsServiceProvider.overrideWithValue(service),
          eventsRepositoryProvider.overrideWithValue(repository),
          appLoggerProvider.overrideWithValue(NoopAppLogger()),
          syncCoordinatorProvider.overrideWith(_NoopSyncCoordinator.new),
          userIdProvider.overrideWith((ref) async => 'u1'),
          allActivitiesProvider.overrideWith((ref) async => const []),
          activitiesControllerProvider.overrideWith(
            () => _CountingActivitiesController(() => activityBuilds++),
          ),
        ],
      );
      addTearDown(container.dispose);

      // Keep both providers alive, as the events list screen does.
      container.listen(activitiesControllerProvider, (_, __) {});
      await container.read(eventsControllerProvider.future);
      final buildsBeforeUpdate = activityBuilds;

      await container
          .read(eventsControllerProvider.notifier)
          .updateEvent(_event().copyWith(startTime: '2026-09-30T07:30:00.000'));

      // Force the (re)build to materialise, then compare. If the provider was
      // NOT invalidated, this read returns the cached value and the counter
      // stays put — which is precisely the bug.
      await Future<void>.delayed(Duration.zero);
      container.read(activitiesControllerProvider);

      expect(
        activityBuilds,
        greaterThan(buildsBeforeUpdate),
        reason:
            'the activities cache must be re-read after an event update, or the '
            'events list keeps rendering the linked activity\'s OLD date',
      );
    },
  );
}
