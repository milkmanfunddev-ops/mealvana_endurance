import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/features/meal_planning/application/shopping_qty_formatter.dart';
import 'package:mealvana_endurance/features/nutrition_plan/domain/run_parameters.dart';

/// Lee, 2026-09-07: the server aggregates in metric; US shoppers read
/// pounds and ounces unless they chose metric in Settings.
void main() {
  test('metric passes the server text through untouched', () {
    expect(formatShoppingQty('1.4 kg', UnitSystem.metric), '1.4 kg');
    expect(formatShoppingQty('320 g', UnitSystem.metric), '320 g');
  });

  test('imperial converts weights: ounces under a pound, pounds above', () {
    expect(formatShoppingQty('320 g', UnitSystem.imperial), '11.5 oz');
    expect(formatShoppingQty('1.4 kg', UnitSystem.imperial), '3.1 lb');
    expect(formatShoppingQty('900 g', UnitSystem.imperial), '2 lb');
  });

  test('imperial converts volumes: fl oz under a quart, quarts above', () {
    expect(formatShoppingQty('250 ml', UnitSystem.imperial), '8.5 fl oz');
    expect(formatShoppingQty('2 l', UnitSystem.imperial), '2.1 qt');
  });

  test('cups, spoons, counts and words pass through in both systems', () {
    for (final q in ['2 cups', '1 tbsp', '½', '3', '1 clove', 'splash', '']) {
      expect(formatShoppingQty(q, UnitSystem.imperial), q);
      expect(formatShoppingQty(q, UnitSystem.metric), q);
    }
  });

  test('multi-unit lines convert each segment on its own', () {
    expect(
      formatShoppingQty('2 cups + 200 g', UnitSystem.imperial),
      '2 cups + 7 oz',
    );
  });
}
