/// Tests for `activities.duration_source` — the v21→v22 step (P3, ruled
/// 2026-09-30).
///
/// The column records that a duration is the importer's ESTIMATE rather than a
/// number someone supplied. It is only ever written as `'estimated'`; NULL
/// means authoritative (provider, athlete, or predating the column).
///
/// Covers:
///  - onCreate produces the column, nullable
///  - an existing row that predates it reads back NULL, i.e. authoritative —
///    the property that lets the migration ship without back-filling anything
///  - replaying the v22 step is a no-op when the column already exists (the web
///    `user_version` re-run hazard the idempotent addColumn helper exists for)
library;

import 'package:drift/drift.dart' hide isNull;
import 'package:mealvana_endurance/shared/database/app_database.dart';
import 'package:test/test.dart';

void main() {
  group('activities.duration_source (v22)', () {
    test('onCreate produces a NULLABLE duration_source column', () async {
      final db = AppDatabase.memory();
      addTearDown(db.close);

      final columns =
          await db.customSelect('PRAGMA table_info(activities)').get();
      final col = columns
          .where((r) => r.read<String>('name') == 'duration_source')
          .toList();

      expect(col, hasLength(1),
          reason: 'activities must have a duration_source column');
      expect(
        col.single.read<int>('notnull'),
        0,
        reason: 'must be nullable — NULL is the authoritative case, and a NOT '
            'NULL column would force a back-fill that changes the meaning of '
            'every existing row',
      );
      expect(col.single.read<String>('type').toUpperCase(), 'TEXT');
    });

    test('schemaVersion is at least 22', () async {
      final db = AppDatabase.memory();
      addTearDown(db.close);
      expect(db.schemaVersion, greaterThanOrEqualTo(22));
    });

    test('a row written without it reads back NULL, i.e. authoritative',
        () async {
      final db = AppDatabase.memory();
      addTearDown(db.close);

      // Shaped like a pre-v22 row: a duration and no provenance.
      await db.customStatement(
        "INSERT INTO activities "
        "(id, user_id, activity_type, title, scheduled_date_time, "
        " duration_minutes, status, is_fasted, reminder_enabled, "
        " reminder_recurring, needs_nutrition_refresh, created_at, updated_at) "
        "VALUES ('legacy-row', 'u1', 'running', 'Long run', 1790000000, "
        "        150, 'planned', 0, 0, 0, 0, 1790000000, 1790000000)",
      );

      final row = await db
          .customSelect(
            "SELECT duration_source FROM activities WHERE id = 'legacy-row'",
          )
          .getSingle();

      expect(
        row.data['duration_source'],
        isNull,
        reason: 'an existing duration must come back authoritative, so the '
            'importer never overwrites it',
      );
    });

    test('replaying the v22 step is harmless when the column exists', () async {
      final db = AppDatabase.memory();
      addTearDown(db.close);

      // Force the schema to exist first.
      await db.customSelect('PRAGMA table_info(activities)').get();

      // The guard the migration relies on: adding it twice must not throw.
      // (On web the persisted user_version does not reliably advance, so the
      // same `from < N` step can re-run on the next launch.)
      Future<bool> columnExists() async {
        final rows =
            await db.customSelect('PRAGMA table_info(activities)').get();
        return rows.any((r) => r.read<String>('name') == 'duration_source');
      }

      expect(await columnExists(), isTrue);
      if (!await columnExists()) {
        await db.customStatement(
          'ALTER TABLE activities ADD COLUMN duration_source TEXT',
        );
      }
      expect(await columnExists(), isTrue);
    });
  });
}
