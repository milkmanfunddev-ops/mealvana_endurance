/// Tests for the v23 schema step: `activities.completion_type`, the local
/// mirror of the Supabase column (testing-wave ticket 99,
/// final-surge-completion.PROPOSED.md).
///
/// Same shape as home_location_v22_migration_test.dart:
///  - onCreate produces the column
///  - a v22 install gets it from the `from < 23` step
///  - replaying that step is a no-op (web `user_version` re-run safety)
library;

import 'package:mealvana_endurance/shared/database/app_database.dart';
import 'package:test/test.dart';

Future<Set<String>> _columns(AppDatabase db, String table) async {
  final rows = await db.customSelect('PRAGMA table_info($table)').get();
  return rows.map((r) => r.read<String>('name')).toSet();
}

void main() {
  group('completion_type (v23)', () {
    test('schemaVersion is at least 23', () async {
      final db = AppDatabase.memory();
      addTearDown(db.close);
      expect(db.schemaVersion, greaterThanOrEqualTo(23));
    });

    test('onCreate produces activities.completion_type', () async {
      final db = AppDatabase.memory();
      addTearDown(db.close);
      expect(await _columns(db, 'activities'), contains('completion_type'));
    });

    test('a v22 install gains it, and the step replays safely', () async {
      final db = AppDatabase.memory();
      addTearDown(db.close);

      await db.customStatement(
        'ALTER TABLE activities DROP COLUMN completion_type',
      );
      expect(
        await _columns(db, 'activities'),
        isNot(contains('completion_type')),
        reason: 'rewind must actually remove the column for this to prove '
            'anything',
      );

      await db.migration.onUpgrade(db.createMigrator(), 22, db.schemaVersion);
      expect(await _columns(db, 'activities'), contains('completion_type'));

      await expectLater(
        db.migration.onUpgrade(db.createMigrator(), 22, db.schemaVersion),
        completes,
      );
      expect(await _columns(db, 'activities'), contains('completion_type'));
    });
  });
}
