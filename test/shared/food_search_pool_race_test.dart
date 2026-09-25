// G28 — the seeded-search race (Xuan, live 2026-09-25).
//
// Repro he hit: tapping a Recommended row whose curated food isn't in the
// device's foods mirror yet falls back to search with the query pre-seeded
// (the ruled fallback). The search screen then showed NO local match for
// "Rice" — only network catalog results, so a rice-protein product surfaced
// and got logged instead of rice.
//
// Mechanism: LogMealScreen seeds the query in its post-frame callback, but
// _seedFoodPool() is async and completes LATER. updateSearch therefore runs
// against an EMPTY pool, and [updateFoodPool] — unlike [setFilter] directly
// above it — never re-applies the active query, so the local matches are
// lost for good. Nothing recovers them until the athlete edits the text.
//
// Contract: loading the pool while a query is active must re-filter, exactly
// as changing the filter does. Pre-existing and latent (a fast typist could
// always hit it); the seeded query made it deterministic.
import 'package:flutter_test/flutter_test.dart';
import 'package:riverpod/riverpod.dart';
import 'package:mealvana_endurance/features/nutrition_plan/domain/food.dart';
import 'package:mealvana_endurance/shared/controllers/food_search_controller.dart';
import 'package:mealvana_endurance/shared/services/app_config.dart';
import 'package:mealvana_endurance/shared/services/app_external_deps.dart';

import '../helpers/widget_test_harness.dart';

const _key = 'meal_log_unified';

Food _food(String id, String name, {String? displayName}) =>
    Food(id: id, name: name, displayName: displayName);

void main() {
  late ProviderContainer container;

  setUp(() {
    container = ProviderContainer(overrides: [
      appConfigProvider.overrideWithValue(AppConfig.forTesting()),
      mockAppExternalDeps(),
    ]);
    addTearDown(container.dispose);
  });

  test(
      'G28 pool-arrives-after-query: a query typed/seeded before the pool '
      'loads still shows its local matches once the pool arrives', () async {
    final notifier = container.read(
      foodSearchControllerProvider(_key).notifier,
    );

    // 1. The seeded query fires FIRST — pool still empty (the live race).
    notifier.updateSearch('Rice');
    expect(
      container.read(foodSearchControllerProvider(_key)).templateFoodResults,
      isEmpty,
      reason: 'nothing to match yet — this part is expected',
    );

    // 2. The async seed completes, exactly as _seedFoodPool does it.
    notifier.setFilter(FoodSearchFilter.generalFirst);
    notifier.updateFoodPool(
      allFoods: [
        _food('f1', 'White Rice (cooked)', displayName: 'cups White Rice'),
        _food('f2', 'Plant protein powder'),
        _food('f3', 'Pasta with marinara'),
      ],
      userFoods: const [],
    );

    // 3. THE CONTRACT: the active query must now be satisfied from the pool.
    final results =
        container.read(foodSearchControllerProvider(_key)).templateFoodResults;
    expect(
      results.map((f) => f.name),
      contains('White Rice (cooked)'),
      reason: 'the local match must surface once the pool is in — otherwise '
          'only network catalog results show and the athlete logs the wrong '
          'food (Xuan: rice became a plant protein powder)',
    );
    expect(
      results.map((f) => f.name),
      isNot(contains('Plant protein powder')),
      reason: 'and it must still be a FILTERED result, not the whole pool',
    );
  });

  test('G28 regression guard: an empty query after the pool loads stays empty',
      () async {
    final notifier = container.read(
      foodSearchControllerProvider(_key).notifier,
    );
    notifier.updateFoodPool(
      allFoods: [_food('f1', 'White Rice (cooked)')],
      userFoods: const [],
    );
    expect(
      container.read(foodSearchControllerProvider(_key)).templateFoodResults,
      isEmpty,
      reason: 'no active query — loading the pool must not dump the catalog',
    );
  });
}
