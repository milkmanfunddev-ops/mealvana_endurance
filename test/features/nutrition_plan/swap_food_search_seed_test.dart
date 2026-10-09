/// Testing-wave 68-006 (ticket 74): the swap picker (Add Food, from an Edit
/// Meal swipe) turned red on search: "Tried to modify a provider while the
/// widget tree was building" (dev Sentry MEALVANA-ENDURANCE-DEV-BX).
///
/// `build` seeded the search pool on every data rebuild; once a query was
/// active, `updateFoodPool` re-ran the search (G28) and wrote the search
/// provider inside `build`. The screen now seeds from a listener in
/// `initState`. These tests drive the real [SwapFoodController.refreshFoods]
/// and the real [FoodSearchController]; only the controller's Drift/network
/// load is replaced by a pool shaped like the rows it reads.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/features/barcode_scanning/application/product_detail_service.dart';
import 'package:mealvana_endurance/features/nutrition_plan/domain/food.dart';
import 'package:mealvana_endurance/features/nutrition_plan/presentation/providers/swap_food_controller.dart';
import 'package:mealvana_endurance/features/nutrition_plan/presentation/screens/swap_food_screen.dart';
import 'package:mealvana_endurance/shared/controllers/food_search_controller.dart';
import 'package:mealvana_endurance/shared/services/food_management/nutrition_product_search_service.dart';
import 'package:mealvana_endurance/shared/services/food_management/shared_food_search_service.dart';
import 'package:mocktail/mocktail.dart';

import '../../helpers/widget_test_harness.dart';

class _MockSharedFoodSearchService extends Mock
    implements SharedFoodSearchService {}

class _MockNutritionProductSearchService extends Mock
    implements NutritionProductSearchService {}

class _MockProductDetailService extends Mock implements ProductDetailService {}

/// The real controller with its load replaced: each build answers fresh list
/// instances, the way a reload from Drift does. Everything else (selection,
/// [refreshFoods], My Foods toggle) is the production code.
class _SeededSwapFoodController extends SwapFoodController {
  static int builds = 0;

  @override
  FutureOr<SwapFoodState> build(SwapFoodParams params) async {
    builds++;
    final userFoods = [_userFood()];
    return SwapFoodState(
      recommendations: const [],
      allFoodsForSearch: [_templateRice(), _templateOats(), ...userFoods],
      userFoods: userFoods,
      allUserFoods: userFoods,
      userFoodIds: userFoods.map((f) => f.id).toSet(),
    );
  }
}

Food _templateRice() => const Food(
  id: 'template-rice-cup',
  name: 'Rice (1 cup cooked)',
  servingAmount: 1,
  servingUnit: 'cup',
  carbsPerServing: 45,
  caloriesPerServing: 205,
);

Food _templateOats() => const Food(
  id: 'template-oats',
  name: 'Oatmeal',
  servingAmount: 1,
  servingUnit: 'cup',
  carbsPerServing: 27,
  caloriesPerServing: 150,
);

Food _userFood() => const Food(
  id: 'user-rice-cake',
  name: 'tw68 rice cake',
  servingAmount: 1,
  servingUnit: 'servings',
  carbsPerServing: 7,
  caloriesPerServing: 35,
);

void main() {
  setUpAll(() {
    registerFallbackValue('');
  });

  late List<FlutterErrorDetails> errors;
  void Function(FlutterErrorDetails)? previousOnError;

  setUp(() {
    _SeededSwapFoodController.builds = 0;
    errors = [];
  });

  /// Restores the test framework's error handler (before any expect, or the
  /// binding reports that instead of the failure), then asserts no error
  /// other than layout overflow was raised. The test font is wider than the
  /// app's; overflow is the smoke suite's concern, not this one's.
  void expectNoProviderErrors() {
    FlutterError.onError = previousOnError;
    final unexpected = errors
        .map((e) => e.exceptionAsString())
        .where((s) => !s.contains('overflowed'))
        .toList();
    expect(unexpected, isEmpty);
  }

  Future<void> pumpSwap(WidgetTester tester) async {
    tester.view.physicalSize = standardPhoneSize;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    // Installed inside the test body: testWidgets sets its own handler
    // after setUp runs.
    previousOnError = FlutterError.onError;
    FlutterError.onError = errors.add;

    final shared = _MockSharedFoodSearchService();
    final nutrition = _MockNutritionProductSearchService();
    when(() => shared.searchCatalog(any())).thenAnswer((_) async => []);
    when(
      () => nutrition.search(any(), limit: any(named: 'limit')),
    ).thenAnswer((_) async => []);

    await pumpSeeded(
      tester,
      const SwapFoodScreen(
        foodToSwapId: 'meal-item-1',
        foodToSwapName: 'Toast',
        category: 'after_run',
        activityId: 'activity-68',
      ),
      overrides: [
        swapFoodControllerProvider.overrideWith(_SeededSwapFoodController.new),
        sharedFoodSearchServiceProvider.overrideWithValue(shared),
        nutritionProductSearchServiceProvider.overrideWithValue(nutrition),
        productDetailServiceProvider.overrideWithValue(
          _MockProductDetailService(),
        ),
      ],
    );
    await tester.pump();
  }

  /// Let the 300 ms catalog debounce fire and its answer land.
  Future<void> settleSearch(WidgetTester tester) async {
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pump();
    await tester.pump();
  }

  ProviderContainer containerOf(WidgetTester tester) =>
      ProviderScope.containerOf(tester.element(find.byType(SwapFoodScreen)));

  /// The search results the screen renders from (My Foods rows are
  /// collapsed under their header, so they are read from state).
  List<String> userResultNames(WidgetTester tester) => containerOf(tester)
      .read(foodSearchControllerProvider('swap_food'))
      .userFoodResults
      .map((f) => f.name)
      .toList();

  SwapFoodController notifier(WidgetTester tester) {
    return containerOf(tester).read(
      swapFoodControllerProvider(
        const SwapFoodParams(
          activityId: 'activity-68',
          category: 'after_run',
          originalFoodId: 'meal-item-1',
          originalFoodName: 'Toast',
        ),
      ).notifier,
    );
  }

  testWidgets('typing "rice" lists the rice rows and nothing throws', (
    tester,
  ) async {
    await pumpSwap(tester);

    await tester.enterText(
      find.byKey(const ValueKey('swap_food.search_field')),
      'rice',
    );
    await settleSearch(tester);

    expectNoProviderErrors();
    expect(find.text('Rice (1 cup cooked)'), findsOneWidget);
    expect(userResultNames(tester), ['tw68 rice cake']);
    expect(find.text('Oatmeal'), findsNothing);
  });

  testWidgets(
    'refreshFoods while the query is active re-filters the new pool and '
    'nothing throws',
    (tester) async {
      await pumpSwap(tester);

      await tester.enterText(
        find.byKey(const ValueKey('swap_food.search_field')),
        'rice',
      );
      await settleSearch(tester);
      final buildsBefore = _SeededSwapFoodController.builds;

      // The screen calls this after a scan, an import or a Create Food.
      final refresh = notifier(tester).refreshFoods();
      await tester.pump();
      await tester.pump();
      await refresh;
      await settleSearch(tester);

      expect(_SeededSwapFoodController.builds, greaterThan(buildsBefore));
      expectNoProviderErrors();
      expect(find.text('Rice (1 cup cooked)'), findsOneWidget);
      expect(userResultNames(tester), ['tw68 rice cake']);
    },
  );

  testWidgets('two refreshes at once leave one consistent result list', (
    tester,
  ) async {
    await pumpSwap(tester);

    await tester.enterText(
      find.byKey(const ValueKey('swap_food.search_field')),
      'rice',
    );
    await settleSearch(tester);

    final controller = notifier(tester);
    final first = controller.refreshFoods();
    final second = controller.refreshFoods();
    await tester.pump();
    await tester.pump();
    await Future.wait([first, second]);
    await settleSearch(tester);

    expectNoProviderErrors();
    expect(find.text('Rice (1 cup cooked)'), findsOneWidget);
  });
}
