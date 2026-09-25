import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/features/content/application/content_service.dart';
import 'package:mealvana_endurance/features/meal_planning/application/meal_catalog_controller.dart';
import 'package:mealvana_endurance/features/meal_planning/data/meal_library_remote_data_source.dart';
import 'package:mealvana_endurance/features/meal_planning/presentation/widgets/meal_catalog_browser.dart';

import '../helpers/test_content.dart';

/// Testing-wave 18-004: a flat Browse result (search or filter) printed the
/// library row's research note under the meal's name. The subtitle is the
/// meal's ingredients, or nothing; the note stays off the card.
void main() {
  // Producer-shaped: search_meals rows as the RPC returns them, `why` being
  // the research note the library was seeded with.
  const note =
      'Dinner: salmon, tofu or steak with some quinoa and asparagus and a '
      'spinach salad.';
  final withIngredients = MealLibraryRemoteDataSource.rowToMealRef({
    'source': 'library',
    'id': 'LD-041',
    'name': 'Tofu, quinoa, asparagus & spinach salad',
    'meal_type': 'dinner',
    'why': note,
    'ingredients': 'tofu, quinoa, asparagus, spinach, olive oil',
    'score': 0.5,
  })!;
  final saved = MealLibraryRemoteDataSource.rowToMealRef({
    'source': 'saved',
    'id': '3b0c1d4e-0000-4000-8000-000000000001',
    'name': 'My lentil bowl',
    'meal_type': 'dinner',
    'why': 'one of your saved meals',
    'ingredients': '',
    'score': 0.65,
  })!;

  Future<void> pumpBrowser(WidgetTester t, MealCatalogState state) async {
    await t.pumpWidget(
      ProviderScope(
        overrides: [
          contentServiceProvider.overrideWith(testContentService),
          mealCatalogControllerProvider.overrideWith(
            () => _FixedCatalogController(state),
          ),
        ],
        child: MaterialApp(
          home: Scaffold(body: MealCatalogBrowser(onOpenMeal: (_) {})),
        ),
      ),
    );
    await t.pump();
  }

  testWidgets(
    'a search result shows its ingredients, never the research note',
    (t) async {
      await pumpBrowser(
        t,
        MealCatalogState(query: 'tofu', results: [withIngredients, saved]),
      );

      expect(find.text(withIngredients.name), findsOneWidget);
      expect(find.text(note), findsNothing);
      expect(
        find.text('tofu, quinoa, asparagus, spinach, olive oil'),
        findsOneWidget,
      );
      // A saved meal with no ingredient line shows no subtitle, not the
      // "one of your saved meals" stand-in.
      expect(find.text('one of your saved meals'), findsNothing);
    },
  );

  testWidgets('a filtered result does not show the research note either', (
    t,
  ) async {
    await pumpBrowser(
      t,
      MealCatalogState(
        mealType: withIngredients.mealType,
        results: [withIngredients],
      ),
    );

    expect(find.text(note), findsNothing);
    expect(
      find.text('tofu, quinoa, asparagus, spinach, olive oil'),
      findsOneWidget,
    );
  });
}

class _FixedCatalogController extends MealCatalogController {
  _FixedCatalogController(this.fixed);

  final MealCatalogState fixed;

  @override
  FutureOr<MealCatalogState> build() => fixed;
}
