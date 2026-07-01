/// Regression tests for migration idempotency (re-run safety).
///
/// On WEB, the persisted `user_version` does not reliably advance after a
/// migration commits (drift wasm / IndexedDB quirk), so drift re-runs the same
/// `from < N` step on the next launch. Before the fix this threw
/// `SqliteException: duplicate column name: coach_insight_text` during
/// `ALTER TABLE personal_formulas ADD COLUMN ...`, which tripped the recovery
/// path — fatal on web ("Database file path not available on web") → the app
/// showed "Something went wrong" and would not boot.
///
/// The migration must now be a no-op when the target schema already exists.
library;

import 'package:drift/drift.dart';
import 'package:mealvana_endurance/shared/database/app_database.dart';
import 'package:test/test.dart';

void main() {
  group('migration idempotency (re-run safety)', () {
    test('re-running onUpgrade from v11 is a no-op when the v12 columns exist',
        () async {
      // onCreate builds the CURRENT schema, so coach_insight_text already exists.
      final db = AppDatabase.memory();
      addTearDown(db.close);

      final before =
          await db.customSelect('PRAGMA table_info(personal_formulas)').get();
      expect(
        before.any((r) => r.read<String>('name') == 'coach_insight_text'),
        isTrue,
        reason: 'onCreate should have produced the v12 column',
      );

      // Simulate the web re-run: user_version stuck at 11, onUpgrade fires again.
      // Before the fix this threw "duplicate column name: coach_insight_text".
      await expectLater(
        db.migration.onUpgrade!(db.createMigrator(), 11, db.schemaVersion),
        completes,
      );

      final after =
          await db.customSelect('PRAGMA table_info(personal_formulas)').get();
      expect(after.any((r) => r.read<String>('name') == 'coach_insight_text'),
          isTrue);
      expect(after.any((r) => r.read<String>('name') == 'coach_insight_marker'),
          isTrue);
    });

    test('re-running the full ladder (from v6) is idempotent', () async {
      final db = AppDatabase.memory();
      addTearDown(db.close);

      // Every add-column / create-table step should skip because the current
      // schema already contains them. No "duplicate column" / "table exists".
      await expectLater(
        db.migration.onUpgrade!(db.createMigrator(), 6, db.schemaVersion),
        completes,
      );

      // Tables the ladder creates are still present + queryable.
      for (final t in ['personal_formulas', 'meal_logs', 'formula_pins']) {
        final rows = await db
            .customSelect(
              "SELECT name FROM sqlite_master WHERE type='table' AND name = ?",
              variables: [Variable.withString(t)],
            )
            .get();
        expect(rows, isNotEmpty, reason: '$t should exist after re-run');
      }
    });
  });
}
