import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/features/content/application/content_service.dart';
import 'package:mealvana_endurance/features/meal_planning/data/meal_library_remote_data_source.dart';
import 'package:mealvana_endurance/features/meal_planning/domain/meal_context.dart';
import 'package:mealvana_endurance/features/meal_planning/domain/meal_ref.dart';
import 'package:mealvana_endurance/features/meal_planning/domain/meal_source.dart';
import 'package:mealvana_endurance/features/meal_planning/domain/meal_type.dart';
import 'package:mealvana_endurance/features/meal_planning/domain/plan_meal.dart';
import 'package:mealvana_endurance/features/meal_planning/presentation/widgets/meal_card.dart';
import 'package:mealvana_endurance/features/meal_planning/presentation/widgets/meal_sheet.dart';

import '../helpers/test_content.dart';

/// search_meals rows as the RPC returns them (producer-shaped), `why` being
/// the library's research note.
Map<String, dynamic> _row(String id, String name, {String ingredients = ''}) =>
    {
      'source': 'library',
      'id': id,
      'name': name,
      'meal_type': 'dinner',
      'why': 'his dinner base is "rice, quinoa or wholewheat pasta"',
      'ingredients': ingredients,
      'kcal': 520,
      'carbs_g': 75,
      'protein_g': 15,
      'fat_g': 18,
      'score': 0.5,
    };

/// Answers with fixed rows run through the real row selection, so the
/// exclusions are the data source's own, and records what it was asked.
class _RecordingRemote extends Fake implements MealLibraryRemoteDataSource {
  _RecordingRemote(this.rows);
  final List<Map<String, dynamic>> rows;
  Set<String>? excludeIds;
  bool? requireNumbers;

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
    bool requireNutritionNumbers = false,
  }) async {
    this.excludeIds = excludeIds;
    requireNumbers = requireNutritionNumbers;
    return MealLibraryRemoteDataSource.selectSearchRows(
      rows,
      limit: limit,
      excludeIds: excludeIds,
      requireNutritionNumbers: requireNutritionNumbers,
    );
  }
}

void main() {
  group('MealCard subtitle (testing-wave 89-003)', () {
    Future<void> pumpCard(WidgetTester t, MealRef meal, {String? subtitle}) =>
        t.pumpWidget(
          ProviderScope(
            overrides: [
              contentServiceProvider.overrideWith(testContentService),
            ],
            child: MaterialApp(
              home: Scaffold(
                body: MealCard(meal: meal, onTap: () {}, subtitle: subtitle),
              ),
            ),
          ),
        );

    testWidgets('with no subtitle the card shows no research note', (t) async {
      final meal = MealLibraryRemoteDataSource.rowToMealRef(
        _row('AD-014', 'Wholewheat pasta, mixed veg & avocado'),
      )!;
      await pumpCard(t, meal);
      expect(find.text(meal.name), findsOneWidget);
      expect(find.textContaining('his dinner base'), findsNothing);
    });

    testWidgets('a subtitle that only repeats the name is not shown', (
      t,
    ) async {
      final meal = MealLibraryRemoteDataSource.rowToMealRef({
        ..._row('3b0c1d4e-0000-4000-8000-000000000002', 'Egg & Veggie Scramble'),
        'source': 'saved',
        'ingredients': 'Egg & Veggie Scramble',
      })!;
      await pumpCard(t, meal, subtitle: meal.ingredients);
      expect(find.text('Egg & Veggie Scramble'), findsOneWidget);
    });
  });

  group('the chat meal sheet swap list (testing-wave 88-009)', () {
    testWidgets('never offers the swapped meal or a meal already in the plan', (
      t,
    ) async {
      final remote = _RecordingRemote([
        _row('AD-015', 'Quinoa, mixed veg & walnuts'),
        _row('AD-020', 'Wholewheat pasta'),
        _row('AD-030', 'Salmon, rice & greens', ingredients: 'salmon, rice'),
      ]);
      const swapping = PlanMeal(
        id: 'pm-1',
        planId: 'plan-1',
        source: MealSource.library,
        libraryMealId: 'AD-015',
        name: 'Quinoa, mixed veg & walnuts',
        mealType: MealType.dinner,
        servings: 4,
        servingsLeft: 4,
      );
      const other = PlanMeal(
        id: 'pm-2',
        planId: 'plan-1',
        source: MealSource.library,
        libraryMealId: 'AD-020',
        name: 'Wholewheat pasta',
        mealType: MealType.dinner,
        servings: 4,
        servingsLeft: 4,
      );

      await t.pumpWidget(
        ProviderScope(
          overrides: [
            contentServiceProvider.overrideWith(testContentService),
            mealLibraryRemoteDataSourceProvider.overrideWithValue(remote),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: MealSheet(
                meal: swapping,
                onServings: (_) {},
                onSwap: (_, __) {},
                onRemove: () {},
                excludeIds: MealSheet.planMealIds(const [swapping, other]),
              ),
            ),
          ),
        ),
      );
      await t.tap(find.byKey(const ValueKey('meal_planning.meal_sheet.swap')));
      await t.pumpAndSettle();

      expect(remote.excludeIds, containsAll(<String>['AD-015', 'AD-020']));
      expect(remote.requireNumbers, isTrue);
      expect(find.text('Salmon, rice & greens'), findsOneWidget);
      expect(find.text('Wholewheat pasta'), findsNothing);
      // The header names the swapped meal once; no candidate repeats it.
      expect(find.text('Quinoa, mixed veg & walnuts'), findsOneWidget);
    });

    testWidgets('the swapped meal is left out even when a host passes nothing', (
      t,
    ) async {
      final remote = _RecordingRemote([_row('AD-015', 'Quinoa')]);
      await t.pumpWidget(
        ProviderScope(
          overrides: [
            contentServiceProvider.overrideWith(testContentService),
            mealLibraryRemoteDataSourceProvider.overrideWithValue(remote),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: MealSheet(
                meal: const PlanMeal(
                  id: 'pm-1',
                  planId: 'plan-1',
                  source: MealSource.library,
                  libraryMealId: 'AD-015',
                  name: 'Quinoa, mixed veg & walnuts',
                  mealType: MealType.dinner,
                  servings: 4,
                  servingsLeft: 4,
                ),
                onServings: (_) {},
                onSwap: (_, __) {},
                onRemove: () {},
              ),
            ),
          ),
        ),
      );
      await t.tap(find.byKey(const ValueKey('meal_planning.meal_sheet.swap')));
      await t.pumpAndSettle();
      expect(remote.excludeIds, {'AD-015'});
      expect(find.text('Quinoa'), findsNothing);
    });
  });
}
