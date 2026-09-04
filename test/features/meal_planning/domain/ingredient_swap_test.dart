import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/features/meal_planning/domain/ingredient_swap.dart';
import 'package:mealvana_endurance/features/meal_planning/domain/ui_action.dart';

/// Plan Phase 6.3 — the catalog's `swaps` strings parse into the
/// `{from, to, effect?}` the `swap_ingredient` action sends.
void main() {
  test('parses the catalog arrow form with a bracketed effect', () {
    final swap = IngredientSwap.parse('water→milk (+10g protein)');
    expect(swap, isNotNull);
    expect(swap!.from, 'water');
    expect(swap.to, 'milk');
    expect(swap.effect, '+10g protein');
  });

  test('accepts an ASCII arrow and no effect; rejects non-swaps', () {
    final swap = IngredientSwap.parse('white rice -> quinoa');
    expect(swap?.from, 'white rice');
    expect(swap?.to, 'quinoa');
    expect(swap?.effect, isNull);
    expect(IngredientSwap.parse('add more salt'), isNull);
    expect(IngredientSwap.parseAll(['a→b', 'nope', '→x']).length, 1);
  });

  test('SwapIngredientAction carries the wire payload', () {
    const action = SwapIngredientAction(
      planMealId: 'pm-1',
      from: 'water',
      to: 'milk',
    );
    expect(action.type, 'swap_ingredient');
    expect(action.payloadFields(), {
      'planMealId': 'pm-1',
      'from': 'water',
      'to': 'milk',
    });
  });
}
