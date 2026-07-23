// Regression coverage for bug 3a3e3fdb: the recipe picker screen
// (`/meal-log/recipe`) used to call `logRecipe` with no `eatenAt` at all, so
// the entry stored null and the fuel timeline fell back to `createdAt`
// (== now) — a recipe logged onto a back-dated day sank to the bottom of that
// day's timeline instead of landing in its chronological slot.
//
// Drives the real screen (router extra -> list tile -> log sheet -> confirm)
// and asserts the controller receives an eatenAt on the passed logDate.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:mealvana_endurance/features/meal_logging/application/meal_logging_service.dart'
    show RecipeLogParams;
import 'package:mealvana_endurance/features/meal_logging/domain/meal_slot.dart';
import 'package:mealvana_endurance/features/meal_logging/presentation/providers/meal_log_providers.dart';
import 'package:mealvana_endurance/features/meal_logging/presentation/screens/recipe_picker_screen.dart';
import 'package:mealvana_endurance/features/recipes/application/recipe_service.dart';
import 'package:mealvana_endurance/features/recipes/domain/recipe.dart';
import 'package:mealvana_endurance/shared/services/app_config.dart';

import '../../helpers/widget_test_harness.dart';

const _testRecipe = Recipe(
  id: 'r1',
  name: 'Back-date Bowl',
  description: 'Test recipe',
  ingredients: ['oats'],
  instructions: ['mix'],
  prepTimeMinutes: 5,
  servings: 1,
  type: RecipeType.breakfast,
  nutrition: RecipeNutrition(
    calories: 400,
    carbohydratesGrams: 60,
    proteinGrams: 20,
    fatGrams: 10,
    fiberGrams: 5,
    sugarGrams: 8,
    sodiumMilligrams: 300,
  ),
);

/// Serves one recipe with no repository / Supabase behind it. Only the two
/// members the picker screen touches are implemented.
class _FakeRecipeService implements RecipeService {
  @override
  Future<void> ensureSynced(String userId, {bool force = false}) async {}

  @override
  Future<List<Recipe>> getAllRecipes() async => const [_testRecipe];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Captures the arguments the screen hands to [MealLogController.logRecipe]
/// instead of writing to the database.
class _CapturingMealLogController extends MealLogController {
  String? capturedLogDate;
  DateTime? capturedEatenAt;
  bool eatenAtWasPassed = false;

  @override
  Future<void> logRecipe({
    required RecipeLogParams params,
    MealSlot? slot,
    required String logDate,
    DateTime? eatenAt,
    String? notes,
  }) async {
    capturedLogDate = logDate;
    capturedEatenAt = eatenAt;
    eatenAtWasPassed = eatenAt != null;
    state = const AsyncData(null);
  }
}

void main() {
  testWidgets('logging a recipe onto a back-dated day passes an eatenAt '
      'on that day', (tester) async {
    final controller = _CapturingMealLogController();

    final router = GoRouter(
      initialLocation: '/',
      initialExtra: {'logDate': '2026-07-19'},
      routes: [
        GoRoute(path: '/', builder: (_, __) => const RecipePickerScreen()),
        GoRoute(
          path: '/main',
          builder: (_, __) => const Scaffold(body: SizedBox()),
        ),
      ],
    );
    addTearDown(router.dispose);

    final overrides = <Override>[
      mockAppExternalDeps(),
      appConfigProvider.overrideWithValue(AppConfig.forTesting()),
      recipeServiceProvider.overrideWithValue(_FakeRecipeService()),
      mealLogControllerProvider.overrideWith(() => controller),
    ];

    await tester.pumpWidget(
      ProviderScope(
        overrides: overrides,
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    // Recipe list rendered from the fake service.
    expect(find.text('Back-date Bowl'), findsOneWidget);

    // Open the log sheet and confirm with defaults.
    await tester.tap(find.text('Back-date Bowl'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Log Recipe'));
    await tester.pumpAndSettle();

    expect(controller.capturedLogDate, '2026-07-19');
    expect(
      controller.eatenAtWasPassed,
      isTrue,
      reason:
          'recipe picker must seed eatenAt from logDate — a null eatenAt '
          'falls back to createdAt (now) and breaks timeline ordering',
    );
    expect(controller.capturedEatenAt!.year, 2026);
    expect(controller.capturedEatenAt!.month, 7);
    expect(controller.capturedEatenAt!.day, 19);
  });
}
