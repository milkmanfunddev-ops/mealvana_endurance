// Write-seam tests for the v2 unified-skip model (workout-card.md v2, Q-D6;
// platform-resolution.md SKIPPED addition 2026-08-17) against a REAL
// in-memory Drift database:
//   - Skip writes status='skipped', CLEARS actual_time (skipping asserts it
//     did not happen), never touches planned_time.
//   - Unskip returns status to planned; planned_time untouched.
//   - Mark-done on a skipped row leaves `skipped` (G1 recovery).
//   - A planned-workout provider re-sync (TP/FS/Runna merge path) preserves
//     planned_time / actual_time / calories_burned — a mark-done or Garmin
//     kcal must not silently revert on the next title tweak — while a
//     provider RESCHEDULE moves planned_time (scheduling owns it).
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/features/activities/application/activity_deduplication_service.dart';
import 'package:mealvana_endurance/features/activities/data/activities_repository.dart';
import 'package:mealvana_endurance/features/activities/domain/activity.dart';
import 'package:mealvana_endurance/shared/database/app_database.dart'
    as db
    show AppDatabase, ActivitiesTableCompanion, Activity;
import 'package:mealvana_endurance/shared/domain/activity_type.dart';
import 'package:mealvana_endurance/shared/services/logging_service.dart';
import 'package:mealvana_endurance/shared/services/sentry/sentry_reporter.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MockSupabaseClient extends Mock implements SupabaseClient {}

class MockAppLogger extends Mock implements AppLogger {}

class MockSentryReporter extends Mock implements SentryReporter {}

class MockActivityDeduplicationService extends Mock
    implements ActivityDeduplicationService {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late db.AppDatabase database;
  late ActivitiesRepository repository;

  const userId = 'user-skip';
  final plannedAt = DateTime(2026, 8, 14, 17, 30);

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    database = db.AppDatabase.forTesting(NativeDatabase.memory());
    final logger = MockAppLogger();
    final sentry = MockSentryReporter();
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
    repository = ActivitiesRepository(
      supabase: MockSupabaseClient(),
      database: database,
      logger: logger,
      sentry: sentry,
      deduplicationService: MockActivityDeduplicationService(),
    );
  });

  tearDown(() => database.close());

  Future<Activity> seedPlannedRun() async {
    final now = DateTime.now();
    return repository.insertActivity(
      Activity(
        id: '',
        userId: userId,
        activityType: ActivityType.running,
        title: 'Run',
        scheduledDateTime: plannedAt,
        durationMinutes: 90,
        createdAt: now,
        updatedAt: now,
      ),
    );
  }

  Future<db.Activity> row(String id) => (database.select(
    database.activitiesTable,
  )..where((t) => t.id.equals(id))).getSingle();

  group('Skip / Unskip write seam (G5)', () {
    test(
      'skip writes status=skipped, clears actual_time, keeps planned_time',
      () async {
        final run = await seedPlannedRun();
        expect(
          (await row(run.id)).plannedTime,
          plannedAt,
          reason: 'forInsert stamps planned_time from the schedule',
        );

        // Skip a DONE_CONFIRMED card: actual_time must be CLEARED.
        await repository.markWorkoutDone(
          activityId: run.id,
          at: DateTime(2026, 8, 14, 15, 0),
        );
        expect((await row(run.id)).actualTime, isNotNull);

        await repository.skipWorkout(activityId: run.id);
        final skipped = await row(run.id);
        expect(skipped.status, 'skipped');
        expect(
          skipped.actualTime,
          isNull,
          reason: 'skipping asserts it did not happen',
        );
        expect(skipped.completedAt, isNull);
        expect(
          skipped.plannedTime,
          plannedAt,
          reason: 'planned_time is never touched by any gesture',
        );
        expect(skipped.needsUpload, isTrue, reason: 'offline-first: dirty');
      },
    );

    test('unskip returns status to planned; planned_time untouched', () async {
      final run = await seedPlannedRun();
      await repository.skipWorkout(activityId: run.id);
      await repository.unskipWorkout(activityId: run.id);
      final r = await row(run.id);
      expect(r.status, 'planned');
      expect(r.actualTime, isNull);
      expect(r.plannedTime, plannedAt);
      expect(r.needsUpload, isTrue);
    });

    test('mark-done on a skipped row leaves skipped (G1 recovery)', () async {
      final run = await seedPlannedRun();
      await repository.skipWorkout(activityId: run.id);
      final at = DateTime(2026, 8, 14, 15, 0);
      await repository.markWorkoutDone(activityId: run.id, at: at);
      final r = await row(run.id);
      expect(r.status, 'completed');
      expect(r.actualTime, at);
      expect(r.plannedTime, plannedAt);
    });

    test(
      'mark-done without an explicit time writes actual_time = planned_time',
      () async {
        // Ruled 2026-08-18 (spec owner; app ahead of the SSOT fold — qa intake
        // 2026-08-18-mark-done-on-non-current-day.md): the confirmation says
        // "it happened as planned", so the row keeps its day and slot — a
        // past-day un-synced run confirmed today must NOT land on today.
        final run = await seedPlannedRun();
        await repository.markWorkoutDone(activityId: run.id);
        final r = await row(run.id);
        expect(r.status, 'completed');
        expect(
          r.actualTime,
          plannedAt,
          reason: 'actual_time = planned_time, never the wall clock',
        );
        expect(r.plannedTime, plannedAt);
      },
    );

    test('nothing in the skip path writes the delete tombstone', () async {
      final run = await seedPlannedRun();
      await repository.skipWorkout(activityId: run.id);
      final r = await row(run.id);
      expect(r.status, isNot('deleted'));
      expect(r.deletedAt, isNull);
    });
  });

  /// What a TP/FS/Runna transformer hands the repository: a fresh Activity
  /// with the provider's fields and NO two-time / kcal fields (they are
  /// local- or Garmin-owned).
  Activity providerIncoming(
    String id, {
    String title = 'Run',
    DateTime? scheduledDateTime,
  }) {
    final now = DateTime.now();
    return Activity(
      id: id,
      userId: userId,
      activityType: ActivityType.running,
      title: title,
      scheduledDateTime: scheduledDateTime ?? plannedAt,
      durationMinutes: 90,
      syncedFromProvider: 'training_peaks',
      providerWorkoutId: 'tp-1',
      createdAt: now,
      updatedAt: now,
    );
  }

  group('provider re-sync merge preserves the two-time model', () {
    test(
      'a title-only TP update keeps planned/actual time and measured kcal',
      () async {
        final run = await seedPlannedRun();
        final doneAt = DateTime(2026, 8, 14, 15, 0);
        await repository.markWorkoutDone(activityId: run.id, at: doneAt);
        // Mirror a measured kcal onto the row (Garmin ladder rung).
        await (database.update(
          database.activitiesTable,
        )..where((t) => t.id.equals(run.id))).write(
          const db.ActivitiesTableCompanion(caloriesBurned: Value(1180)),
        );

        await repository.updateActivityFromProvider(
          providerIncoming(run.id, title: 'Tempo run (renamed in TP)'),
        );

        final r = await row(run.id);
        expect(r.title, 'Tempo run (renamed in TP)');
        expect(r.plannedTime, plannedAt);
        expect(
          r.actualTime,
          doneAt,
          reason: 'a planned-workout provider update never clears mark-done',
        );
        expect(r.caloriesBurned, 1180);
        expect(r.status, 'completed', reason: 'local status is preserved');
      },
    );

    test(
      'a provider RESCHEDULE moves planned_time (scheduling owns it)',
      () async {
        final run = await seedPlannedRun();
        final moved = DateTime(2026, 8, 14, 19, 0);
        await repository.updateActivityFromProvider(
          providerIncoming(run.id, scheduledDateTime: moved),
        );
        final r = await row(run.id);
        expect(r.scheduledDateTime, moved);
        expect(r.plannedTime, moved);
      },
    );
  });
}
