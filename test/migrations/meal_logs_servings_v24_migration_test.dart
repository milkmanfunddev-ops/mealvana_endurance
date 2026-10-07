/// Tests for the v24 schema step: `meal_logs.servings`, the local mirror of
/// Supabase migration 20260926163500 (mealplanning testing-wave ticket 135,
/// backported by develop-2026-10 ticket 29).
///
/// Same shape as completion_type_v23_migration_test.dart:
///  - onCreate produces the column
///  - a v23 install gets it from the `from < 24` step, existing rows at 1.0
///  - replaying that step is a no-op (web `user_version` re-run safety)
///  - a mealplanning-lineage v23 install also gains duration_source
library;

import 'package:mealvana_endurance/shared/database/app_database.dart';
import 'package:test/test.dart';

Future<Set<String>> _columns(AppDatabase db, String table) async {
  final rows = await db.customSelect('PRAGMA table_info($table)').get();
  return rows.map((r) => r.read<String>('name')).toSet();
}

void main() {
  group('meal_logs.servings (v24)', () {
    test('schemaVersion is at least 24', () async {
      final db = AppDatabase.memory();
      addTearDown(db.close);
      expect(db.schemaVersion, greaterThanOrEqualTo(24));
    });

    test('onCreate produces meal_logs.servings', () async {
      final db = AppDatabase.memory();
      addTearDown(db.close);
      expect(await _columns(db, 'meal_logs'), contains('servings'));
    });

    test('a v23 install gains it at 1.0, and the step replays safely',
        () async {
      final db = AppDatabase.memory();
      addTearDown(db.close);

      await db.customStatement('ALTER TABLE meal_logs DROP COLUMN servings');
      expect(
        await _columns(db, 'meal_logs'),
        isNot(contains('servings')),
        reason: 'rewind must actually remove the column for this to prove '
            'anything',
      );
      await db.customStatement(
        "INSERT INTO meal_logs (id, user_id, log_date, name, source, items, "
        "created_at, updated_at) VALUES ('m1', 'u1', '2026-09-26', 'Oats', "
        "'manual', '[]', 0, 0)",
      );

      await db.migration.onUpgrade(db.createMigrator(), 23, db.schemaVersion);
      expect(await _columns(db, 'meal_logs'), contains('servings'));
      final row = await db
          .customSelect("SELECT servings FROM meal_logs WHERE id = 'm1'")
          .getSingle();
      expect(row.read<double>('servings'), 1.0);

      await expectLater(
        db.migration.onUpgrade(db.createMigrator(), 23, db.schemaVersion),
        completes,
      );
      expect(await _columns(db, 'meal_logs'), contains('servings'));
    });

    test('a mealplanning-lineage v23 install also gains duration_source',
        () async {
      final db = AppDatabase.memory();
      addTearDown(db.close);

      await db.customStatement(
        'ALTER TABLE activities DROP COLUMN duration_source',
      );
      await db.migration.onUpgrade(db.createMigrator(), 23, db.schemaVersion);
      expect(await _columns(db, 'activities'), contains('duration_source'));
    });
  });
}
