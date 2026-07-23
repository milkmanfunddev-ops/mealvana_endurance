import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/features/formula_kit/domain/formula_macros.dart';
import 'package:mealvana_endurance/features/nutrition_plan/domain/food.dart';

void main() {
  group('FormulaMacros', () {
    const banana = Food(
      id: 'food-banana',
      name: 'Banana',
      displayName: 'medium banana',
      servingUnit: 'medium',
      carbsPerServing: 27,
      proteinPerServing: 1.3,
      fatPerServing: 0.4,
      sodiumMg: 1,
      fluidMlPerServing: 0,
      caloriesPerServing: 105,
    );

    test('componentFromFood snapshots per-serving macros + source', () {
      final c = FormulaMacros.componentFromFood(banana, 1.5, isUserFood: false);

      expect(c[FormulaMacros.kFoodId], 'food-banana');
      expect(c[FormulaMacros.kFoodName], 'medium banana');
      expect(c[FormulaMacros.kQuantity], 1.5);
      expect(c[FormulaMacros.kSource], FormulaMacros.sourceTemplate);
      expect(c[FormulaMacros.kCarbsPerServing], 27);
      expect(c[FormulaMacros.kCaloriesPerServing], 105);
    });

    test('user-food source flag is honored', () {
      final c = FormulaMacros.componentFromFood(banana, 1, isUserFood: true);
      expect(c[FormulaMacros.kSource], FormulaMacros.sourceUser);
    });

    test('totalsForComponent multiplies per-serving by quantity', () {
      final c = FormulaMacros.componentFromFood(banana, 2, isUserFood: false);
      final t = FormulaMacros.totalsForComponent(c);

      expect(t.carbsG, 54); // 27 * 2
      expect(t.calories, 210); // 105 * 2
      expect(t.proteinG, 3); // 1.3 * 2 = 2.6 → round 3
    });

    test('totalsFor aggregates across components', () {
      final components = [
        FormulaMacros.componentFromFood(banana, 1, isUserFood: false),
        FormulaMacros.componentFromFood(banana, 0.5, isUserFood: false),
      ];
      final t = FormulaMacros.totalsFor(components);

      expect(t.carbsG, 41); // 27 + 13.5 = 40.5 → round 41
      expect(t.calories, 158); // 105 + 52.5 = 157.5 → round 158
    });

    test('empty components → zero totals', () {
      final t = FormulaMacros.totalsFor(const []);
      expect(t.carbsG, 0);
      expect(t.calories, 0);
      expect(t.sodiumMg, 0);
    });

    test('missing macro fields coerce to zero, not crash', () {
      final t = FormulaMacros.totalsFor([
        {FormulaMacros.kFoodName: 'Mystery', FormulaMacros.kQuantity: 3},
      ]);
      expect(t.carbsG, 0);
      expect(t.calories, 0);
    });
  });

  // During formulas are quantity-less by design (2026-06-11): plan generation
  // scales components uniformly to the phase carb target. These helpers are
  // mirrored in the edge function (personal-formula-pins.ts) — keep in sync.
  group('during carb-target scaling', () {
    test('carbScaleFactor scales formula carbs to the target', () {
      final components = [
        {FormulaMacros.kQuantity: 1, FormulaMacros.kCarbsPerServing: 25},
        {FormulaMacros.kQuantity: 1, FormulaMacros.kCarbsPerServing: 0},
      ];
      expect(FormulaMacros.carbScaleFactor(components, 100), 4);
    });

    test(
      'carbScaleFactor is 1 for non-positive target or carb-free formula',
      () {
        final carby = [
          {FormulaMacros.kQuantity: 1, FormulaMacros.kCarbsPerServing: 25},
        ];
        expect(FormulaMacros.carbScaleFactor(carby, 0), 1);
        expect(FormulaMacros.carbScaleFactor(carby, -5), 1);
        final carbFree = [
          {FormulaMacros.kQuantity: 2, FormulaMacros.kCarbsPerServing: 0},
        ];
        expect(FormulaMacros.carbScaleFactor(carbFree, 90), 1);
      },
    );

    test('carbScaleFactor ignores zero-quantity components in the base', () {
      final components = [
        {FormulaMacros.kQuantity: 0, FormulaMacros.kCarbsPerServing: 100},
        {FormulaMacros.kQuantity: 1, FormulaMacros.kCarbsPerServing: 25},
      ];
      expect(FormulaMacros.carbScaleFactor(components, 50), 2);
    });

    test('scaledQuantity rounds to 0.5 steps and floors at 0.5', () {
      expect(FormulaMacros.scaledQuantity(1, 3), 3);
      expect(FormulaMacros.scaledQuantity(1, 2.6), 2.5);
      expect(FormulaMacros.scaledQuantity(1, 2.76), 3);
      expect(FormulaMacros.scaledQuantity(1, 0.2), 0.5);
      expect(FormulaMacros.scaledQuantity(2, 0.05), 0.5);
    });
  });
}
