/// Widget tests for [LogScannedFoodScreen] — the food-logging-specific
/// confirmation page shown after a barcode scan in the meal-log flow.
///
/// This page deliberately replaces the nutrition-plan `FoodDetailScreen`
/// (before/during/after-run category assignment) when the user is simply
/// logging what they ate. It must return a [ScannedFoodLogRequest] carrying the
/// chosen servings + meal slot, and `null` when the user backs out.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mealvana_endurance/features/meal_logging/domain/meal_slot.dart';
import 'package:mealvana_endurance/features/meal_logging/presentation/screens/log_scanned_food_screen.dart';
import 'package:mealvana_endurance/features/nutrition_plan/domain/food.dart';

const _gel = Food(
  id: 'gel-1',
  name: 'Energy Gel',
  displayName: 'Caffeine Energy Gel',
  servingAmount: 1,
  servingUnit: 'gel',
  caloriesPerServing: 100,
  carbsPerServing: 22,
  proteinPerServing: 0,
  fatPerServing: 0,
  sodiumMg: 50,
);

/// Sizes a tall surface (default 800x600 clips the chips + bottom button),
/// pumps the host, and opens [LogScannedFoodScreen].
Future<void> _open(
  WidgetTester tester, {
  ValueChanged<ScannedFoodLogRequest?>? onResult,
  MealSlot initialSlot = MealSlot.snack,
}) async {
  await tester.binding.setSurfaceSize(const Size(800, 1400));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    _host(onResult: onResult ?? (_) {}, initialSlot: initialSlot),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

/// Builds a host app that pushes [LogScannedFoodScreen] when "open" is tapped,
/// storing the popped result via [onResult].
Widget _host({
  required ValueChanged<ScannedFoodLogRequest?> onResult,
  MealSlot initialSlot = MealSlot.snack,
}) {
  return ProviderScope(
    child: MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () async {
                final r = await Navigator.of(context)
                    .push<ScannedFoodLogRequest>(
                      MaterialPageRoute(
                        builder: (_) => LogScannedFoodScreen(
                          food: _gel,
                          initialSlot: initialSlot,
                        ),
                      ),
                    );
                onResult(r);
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('renders the scanned product name and per-serving nutrition', (
    tester,
  ) async {
    await _open(tester);

    expect(find.text('Log Food'), findsWidgets); // app bar + button
    expect(find.text('Caffeine Energy Gel'), findsOneWidget);
    expect(find.text('100'), findsOneWidget); // calories, 1 serving
    expect(find.text('22'), findsOneWidget); // carbs, 1 serving
    expect(find.text('Snack'), findsOneWidget);
    expect(find.text('Breakfast'), findsOneWidget);
  });

  testWidgets('incrementing servings scales nutrition and is returned in the '
      'request', (tester) async {
    ScannedFoodLogRequest? result;
    await _open(tester, onResult: (r) => result = r);

    // Bump servings 1 -> 2 (two +0.5 taps).
    final plus = find.byIcon(Icons.add_circle_outline);
    await tester.tap(plus);
    await tester.pump();
    await tester.tap(plus);
    await tester.pump();

    // Nutrition now reflects 2 servings: 200 kcal, 44 g carbs.
    expect(find.text('200'), findsOneWidget);
    expect(find.text('44'), findsOneWidget);

    await tester.tap(find.widgetWithText(ElevatedButton, 'Log Food').first);
    await tester.pumpAndSettle();

    expect(result, isNotNull);
    expect(result!.servings, 2.0);
    expect(result!.slot, MealSlot.snack);
  });

  testWidgets('choosing a different meal slot is returned in the request', (
    tester,
  ) async {
    ScannedFoodLogRequest? result;
    await _open(tester, onResult: (r) => result = r);

    await tester.tap(find.text('Lunch'));
    await tester.pump();
    await tester.tap(find.widgetWithText(ElevatedButton, 'Log Food').first);
    await tester.pumpAndSettle();

    expect(result, isNotNull);
    expect(result!.slot, MealSlot.lunch);
  });

  testWidgets('servings cannot go below the 0.5 minimum', (tester) async {
    await _open(tester);

    final minus = find.byIcon(Icons.remove_circle_outline);
    // From 1.0: -0.5 -> 0.5 (allowed), then the button disables at the floor.
    await tester.tap(minus);
    await tester.pump();
    expect(find.text('0.5'), findsOneWidget);

    final IconButton minusButton = tester.widget(
      find.ancestor(of: minus, matching: find.byType(IconButton)),
    );
    expect(
      minusButton.onPressed,
      isNull,
      reason: 'decrement disabled at the 0.5 floor',
    );
  });

  testWidgets('backing out returns null (no log request)', (tester) async {
    ScannedFoodLogRequest? result;
    bool called = false;
    await _open(
      tester,
      onResult: (r) {
        result = r;
        called = true;
      },
    );

    // Pop the route without confirming (simulates the back button).
    final NavigatorState nav = tester.state(find.byType(Navigator));
    nav.pop();
    await tester.pumpAndSettle();

    expect(called, isTrue);
    expect(result, isNull);
  });
}
