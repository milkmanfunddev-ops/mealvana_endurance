// Write-seam regression tests for brick ungroup, against a REAL in-memory
// Drift database. Born from the 2026-09-11 prod data loss (ops intake of the
// same date): the create-undo was armed with a LEG id instead of the brick's,
// and ungroupBrick — which restores-then-deletes — happily hard-deleted the
// real workout while restoring nothing. Three seams pinned:
//   - ungroupBrick REFUSES a non-brick target (throws, writes nothing);
//   - ungroup restores every archived leg and TOMBSTONES the brick (the old
//     hard delete made the server-side delete a silent no-op, because the
//     tombstone upload builds its payload by reading the local row);
//   - a created-from-existing brick with no archived legs to restore is an
//     integrity error, never a proceed-and-delete.
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

  const userId = 'user-ungroup';
  final day = DateTime(2026, 9, 11, 7, 0);

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

  Future<db.Activity?> row(String id) => (database.select(
    database.activitiesTable,
  )..where((t) => t.id.equals(id))).getSingleOrNull();

  group('ungroupBrick refuses non-brick targets (the 2026-09-11 data loss)', () {
    test('throws on a plain planned workout and writes NOTHING', () async {
      final swim = await seed(ActivityType.swimming, 'Swim', 7);

      await expectLater(
        repository.ungroupBrick(swim.id),
        throwsA(isA<StateError>()),
      );

      final after = await row(swim.id);
      expect(after, isNotNull, reason: 'the old code HARD-DELETED the row');
      expect(after!.status, 'planned');
      expect(after.deletedAt, isNull);
    });

    test('throws on an archived-for-brick LEG (the exact prod scenario: '
        'undo armed with a leg id)', () async {
      final swim = await seed(ActivityType.swimming, 'Swim', 7);
      final run = await seed(ActivityType.running, '12 mi Run', 11);
      final brick = await repository.createBrickFromActivities(
        activities: [swim, run],
        segmentOrder: const ['swimming', 'running'],
      );

      // The swim is now archivedForBrick — invisible chrome-side. Pointing
      // ungroup at IT (not the brick) must refuse, not silently delete.
      await expectLater(
        repository.ungroupBrick(swim.id),
        throwsA(isA<StateError>()),
      );

      final swimRow = await row(swim.id);
      expect(swimRow, isNotNull, reason: 'leg must survive the bad call');
      expect(swimRow!.brickId, brick.id, reason: 'still linked to its brick');

      // And the REAL ungroup still works afterwards: everything comes back.
      await repository.ungroupBrick(brick.id);
      expect((await row(swim.id))!.status, 'planned');
      expect((await row(run.id))!.status, 'planned');
    });
  });

  group('ungroup restores legs and tombstones the brick', () {
    test('all legs return to planned; brick row persists as a tombstone '
        'with needs_upload (NOT hard-deleted)', () async {
      final swim = await seed(ActivityType.swimming, 'Swim', 7);
      final run = await seed(ActivityType.running, '12 mi Run', 11);
      final ride = await seed(ActivityType.cycling, '25 mi Ride', 12);
      final brick = await repository.createBrickFromActivities(
        activities: [swim, run, ride],
        segmentOrder: const ['swimming', 'running', 'cycling'],
      );

      await repository.ungroupBrick(brick.id);

      for (final leg in [swim, run, ride]) {
        final r = await row(leg.id);
        expect(r!.status, 'planned');
        expect(r.brickId, isNull);
        expect(r.needsUpload, isTrue, reason: 'restore must sync up');
      }

      final brickRow = await row(brick.id);
      expect(
        brickRow,
        isNotNull,
        reason:
            'hard-deleting the brick starved _uploadActivityDeletion of its '
            'payload row — the server never heard about the delete',
      );
      expect(brickRow!.status, 'deleted');
      expect(brickRow.deletedAt, isNotNull);
      expect(brickRow.needsUpload, isTrue);
    });

    test('a from-existing brick with no archived legs to restore is an '
        'integrity error, not a proceed-and-delete', () async {
      final swim = await seed(ActivityType.swimming, 'Swim', 7);
      final run = await seed(ActivityType.running, 'Run', 11);
      final brick = await repository.createBrickFromActivities(
        activities: [swim, run],
        segmentOrder: const ['swimming', 'running'],
      );

      // Simulate the ghost/clobber state: the legs lost their archive
      // status (e.g. a sync pull overwrote them) — nothing left to restore.
      await (database.update(
        database.activitiesTable,
      )..where((t) => t.brickId.equals(brick.id))).write(
        const db.ActivitiesTableCompanion(
          status: Value('planned'),
          brickId: Value(null),
        ),
      );

      await expectLater(
        repository.ungroupBrick(brick.id),
        throwsA(isA<StateError>()),
      );

      final brickRow = await row(brick.id);
      expect(brickRow, isNotNull, reason: 'brick untouched on refusal');
      expect(brickRow!.deletedAt, isNull);
    });
  });
}
