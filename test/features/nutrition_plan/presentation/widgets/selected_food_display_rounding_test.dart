// Ticket 45 (testing-wave develop-2026-10, Finding 31-005): the swap picker
// used to truncate (95 × 1.5 → 142) while the swapped row rounded (143). Both
// now read Food.caloriesFor, so the picker shows 143.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/features/nutrition_plan/domain/food.dart';
import 'package:mealvana_endurance/features/nutrition_plan/presentation/widgets/swap_food/selected_food_display_widget.dart';

void main() {
  testWidgets('Apple (medium) at 1.5 servings shows 143 kcal', (tester) async {
    // A `template_foods` row as the catalog returns it.
    final apple = Food.fromJson({
      'id': 'apple-medium',
      'name': 'Apple (medium)',
      'serving_unit': 'apple',
      'calories_per_serving': 95,
      'carbs_per_serving': 25,
      'protein_per_serving': 0.5,
      'fat_per_serving': 0.3,
    });

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: SelectedFoodDisplayWidget(
              food: apple,
              quantity: 1.5,
              onQuantityChanged: (_) {},
              onClear: () {},
            ),
          ),
        ),
      ),
    );

    expect(find.text('143 kcal'), findsOneWidget);
    expect(find.text('142 kcal'), findsNothing);
  });
}
