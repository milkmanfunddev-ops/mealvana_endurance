// Controller seam for the brick create -> ungroup -> regroup round trip,
// through the REAL notifier (docs/test/README.md §Seam tests).
//
// Born from the 2026-10-07 dashboard ghost brick: after ungroup + regroup the
// legs must point at the NEW brick and the new brick's archived-leg reader
// must see both of them — the invariant the remote push (pinned in
// activities_repository_brick_push_order_test.dart) carries to the server.
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/features/activities/application/activities_service.dart';
import 'package:mealvana_endurance/features/activities/application/activity_deduplication_service.dart';
import 'package:mealvana_endurance/features/activities/data/activities_repository.dart';
import 'package:mealvana_endurance/features/activities/domain/activity.dart';
import 'package:mealvana_endurance/features/activities/presentation/providers/brick_actions_controller.dart';
import 'package:mealvana_endurance/features/coach_mode/data/coach_repository.dart';
import 'package:mealvana_endurance/shared/database/app_database.dart'
    as db
    show AppDatabase, Activity;
import 'package:mealvana_endurance/shared/database/database_provider.dart';
import 'package:mealvana_endurance/shared/domain/activity_type.dart';
import 'package:mealvana_endurance/shared/services/logging_service.dart';
import 'package:mealvana_endurance/shared/services/schema_recovery_service.dart';
import 'package:mealvana_endurance/shared/services/sentry/sentry_reporter.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MockSupabaseClient extends Mock implements SupabaseClient {}

class MockAppLogger extends Mock implements AppLogger {}

class MockSentryReporter extends Mock implements SentryReporter {}

class MockCoachRepository extends Mock implements CoachRepository {}

class MockActivityDeduplicationService extends Mock
    implements ActivityDeduplicationService {}

/// Pass-through recovery: runs the operation, no retry machinery.
class PassthroughSchemaRecovery extends Fake implements SchemaRecoveryService {
  @override
  Future<T> withSchemaRecovery<T>({
    required Future<T> Function() operation,
    required Future<T> Function() onRetryNeeded,
    String? context,
  }) => operation();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late db.AppDatabase database;
  late ProviderContainer container;
  late ActivitiesRepository repository;

  const userId = 'user-regroup-seam';
  final day = DateTime(2026, 10, 7);

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    database = db.AppDatabase.forTesting(NativeDatabase.memory());
    final logger = MockAppLogger();
    registerFallbackValue(StackTrace.empty);
    when(
      () => logger.info(
        any(),
        context: any(named: 'context'),
        data: any(named: 'data'),
      ),
    ).thenReturn(null);
    when(
      () => logger.debug(
        any(),
        context: any(named: 'context'),
        data: any(named: 'data'),
      ),
    ).thenReturn(null);
    when(
      () => logger.warning(
        any(),
        context: any(named: 'context'),
        error: any(named: 'error'),
        stackTrace: any(named: 'stackTrace'),
        data: any(named: 'data'),
      ),
    ).thenReturn(null);
    when(
      () => logger.error(
        any(),
        context: any(named: 'context'),
        error: any(named: 'error'),
        stackTrace: any(named: 'stackTrace'),
        data: any(named: 'data'),
      ),
    ).thenReturn(null);
    final sentry = MockSentryReporter();
    when(
      () => sentry.reportNetworkError(
        any(),
        url: any(named: 'url'),
        method: any(named: 'method'),
        statusCode: any(named: 'statusCode'),
        timeout: any(named: 'timeout'),
        stackTrace: any(named: 'stackTrace'),
      ),
    ).thenAnswer((_) async {});

    // Hand-built against the in-memory DB and a mock client, exactly like
    // the undo seam test: the providers reach for Supabase.instance.
    repository = ActivitiesRepository(
      supabase: MockSupabaseClient(),
      database: database,
      logger: logger,
      sentry: sentry,
      deduplicationService: MockActivityDeduplicationService(),
    );
    final service = ActivitiesService(
      database,
      logger,
      repository,
      MockCoachRepository(),
    );
    container = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(database),
        appLoggerProvider.overrideWithValue(logger),
        activitiesRepositoryProvider.overrideWithValue(repository),
        activitiesServiceProvider.overrideWithValue(service),
        schemaRecoveryServiceProvider.overrideWithValue(
          PassthroughSchemaRecovery(),
        ),
      ],
    );
    addTearDown(container.dispose);
  });

  tearDown(() => database.close());

  Future<Activity> seed(ActivityType type, String title, int hour) async {
    final now = DateTime.now();
    return repository.insertActivity(
      Activity(
        id: '',
        userId: userId,
        activityType: type,
        title: title,
        scheduledDateTime: DateTime(day.year, day.month, day.day, hour),
        durationMinutes: 60,
        createdAt: now,
        updatedAt: now,
      ),
    );
  }

  Future<db.Activity> row(String id) => (database.select(
    database.activitiesTable,
  )..where((t) => t.id.equals(id))).getSingle();

  test('create -> ungroup -> regroup through the real notifier: legs end up '
      'on the NEW brick and its archived-leg reader sees both', () async {
    final swim = await seed(ActivityType.swimming, 'Swim', 7);
    final run = await seed(ActivityType.running, '12 mi Run', 11);
    final notifier = container.read(brickActionsControllerProvider.notifier);

    final brick1 = await notifier.createBrickFromSelection(
      activities: [swim, run],
      segmentOrder: const ['swimming', 'running'],
    );
    expect(brick1.activityType, ActivityType.brick);

    await notifier.ungroupBrick(brick1.id);
    for (final leg in [swim, run]) {
      final r = await row(leg.id);
      expect(r.status, 'planned', reason: 'ungroup gives every leg back');
      expect(r.brickId, isNull);
      expect(r.deletedAt, isNull);
    }
    expect((await row(brick1.id)).status, 'deleted');

    // Regroup with the legs as they now are (the dashboard re-reads them).
    final legs = [
      (await repository.getActivityById(userId, swim.id))!,
      (await repository.getActivityById(userId, run.id))!,
    ];
    final brick2 = await notifier.createBrickFromSelection(
      activities: legs,
      segmentOrder: const ['swimming', 'running'],
    );

    expect(brick2.activityType, ActivityType.brick);
    expect(brick2.id, isNot(brick1.id));
    for (final leg in [swim, run]) {
      final r = await row(leg.id);
      expect(r.brickId, brick2.id, reason: 'legs point at the NEW brick');
      expect(r.status, 'archived_for_brick');
      expect(r.deletedAt, isNull);
    }

    final onNew = await repository.getArchivedActivitiesForBrick(brick2.id);
    expect(onNew.map((a) => a.id).toSet(), {swim.id, run.id});
    final onOld = await repository.getArchivedActivitiesForBrick(brick1.id);
    expect(onOld, isEmpty, reason: 'nothing is still archived against brick1');
    expect((await row(brick1.id)).status, 'deleted');
  });
}
