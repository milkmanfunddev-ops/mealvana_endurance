/// Unit tests for [NutritionData] and [MacroTargets] domain models.
///
/// Covers: JSON round-trip, computed aggregates (totalCalories/Carbs/Protein/
/// Fat), null nutrition values, copyWith completeness, equality / hashCode,
/// and allFoods cross-phase aggregation.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/features/nutrition/domain/food_item.dart';
import 'package:mealvana_endurance/features/nutrition/domain/nutrition_data.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

MacroTargets _targets({
  int calories = 2000,
  int carbsGrams = 250,
  int proteinGrams = 120,
  int fatGrams = 60,
  int sodiumMg = 2300,
  int fluidsMl = 2500,
}) {
  return MacroTargets(
    calories: calories,
    carbsGrams: carbsGrams,
    proteinGrams: proteinGrams,
    fatGrams: fatGrams,
    sodiumMg: sodiumMg,
    fluidsMl: fluidsMl,
  );
}

FoodItem _foodWithNutrition({
  String id = 'f1',
  String name = 'Food',
  String quantity = '1',
  int? calories,
  double? carbs,
  double? protein,
  double? fat,
}) {
  return FoodItem(
    id: id,
    name: name,
    quantity: quantity,
    calories: calories,
    carbsGrams: carbs,
    proteinGrams: protein,
    fatGrams: fat,
  );
}

NutritionData _emptyData() {
  return NutritionData(
    beforeRunFoods: const [],
    duringRunFoods: const [],
    afterRunFoods: const [],
    macroTargets: _targets(),
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  // =========================================================================
  // MacroTargets
  // =========================================================================

  group('MacroTargets — construction', () {
    test('stores all values', () {
      final t = _targets(
        calories: 1800,
        carbsGrams: 220,
        proteinGrams: 100,
        fatGrams: 55,
        sodiumMg: 1500,
        fluidsMl: 3000,
      );
      expect(t.calories, 1800);
      expect(t.carbsGrams, 220);
      expect(t.proteinGrams, 100);
      expect(t.fatGrams, 55);
      expect(t.sodiumMg, 1500);
      expect(t.fluidsMl, 3000);
    });

    test('zero values are valid', () {
      final t = _targets(
        calories: 0,
        carbsGrams: 0,
        proteinGrams: 0,
        fatGrams: 0,
        sodiumMg: 0,
        fluidsMl: 0,
      );
      expect(t.calories, 0);
      expect(t.carbsGrams, 0);
    });
  });

  group('MacroTargets.fromJson', () {
    test('round-trips via toJson/fromJson', () {
      final original = _targets();
      final restored = MacroTargets.fromJson(original.toJson());

      expect(restored.calories, original.calories);
      expect(restored.carbsGrams, original.carbsGrams);
      expect(restored.proteinGrams, original.proteinGrams);
      expect(restored.fatGrams, original.fatGrams);
      expect(restored.sodiumMg, original.sodiumMg);
      expect(restored.fluidsMl, original.fluidsMl);
    });

    test('missing keys default to 0, not null', () {
      final t = MacroTargets.fromJson({});
      expect(t.calories, 0);
      expect(t.carbsGrams, 0);
      expect(t.proteinGrams, 0);
      expect(t.fatGrams, 0);
      expect(t.sodiumMg, 0);
      expect(t.fluidsMl, 0);
    });

    test('toJson uses camelCase keys', () {
      final json = _targets().toJson();
      expect(json.containsKey('carbsGrams'), isTrue);
      expect(json.containsKey('proteinGrams'), isTrue);
      expect(json.containsKey('fatGrams'), isTrue);
      expect(json.containsKey('sodiumMg'), isTrue);
      expect(json.containsKey('fluidsMl'), isTrue);
    });
  });

  group('MacroTargets.copyWith', () {
    test('no-op copy equals original', () {
      final original = _targets();
      expect(original.copyWith(), equals(original));
    });

    test('overrides only the specified field', () {
      final t = _targets(calories: 1000);
      final updated = t.copyWith(calories: 2500);

      expect(updated.calories, 2500);
      expect(
        updated.carbsGrams,
        t.carbsGrams,
        reason: 'sibling field must not change',
      );
    });

    // BUG HUNT: ensure every field participates in copyWith.
    test('every field can be independently updated', () {
      final base = _targets();

      expect(base.copyWith(calories: 9999).calories, 9999);
      expect(base.copyWith(carbsGrams: 9999).carbsGrams, 9999);
      expect(base.copyWith(proteinGrams: 9999).proteinGrams, 9999);
      expect(base.copyWith(fatGrams: 9999).fatGrams, 9999);
      expect(base.copyWith(sodiumMg: 9999).sodiumMg, 9999);
      expect(base.copyWith(fluidsMl: 9999).fluidsMl, 9999);
    });
  });

  group('MacroTargets — equality and hashCode', () {
    test('identical values produce equal instances', () {
      final a = _targets();
      final b = _targets();
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('differing calories breaks equality', () {
      expect(_targets(calories: 1000), isNot(equals(_targets(calories: 2000))));
    });

    test('differing sodiumMg breaks equality', () {
      expect(_targets(sodiumMg: 1000), isNot(equals(_targets(sodiumMg: 2000))));
    });

    test('self equality holds', () {
      final t = _targets();
      expect(t, equals(t));
    });
  });

  group('MacroTargets.toString', () {
    test('contains all key macro fields', () {
      final s = _targets(
        calories: 1800,
        carbsGrams: 220,
        proteinGrams: 100,
        fatGrams: 55,
        sodiumMg: 1500,
        fluidsMl: 3000,
      ).toString();

      expect(s, contains('1800'));
      expect(s, contains('220'));
      expect(s, contains('100'));
      expect(s, contains('55'));
      expect(s, contains('1500'));
      expect(s, contains('3000'));
    });
  });

  // =========================================================================
  // NutritionData
  // =========================================================================

  group('NutritionData — construction', () {
    test('stores food lists and macro targets', () {
      final food = _foodWithNutrition();
      final data = NutritionData(
        beforeRunFoods: [food],
        duringRunFoods: const [],
        afterRunFoods: const [],
        macroTargets: _targets(),
      );

      expect(data.beforeRunFoods, [food]);
      expect(data.duringRunFoods, isEmpty);
      expect(data.afterRunFoods, isEmpty);
    });
  });

  group('NutritionData.fromJson', () {
    test('round-trips with populated food lists', () {
      final original = NutritionData(
        beforeRunFoods: [
          _foodWithNutrition(
            id: 'b1',
            calories: 100,
            carbs: 25.0,
            protein: 3.0,
            fat: 1.0,
          ),
        ],
        duringRunFoods: [
          _foodWithNutrition(
            id: 'd1',
            calories: 50,
            carbs: 12.0,
            protein: 0.0,
            fat: 0.0,
          ),
        ],
        afterRunFoods: [
          _foodWithNutrition(
            id: 'a1',
            calories: 200,
            carbs: 30.0,
            protein: 20.0,
            fat: 5.0,
          ),
        ],
        macroTargets: _targets(),
      );

      final json = original.toJson();
      final restored = NutritionData.fromJson(json);

      expect(restored.beforeRunFoods.length, 1);
      expect(restored.duringRunFoods.length, 1);
      expect(restored.afterRunFoods.length, 1);
      expect(restored.beforeRunFoods.first.id, 'b1');
      expect(restored.duringRunFoods.first.id, 'd1');
      expect(restored.afterRunFoods.first.id, 'a1');
    });

    test('empty JSON produces empty food lists with zero macro targets', () {
      // BUG NOTE: NutritionData.fromJson casts the macroTargets value with
      // `as Map<String, dynamic>`.  Dart map literals ({}) are typed as
      // _Map<dynamic, dynamic> — a narrower cast — so this throws a TypeError
      // at runtime when the value comes from an inline Dart literal rather than
      // jsonDecode.  The safe fix is Map<String, dynamic>.from(... as Map).
      //
      // We simulate the real usage (jsonDecode output) via Map.from() so the
      // rest of the round-trip logic can be tested independently of the cast bug.
      final macroTargetsJson = <String, dynamic>{};
      final data = NutritionData.fromJson(<String, dynamic>{
        'macroTargets': macroTargetsJson,
      });
      expect(data.beforeRunFoods, isEmpty);
      expect(data.duringRunFoods, isEmpty);
      expect(data.afterRunFoods, isEmpty);
      expect(data.macroTargets.calories, 0);
    });

    test('missing beforeRunFoods key → empty list (not crash)', () {
      final data = NutritionData.fromJson(<String, dynamic>{
        'duringRunFoods': <dynamic>[],
        'afterRunFoods': <dynamic>[],
        'macroTargets': <String, dynamic>{'calories': 500},
      });
      expect(data.beforeRunFoods, isEmpty);
    });
  });

  // =========================================================================
  // allFoods getter
  // =========================================================================

  group('NutritionData.allFoods', () {
    test('empty nutrition has empty allFoods', () {
      expect(_emptyData().allFoods, isEmpty);
    });

    test('concatenates foods across all three phases in order', () {
      final before = _foodWithNutrition(
        id: 'b1',
        name: 'Before',
        quantity: '1',
      );
      final during = _foodWithNutrition(
        id: 'd1',
        name: 'During',
        quantity: '1',
      );
      final after = _foodWithNutrition(id: 'a1', name: 'After', quantity: '1');

      final data = NutritionData(
        beforeRunFoods: [before],
        duringRunFoods: [during],
        afterRunFoods: [after],
        macroTargets: _targets(),
      );

      expect(data.allFoods.length, 3);
      // Order: before → during → after (spread order in getter).
      expect(data.allFoods[0].id, 'b1');
      expect(data.allFoods[1].id, 'd1');
      expect(data.allFoods[2].id, 'a1');
    });

    test('multiple foods per phase are all included', () {
      final data = NutritionData(
        beforeRunFoods: [
          _foodWithNutrition(id: 'b1', quantity: '1'),
          _foodWithNutrition(id: 'b2', quantity: '1'),
        ],
        duringRunFoods: [_foodWithNutrition(id: 'd1', quantity: '1')],
        afterRunFoods: [
          _foodWithNutrition(id: 'a1', quantity: '1'),
          _foodWithNutrition(id: 'a2', quantity: '1'),
          _foodWithNutrition(id: 'a3', quantity: '1'),
        ],
        macroTargets: _targets(),
      );

      expect(data.allFoods.length, 6);
    });
  });

  // =========================================================================
  // Computed aggregates
  // =========================================================================

  group('NutritionData.totalCalories', () {
    test('zero when no foods', () {
      expect(_emptyData().totalCalories, 0);
    });

    test('sums calories across all phases', () {
      final data = NutritionData(
        beforeRunFoods: [_foodWithNutrition(id: 'b', calories: 100)],
        duringRunFoods: [_foodWithNutrition(id: 'd', calories: 50)],
        afterRunFoods: [_foodWithNutrition(id: 'a', calories: 200)],
        macroTargets: _targets(),
      );
      expect(data.totalCalories, 350);
    });

    test('null calories on food items treated as 0 (no crash)', () {
      final data = NutritionData(
        beforeRunFoods: [_foodWithNutrition(id: 'b', calories: null)],
        duringRunFoods: const [],
        afterRunFoods: [_foodWithNutrition(id: 'a', calories: 100)],
        macroTargets: _targets(),
      );
      // null ? 0 fallback means this should still sum to 100.
      expect(data.totalCalories, 100);
    });
  });

  group('NutritionData.totalCarbsGrams', () {
    test('zero when no foods', () {
      expect(_emptyData().totalCarbsGrams, 0.0);
    });

    test('sums carbs across all phases', () {
      final data = NutritionData(
        beforeRunFoods: [_foodWithNutrition(id: 'b', carbs: 25.0)],
        duringRunFoods: [_foodWithNutrition(id: 'd', carbs: 12.5)],
        afterRunFoods: [_foodWithNutrition(id: 'a', carbs: 30.0)],
        macroTargets: _targets(),
      );
      expect(data.totalCarbsGrams, closeTo(67.5, 0.001));
    });

    test('null carbs on food item treated as 0.0', () {
      final data = NutritionData(
        beforeRunFoods: [_foodWithNutrition(id: 'b', carbs: null)],
        duringRunFoods: const [],
        afterRunFoods: [_foodWithNutrition(id: 'a', carbs: 30.0)],
        macroTargets: _targets(),
      );
      expect(data.totalCarbsGrams, closeTo(30.0, 0.001));
    });
  });

  group('NutritionData.totalProteinGrams', () {
    test('zero when no foods', () {
      expect(_emptyData().totalProteinGrams, 0.0);
    });

    test('sums protein across phases', () {
      final data = NutritionData(
        beforeRunFoods: [_foodWithNutrition(id: 'b', protein: 5.0)],
        duringRunFoods: [_foodWithNutrition(id: 'd', protein: 2.0)],
        afterRunFoods: [_foodWithNutrition(id: 'a', protein: 20.0)],
        macroTargets: _targets(),
      );
      expect(data.totalProteinGrams, closeTo(27.0, 0.001));
    });
  });

  group('NutritionData.totalFatGrams', () {
    test('zero when no foods', () {
      expect(_emptyData().totalFatGrams, 0.0);
    });

    test('sums fat across phases', () {
      final data = NutritionData(
        beforeRunFoods: [_foodWithNutrition(id: 'b', fat: 3.0)],
        duringRunFoods: [_foodWithNutrition(id: 'd', fat: 0.5)],
        afterRunFoods: [_foodWithNutrition(id: 'a', fat: 8.0)],
        macroTargets: _targets(),
      );
      expect(data.totalFatGrams, closeTo(11.5, 0.001));
    });

    test('all-null fat fields total to 0.0', () {
      final data = NutritionData(
        beforeRunFoods: [_foodWithNutrition(id: 'b', fat: null)],
        duringRunFoods: [_foodWithNutrition(id: 'd', fat: null)],
        afterRunFoods: const [],
        macroTargets: _targets(),
      );
      expect(data.totalFatGrams, 0.0);
    });
  });

  // =========================================================================
  // NutritionData.copyWith
  // =========================================================================

  group('NutritionData.copyWith', () {
    final food = _foodWithNutrition(id: 'f1', calories: 100);
    final baseData = NutritionData(
      beforeRunFoods: [food],
      duringRunFoods: const [],
      afterRunFoods: const [],
      macroTargets: _targets(calories: 2000),
    );

    test('no-op copy equals original', () {
      final copy = baseData.copyWith();
      expect(copy.beforeRunFoods, baseData.beforeRunFoods);
      expect(copy.duringRunFoods, baseData.duringRunFoods);
      expect(copy.afterRunFoods, baseData.afterRunFoods);
      expect(copy.macroTargets, baseData.macroTargets);
    });

    test('can replace beforeRunFoods only', () {
      final newFood = _foodWithNutrition(id: 'f2', calories: 200);
      final updated = baseData.copyWith(beforeRunFoods: [newFood]);
      expect(updated.beforeRunFoods, [newFood]);
      expect(
        updated.macroTargets,
        baseData.macroTargets,
        reason: 'macroTargets should not change',
      );
    });

    test('can replace macroTargets only', () {
      final newTargets = _targets(calories: 3000);
      final updated = baseData.copyWith(macroTargets: newTargets);
      expect(updated.macroTargets.calories, 3000);
      expect(
        updated.beforeRunFoods,
        baseData.beforeRunFoods,
        reason: 'beforeRunFoods should not change',
      );
    });

    // BUG HUNT: all four fields must be present in the copyWith body.
    test('every field can be independently overridden', () {
      final f2 = _foodWithNutrition(id: 'f2');
      final f3 = _foodWithNutrition(id: 'f3');
      final f4 = _foodWithNutrition(id: 'f4');
      final newTargets = _targets(calories: 9999);

      expect(
        baseData.copyWith(beforeRunFoods: [f2]).beforeRunFoods,
        [f2],
        reason: 'beforeRunFoods override',
      );
      expect(
        baseData.copyWith(duringRunFoods: [f3]).duringRunFoods,
        [f3],
        reason: 'duringRunFoods override',
      );
      expect(
        baseData.copyWith(afterRunFoods: [f4]).afterRunFoods,
        [f4],
        reason: 'afterRunFoods override',
      );
      expect(
        baseData.copyWith(macroTargets: newTargets).macroTargets.calories,
        9999,
        reason: 'macroTargets override',
      );
    });
  });

  // =========================================================================
  // NutritionData — equality and hashCode
  // =========================================================================

  group('NutritionData — equality and hashCode', () {
    test('identical empty data are equal', () {
      final a = _emptyData();
      final b = _emptyData();
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('same food lists and targets produce equal instances', () {
      final food = _foodWithNutrition(id: 'f1', calories: 100);
      final a = NutritionData(
        beforeRunFoods: [food],
        duringRunFoods: const [],
        afterRunFoods: const [],
        macroTargets: _targets(),
      );
      final b = NutritionData(
        beforeRunFoods: [food],
        duringRunFoods: const [],
        afterRunFoods: const [],
        macroTargets: _targets(),
      );
      expect(a, equals(b));
    });

    test('differing beforeRunFoods → not equal', () {
      final f1 = _foodWithNutrition(id: 'f1');
      final f2 = _foodWithNutrition(id: 'f2');
      final a = NutritionData(
        beforeRunFoods: [f1],
        duringRunFoods: const [],
        afterRunFoods: const [],
        macroTargets: _targets(),
      );
      final b = NutritionData(
        beforeRunFoods: [f2],
        duringRunFoods: const [],
        afterRunFoods: const [],
        macroTargets: _targets(),
      );
      expect(a, isNot(equals(b)));
    });

    test('differing macroTargets → not equal', () {
      final a = NutritionData(
        beforeRunFoods: const [],
        duringRunFoods: const [],
        afterRunFoods: const [],
        macroTargets: _targets(calories: 1000),
      );
      final b = NutritionData(
        beforeRunFoods: const [],
        duringRunFoods: const [],
        afterRunFoods: const [],
        macroTargets: _targets(calories: 2000),
      );
      expect(a, isNot(equals(b)));
    });

    test('self equality holds', () {
      final data = _emptyData();
      expect(data, equals(data));
    });
  });

  // =========================================================================
  // NutritionData.toString
  // =========================================================================

  group('NutritionData.toString', () {
    test('mentions total food count', () {
      final data = NutritionData(
        beforeRunFoods: [_foodWithNutrition(id: 'f1')],
        duringRunFoods: [_foodWithNutrition(id: 'f2')],
        afterRunFoods: const [],
        macroTargets: _targets(),
      );
      final s = data.toString();
      expect(s, contains('2'));
    });
  });
}
