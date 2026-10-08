// Ticket 38 (testing-wave develop-2026-10): the swap path keeps the quantity
// apart from the portion text.
//
// Review & Log and Edit Meal used to build the swapped item with the quantity
// folded into the portion ("2 cups") and no `quantity`, so reopening it showed
// Quantity 1 over "2 cups". Both now call [swappedComponent]: the portion is
// the per-serving base, the macros hold what was eaten, and `quantity` says how
// many servings. The foods are `template_foods` rows parsed by the real
// [Food.fromJson], the shape the swap sheet hands back.
//
// The second group drives the real Review & Log screen: swipe an item to swap,
// the swap route answers a [SwapFoodSelection], and the row reads "2 × 1 cup".
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mealvana_endurance/features/meal_logging/domain/meal_analysis_result.dart';
import 'package:mealvana_endurance/features/meal_logging/domain/meal_swap.dart';
import 'package:mealvana_endurance/features/meal_logging/presentation/screens/meal_review_screen.dart';
import 'package:mealvana_endurance/features/nutrition_plan/domain/food.dart';
import 'package:mealvana_endurance/features/nutrition_plan/presentation/providers/swap_food_controller.dart';
import 'package:mealvana_endurance/shared/services/app_config.dart';

import '../../helpers/widget_test_harness.dart';

/// A `template_foods` row as the catalog returns it.
Food _oatmeal({String? servingUnit = 'cup'}) => Food.fromJson({
  'id': 'oatmeal-cooked',
  'name': 'Oatmeal',
  'display_name': 'Cooked oatmeal',
  'serving_unit': servingUnit,
  'serving_unit_plural': servingUnit == null ? null : '${servingUnit}s',
  'calories_per_serving': 150,
  'carbs_per_serving': 27,
  'protein_per_serving': 5.5,
  'fat_per_serving': 2.5,
  'sodium_mg': 115,
});

void main() {
  group('swappedComponent', () {
    test('qty 2 keeps one serving as the portion and 2 as the quantity', () {
      final c = swappedComponent(_oatmeal(), 2);

      expect(c.name, 'Cooked oatmeal');
      expect(c.portion, '1 cup');
      expect(c.quantity, 2);
      expect(c.portionLabel, '2 × 1 cup');
      // Macros hold what was eaten (02-005).
      expect(c.calories, 300);
      expect(c.carbG, 54);
      expect(c.proteinG, 11);
      expect(c.fatG, 5);
      expect(c.sodiumMg, 230);
    });

    test('qty 1 reads as the bare portion', () {
      final c = swappedComponent(_oatmeal(), 1);

      expect(c.portion, '1 cup');
      expect(c.quantity, 1);
      expect(c.portionLabel, '1 cup');
      expect(c.calories, 150);
      expect(c.toJson().containsKey('quantity'), isFalse);
    });

    test('a food with no serving unit is one serving', () {
      final c = swappedComponent(_oatmeal(servingUnit: null), 1.5);

      expect(c.portion, '1 serving');
      expect(c.portionLabel, '1.5 × 1 serving');
      expect(c.calories, 225);
    });

    // Ticket 45 (31-005): the row and the swap picker round once, the same
    // way, through Food.caloriesFor. 95 × 1.5 = 142.5 → 143 in both.
    test('Apple (medium) at 1.5 servings is 143 kcal, macros rounded', () {
      final apple = Food.fromJson({
        'id': 'apple-medium',
        'name': 'Apple (medium)',
        'serving_unit': 'apple',
        'calories_per_serving': 95,
        'carbs_per_serving': 25.1,
        'protein_per_serving': 0.5,
        'fat_per_serving': 0.3,
        'sodium_mg': 1,
      });

      final c = swappedComponent(apple, 1.5);

      expect(c.calories, 143);
      expect(c.calories, apple.caloriesFor(1.5));
      // 25.1 × 1.5 = 37.650000000000006 before rounding (112-004).
      expect(c.carbG, 37.7);
      expect(c.proteinG, 0.8);
      expect(c.fatG, 0.5);
      expect(c.sodiumMg, 2);
    });

    test('unknown numbers stay unknown', () {
      final c = swappedComponent(
        Food.fromJson({'id': 'x', 'name': 'Mystery', 'serving_unit': 'bar'}),
        2,
      );

      expect(c.name, 'Mystery');
      expect(c.calories, isNull);
      expect(c.carbG, isNull);
      expect(c.proteinG, isNull);
      expect(c.fatG, isNull);
      expect(c.sodiumMg, isNull);
    });
  });

  group('Review & Log swap', () {
    testWidgets('swapping an item at quantity 2 shows "2 × 1 cup"', (
      tester,
    ) async {
      tester.view.physicalSize = standardPhoneSize;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      // The `describe-meal` answer (MealAnalysisSchema), parsed for real.
      final result = MealAnalysisResult.fromJson({
        'name': 'Breakfast',
        'suggested_slot': 'breakfast',
        'confidence': 'high',
        'items': [
          {
            'name': 'Granola',
            'portion': '1/2 cup',
            'calories': 200,
            'carb_g': 30,
            'protein_g': 5,
            'fat_g': 7,
            'sodium_mg': 40,
          },
        ],
        'totals': {
          'calories': 200,
          'carb_g': 30,
          'protein_g': 5,
          'fat_g': 7,
          'sodium_mg': 40,
        },
      });

      final router = GoRouter(
        initialLocation: '/main',
        routes: [
          GoRoute(
            path: '/main',
            builder: (context, _) => Scaffold(
              body: TextButton(
                onPressed: () => context.push(
                  '/meal-log/review',
                  extra: {
                    'result': result,
                    'source': 'describe',
                    'logDate': '2026-10-08',
                    'photoPath': null,
                  },
                ),
                child: const Text('open review'),
              ),
            ),
          ),
          GoRoute(
            path: '/meal-log/review',
            builder: (_, _) => const MealReviewScreen(),
          ),
          // Stands in for the swap sheet: the user picks oatmeal, quantity 2.
          GoRoute(
            path: '/swap-food',
            builder: (context, _) => Scaffold(
              body: TextButton(
                onPressed: () => context.pop(
                  SwapFoodSelection(
                    food: _oatmeal(),
                    quantity: 2,
                    isUserFood: false,
                  ),
                ),
                child: const Text('pick oatmeal x2'),
              ),
            ),
          ),
        ],
      );
      addTearDown(router.dispose);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            mockAppExternalDeps(),
            appConfigProvider.overrideWithValue(AppConfig.forTesting()),
          ],
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pump();
      await tester.tap(find.text('open review'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('Granola'), findsOneWidget);

      // Swipe right-to-left = swap.
      await tester.drag(find.text('Granola'), const Offset(-500, 0));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.tap(find.text('pick oatmeal x2'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.byType(MealReviewScreen), findsOneWidget);
      expect(find.text('Granola'), findsNothing);
      expect(find.text('Cooked oatmeal'), findsOneWidget);
      expect(find.textContaining('2 × 1 cup'), findsOneWidget);
      expect(find.textContaining('2 cups'), findsNothing);
    });
  });
}
