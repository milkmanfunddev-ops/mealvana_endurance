import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/features/content/application/content_service.dart';
import 'package:mealvana_endurance/features/meal_planning/application/meal_catalog_controller.dart';
import 'package:mealvana_endurance/features/meal_planning/data/meal_library_remote_data_source.dart';
import 'package:mealvana_endurance/features/meal_planning/domain/meal_image.dart';
import 'package:mealvana_endurance/features/meal_planning/domain/meal_ref.dart';
import 'package:mealvana_endurance/features/meal_planning/presentation/widgets/meal_catalog_browser.dart';
import 'package:mealvana_endurance/features/meal_planning/presentation/widgets/meal_icon_glyphs.dart';

import '../helpers/test_content.dart';

/// Search results share one photograph between two porridges. The list shows
/// it once; the second porridge keeps its icon, and tapping it still opens the
/// Meal as it is — the rule changes what the list draws, not the Meal.
void main() {
  const porridge = 'https://upload.wikimedia.org/porridge.jpg';

  MealRef meal(String id, String name, Map<String, dynamic> image) =>
      MealLibraryRemoteDataSource.rowToMealRef({
        'source': 'library',
        'id': id,
        'name': name,
        'meal_type': 'breakfast',
        ...image,
      })!;

  final dish = {
    'image_mode': 'dish',
    'image_url': porridge,
    'image_credit': 'VirtualSteve · CC-BY-SA-2.5 · Wikimedia Commons',
    'image_tiles': <dynamic>[],
  };
  final results = [
    meal('AB-010', 'Porridge with brown sugar & chia', dish),
    meal('AB-096', 'Plain porridge with stewed pear', dish),
  ];

  Finder photo(String url) => find.byWidgetPredicate(
    (w) =>
        w is Image &&
        w.image is NetworkImage &&
        (w.image as NetworkImage).url == url,
  );

  testWidgets('a photograph appears once in a list of results', (t) async {
    final opened = <MealRef>[];
    await t.pumpWidget(
      ProviderScope(
        overrides: [
          contentServiceProvider.overrideWith(testContentService),
          mealCatalogControllerProvider.overrideWith(
            () => _FixedCatalogController(
              MealCatalogState(query: 'porridge', results: results),
            ),
          ),
        ],
        child: MaterialApp(
          home: Scaffold(body: MealCatalogBrowser(onOpenMeal: opened.add)),
        ),
      ),
    );
    await t.pump();

    expect(photo(porridge), findsOneWidget);
    expect(find.byType(MealIconTile), findsOneWidget);

    await t.tap(find.text('Plain porridge with stewed pear'));
    expect(opened.single.id, 'AB-096');
    expect(opened.single.imageMode, MealImageMode.dish);
  });
}

class _FixedCatalogController extends MealCatalogController {
  _FixedCatalogController(this.fixed);

  final MealCatalogState fixed;

  @override
  FutureOr<MealCatalogState> build() => fixed;
}
