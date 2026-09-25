// Ticket 101 (Lee's ruling 2026-09-25, follow-on to Finding 29-002): a
// workout FinalSurge reports completed (`completion_type = 'provider'`) is
// final for the athlete. Mark-undone (and Skip, which also clears the
// completion) is refused, so the next sync cannot flip it back and forth.
//
// The provider row is the FinalSurge transformer's output for the real
// 2026-09-24 payload (producer-shaped), stored through the real repository
// into an in-memory Drift database. The controller test goes through the
// real ActivitiesController write path with only its build seeded.
import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/features/activities/application/activities_service.dart';
import 'package:mealvana_endurance/features/activities/application/activity_deduplication_service.dart';
import 'package:mealvana_endurance/features/activities/data/activities_repository.dart';
import 'package:mealvana_endurance/features/activities/domain/activity.dart';
import 'package:mealvana_endurance/features/activities/domain/provider_completion_is_final.dart';
import 'package:mealvana_endurance/shared/domain/activity_type.dart';
import 'package:mealvana_endurance/features/activities/presentation/providers/activities_controller.dart';
import 'package:mealvana_endurance/features/coach_mode/data/coach_repository.dart';
import 'package:mealvana_endurance/features/integrations/application/final_surge_transformer.dart';
import 'package:mealvana_endurance/shared/database/app_database.dart' as db;
import 'package:mealvana_endurance/shared/services/logging_service.dart';
import 'package:mocktail/mocktail.dart';

import '../../fixtures/final_surge_completed_fixtures.dart';
import '../../helpers/widget_test_harness.dart';

class _MockCoachRepository extends Mock implements CoachRepository {}

const _userId = 'u1';

class _SeededActivitiesController extends ActivitiesController {
  _SeededActivitiesController(this._seed);
  final List<Activity> _seed;

  @override
  FutureOr<List<Activity>> build() => _seed;
}

void main() {
  late db.AppDatabase database;
  late ActivitiesRepository repository;

  setUp(() {
    database = db.AppDatabase.forTesting(NativeDatabase.memory());
    repository = ActivitiesRepository(
      supabase: fakeSupabaseClient(),
      database: database,
      logger: MockAppLogger(),
      sentry: mockSentryReporter(),
      deduplicationService: ActivityDeduplicationService(
        logger: MockAppLogger(),
      ),
    );
  });

  tearDown(() => database.close());

  Future<Activity> seedProviderCompleted() async {
    final fromFeed = const FinalSurgeTransformer()
        .transform(fsCompletedEasy, _userId)!
        .activity;
    expect(fromFeed.isProviderCompleted, isTrue);
    return repository.insertActivity(fromFeed);
  }

  Future<db.Activity> row(String id) => (database.select(
    database.activitiesTable,
  )..where((t) => t.id.equals(id))).getSingle();

  group('repository', () {
    test('mark-undone on a provider-completed workout is refused', () async {
      final a = await seedProviderCompleted();
      final before = await row(a.id);

      await expectLater(
        repository.markWorkoutUndone(activityId: a.id),
        throwsA(isA<ProviderCompletionIsFinal>()),
      );

      final after = await row(a.id);
      expect(after.status, 'completed');
      expect(after.completionType, 'provider');
      expect(after.actualTime, before.actualTime);
      expect(after.completedAt, before.completedAt);
    });

    test('skip on a provider-completed workout is refused', () async {
      final a = await seedProviderCompleted();
      await expectLater(
        repository.skipWorkout(activityId: a.id),
        throwsA(isA<ProviderCompletionIsFinal>()),
      );
      expect((await row(a.id)).status, 'completed');
    });

    test('an athlete mark-done can still be undone', () async {
      final now = DateTime.now();
      final run = await repository.insertActivity(
        Activity(
          id: '',
          userId: _userId,
          activityType: ActivityType.running,
          title: 'Run',
          scheduledDateTime: DateTime(2026, 9, 24, 5, 30),
          durationMinutes: 40,
          createdAt: now,
          updatedAt: now,
        ),
      );
      await repository.markWorkoutDone(activityId: run.id);
      await repository.markWorkoutUndone(activityId: run.id);
      final r = await row(run.id);
      expect(r.status, 'planned');
      expect(r.actualTime, isNull);
    });
  });

  group('controller (real notifier write path)', () {
    test(
      'markWorkoutUndone on a provider-completed workout throws and changes nothing',
      () async {
        final a = await seedProviderCompleted();
        final container = ProviderContainer(
          overrides: [
            activitiesServiceProvider.overrideWithValue(
              ActivitiesService(
                database,
                MockAppLogger(),
                repository,
                _MockCoachRepository(),
              ),
            ),
            appLoggerProvider.overrideWithValue(MockAppLogger()),
            activitiesControllerProvider.overrideWith(
              () => _SeededActivitiesController([a]),
            ),
          ],
        );
        addTearDown(container.dispose);
        await container.read(activitiesControllerProvider.future);

        final states = <List<Activity>?>[];
        container.listen(
          activitiesControllerProvider,
          (_, next) => states.add(next.value),
        );

        await expectLater(
          container
              .read(activitiesControllerProvider.notifier)
              .markWorkoutUndone(a.id),
          throwsA(isA<ProviderCompletionIsFinal>()),
        );

        // No optimistic flip to planned, not even for a frame.
        for (final s in states) {
          expect(s!.single.status, ActivityStatus.completed);
        }
        final shown = container.read(activitiesControllerProvider).value!;
        expect(shown.single.status, ActivityStatus.completed);
        expect(shown.single.actualTime, isNotNull);
        expect((await row(a.id)).status, 'completed');
      },
    );
  });
}
