// The Swap screen never offers a meal whose numbers are missing (mp-678,
// testing-wave 74 / 61-001): a swap puts the pick into the plan, and a plan
// never takes a meal without its kcal, carbs, protein and fat.
//
// The candidates are `search_meals`-shaped rows mapped through the real
// `rowToMealRef`, so the null-ness under test is the one the database sends.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/features/content/application/content_service.dart';
import 'package:mealvana_endurance/features/meal_planning/application/meal_plan_controller.dart';
import 'package:mealvana_endurance/features/meal_planning/data/meal_library_remote_data_source.dart';
import 'package:mealvana_endurance/features/meal_planning/data/vana_action_client.dart';
import 'package:mealvana_endurance/features/meal_planning/domain/meal_context.dart';
import 'package:mealvana_endurance/features/meal_planning/domain/meal_plan.dart';
import 'package:mealvana_endurance/features/meal_planning/domain/meal_ref.dart';
import 'package:mealvana_endurance/features/meal_planning/domain/meal_source.dart';
import 'package:mealvana_endurance/features/meal_planning/domain/meal_type.dart';
import 'package:mealvana_endurance/features/meal_planning/domain/plan_meal.dart';
import 'package:mealvana_endurance/features/meal_planning/presentation/screens/swap_meal_screen.dart';

import '../../domain/fixture_helpers.dart';
import '../helpers/test_content.dart';

/// A row as `search_meals` returns it: the library row, sourced and scored.
Map<String, dynamic> _searchRow(
  String id,
  String name, {
  Object? kcal = 600,
  Object? carbs = 70.0,
  Object? protein = 35.0,
  Object? fat = 15.0,
}) => {
  'id': id,
  'name': name,
  'meal_type': 'dinner',
  'source': 'library',
  'library_meal_id': id,
  'contexts': const ['everyday'],
  'batch': true,
  'prep_minutes': 20,
  'kcal': kcal,
  'carbs_g': carbs,
  'protein_g': protein,
  'fat_g': fat,
  'allergens': const <String>[],
  'diets_ok': const <String>[],
  'why': 'fits the week',
  'attribution': 'the library',
  'ingredients': 'rice, beans',
  'kind': 'assembly',
  'score': 0.9,
};

class _FakeRemote extends Fake implements MealLibraryRemoteDataSource {
  _FakeRemote(this.rows);
  final List<Map<String, dynamic>> rows;

  @override
  Future<List<MealRef>> searchMeals({
    String? query,
    MealType? mealType,
    List<MealContext>? contexts,
    bool? batch,
    bool includeSaved = true,
    int limit = 12,
    List<String>? excludeAllergens,
    String? requireDiet,
    MealKind? kind,
    bool includeDisliked = false,
    Set<String> excludeIds = const {},
    int offset = 0,
  }) async => [
    for (final r in rows) MealLibraryRemoteDataSource.rowToMealRef(r)!,
  ];
}

/// Holds a plan with one dinner, the meal being swapped out.
class _PlanController extends MealPlanController {
  _PlanController(this.plan);
  final MealPlan plan;

  @override
  Future<MealPlan?> build() async => plan;
}

void main() {
  final content = loadDefaultContent();

  MealPlan planWithOneDinner() {
    final fixture = VanaActionResult.fromJson(loadFixture('batch')).plan!;
    return fixture.copyWith(
      meals: [
        PlanMeal(
          id: 'pm-1',
          planId: fixture.id,
          source: MealSource.library,
          libraryMealId: 'AD-014',
          name: 'Salmon quinoa bowl',
          mealType: MealType.dinner,
          servings: 4,
          servingsLeft: 4,
        ),
      ],
    );
  }

  testWidgets('the Swap list leaves out a meal whose numbers are missing', (
    tester,
  ) async {
    // The screen reads the plan once, after its first frame, the way it finds
    // it loaded when opened from the Plan tab.
    final container = ProviderContainer(
      overrides: [
        contentServiceProvider.overrideWith(testContentService),
        mealPlanControllerProvider.overrideWith(
          () => _PlanController(planWithOneDinner()),
        ),
        mealLibraryRemoteDataSourceProvider.overrideWithValue(
          _FakeRemote([
            // Ranked first, so a guard that only looked past the top
            // result would still be caught.
            _searchRow(
              'AD-103',
              'Farro & cauliflower bowl',
              kcal: null,
              carbs: null,
              protein: null,
              fat: null,
            ),
            _searchRow('AD-015', 'Lentil dal'),
            // One number missing is enough to leave it out.
            _searchRow('AD-016', 'Tofu stir fry', fat: null),
            // 0 g fat is a number: this one stays.
            _searchRow('AD-017', 'Chicken rice', fat: 0),
          ]),
        ),
      ],
    );
    addTearDown(container.dispose);
    await tester.runAsync(
      () => container.read(mealPlanControllerProvider.future),
    );
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: SwapMealScreen(planMealId: 'pm-1')),
      ),
    );
    await tester.pump();
    await tester.pump();
    await tester.pump();

    expect(find.text(content['meal_planning.swap_title']!), findsOneWidget);
    expect(find.text('Lentil dal'), findsOneWidget);
    expect(find.text('Chicken rice'), findsOneWidget);
    expect(find.text('Farro & cauliflower bowl'), findsNothing);
    expect(find.text('Tofu stir fry'), findsNothing);
  });
}
