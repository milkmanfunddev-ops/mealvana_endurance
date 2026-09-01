import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/features/formula_kit/data/pre_workout_templates_repository.dart';
import 'package:mealvana_endurance/features/formula_kit/domain/before_sub_phase.dart';
import 'package:mealvana_endurance/shared/database/app_database.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MockSupabaseClient extends Mock implements SupabaseClient {}

/// Regression coverage for the Formula Library "no formulas showing" report
/// (2026-08-06) and the v3 catalog sync.
///
/// Drives the repository's delete-and-batch-insert mapper with rows shaped
/// exactly like the live dev Supabase wire payload (including the v3 columns
/// `sub_phase` / `fiber_per_serving` and both time_window generations) and
/// proves:
///   1. every wire row lands in Drift — server-side columns the local schema
///      doesn't know are ignored, never a sync-breaking error;
///   2. `sub_phase` round-trips and wins over the time_window label
///      (category-first, Lee ruling 2026-08-06) — including for a NOVEL
///      future window string;
///   3. rows without `sub_phase` (prod catalog until its migration replays)
///      still classify through the window fallback, both generations.
Map<String, dynamic> wireRow({
  required String id,
  required String name,
  required String timeWindow,
  String? subPhase,
  String templateType = 'food',
}) {
  return <String, dynamic>{
    'id': id,
    'name': name,
    'base_category': 'Fruit',
    'time_window': timeWindow,
    if (subPhase != null) 'sub_phase': subPhase,
    'digestion_speed': 'Fast',
    'allergens': <dynamic>[],
    'serving_unit': '1 pouch (90g)',
    'min_servings': 1,
    'max_servings': 3,
    'plus_banana': false,
    'plus_sports_drink': false,
    'notes': null,
    'is_active': true,
    'created_at': '2026-08-05T20:15:56.595414+00:00',
    'updated_at': '2026-08-05T20:15:56.595414+00:00',
    'carbs_per_serving': 11.0,
    'protein_per_serving': 0.2,
    'fat_per_serving': 0.0,
    'sodium_mg': 3.0,
    'fluid_ml': 77.0,
    'template_type': templateType,
    'component_food_names': ['applesauce_pouch'],
    'component_quantities': {'applesauce_pouch': 1},
    'excluded_diets': <dynamic>[],
    // Live v3 wire columns the Drift schema may or may not mirror — the
    // mapper must ignore anything it doesn't know rather than fail the sync.
    'is_indivisible': true,
    'fiber_per_serving': 1.0,
    'some_future_column_the_client_does_not_know': 42,
  };
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase database;
  late PreWorkoutTemplatesRepository repository;

  setUp(() {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    repository = PreWorkoutTemplatesRepository(MockSupabaseClient(), database);
  });

  tearDown(() async {
    await database.close();
  });

  test(
    'v3 wire rows all land in Drift; unknown server columns are ignored',
    () async {
      await repository.syncRowsToLocalForTest([
        wireRow(
          id: 'a',
          name: 'Applesauce Pouch',
          timeWindow: '30-120 min',
          subPhase: 'snack',
        ),
        wireRow(
          id: 'b',
          name: 'Oatmeal + Banana + Honey',
          timeWindow: '2-4 hours',
          subPhase: 'full_meal',
        ),
        wireRow(
          id: 'c',
          name: 'Banana (Top-Off)',
          timeWindow: '< 30 min',
          subPhase: 'top_up',
        ),
      ]);

      final rows = await repository.getAll();
      expect(rows, hasLength(3));
      final byId = {for (final r in rows) r.id: r};
      expect(byId['a']!.subPhase, 'snack');
      expect(byId['b']!.subPhase, 'full_meal');
      expect(byId['a']!.fiberPerServing, 1.0);
    },
  );

  test('category-first grouping: sub_phase beats the window label — a NOVEL '
      'future time_window cannot move or drop the formula', () async {
    await repository.syncRowsToLocalForTest([
      wireRow(
        id: 'novel',
        name: 'Pretzels + Sports Drink',
        // Matches NEITHER string generation — the exact shape that emptied
        // the meal/snack pools on 2026-08-05.
        timeWindow: '90 min - 2.5 hours',
        subPhase: 'snack',
      ),
    ]);

    final row = (await repository.getAll()).single;
    final resolved =
        BeforeSubPhase.fromStorageValue(row.subPhase) ??
        BeforeSubPhase.fromTimeWindow(row.timeWindow);
    expect(resolved, BeforeSubPhase.snack);
    // The window alone classifies to nothing — proving sub_phase carried it.
    expect(BeforeSubPhase.fromTimeWindow(row.timeWindow), isNull);
  });

  test('pre-migration rows (no sub_phase, prod catalog) still classify via '
      'the window fallback — both generations', () async {
    await repository.syncRowsToLocalForTest([
      wireRow(id: 'old-meal', name: 'Oatmeal', timeWindow: '1.5-3 hours'),
      wireRow(id: 'new-meal', name: 'Pancakes', timeWindow: '2-4 hours'),
      wireRow(id: 'old-snack', name: 'Toast', timeWindow: '30-90 min'),
    ]);

    final rows = await repository.getAll();
    BeforeSubPhase? resolve(PreWorkoutTemplateEntry e) =>
        BeforeSubPhase.fromStorageValue(e.subPhase) ??
        BeforeSubPhase.fromTimeWindow(e.timeWindow);

    final byId = {for (final r in rows) r.id: r};
    expect(byId['old-meal']!.subPhase, isNull);
    expect(resolve(byId['old-meal']!), BeforeSubPhase.meal);
    expect(resolve(byId['new-meal']!), BeforeSubPhase.meal);
    expect(resolve(byId['old-snack']!), BeforeSubPhase.snack);
  });

  test(
    'resync replaces the catalog wholesale (delete-and-batch-insert)',
    () async {
      await repository.syncRowsToLocalForTest([
        wireRow(id: 'stale', name: 'Old Row', timeWindow: '30-90 min'),
      ]);
      await repository.syncRowsToLocalForTest([
        wireRow(
          id: 'fresh',
          name: 'New Row',
          timeWindow: '30-120 min',
          subPhase: 'snack',
        ),
      ]);

      final rows = await repository.getAll();
      expect(rows.map((r) => r.id), ['fresh']);
    },
  );
}
