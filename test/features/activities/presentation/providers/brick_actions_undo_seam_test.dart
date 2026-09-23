// Controller seam for the brick create→undo round trip, through the REAL
// notifier (docs/test/README.md §Seam tests: every controller write path
// gets one test through the real notifier).
//
// Born from the 2026-09-11 prod data loss: the create-undo snackbar re-derived
// the brick id from a just-invalidated provider and fell back to the FIRST
// SELECTED LEG's id, so Undo hard-deleted a real workout. The screen now arms
// Undo with the id `createBrickFromSelection` RETURNS — this test pins that
// the returned id names an actual brick and that undoing with it (the exact
// call the snackbar makes) restores every leg.
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

/// Pass-through recovery: runs the operation, no retry machinery. The seam
/// under test is the controller→service→repository write path, not schema
/// recovery.
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

  const userId = 'user-undo-seam';
  final day = DateTime(2026, 9, 11);

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

    // The repository/service providers reach for Supabase.instance, which
    // does not exist under test — hand-build both against the in-memory DB
    // and a mock client, exactly like the repository seam tests do.
    final repository = ActivitiesRepository(
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
    final repo = container.read(activitiesRepositoryProvider);
    final now = DateTime.now();
    return repo.insertActivity(
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

  Future<db.Activity?> row(String id) => (database.select(
    database.activitiesTable,
  )..where((t) => t.id.equals(id))).getSingleOrNull();

  test('create returns the BRICK (never a leg), and undoing with that id '
      'through the real notifier restores every leg', () async {
    final swim = await seed(ActivityType.swimming, 'Swim', 7);
    final run = await seed(ActivityType.running, '12 mi Run', 11);
    final ride = await seed(ActivityType.cycling, '25 mi Ride', 12);

    final notifier = container.read(brickActionsControllerProvider.notifier);

    final created = await notifier.createBrickFromSelection(
      activities: [swim, run, ride],
      segmentOrder: const ['swimming', 'running', 'cycling'],
    );

    // The id the snackbar arms its Undo with must name an actual brick —
    // not selected.first (the swim), which is what the old derivation
    // handed back every time the provider read was stale.
    expect(created.activityType, ActivityType.brick);
    expect(created.id, isNot(swim.id));
    expect(
      created.brickMetadata?.originalActivityIds,
      containsAll([swim.id, run.id, ride.id]),
    );

    // The exact call the Undo action makes.
    await notifier.ungroupBrick(created.id);

    for (final leg in [swim, run, ride]) {
      final r = await row(leg.id);
      expect(r!.status, 'planned', reason: 'every leg comes back');
      expect(r.deletedAt, isNull);
      expect(r.brickId, isNull);
    }
    expect((await row(created.id))!.status, 'deleted');
  });
}
