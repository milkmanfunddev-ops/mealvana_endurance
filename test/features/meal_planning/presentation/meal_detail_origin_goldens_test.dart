// Golden coverage for the meal detail screen per directions origin
// (mp-146 / ticket 32): verbatim source, alternate source, simple assembly,
// AI-generated — each in light and dark at 390 logical px (iPhone 14/15
// width). Not the SE width the other goldens use: the screen's existing
// "See the original recipe · host" row overflows at 320 and 360, before
// this ticket, and `takeException` would fail every golden. Same contract
// as `widget_goldens_test.dart`: the test font pins layout, colour and
// structure, not glyphs.
//
//   flutter test test/features/meal_planning/presentation/meal_detail_origin_goldens_test.dart
//   flutter test test/features/meal_planning/presentation/meal_detail_origin_goldens_test.dart --update-goldens
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/features/content/application/content_service.dart';
import 'package:mealvana_endurance/features/meal_planning/application/meal_detail_controller.dart';
import 'package:mealvana_endurance/features/meal_planning/domain/directions_origin.dart';
import 'package:mealvana_endurance/features/meal_planning/domain/meal_detail.dart';
import 'package:mealvana_endurance/features/meal_planning/domain/meal_ref.dart';
import 'package:mealvana_endurance/features/meal_planning/domain/meal_source.dart';
import 'package:mealvana_endurance/features/meal_planning/domain/meal_type.dart';
import 'package:mealvana_endurance/features/meal_planning/presentation/screens/meal_detail_screen.dart';
import 'package:mealvana_endurance/shared/providers/is_admin_provider.dart';

import 'helpers/test_content.dart';

const _width = 390.0;

void main() {
  final base = MealDetail(
    meal: MealRef(
      source: MealSource.library,
      id: 'D-100',
      name: 'Salmon, quinoa, asparagus & spinach salad',
      mealType: MealType.dinner,
      kcal: 620,
      carbsG: 52,
      proteinG: 41,
      fatG: 22,
      prepMinutes: 20,
    ),
    ingredients: const [
      MealIngredient(name: 'salmon fillet', qty: '150 g'),
      MealIngredient(name: 'quinoa', qty: '80 g'),
    ],
    methodSteps: const ['Cook the quinoa.', 'Sear the salmon.'],
    directions: const MealDirections(),
    sourceUrl: 'https://runningmagazine.ca/recipes/salmon-quinoa',
    servings: 2,
  );

  final origins = <String, MealDirections>{
    'source': const MealDirections(
      origin: DirectionsOrigin.source,
      sourceName: 'Jennifer Sygo',
      sourceUrl: 'https://runningmagazine.ca/recipes/salmon-quinoa',
      verbatim: true,
    ),
    'alt_source': const MealDirections(
      origin: DirectionsOrigin.altSource,
      sourceName: 'BBC Good Food',
      sourceUrl: 'https://www.bbcgoodfood.com/recipes/salmon-quinoa',
    ),
    'assembly_simple': const MealDirections(
      origin: DirectionsOrigin.assemblySimple,
    ),
    'ai_generated': const MealDirections(origin: DirectionsOrigin.aiGenerated),
  };

  for (final entry in origins.entries) {
    for (final brightness in Brightness.values) {
      testWidgets(
        'golden: meal_detail_origin_${entry.key} (${brightness.name})',
        (tester) async {
          tester.view.physicalSize = const Size(_width, 1000);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.reset);

          final detail = base.copyWith(directions: entry.value);
          await tester.pumpWidget(
            ProviderScope(
              overrides: [
                contentServiceProvider.overrideWith(testContentService),
                isAdminProvider.overrideWith((ref) async => false),
                mealDetailControllerProvider(
                  'D-100',
                ).overrideWith(() => _FixedDetailController(detail)),
              ],
              child: MaterialApp(
                debugShowCheckedModeBanner: false,
                theme: ThemeData(brightness: brightness),
                home: const RepaintBoundary(
                  key: Key('golden'),
                  child: MealDetailScreen(id: 'D-100'),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);

          final suffix = brightness == Brightness.dark ? 'dark' : 'light';
          await expectLater(
            find.byKey(const Key('golden')),
            matchesGoldenFile(
              'goldens/meal_detail_origin_${entry.key}_$suffix.png',
            ),
          );
        },
      );
    }
  }
}

class _FixedDetailController extends MealDetailController {
  _FixedDetailController(this.detail);

  final MealDetail detail;

  @override
  Future<MealDetail> build(String id) async => detail;
}
