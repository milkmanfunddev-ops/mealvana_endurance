import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/features/content/application/content_service.dart';
import 'package:mealvana_endurance/features/meal_planning/data/meal_library_remote_data_source.dart';
import 'package:mealvana_endurance/features/meal_planning/domain/meal_ref.dart';
import 'package:mealvana_endurance/features/meal_planning/presentation/widgets/meal_card.dart';

import '../helpers/test_content.dart';

/// A card's thumbnail is too small for a credit line, so the credit rides on
/// its semantics instead (meal-image-mosaic.md MIM-6). Meals are built from
/// `search_meals`-shaped rows through the real mapping, because a dish photo on
/// that path arrives with its credit line and nothing else.
void main() {
  MealRef meal(Map<String, dynamic> image, {String name = 'Avocado toast'}) =>
      MealLibraryRemoteDataSource.rowToMealRef({
        'source': 'library',
        'id': 'AB-001',
        'name': name,
        'meal_type': 'breakfast',
        ...image,
      })!;

  final dish = meal({
    'image_mode': 'dish',
    'image_url': 'https://upload.wikimedia.org/avocado.jpg',
    'image_credit': 'Jami430 · CC-BY-SA-4.0 · Wikimedia Commons',
    'image_tiles': <dynamic>[],
  });

  final mosaic = meal({
    'image_mode': 'mosaic',
    'image_url': null,
    'image_tiles': [
      {
        'url': 'https://images.pexels.com/oats.jpeg',
        'name': 'Rolled oats',
        'creator': 'Ella Olsson',
        'license': 'Pexels',
        'sourceUrl': 'https://www.pexels.com/photo/1/',
        'provider': 'pexels',
      },
      {
        'url': 'https://images.unsplash.com/blueberries.jpg',
        'name': 'Blueberries',
        'creator': 'Annie Spratt',
        'license': 'Unsplash',
        'sourceUrl': 'https://unsplash.com/photos/blueberries',
        'provider': 'unsplash',
      },
      {
        // The same photograph again: credited once.
        'url': 'https://images.pexels.com/oats.jpeg',
        'name': 'Oats',
        'creator': 'Ella Olsson',
        'license': 'Pexels',
        'sourceUrl': 'https://www.pexels.com/photo/1/',
        'provider': 'pexels',
      },
    ],
  }, name: 'Steel-cut oats with peanut butter, blueberries & toasted coconut');

  Future<void> pump(WidgetTester tester, List<MealRef> meals) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [contentServiceProvider.overrideWith(testContentService)],
        child: MaterialApp(
          home: Scaffold(
            body: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                for (final m in meals)
                  MealCard(meal: m, onTap: () {}, trailing: const Text('Add')),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('a dish photo carries its credit line for screen readers', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await pump(tester, [dish]);

    expect(
      find.bySemanticsLabel(
        RegExp('Jami430 · CC-BY-SA-4.0 · Wikimedia Commons'),
      ),
      findsOneWidget,
    );
    semantics.dispose();
  });

  testWidgets('a mosaic carries every photographer once, and no visible line', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await pump(tester, [mosaic]);

    // The card merges its children into one node; the credit is its first line.
    final label = tester
        .getSemantics(find.bySemanticsLabel(RegExp('Photo by')))
        .label;
    expect(
      label.split('\n').first,
      'Photo by Ella Olsson on Pexels · Photo by Annie Spratt on Unsplash',
    );
    expect(find.textContaining('Photo by'), findsNothing);
    semantics.dispose();
  });

  testWidgets('the list lays out at the smallest supported width', (
    tester,
  ) async {
    await pump(tester, [dish, mosaic, dish]);

    expect(tester.takeException(), isNull);
    expect(find.byType(MealCard), findsNWidgets(3));
    expect(tester.getSize(find.byType(MealCard).first).width, 320 - 32);
  });
}
