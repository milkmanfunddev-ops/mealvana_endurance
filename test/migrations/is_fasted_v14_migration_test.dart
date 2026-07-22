/// Tests for the `activities.is_fasted` column folded into the v14 migration
/// step (v14 had not shipped when the column was added, so it shares the
/// existing `from < 14` step instead of bumping to v15).
///
/// Covers:
///  - onCreate produces the column (NOT NULL, default 0/false)
///  - inserts that omit the column read back `false`
///  - replaying the v13→v14 onUpgrade step is a no-op when the column already
///    exists (web `user_version` re-run safety — see
///    rerun_migration_idempotency_test.dart for the general pattern)
library;

import 'package:drift/drift.dart';
import 'package:mealvana_endurance/shared/database/app_database.dart';
import 'package:test/test.dart';

void main() {
  group('activities.is_fasted (v14 fold-in)', () {
    test('onCreate produces is_fasted as NOT NULL with default false', () async {
      final db = AppDatabase.memory();
      addTearDown(db.close);

      final columns = await db
          .customSelect('PRAGMA table_info(activities)')
          .get();
      final isFasted = columns
          .where((r) => r.read<String>('name') == 'is_fasted')
          .toList();

      expect(
        isFasted,
        hasLength(1),
        reason: 'activities table must have an is_fasted column',
      );
      expect(
        isFasted.single.read<int>('notnull'),
        1,
        reason: 'is_fasted must be NOT NULL',
      );
    });

    test('rows inserted without is_fasted default to false', () async {
      final db = AppDatabase.memory();
      addTearDown(db.close);

      final now = DateTime(2026, 7, 20, 6);
      await db
          .into(db.activitiesTable)
          .insert(
            ActivitiesTableCompanion.insert(
              id: const Value('activity-default-fasted'),
              userId: 'user-1',
              activityType: 'running',
              title: 'Morning Run',
              scheduledDateTime: now,
              createdAt: now,
              updatedAt: now,
            ),
          );

      final row = await (db.select(
        db.activitiesTable,
      )..where((tbl) => tbl.id.equals('activity-default-fasted'))).getSingle();

      expect(row.isFasted, isFalse);
    });

    test('is_fasted round-trips true through the Drift table', () async {
      final db = AppDatabase.memory();
      addTearDown(db.close);

      final now = DateTime(2026, 7, 20, 6);
      await db
          .into(db.activitiesTable)
          .insert(
            ActivitiesTableCompanion.insert(
              id: const Value('activity-fasted'),
              userId: 'user-1',
              activityType: 'running',
              title: 'Fasted Run',
              scheduledDateTime: now,
              isFasted: const Value(true),
              createdAt: now,
              updatedAt: now,
            ),
          );

      final row = await (db.select(
        db.activitiesTable,
      )..where((tbl) => tbl.id.equals('activity-fasted'))).getSingle();

      expect(row.isFasted, isTrue);
    });

    test(
      're-running onUpgrade from v13 is a no-op when is_fasted already exists',
      () async {
        // onCreate builds the CURRENT schema, so is_fasted already exists.
        final db = AppDatabase.memory();
        addTearDown(db.close);

        // Simulate the web re-run: user_version stuck at 13, onUpgrade fires
        // again. Without the idempotent addColumn guard this would throw
        // "duplicate column name: is_fasted".
        await expectLater(
          db.migration.onUpgrade!(db.createMigrator(), 13, db.schemaVersion),
          completes,
        );

        final after = await db
            .customSelect('PRAGMA table_info(activities)')
            .get();
        expect(
          after.any((r) => r.read<String>('name') == 'is_fasted'),
          isTrue,
        );
      },
    );
  });
}
