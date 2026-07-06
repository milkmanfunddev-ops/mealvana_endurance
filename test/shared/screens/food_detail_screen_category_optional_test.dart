import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mealvana_endurance/shared/screens/food_detail_screen.dart';
import 'package:mealvana_endurance/shared/widgets/kyle_design/buttons/primary_button.dart';

import '../../helpers/widget_test_harness.dart';

void main() {
  group('FoodDetailScreen category selection is optional', () {
    testWidgets(
      'save button is enabled with no categories selected',
      (tester) async {
        final foodData = FoodDetailData(
          id: 'test-food-id',
          name: 'Gelato',
          carbsPerServing: 30,
          proteinPerServing: 3,
          fatPerServing: 10,
          caloriesPerServing: 220,
          categoryIds: [],
        );

        await pumpSeeded(
          tester,
          FoodDetailScreen(
            foodData: foodData,
            mode: FoodDetailMode.addFromScan,
            showCategories: true,
            preSelectedCategories: [],
          ),
          settle: true,
        );

        final buttonFinder = find.byKey(
          const ValueKey('custom_food.create_button'),
        );
        expect(buttonFinder, findsOneWidget);

        final button = tester.widget<KylePrimaryButton>(buttonFinder);
        expect(
          button.onPressed,
          isNotNull,
          reason: 'Save button should be enabled even with no categories selected',
        );
      },
    );

    testWidgets(
      'category selector shows optional label',
      (tester) async {
        final foodData = FoodDetailData(
          id: 'test-food-id',
          name: 'Gelato',
          carbsPerServing: 30,
          proteinPerServing: 3,
          fatPerServing: 10,
          caloriesPerServing: 220,
          categoryIds: [],
        );

        await pumpSeeded(
          tester,
          FoodDetailScreen(
            foodData: foodData,
            mode: FoodDetailMode.addFromScan,
            showCategories: true,
            preSelectedCategories: [],
          ),
          settle: true,
        );

        expect(
          find.text('Select all that apply (optional)'),
          findsOneWidget,
        );
        expect(
          find.text('Select one or more categories (at least one required)'),
          findsNothing,
        );
      },
    );
  });
}
