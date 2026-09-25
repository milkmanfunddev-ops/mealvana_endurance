// Ticket 101 (Lee's ruling 2026-09-25): an upload never sends 'manual' over
// a server 'provider'. After the v23 Drift migration a device's local
// `completion_type` is null for every row it already held, including rows the
// server knows FinalSurge completed. The old `completionType ?? 'manual'`
// sent 'manual' up and overwrote the server's 'provider'.
//
// PostgREST only updates the columns a request names (the union of the rows'
// keys, `columns=`). A row missing a key inside a MIXED bulk request gets NULL
// (postgrest-dart defaultToNull) or the column default 'manual'
// (missing=default) — both overwrite 'provider'. So a null completion_type is
// omitted, and one upsert request never mixes rows with and without it.
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/features/activities/application/activity_deduplication_service.dart';
import 'package:mealvana_endurance/features/activities/data/activities_repository.dart';
import 'package:mealvana_endurance/features/activities/data/activity_mapper.dart';
import 'package:mealvana_endurance/features/activities/domain/activity.dart'
    as domain;
import 'package:mealvana_endurance/features/integrations/application/final_surge_transformer.dart';
import 'package:mealvana_endurance/shared/database/app_database.dart';
import 'package:mealvana_endurance/shared/services/logging_service.dart';
import 'package:mealvana_endurance/shared/services/sync/entity_sync/activity_sync_handler.dart';

import '../../../fixtures/final_surge_completed_fixtures.dart';
import '../../../helpers/widget_test_harness.dart';

void main() {
  late AppDatabase database;
  late ActivitiesRepository repository;
  final mapper = ActivityMapper(logger: NoopAppLogger());

  setUp(() {
    database = AppDatabase.forTesting(NativeDatabase.memory());
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

  Future<Activity> row(String id) => (database.select(
    database.activitiesTable,
  )..where((t) => t.id.equals(id))).getSingle();

  /// The FinalSurge-completed row as a device that ran the v23 migration
  /// holds it: completed with the platform's actuals, completion_type null
  /// (the column was added empty; the server row says 'provider').
  Future<Activity> v23LegacyCompletedRow() async {
    final fromFeed = const FinalSurgeTransformer()
        .transform(fsCompletedEasy, 'u1')!
        .activity;
    final stored = await repository.insertActivity(fromFeed);
    await (database.update(database.activitiesTable)
          ..where((t) => t.id.equals(stored.id)))
        .write(const ActivitiesTableCompanion(completionType: Value(null)));
    final r = await row(stored.id);
    expect(r.status, 'completed');
    expect(r.completionType, isNull);
    return r;
  }

  test('dirty-row payload omits a null completion_type', () async {
    final r = await v23LegacyCompletedRow();
    final payload = mapper.buildUploadPayloadFromRow(r);
    expect(payload.containsKey('completion_type'), isFalse);
    expect(payload['status'], 'completed');
  });

  test('domain payload omits a null completion_type', () async {
    final r = await v23LegacyCompletedRow();
    final payload = mapper.buildSupabasePayload(mapper.fromDriftRow(r));
    expect(payload.containsKey('completion_type'), isFalse);
  });

  test('edge-function payload omits a null completion_type', () async {
    final r = await v23LegacyCompletedRow();
    final handler = ActivitySyncHandler(
      database: database,
      logger: NoopAppLogger(),
    );
    expect(handler.activityToJson(r).containsKey('completion_type'), isFalse);
  });

  test('a set completion_type still goes up as it is', () async {
    final fromFeed = const FinalSurgeTransformer()
        .transform(fsCompletedEasy, 'u1')!
        .activity;
    final stored = await repository.insertActivity(fromFeed);
    final r = await row(stored.id);
    expect(
      mapper.buildUploadPayloadFromRow(r)['completion_type'],
      domain.Activity.providerCompletionType,
    );
    final marked = r.copyWith(completionType: const Value('manual'));
    expect(
      mapper.buildUploadPayloadFromRow(marked)['completion_type'],
      'manual',
    );
  });

  test(
    'a bulk upload never mixes rows with and without completion_type',
    () async {
      final legacy = await v23LegacyCompletedRow();
      final provider = legacy.copyWith(
        id: 'fs-2',
        completionType: const Value('provider'),
      );
      final manual = legacy.copyWith(
        id: 'm-1',
        completionType: const Value('manual'),
      );
      final legacy2 = legacy.copyWith(id: 'legacy-2');

      final batches = ActivityMapper.uniformKeyBatches(
        [
          legacy,
          provider,
          manual,
          legacy2,
        ].map(mapper.buildUploadPayloadFromRow).toList(),
      );

      expect(batches, hasLength(2));
      for (final batch in batches) {
        final withKey = batch.where((p) => p.containsKey('completion_type'));
        expect(
          withKey.isEmpty || withKey.length == batch.length,
          isTrue,
          reason: 'a mixed request fills the missing key with NULL/manual',
        );
      }
      final ids = [
        for (final b in batches) [for (final p in b) p['id']],
      ];
      expect(
        ids,
        containsAll([
          [legacy.id, 'legacy-2'],
          ['fs-2', 'm-1'],
        ]),
      );
    },
  );
}
