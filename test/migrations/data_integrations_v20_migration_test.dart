/// Tests for the v20 data-integrations@v1 capture columns
/// (Q-INT26; Supabase migration 20260911150000).
///
/// Covers, in the repo's migration-test shape (see
/// rerun_migration_idempotency_test.dart):
///  - onCreate produces the new activities + integrations columns
///  - a v19 install gets every column from the `from < 20` step
///  - replaying the v18→v20 ladder is a no-op when the columns exist (web
///    `user_version` re-run safety)
///  - the new activity fields round-trip through the companion, and null
///    stays null (DI-13: never fabricate, null != 0)
library;

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:mealvana_endurance/shared/database/app_database.dart';
import 'package:test/test.dart';

Future<Set<String>> _columns(AppDatabase db, String table) async {
  final rows = await db.customSelect('PRAGMA table_info($table)').get();
  return rows.map((r) => r.read<String>('name')).toSet();
}

const _newActivityColumns = {
  'tss_planned',
  'tss_actual',
  'if_planned',
  'if_actual',
  'tp_calories',
  'tp_calories_planned',
  'parent_summary_id',
  'is_parent',
};

const _newIntegrationColumns = {'provider_is_premium', 'athlete_metrics_json'};

/// Rewind a fresh (v20) in-memory database to the v19 shape: SQLite 3.35+
/// supports DROP COLUMN for these plain nullable columns.
Future<void> _rewindToV19(AppDatabase db) async {
  for (final col in _newActivityColumns) {
    await db.customStatement('ALTER TABLE activities DROP COLUMN $col');
  }
  for (final col in _newIntegrationColumns) {
    await db.customStatement('ALTER TABLE integrations DROP COLUMN $col');
  }
}

void main() {
  group('data-integrations capture columns (v20)', () {
    test('schemaVersion is 20', () async {
      final db = AppDatabase.memory();
      addTearDown(db.close);
      expect(db.schemaVersion, greaterThanOrEqualTo(20));
    });

    test('onCreate produces the new columns', () async {
      final db = AppDatabase.memory();
      addTearDown(db.close);

      expect(await _columns(db, 'activities'), containsAll(_newActivityColumns));
      expect(
        await _columns(db, 'integrations'),
        containsAll(_newIntegrationColumns),
      );
    });

    test('a v19 install gets every column from the from < 20 step', () async {
      final db = AppDatabase.memory();
      addTearDown(db.close);

      await _rewindToV19(db);
      expect(
        await _columns(db, 'activities'),
        isNot(contains('tss_planned')),
      );
      expect(
        await _columns(db, 'integrations'),
        isNot(contains('provider_is_premium')),
      );

      await db.migration.onUpgrade(db.createMigrator(), 19, db.schemaVersion);

      expect(await _columns(db, 'activities'), containsAll(_newActivityColumns));
      expect(
        await _columns(db, 'integrations'),
        containsAll(_newIntegrationColumns),
      );
    });

    test('re-running the ladder when the columns exist is a no-op', () async {
      final db = AppDatabase.memory();
      addTearDown(db.close);

      await expectLater(
        db.migration.onUpgrade(db.createMigrator(), 18, db.schemaVersion),
        completes,
      );
      // And again — the web user_version replay shape.
      await expectLater(
        db.migration.onUpgrade(db.createMigrator(), 18, db.schemaVersion),
        completes,
      );
      expect(await _columns(db, 'activities'), containsAll(_newActivityColumns));
    });

    test('capture fields round-trip; omitted fields stay null', () async {
      final db = AppDatabase.memory();
      addTearDown(db.close);
      final now = DateTime.utc(2026, 9, 11, 12);

      await db
          .into(db.activitiesTable)
          .insert(
            ActivitiesTableCompanion.insert(
              id: const Value('act-1'),
              userId: 'user-1',
              activityType: 'cycling',
              title: 'TP Ride',
              scheduledDateTime: now,
              createdAt: now,
              updatedAt: now,
              tssPlanned: const Value(85.0),
              ifPlanned: const Value(0.82),
              tpCaloriesPlanned: const Value(640.0),
              parentSummaryId: const Value('parent-123'),
              isParent: const Value(false),
              // tss_actual / if_actual / tp_calories deliberately omitted —
              // the basic-athlete shape.
            ),
          );

      final row = await (db.select(
        db.activitiesTable,
      )..where((t) => t.id.equals('act-1'))).getSingle();

      expect(row.tssPlanned, 85.0);
      expect(row.ifPlanned, 0.82);
      expect(row.tpCaloriesPlanned, 640.0);
      expect(row.parentSummaryId, 'parent-123');
      expect(row.isParent, isFalse);
      // Null-tolerance (DI-13): omitted provider fields stay null.
      expect(row.tssActual, isNull);
      expect(row.ifActual, isNull);
      expect(row.tpCalories, isNull);
    });
  });
}
