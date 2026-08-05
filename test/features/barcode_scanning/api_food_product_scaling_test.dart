/// Nutrition scaling for scanned barcode products.
///
/// This is the arithmetic that turns an Open Food Facts payload into the
/// numbers an athlete logs and fuels off. It has no test coverage at all —
/// `lib/features/barcode_scanning/` has no `test/features/` counterpart — and
/// it is the same shape as the bugs this branch already found in the unit
/// layer: quiet, plausible-looking numbers that are simply wrong.
///
/// Two behaviours get probed hardest:
///
///   • the ±5 g "close enough" tolerance, which returns the API's per-serving
///     values UNSCALED. Five grams is a rounding error on a 100 g portion and
///     most of the product on a 5 g gel, so an absolute tolerance behaves very
///     differently across the range of things people actually scan.
///
///   • the per-100 g fallback, which is what runs whenever the payload has no
///     per-serving block — the common case for supermarket products.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/features/barcode_scanning/domain/api_food_product.dart';

void main() {
  ApiFoodProduct product({
    double? caloriesPer100g,
    double? carbsPer100g,
    double? proteinPer100g,
    double? fatPer100g,
    double? sodiumMgPer100g,
    double? caloriesPerServing,
    double? carbsPerServing,
    double? proteinPerServing,
    double? fatPerServing,
    double? sodiumMgPerServing,
    double? servingGrams,
  }) => ApiFoodProduct(
    barcode: '0000000000000',
    productName: 'Test Product',
    apiSource: 'open_food_facts',
    confidenceScore: 1.0,
    caloriesPer100g: caloriesPer100g,
    carbohydratesPer100g: carbsPer100g,
    proteinPer100g: proteinPer100g,
    fatPer100g: fatPer100g,
    sodiumMgPer100g: sodiumMgPer100g,
    caloriesPerServing: caloriesPerServing,
    carbohydratesPerServing: carbsPerServing,
    proteinPerServing: proteinPerServing,
    fatPerServing: fatPerServing,
    sodiumMgPerServing: sodiumMgPerServing,
    servingGrams: servingGrams,
  );

  group('per-100g fallback (no per-serving data)', () {
    final oats = product(
      caloriesPer100g: 380,
      carbsPer100g: 60,
      proteinPer100g: 13,
      fatPer100g: 7,
      sodiumMgPer100g: 20,
    );

    test('100 g is the per-100g values unchanged', () {
      final v = oats.calculateForServing(100);
      expect(v.calories, 380);
      expect(v.carbohydrates, closeTo(60, 0.001));
      expect(v.protein, closeTo(13, 0.001));
      expect(v.fat, closeTo(7, 0.001));
      expect(v.sodiumMg, 20);
    });

    test('half a portion is half of everything', () {
      final v = oats.calculateForServing(50);
      expect(v.calories, 190);
      expect(v.carbohydrates, closeTo(30, 0.001));
      expect(v.sodiumMg, 10);
    });

    test('scales above 100 g too', () {
      final v = oats.calculateForServing(250);
      expect(v.calories, 950);
      expect(v.carbohydrates, closeTo(150, 0.001));
    });

    test('a zero serving yields zeroes, not the full portion', () {
      final v = oats.calculateForServing(0);
      expect(v.calories, 0);
      expect(v.carbohydrates, 0);
    });

    test('missing macros stay null rather than becoming zero', () {
      // Null and 0 mean different things to the fuelling engine: "unknown"
      // must not silently become "contains none of this".
      final partial = product(caloriesPer100g: 100);
      final v = partial.calculateForServing(100);
      expect(v.calories, 100);
      expect(v.carbohydrates, isNull);
      expect(v.protein, isNull);
      expect(v.fat, isNull);
      expect(v.sodiumMg, isNull);
    });
  });

  group('per-serving data, exact match', () {
    test('is used directly when the requested serving matches', () {
      final gel = product(
        caloriesPerServing: 100,
        carbsPerServing: 25,
        sodiumMgPerServing: 50,
        servingGrams: 40,
      );
      final v = gel.calculateForServing(40);
      expect(v.calories, 100);
      expect(v.carbohydrates, closeTo(25, 0.001));
      expect(v.sodiumMg, 50);
    });

    test('is used directly when the product declares no serving weight', () {
      final unknownWeight = product(
        caloriesPerServing: 90,
        carbsPerServing: 22,
      );
      final v = unknownWeight.calculateForServing(75);
      expect(v.calories, 90);
    });
  });

  group('per-serving data, scaled', () {
    final bar = product(
      caloriesPerServing: 200,
      carbsPerServing: 40,
      proteinPerServing: 10,
      fatPerServing: 6,
      sodiumMgPerServing: 100,
      servingGrams: 50,
    );

    test('doubling the serving doubles the macros', () {
      final v = bar.calculateForServing(100);
      expect(v.calories, 400);
      expect(v.carbohydrates, closeTo(80, 0.001));
      expect(v.sodiumMg, 200);
    });

    test('a much smaller serving scales down', () {
      final v = bar.calculateForServing(10);
      expect(v.calories, 40);
      expect(v.carbohydrates, closeTo(8, 0.001));
    });
  });

  group('the serving tolerance is RELATIVE, not a fixed number of grams', () {
    // Changed 2026-08-05 from an absolute 5 g threshold. The old rule treated
    // 5 g as "close enough" regardless of portion size, so it was rounding
    // noise on a 100 g cereal serving and the entire product on a 5 g chew.
    // The tolerance is now 10% of the declared serving.

    test('a 4% difference on a 100 g portion is still treated as noise', () {
      final cereal = product(
        caloriesPerServing: 380,
        carbsPerServing: 60,
        servingGrams: 100,
      );
      // 104 g is within 10% of 100 g — the original intent is preserved.
      expect(cereal.calculateForServing(104).calories, 380);
    });

    test('a 5 g difference on a 5 g chew now SCALES (the fix)', () {
      // The regression this change exists to kill: |9 - 5| = 4 was under the
      // old absolute 5 g tolerance, so a 9 g portion reported the 5 g values —
      // an 80% understatement on a during-race fuel item. 4 g is 80% of a 5 g
      // serving, far outside a 10% tolerance, so it scales now.
      final chew = product(
        caloriesPerServing: 20,
        carbsPerServing: 5,
        servingGrams: 5,
      );
      final v = chew.calculateForServing(9);
      expect(
        v.calories,
        36,
        reason: '9 g of a 5 g chew is 1.8 servings: 20 kcal * 1.8 = 36.',
      );
      expect(v.carbohydrates, closeTo(9, 0.001));
    });

    test('small servings are no longer under-reported at any offset', () {
      // Sweep the range that used to fall inside the absolute tolerance.
      final chew = product(
        caloriesPerServing: 20,
        carbsPerServing: 5,
        servingGrams: 5,
      );
      for (final requested in [6.0, 7.0, 8.0, 9.0]) {
        final v = chew.calculateForServing(requested);
        final expected = (20 * (requested / 5)).round();
        expect(
          v.calories,
          expected,
          reason:
              '$requested g of a 5 g serving should be $expected kcal; the '
              'absolute-tolerance bug returned 20.',
        );
      }
    });

    test('a tiny relative difference on a small serving is still noise', () {
      // 5.2 g of a 5 g chew is within 10% — no false precision manufactured.
      final chew = product(
        caloriesPerServing: 20,
        carbsPerServing: 5,
        servingGrams: 5,
      );
      expect(chew.calculateForServing(5.2).calories, 20);
    });

    test('the tolerance scales with the serving, in both directions', () {
      // 10% of 50 g is 5 g: 54 g is inside, 60 g is outside.
      final bar = product(
        caloriesPerServing: 100,
        carbsPerServing: 20,
        servingGrams: 50,
      );
      expect(bar.calculateForServing(54).calories, 100);
      expect(bar.calculateForServing(60).calories, 120);
    });

    test('the boundary itself is inclusive', () {
      // Exactly 10% away counts as close enough (<=), so no scaling.
      final bar = product(
        caloriesPerServing: 100,
        carbsPerServing: 20,
        servingGrams: 50,
      );
      expect(bar.calculateForServing(55).calories, 100);
    });

    test('a large serving scales as before', () {
      final bar = product(
        caloriesPerServing: 200,
        carbsPerServing: 40,
        servingGrams: 50,
      );
      expect(bar.calculateForServing(100).calories, 400);
    });
  });

  group('degenerate serving weights do not corrupt the result', () {
    test('a zero declared serving weight falls back to per-100g', () {
      // scaleFactor would be a division by zero; the guard is
      // `servingGrams! > 0`, after which the per-100g branch runs.
      final broken = product(
        caloriesPerServing: 100,
        caloriesPer100g: 250,
        servingGrams: 0,
      );
      final v = broken.calculateForServing(50);
      expect(v.calories, 125);
      expect(v.calories, isNotNull);
    });

    test('every produced number is finite', () {
      final broken = product(
        caloriesPerServing: 100,
        carbsPerServing: 30,
        caloriesPer100g: 250,
        carbsPer100g: 40,
        servingGrams: 0,
      );
      final v = broken.calculateForServing(50);
      for (final n in [v.carbohydrates, v.protein, v.fat]) {
        if (n != null) expect(n.isFinite, isTrue);
      }
      expect(v.calories?.isFinite ?? true, isTrue);
    });
  });
}
