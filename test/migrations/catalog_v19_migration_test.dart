/// Tests for the v19 template_foods catalog columns
/// (food-recommendation@v1: min_servings_during + is_indivisible mirrors and
/// the catalog-conventions v1.1 solvent_min_ml — Supabase migration
/// 20260903120000).
///
/// Covers:
///  - onCreate produces the three columns with the right nullability/defaults
///  - rows inserted without them read back the defaults (1.0 / false / null)
///  - replaying the v18→v19 onUpgrade step is a no-op when the columns already
///    exist (web `user_version` re-run safety, same pattern as
///    is_fasted_v14_migration_test.dart)
library;

import 'package:drift/drift.dart' hide isNull;
import 'package:mealvana_endurance/shared/database/app_database.dart';
import 'package:test/test.dart';

void main() {
  group('template_foods v19 catalog columns', () {
    test('onCreate produces the three columns', () async {
      final db = AppDatabase.memory();
      addTearDown(db.close);

      final columns = await db
          .customSelect('PRAGMA table_info(template_foods)')
          .get();
      Map<String, dynamic> col(String name) {
        final matches =
            columns.where((r) => r.read<String>('name') == name).toList();
        expect(matches, hasLength(1),
            reason: 'template_foods must have a $name column');
        return {
          'notnull': matches.single.read<int>('notnull'),
        };
      }

      expect(col('min_servings_during')['notnull'], 1,
          reason: 'min_servings_during is NOT NULL DEFAULT 1.0');
      expect(col('is_indivisible')['notnull'], 1,
          reason: 'is_indivisible is NOT NULL DEFAULT false');
      expect(col('solvent_min_ml')['notnull'], 0,
          reason: 'solvent_min_ml is nullable (NULL = undeclared -> 250 ml '
              'pairing fallback, never 0)');
    });

    test('rows inserted without the columns read back the defaults', () async {
      final db = AppDatabase.memory();
      addTearDown(db.close);

      await db.into(db.templateFoodsTable).insert(
            TemplateFoodsTableCompanion.insert(
              id: 'tf-v19-defaults',
              name: 'test_food',
              displayName: 'Test Food',
              servingSize: '1 serving',
            ),
          );

      final row = await (db.select(db.templateFoodsTable)
            ..where((t) => t.id.equals('tf-v19-defaults')))
          .getSingle();

      expect(row.minServingsDuring, 1.0);
      expect(row.isIndivisible, isFalse);
      expect(row.solventMinMl, isNull);
    });

    test('solvent_min_ml round-trips through the Drift table', () async {
      final db = AppDatabase.memory();
      addTearDown(db.close);

      await db.into(db.templateFoodsTable).insert(
            TemplateFoodsTableCompanion.insert(
              id: 'tf-v19-solvent',
              name: 'high_carb_drink_mix',
              displayName: 'High-Carb Drink Mix',
              servingSize: '1 packet (90g carbs in 20-24 oz water)',
              minServingsDuring: const Value(0.5),
              isIndivisible: const Value(false),
              solventMinMl: const Value(600),
            ),
          );

      final row = await (db.select(db.templateFoodsTable)
            ..where((t) => t.id.equals('tf-v19-solvent')))
          .getSingle();

      expect(row.solventMinMl, 600);
      expect(row.minServingsDuring, 0.5);
    });

    test(
      're-running onUpgrade from v18 is a no-op when the columns exist',
      () async {
        final db = AppDatabase.memory();
        addTearDown(db.close);

        await expectLater(
          db.migration.onUpgrade!(db.createMigrator(), 18, db.schemaVersion),
          completes,
        );

        final after = await db
            .customSelect('PRAGMA table_info(template_foods)')
            .get();
        for (final name in [
          'min_servings_during',
          'is_indivisible',
          'solvent_min_ml',
        ]) {
          expect(after.any((r) => r.read<String>('name') == name), isTrue,
              reason: '$name must survive the replay');
        }
      },
    );
  });
}
