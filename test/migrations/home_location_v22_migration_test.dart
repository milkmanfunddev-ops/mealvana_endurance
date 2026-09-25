/// Tests for the v22 home-location schema step (v21 until develop's 2026-09-16 merge renumbered it) (`.scratch/mealplanning`
/// ticket 02).
///
/// Same shape as meal_planning_v20_migration_test.dart:
///  - onCreate produces the four `users` columns
///  - a v21 install gets them from the `from < 22` step
///  - replaying that step is a no-op (web `user_version` re-run safety)
library;

import 'package:mealvana_endurance/shared/database/app_database.dart';
import 'package:test/test.dart';

Future<Set<String>> _columns(AppDatabase db, String table) async {
  final rows = await db.customSelect('PRAGMA table_info($table)').get();
  return rows.map((r) => r.read<String>('name')).toSet();
}

const _homeColumns = ['home_city', 'home_lat', 'home_lon', 'home_timezone'];

void main() {
  group('home location (v22)', () {
    test('schemaVersion is at least 22', () async {
      final db = AppDatabase.memory();
      addTearDown(db.close);
      expect(db.schemaVersion, greaterThanOrEqualTo(22));
    });

    test('onCreate produces the four home columns on users', () async {
      final db = AppDatabase.memory();
      addTearDown(db.close);

      expect(await _columns(db, 'users'), containsAll(_homeColumns));
    });

    test('a v20 install gains them, and the step replays safely', () async {
      final db = AppDatabase.memory();
      addTearDown(db.close);

      // Rewind to the v20 shape. SQLite in this Dart build has DROP COLUMN
      // (3.35+), which is what the addColumn guard is written against.
      for (final column in _homeColumns) {
        await db.customStatement('ALTER TABLE users DROP COLUMN $column');
      }
      expect(
        await _columns(db, 'users'),
        isNot(contains('home_city')),
        reason: 'rewind must actually remove the columns for this to prove '
            'anything',
      );

      await db.migration.onUpgrade(db.createMigrator(), 21, db.schemaVersion);
      expect(await _columns(db, 'users'), containsAll(_homeColumns));

      // And again — the web user_version replay shape.
      await expectLater(
        db.migration.onUpgrade(db.createMigrator(), 21, db.schemaVersion),
        completes,
      );
      expect(await _columns(db, 'users'), containsAll(_homeColumns));
    });
  });
}
