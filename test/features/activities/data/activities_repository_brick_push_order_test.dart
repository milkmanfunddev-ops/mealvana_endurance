// Remote-push seam for brick group/ungroup, against a REAL in-memory Drift
// database and a recording fake of `supabase.from('activities')`.
//
// Born from the 2026-10-07 dashboard ghost brick: ungroup pushed ONLY the
// brick tombstone and left the restored legs merely dirty; regroup pushed
// NOTHING. The server therefore held tombstoned brick1 + legs still archived
// against brick1 + no brick2 until the next dirty sweep. Two seams pinned:
//   - createBrickFromActivities pushes the brick FIRST, then every leg
//     (legs reference the brick — fk_activities_brick_id — so the parent
//     must exist remotely before a leg pointing at it is upserted);
//   - ungroupBrick pushes the restored legs BEFORE the brick tombstone.
// Plus the on-disk status spelling: toCompanion writes the Postgres enum
// value ('archived_for_brick'), and the archived-leg reader keeps finding
// legacy camelCase rows.
import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/features/activities/application/activity_deduplication_service.dart';
import 'package:mealvana_endurance/features/activities/data/activities_repository.dart';
import 'package:mealvana_endurance/features/activities/data/activity_mapper.dart';
import 'package:mealvana_endurance/features/activities/domain/activity.dart';
import 'package:mealvana_endurance/shared/database/app_database.dart'
    as db
    show AppDatabase, Activity;
import 'package:mealvana_endurance/shared/domain/activity_type.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../helpers/fakes/recording_report.dart';

class MockSupabaseClient extends Mock implements SupabaseClient {}

class MockActivityDeduplicationService extends Mock
    implements ActivityDeduplicationService {}

/// `supabase.from('activities')` stand-in: records every upsert payload in
/// arrival order and acknowledges it (the tombstone path awaits
/// `.upsert(..).select('id')` and demands a non-empty row list). Inserts
/// (the seed path) are acknowledged but not recorded.
class _RecordingQueryBuilder extends Fake implements SupabaseQueryBuilder {
  final List<Map<String, dynamic>> upserts = [];

  List<String> get upsertedIds =>
      upserts.map((p) => p['id'] as String).toList();

  @override
  PostgrestFilterBuilder<dynamic> insert(
    Object values, {
    bool defaultToNull = true,
  }) => _AckBuilder(const []);

  @override
  PostgrestFilterBuilder<dynamic> upsert(
    Object values, {
    String? onConflict,
    bool ignoreDuplicates = false,
    bool defaultToNull = true,
  }) {
    final payload = Map<String, dynamic>.from(values as Map);
    upserts.add(payload);
    return _AckBuilder([
      {'id': payload['id']},
    ]);
  }
}

class _AckBuilder extends Fake
    implements PostgrestFilterBuilder<PostgrestList> {
  _AckBuilder(this._rows);

  final PostgrestList _rows;

  @override
  PostgrestTransformBuilder<PostgrestList> select([String columns = '*']) =>
      this;

  @override
  Future<U> then<U>(
    FutureOr<U> Function(PostgrestList value) onValue, {
    Function? onError,
  }) => Future<PostgrestList>.value(_rows).then(onValue, onError: onError);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late db.AppDatabase database;
  late ActivitiesRepository repository;
  late ActivityMapper mapper;
  late _RecordingQueryBuilder remote;

  const userId = 'user-push-order';
  final day = DateTime(2026, 10, 7, 7, 0);

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    database = db.AppDatabase.forTesting(NativeDatabase.memory());
    final report = RecordingReport();

    remote = _RecordingQueryBuilder();
    final supabase = MockSupabaseClient();
    when(() => supabase.from('activities')).thenAnswer((_) => remote);

    mapper = ActivityMapper(report: report);
    repository = ActivitiesRepository(
      supabase: supabase,
      database: database,
      report: report,
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

  Future<db.Activity> row(String id) => (database.select(
    database.activitiesTable,
  )..where((t) => t.id.equals(id))).getSingle();

  /// The pushes are fire-and-forget (unawaited after the transaction), so
  /// wait for the recorder to see [count] upserts — bounded, never forever.
  Future<void> pumpUntilUpserts(int count) async {
    for (var i = 0; i < 400 && remote.upserts.length < count; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
  }

  group('createBrickFromActivities pushes the whole write set, brick first',
      () {
    test('upsert order is [brick, legA, legB]; every row leaves dirty',
        () async {
      final swim = await seed(ActivityType.swimming, 'Swim', 7);
      final run = await seed(ActivityType.running, 'Run', 11);
      remote.upserts.clear();

      final brick = await repository.createBrickFromActivities(
        activities: [swim, run],
        segmentOrder: const ['swimming', 'running'],
      );
      await pumpUntilUpserts(3);

      expect(
        remote.upsertedIds,
        [brick.id, swim.id, run.id],
        reason:
            'the brick row must exist remotely before a leg referencing it '
            '(fk_activities_brick_id) is upserted; before the fix NOTHING '
            'was pushed here',
      );

      // The legs went up pointing at the brick, in the Postgres spelling.
      for (final leg in remote.upserts.skip(1)) {
        expect(leg['brick_id'], brick.id);
        expect(leg['status'], 'archived_for_brick');
      }

      // The push acknowledged, so the dirty flags are clear — nothing is
      // left for the next uploadDirtyRecords sweep.
      for (final id in [brick.id, swim.id, run.id]) {
        expect((await row(id)).needsUpload, isFalse, reason: id);
      }
    });
  });

  group('ungroupBrick pushes the restored legs BEFORE the tombstone', () {
    test('upsert order is [legA, legB, brick tombstone]', () async {
      final swim = await seed(ActivityType.swimming, 'Swim', 7);
      final run = await seed(ActivityType.running, 'Run', 11);
      final brick = await repository.createBrickFromActivities(
        activities: [swim, run],
        segmentOrder: const ['swimming', 'running'],
      );
      await pumpUntilUpserts(3);
      remote.upserts.clear();

      await repository.ungroupBrick(brick.id);
      await pumpUntilUpserts(3);

      expect(
        remote.upsertedIds,
        [swim.id, run.id, brick.id],
        reason:
            'before the fix only the tombstone went up and the legs stayed '
            'archived against a deleted brick on the server',
      );
      for (final leg in remote.upserts.take(2)) {
        expect(leg['status'], 'planned');
        expect(leg['brick_id'], isNull);
      }
      expect(remote.upserts.last['status'], 'deleted');

      for (final id in [swim.id, run.id, brick.id]) {
        expect((await row(id)).needsUpload, isFalse, reason: id);
      }
    });

    test('ungroup -> regroup leaves the server pointing at the NEW brick '
        '(the dashboard ghost-brick scenario)', () async {
      final swim = await seed(ActivityType.swimming, 'Swim', 7);
      final run = await seed(ActivityType.running, 'Run', 11);
      final brick1 = await repository.createBrickFromActivities(
        activities: [swim, run],
        segmentOrder: const ['swimming', 'running'],
      );
      await pumpUntilUpserts(3);

      await repository.ungroupBrick(brick1.id);
      await pumpUntilUpserts(6);
      remote.upserts.clear();

      final legs = [
        (await repository.getActivityById(userId, swim.id))!,
        (await repository.getActivityById(userId, run.id))!,
      ];
      final brick2 = await repository.createBrickFromActivities(
        activities: legs,
        segmentOrder: const ['swimming', 'running'],
      );
      await pumpUntilUpserts(3);

      expect(brick2.id, isNot(brick1.id));
      expect(remote.upsertedIds, [brick2.id, swim.id, run.id]);
      for (final leg in remote.upserts.skip(1)) {
        expect(leg['brick_id'], brick2.id, reason: 'never brick1');
        expect(leg['status'], 'archived_for_brick');
      }
    });
  });

  group('one status spelling on disk', () {
    test('toCompanion writes the Postgres enum value, not the Dart name',
        () {
      final now = DateTime.now();
      Activity withStatus(ActivityStatus status) => Activity(
        id: 'a1',
        userId: userId,
        activityType: ActivityType.running,
        title: 'Run',
        scheduledDateTime: day,
        status: status,
        createdAt: now,
        updatedAt: now,
      );

      expect(
        mapper.toCompanion(withStatus(ActivityStatus.archivedForBrick)).status
            .value,
        'archived_for_brick',
      );
      expect(
        mapper.toCompanion(withStatus(ActivityStatus.inProgress)).status.value,
        'in_progress',
      );
      expect(
        mapper.toCompanion(withStatus(ActivityStatus.planned)).status.value,
        'planned',
      );
    });

    test('brick creation lands archived_for_brick on the leg rows', () async {
      final swim = await seed(ActivityType.swimming, 'Swim', 7);
      final run = await seed(ActivityType.running, 'Run', 11);
      await repository.createBrickFromActivities(
        activities: [swim, run],
        segmentOrder: const ['swimming', 'running'],
      );
      expect((await row(swim.id)).status, 'archived_for_brick');
      expect((await row(run.id)).status, 'archived_for_brick');
    });

    test('the archived-leg reader still finds legacy camelCase rows',
        () async {
      final swim = await seed(ActivityType.swimming, 'Swim', 7);
      final run = await seed(ActivityType.running, 'Run', 11);
      await database.customStatement(
        "UPDATE activities SET status = 'archivedForBrick', "
        "brick_id = 'legacy-brick' WHERE id IN ('${swim.id}', '${run.id}')",
      );

      final found = await repository.getArchivedActivitiesForBrick(
        'legacy-brick',
      );
      expect(found.map((a) => a.id), [swim.id, run.id]);
      expect(
        found.map((a) => a.status).toSet(),
        {ActivityStatus.archivedForBrick},
      );
    });
  });
}
