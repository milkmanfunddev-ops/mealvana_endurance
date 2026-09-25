// Ticket 99 seam test (Finding 29-002): a completed FinalSurge payload marks
// the stored activity completed with the measured values, and a later payload
// without completion does not undo it.
//
// Real path end to end: FinalSurgeSyncService -> FinalSurgeTransformer ->
// ChangeDetectionService -> ActivitiesRepository -> Drift (in memory). Only
// the FS HTTP client and the integrations row are stubbed; the client answers
// with the producer-shaped payloads the dev feed sent on 2026-09-24.
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/features/activities/application/activity_deduplication_service.dart';
import 'package:mealvana_endurance/features/activities/data/activities_repository.dart';
import 'package:mealvana_endurance/features/activities/domain/activity.dart'
    as domain;
import 'package:mealvana_endurance/features/integrations/application/change_detection_service.dart';
import 'package:mealvana_endurance/features/integrations/application/final_surge_sync_service.dart';
import 'package:mealvana_endurance/features/integrations/application/final_surge_transformer.dart';
import 'package:mealvana_endurance/features/integrations/data/final_surge_api_client.dart';
import 'package:mealvana_endurance/features/integrations/data/integrations_repository.dart';
import 'package:mealvana_endurance/features/integrations/domain/integration.dart';
import 'package:mealvana_endurance/shared/database/app_database.dart';
import 'package:mocktail/mocktail.dart';

import '../../fixtures/final_surge_completed_fixtures.dart';
import '../../helpers/widget_test_harness.dart';

class _MockApiClient extends Mock implements FinalSurgeApiClient {}

class _MockIntegrationsRepository extends Mock
    implements IntegrationsRepository {}

const _userId = 'u1';

void main() {
  late AppDatabase db;
  late ActivitiesRepository activities;
  late _MockApiClient api;
  late FinalSurgeSyncService service;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    activities = ActivitiesRepository(
      supabase: fakeSupabaseClient(),
      database: db,
      logger: MockAppLogger(),
      sentry: mockSentryReporter(),
      deduplicationService: ActivityDeduplicationService(
        logger: MockAppLogger(),
      ),
    );
    api = _MockApiClient();
    final integrations = _MockIntegrationsRepository();
    when(() => integrations.getIntegration(_userId, 'final_surge')).thenAnswer(
      (_) async => IntegrationModel(
        userId: _userId,
        provider: 'final_surge',
        accessToken: 'token',
        refreshToken: 'refresh',
        providerAthleteId: 'athlete',
        isActive: true,
      ),
    );
    when(
      () => integrations.updateSyncStatus(
        any(),
        any(),
        status: any(named: 'status'),
        error: any(named: 'error'),
      ),
    ).thenAnswer((_) async {});

    service = FinalSurgeSyncService(
      apiClient: api,
      integrationsRepository: integrations,
      activitiesRepository: activities,
      transformer: const FinalSurgeTransformer(),
      changeDetectionService: ChangeDetectionService(),
    );
  });

  tearDown(() async => db.close());

  /// One sync against a feed that answers with [workouts].
  Future<void> syncWith(List<Map<String, dynamic>> workouts) async {
    when(
      () => api.getUpcomingWorkouts(
        any(),
        numDays: any(named: 'numDays'),
        numWorkouts: any(named: 'numWorkouts'),
      ),
    ).thenAnswer(
      (_) async =>
          FinalSurgeWorkoutsResponse(success: true, workouts: workouts),
    );
    final result = await service.syncWorkouts(_userId, numDays: 7);
    expect(result.success, isTrue, reason: result.error);
  }

  Future<domain.Activity> stored(String workoutKey) async {
    final rows = await activities.getActivitiesByUserAndProvider(
      _userId,
      'final_surge',
    );
    return rows.singleWhere((a) => a.providerWorkoutId == workoutKey);
  }

  Future<String?> storedCompletionTypeColumn(String workoutKey) async {
    final row = await (db.select(
      db.activitiesTable,
    )..where((t) => t.providerWorkoutId.equals(workoutKey))).getSingle();
    return row.completionType;
  }

  const easyKey = 'd67e6590-af7e-47bb-9508-e14739db5da5';
  const runKey = '3de79f1a-d03f-453d-8df5-5c921936603d';

  test('a planned row turns completed with the measured values when FS '
      'reports it done, and a later plan-only payload does not undo it', () async {
    // 1. The plan arrives first: stored planned, no actuals.
    await syncWith([fsEasyWithoutCompletion()]);
    final planned = await stored(easyKey);
    expect(planned.status, domain.ActivityStatus.planned);
    expect(planned.actualDistanceMiles, isNull);

    // 2. FS reports the run done.
    await syncWith([fsCompletedEasy]);
    final done = await stored(easyKey);
    expect(done.id, planned.id, reason: 'the same row, not a duplicate');
    expect(done.status, domain.ActivityStatus.completed);
    expect(done.completionType, domain.Activity.providerCompletionType);
    expect(await storedCompletionTypeColumn(easyKey), 'provider');
    expect(done.actualDurationMinutes, 34);
    expect(done.actualDistanceMiles, closeTo(3.544, 0.001));
    expect(done.actualTime, DateTime(2026, 9, 24, 5, 32));
    expect(
      done.completedAt,
      DateTime(2026, 9, 24, 5, 32).add(const Duration(seconds: 2021)),
    );
    // Planned fields keep the plan.
    expect(done.distanceMiles, 8.0);
    expect(done.durationMinutes, isNull);

    // 3. A later payload without completion never reverts it.
    await syncWith([fsEasyWithoutCompletion()]);
    final after = await stored(easyKey);
    expect(after.status, domain.ActivityStatus.completed);
    expect(after.completionType, domain.Activity.providerCompletionType);
    expect(after.actualDurationMinutes, 34);
    expect(after.actualDistanceMiles, closeTo(3.544, 0.001));
    expect(after.actualTime, DateTime(2026, 9, 24, 5, 32));
    expect(after.completedAt, done.completedAt);
  });

  test('a completed workout first seen on a sync is inserted completed', () async {
    await syncWith([fsCompletedRun]);
    final run = await stored(runKey);
    expect(run.status, domain.ActivityStatus.completed);
    expect(run.completionType, domain.Activity.providerCompletionType);
    expect(run.actualDurationMinutes, 36);
    expect(run.actualDistanceMiles, closeTo(3.864, 0.001));
    expect(run.actualTime, DateTime(2026, 9, 24, 7, 28));
    expect(run.distanceMiles, isNot(closeTo(3.864, 0.01)));
  });

  test('an athlete mark-done is upgraded to the provider measurements', () async {
    await syncWith([fsEasyWithoutCompletion()]);
    final planned = await stored(easyKey);
    // The athlete's mark-done: status + actual_time, no measurements.
    await activities.markWorkoutDone(activityId: planned.id);
    expect(
      (await stored(easyKey)).status,
      domain.ActivityStatus.completed,
    );

    await syncWith([fsCompletedEasy]);
    final upgraded = await stored(easyKey);
    expect(upgraded.status, domain.ActivityStatus.completed);
    expect(upgraded.completionType, domain.Activity.providerCompletionType);
    expect(upgraded.actualDistanceMiles, closeTo(3.544, 0.001));
    expect(upgraded.actualDurationMinutes, 34);
  });

  test('a completion that sends no measurements keeps the athlete\'s own '
      'numbers (wave 25 review)', () async {
    await syncWith([fsEasyWithoutCompletion()]);
    final planned = await stored(easyKey);
    await activities.markWorkoutDone(activityId: planned.id);
    await (db.update(db.activitiesTable)
          ..where((t) => t.providerWorkoutId.equals(easyKey)))
        .write(
          const ActivitiesTableCompanion(
            actualDistanceMiles: Value(5.2),
            actualDurationMinutes: Value(41),
          ),
        );

    final bare = Map<String, dynamic>.of(fsCompletedEasy)
      ..remove('ActualTime')
      ..remove('ActualDistanceMeters');
    await syncWith([bare]);
    final after = await stored(easyKey);
    expect(after.status, domain.ActivityStatus.completed);
    expect(after.actualDistanceMiles, 5.2);
    expect(after.actualDurationMinutes, 41);

    // And it settles: the same bare payload writes nothing next time.
    await syncWith([bare]);
    expect((await stored(easyKey)).localUpdatedAt, after.localUpdatedAt);
  });

  test('an unchanged completed payload writes nothing on the next sync', () async {
    await syncWith([fsCompletedEasy]);
    final first = await stored(easyKey);
    await syncWith([fsCompletedEasy]);
    final second = await stored(easyKey);
    expect(second.localUpdatedAt, first.localUpdatedAt);
  });

  test('M-1.3: a completed payload revives a deleted row with the measured '
      'values', () async {
    await syncWith([fsEasyWithoutCompletion()]);
    await (db.update(db.activitiesTable)
          ..where((t) => t.providerWorkoutId.equals(easyKey)))
        .write(
          ActivitiesTableCompanion(
            status: const Value('deleted'),
            deletedAt: Value(DateTime(2026, 9, 24, 12)),
          ),
        );

    await syncWith([fsCompletedEasy]);
    final row = await (db.select(
      db.activitiesTable,
    )..where((t) => t.providerWorkoutId.equals(easyKey))).getSingle();
    expect(row.status, 'completed');
    expect(row.deletedAt, isNull);
    expect(row.completionType, 'provider');
    expect(row.actualDurationMinutes, 34);
    expect(row.actualDistanceMiles, closeTo(3.544, 0.001));
    expect(row.actualTime, DateTime(2026, 9, 24, 5, 32));
  });
}
