/// Tests for the v20 meal-planning schema step (Phase 4b of
/// docs/implement_mealplanning/05-flutter-feature.md §2).
///
/// Same shape as user_entitlements_v19_migration_test.dart:
///  - onCreate produces `meal_plans`, `plan_meals`, `user_memories` with the
///    expected columns, and the additive columns on `meal_logs` /
///    `saved_meals`
///  - a v19 install gets everything from the `from < 20` step
///  - replaying that step is a no-op (web `user_version` re-run safety)
///  - the new rows round-trip through their companions
library;

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:mealvana_endurance/shared/database/app_database.dart';
import 'package:test/test.dart';

Future<Set<String>> _tables(AppDatabase db) async {
  final rows = await db
      .customSelect(
        "SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%'",
      )
      .get();
  return rows.map((r) => r.read<String>('name')).toSet();
}

Future<Set<String>> _columns(AppDatabase db, String table) async {
  final rows = await db.customSelect('PRAGMA table_info($table)').get();
  return rows.map((r) => r.read<String>('name')).toSet();
}

/// Rewind a fresh (v20) in-memory database to the v19 shape: drop the three
/// new tables and rebuild `meal_logs` / `saved_meals` without the v20 columns.
Future<void> _rewindToV19(AppDatabase db) async {
  await db.customStatement('DROP TABLE meal_plans');
  await db.customStatement('DROP TABLE plan_meals');
  await db.customStatement('DROP TABLE user_memories');
  // SQLite < 3.35 has no DROP COLUMN; rebuild the two tables the v19 way.
  await db.customStatement('DROP TABLE meal_logs');
  await db.customStatement('''
    CREATE TABLE meal_logs (
      id TEXT NOT NULL PRIMARY KEY, user_id TEXT NOT NULL, log_date TEXT NOT NULL,
      slot TEXT, name TEXT NOT NULL, source TEXT NOT NULL,
      items TEXT NOT NULL DEFAULT '[]', calories INTEGER, carbs_g REAL,
      protein_g REAL, fat_g REAL, sodium_mg REAL, photo_path TEXT,
      recipe_id TEXT, saved_meal_id TEXT, notes TEXT, eaten_at INTEGER,
      created_at INTEGER NOT NULL, updated_at INTEGER NOT NULL,
      is_deleted INTEGER NOT NULL DEFAULT 0, needs_upload INTEGER,
      local_updated_at INTEGER
    )''');
  await db.customStatement('DROP TABLE saved_meals');
  await db.customStatement('''
    CREATE TABLE saved_meals (
      id TEXT NOT NULL PRIMARY KEY, user_id TEXT NOT NULL, name TEXT NOT NULL,
      items TEXT NOT NULL DEFAULT '[]', calories INTEGER, carbs_g REAL,
      protein_g REAL, fat_g REAL, sodium_mg REAL, photo_path TEXT,
      last_used_at INTEGER, created_at INTEGER NOT NULL,
      updated_at INTEGER NOT NULL, is_deleted INTEGER NOT NULL DEFAULT 0,
      needs_upload INTEGER, local_updated_at INTEGER
    )''');
}

void main() {
  group('meal planning (v20)', () {
    test('schemaVersion is 20', () async {
      final db = AppDatabase.memory();
      addTearDown(db.close);
      expect(db.schemaVersion, 20);
    });

    test('onCreate produces the three tables with their columns', () async {
      final db = AppDatabase.memory();
      addTearDown(db.close);

      final tables = await _tables(db);
      expect(
        tables,
        containsAll(['meal_plans', 'plan_meals', 'user_memories']),
      );

      expect(
        await _columns(db, 'meal_plans'),
        containsAll([
          'id',
          'user_id',
          'week_start',
          'status',
          'batch_cooking',
          'rules',
          'shopping',
          'brief',
          'conversation_id',
          'days',
          'day_notes',
          'day_notes_stale',
          'day_notes_at',
          'created_at',
          'updated_at',
          'is_deleted',
          'needs_upload',
          'local_updated_at',
        ]),
      );
      expect(
        await _columns(db, 'plan_meals'),
        containsAll([
          'id',
          'plan_id',
          'user_id',
          'source',
          'library_meal_id',
          'saved_meal_id',
          'name',
          'meal_type',
          'session',
          'servings',
          'servings_left',
          'kcal',
          'carbs_g',
          'protein_g',
          'fat_g',
          'swaps_applied',
          'comments',
          'position',
          'icon',
          'created_at',
          'updated_at',
          'is_deleted',
          'needs_upload',
          'local_updated_at',
        ]),
      );
      expect(
        await _columns(db, 'user_memories'),
        containsAll([
          'id',
          'user_id',
          'kind',
          'key',
          'fact',
          'value',
          'confidence',
          'source',
          'created_at',
          'last_confirmed_at',
          'expires_at',
          'is_deleted',
          'needs_upload',
          'local_updated_at',
        ]),
      );
      // The server-only pgvector column must never be mirrored.
      expect(await _columns(db, 'user_memories'), isNot(contains('embedding')));

      expect(await _columns(db, 'meal_logs'), contains('plan_meal_id'));
      expect(
        await _columns(db, 'saved_meals'),
        containsAll([
          'icon',
          'notes',
          'meal_types',
          'batch',
          'library_meal_id',
        ]),
      );
    });

    test('a v19 install gets everything from the from < 20 step', () async {
      final db = AppDatabase.memory();
      addTearDown(db.close);

      await _rewindToV19(db);
      expect(await _tables(db), isNot(contains('meal_plans')));
      expect(await _columns(db, 'meal_logs'), isNot(contains('plan_meal_id')));
      expect(await _columns(db, 'saved_meals'), isNot(contains('icon')));

      await db.migration.onUpgrade(db.createMigrator(), 19, db.schemaVersion);

      expect(
        await _tables(db),
        containsAll(['meal_plans', 'plan_meals', 'user_memories']),
      );
      expect(await _columns(db, 'meal_logs'), contains('plan_meal_id'));
      expect(
        await _columns(db, 'saved_meals'),
        containsAll([
          'icon',
          'notes',
          'meal_types',
          'batch',
          'library_meal_id',
        ]),
      );
    });

    test('re-running the v20 step when everything exists is a no-op', () async {
      final db = AppDatabase.memory();
      addTearDown(db.close);

      await expectLater(
        db.migration.onUpgrade(db.createMigrator(), 19, db.schemaVersion),
        completes,
      );
      // And again — the web user_version replay shape.
      await expectLater(
        db.migration.onUpgrade(db.createMigrator(), 19, db.schemaVersion),
        completes,
      );
      expect(await _tables(db), contains('plan_meals'));
    });

    test('an existing saved_meals row survives the column additions', () async {
      final db = AppDatabase.memory();
      addTearDown(db.close);
      await _rewindToV19(db);
      await db.customStatement('''
        INSERT INTO saved_meals (id, user_id, name, created_at, updated_at)
        VALUES ('sm-1', 'user-1', 'Oats', 0, 0)''');

      await db.migration.onUpgrade(db.createMigrator(), 19, db.schemaVersion);

      final row = await (db.select(
        db.savedMealsTable,
      )..where((t) => t.id.equals('sm-1'))).getSingle();
      expect(row.name, 'Oats');
      expect(row.mealTypes, '[]'); // NOT NULL DEFAULT '[]' backfilled
      expect(row.icon, isNull);
      expect(row.batch, isNull);
    });

    test(
      'plan + meal + memory rows round-trip through the companions',
      () async {
        final db = AppDatabase.memory();
        addTearDown(db.close);
        final now = DateTime.utc(2026, 9, 1, 12);

        await db
            .into(db.mealPlansTable)
            .insert(
              MealPlansTableCompanion.insert(
                id: const Value('plan-1'),
                userId: 'user-1',
                weekStart: '2026-08-31',
                status: const Value('draft'),
                days: const Value('{"2026-09-01":{"lunch":null}}'),
                createdAt: now,
                updatedAt: now,
              ),
            );
        await db
            .into(db.planMealsTable)
            .insert(
              PlanMealsTableCompanion.insert(
                id: const Value('pm-1'),
                planId: 'plan-1',
                userId: 'user-1',
                source: 'library',
                libraryMealId: const Value('D-048'),
                name: 'Chicken & rice',
                mealType: 'dinner',
                session: const Value('cook-sun'),
                servings: const Value(4),
                servingsLeft: const Value(3),
                icon: const Value('chicken'),
                createdAt: now,
                updatedAt: now,
              ),
            );
        await db
            .into(db.userMemoriesTable)
            .insert(
              UserMemoriesTableCompanion.insert(
                id: const Value('mem-1'),
                userId: 'user-1',
                kind: 'setting',
                key: const Value('batch_cooking'),
                fact: 'Cooks in batches',
                value: const Value('true'),
                confidence: const Value(1),
                source: const Value('settings'),
                createdAt: now,
                lastConfirmedAt: now,
              ),
            );

        final plan = await db.select(db.mealPlansTable).getSingle();
        expect(plan.batchCooking, isTrue); // server default mirrored
        expect(plan.dayNotesStale, isTrue);
        expect(plan.rules, '[]');
        expect(plan.days, contains('2026-09-01'));

        final meal = await db.select(db.planMealsTable).getSingle();
        expect(meal.planId, 'plan-1');
        expect(meal.session, 'cook-sun');
        expect(meal.servingsLeft, 3);
        expect(meal.isDeleted, isFalse);
        expect(meal.swapsApplied, '[]');

        final memory = await db.select(db.userMemoriesTable).getSingle();
        expect(memory.kind, 'setting');
        expect(memory.key, 'batch_cooking');
        expect(memory.value, 'true');
        expect(memory.confidence, 1);
      },
    );
  });
}
