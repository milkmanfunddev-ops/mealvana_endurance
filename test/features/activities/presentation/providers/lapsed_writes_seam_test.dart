/// A lapsed account cannot write activities (mp-457 §4, mp-491, ticket 12).
///
/// Through the real notifiers: every write path on ActivitiesController and
/// BrickActionsController asks the write guard first. Refused, it opens the
/// paywall once and reaches no service, repository or database, so nothing
/// is written locally or queued for sync. The services are overridden to
/// fail on construction, so a write that slipped past the guard fails here.
library;

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/features/activities/application/activities_service.dart';
import 'package:mealvana_endurance/features/activities/data/activities_repository.dart';
import 'package:mealvana_endurance/features/activities/domain/activity.dart';
import 'package:mealvana_endurance/features/activities/presentation/providers/activities_controller.dart';
import 'package:mealvana_endurance/features/activities/presentation/providers/brick_actions_controller.dart';
import 'package:mealvana_endurance/shared/database/database_provider.dart';

import '../../../../helpers/write_access.dart';

class _FakeActivity extends Fake implements Activity {}

class _SeededActivities extends ActivitiesController {
  @override
  FutureOr<List<Activity>> build() => const [];
}

class _SeededBrickActions extends BrickActionsController {
  @override
  FutureOr<void> build() {}
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
        activitiesServiceProvider.overrideWith(untouched('activitiesService')),
        activitiesRepositoryProvider.overrideWith(
          untouched('activitiesRepository'),
        ),
        appDatabaseProvider.overrideWith(untouched('appDatabase')),
        activitiesControllerProvider.overrideWith(_SeededActivities.new),
        brickActionsControllerProvider.overrideWith(_SeededBrickActions.new),
      ],
    );
    addTearDown(container.dispose);
  });

  group('ActivitiesController, lapsed', () {
    ActivitiesController ctrl() =>
        container.read(activitiesControllerProvider.notifier);
    final activity = _FakeActivity();
    final paths = <String, Future<Object?> Function()>{
      'createActivity': () => ctrl().createActivity(
        title: 'Run',
        scheduledDateTime: DateTime(2026, 9, 22, 7),
      ),
      'updateActivity': () => ctrl().updateActivity(activity),
      'deleteActivity': () => ctrl().deleteActivity('a1'),
      'markWorkoutDone': () => ctrl().markWorkoutDone('a1'),
      'markWorkoutUndone': () => ctrl().markWorkoutUndone('a1'),
      'skipWorkout': () => ctrl().skipWorkout('a1'),
      'unskipWorkout': () => ctrl().unskipWorkout('a1'),
      'restoreActivity': () => ctrl().restoreActivity(activity),
    };
    for (final entry in paths.entries) {
      test('${entry.key} opens the paywall and writes nothing', () async {
        await expectWriteRefused(opens, entry.value);
        expect(container.read(activitiesControllerProvider).value, isEmpty);
      });
    }
  });

  group('BrickActionsController, lapsed', () {
    BrickActionsController ctrl() =>
        container.read(brickActionsControllerProvider.notifier);
    final paths = <String, Future<Object?> Function()>{
      'createBrickFromSelection': () => ctrl().createBrickFromSelection(
        activities: [_FakeActivity(), _FakeActivity()],
        segmentOrder: const ['a1', 'a2'],
      ),
      'ungroupBrick': () => ctrl().ungroupBrick('b1'),
      'removeSegmentFromBrick': () =>
          ctrl().removeSegmentFromBrick(brickId: 'b1', segmentIndex: 0),
    };
    for (final entry in paths.entries) {
      test('${entry.key} opens the paywall and writes nothing', () async {
        await expectWriteRefused(opens, entry.value);
      });
    }
  });
}
