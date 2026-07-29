import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/features/nutrition_plan/domain/food_item_data.dart';
import 'package:mealvana_endurance/features/nutrition_plan/domain/plan_section.dart';

// Regression for bug 3abe3fdb754c8153: the curated template name
// ("Smoothie") was never shown — templateSummary gated it behind an
// empty-foodItems condition that never occurs, so a 3-ingredient smoothie
// rendered as three unrelated food lines.
void main() {
  const banana = FoodItemData(id: 'f1', name: 'banana', quantity: '0.5', displayName: 'Banana');
  const blueberries = FoodItemData(
    id: 'f2',
    name: 'blueberries',
    quantity: '0.5',
    displayName: 'Blueberries',
  );
  const milk = FoodItemData(id: 'f3', name: 'milk', quantity: '0.5', displayName: 'Milk');

  group('BeforeSubPhase.templateSummary', () {
    test('prefers the curated template name when present', () {
      const sub = BeforeSubPhase(
        subPhaseType: 'snack',
        foodItems: [banana, blueberries, milk],
        templateName: 'Smoothie',
      );
      expect(sub.templateSummary, 'Smoothie');
    });

    test('falls back to joined ingredient names when no template name', () {
      const sub = BeforeSubPhase(
        subPhaseType: 'snack',
        foodItems: [banana, blueberries, milk],
      );
      expect(sub.templateSummary, 'Banana + Blueberries + Milk');
    });

    test('empty template name also falls back to the ingredient join', () {
      const sub = BeforeSubPhase(
        subPhaseType: 'snack',
        foodItems: [banana, milk],
        templateName: '',
      );
      expect(sub.templateSummary, 'Banana + Milk');
    });

    test('returns template name even with no food items', () {
      const sub = BeforeSubPhase(
        subPhaseType: 'meal',
        foodItems: [],
        templateName: 'Oatmeal + Raisins',
      );
      expect(sub.templateSummary, 'Oatmeal + Raisins');
    });
  });
}
