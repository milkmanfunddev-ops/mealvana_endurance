import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/features/content/application/content_service.dart';
import 'package:mealvana_endurance/features/meal_planning/data/meal_library_remote_data_source.dart';
import 'package:mealvana_endurance/features/meal_planning/domain/meal_ref.dart';
import 'package:mealvana_endurance/features/meal_planning/presentation/widgets/meal_card.dart';
import 'package:mealvana_endurance/features/meal_planning/presentation/widgets/meal_icon_glyphs.dart';
import 'package:mealvana_endurance/shared/widgets/kyle_design/data/meal_image_mosaic.dart';

import '../helpers/test_content.dart';

/// A fifth of the library has no honest picture, permanently. Those Meals keep
/// their icon, drawn where the picture would be and shaped like it, so a list
/// mixing pictures and icons stays aligned (meal-image-mosaic.md MIM-9). Meals
/// come from `search_meals`-shaped rows through the real mapping.
void main() {
  MealRef meal(String id, String name, Map<String, dynamic> image) =>
      MealLibraryRemoteDataSource.rowToMealRef({
        'source': 'library',
        'id': id,
        'name': name,
        'meal_type': 'breakfast',
        ...image,
      })!;

  final dish = meal('AB-001', 'Avocado toast', {
    'image_mode': 'dish',
    'image_url': 'https://upload.wikimedia.org/avocado.jpg',
    'image_credit': 'Jami430 · CC-BY-SA-4.0 · Wikimedia Commons',
    'image_tiles': <dynamic>[],
  });
  final none = meal('AB-002', 'Cherry ice cream smoothie', {
    'image_mode': 'none',
    'image_url': null,
    'image_tiles': <dynamic>[],
  });
  final mosaic = meal('AB-003', 'Oats with blueberries', {
    'image_mode': 'mosaic',
    'image_url': null,
    'image_tiles': [
      {'url': 'https://images.pexels.com/oats.jpeg', 'name': 'Rolled oats'},
      {
        'url': 'https://images.unsplash.com/blueberries.jpg',
        'name': 'Blueberries',
      },
    ],
  });

  Future<void> pump(
    WidgetTester tester,
    List<MealRef> meals, {
    Brightness brightness = Brightness.light,
    bool compact = false,
  }) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [contentServiceProvider.overrideWith(testContentService)],
        child: MaterialApp(
          theme: ThemeData(brightness: brightness),
          home: Scaffold(
            body: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                for (final m in meals)
                  MealCard(meal: m, onTap: () {}, compact: compact),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  Finder leading(int i) => find.descendant(
    of: find.byType(MealCard).at(i),
    matching: find.byType(MealImageMosaic),
  );

  Finder iconIn(int i) =>
      find.descendant(of: leading(i), matching: find.byType(MealIconGlyph));

  BorderRadiusGeometry cornersOf(WidgetTester t, int i) => t
      .widget<ClipRRect>(
        find.descendant(of: leading(i), matching: find.byType(ClipRRect)).first,
      )
      .borderRadius;

  testWidgets('a Meal with no picture shows its icon where the picture would '
      'be, the same size and shape', (tester) async {
    await pump(tester, [dish, none, mosaic]);

    expect(iconIn(1), findsOneWidget);
    final pictureBox = tester.getRect(leading(0));
    final iconBox = tester.getRect(leading(1));
    expect(pictureBox.size, const Size(36, 36));
    expect(iconBox.size, pictureBox.size);
    expect(iconBox.left, pictureBox.left);
    expect(tester.getRect(leading(2)).size, pictureBox.size);
    expect(cornersOf(tester, 1), cornersOf(tester, 0));
  });

  testWidgets('the icon state names nothing and signals no failure', (
    tester,
  ) async {
    await pump(tester, [none]);

    // No meal name in a box, no "missing image" glyph.
    expect(
      find.descendant(of: leading(0), matching: find.byType(Text)),
      findsNothing,
    );
    expect(
      find.descendant(of: leading(0), matching: find.byType(Icon)),
      findsNothing,
    );
  });

  testWidgets('a photograph that fails to load leaves the icon, not a blank '
      'slot', (tester) async {
    // flutter_test answers every image request with HTTP 400.
    await pump(tester, [dish]);
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pump();
    await tester.pump();

    expect(find.byType(Image), findsNothing);
    expect(iconIn(0), findsOneWidget);
    expect(tester.getSize(leading(0)), const Size(36, 36));
  });

  testWidgets('a compact card keeps the footprint rule', (tester) async {
    await pump(tester, [dish, none], compact: true);

    expect(tester.getSize(leading(0)), const Size(32, 32));
    expect(tester.getSize(leading(1)), const Size(32, 32));
  });

  for (final brightness in Brightness.values) {
    testWidgets('a mixed list lays out at the smallest width, $brightness', (
      tester,
    ) async {
      await pump(tester, [dish, none, mosaic, none], brightness: brightness);

      expect(tester.takeException(), isNull);
      expect(iconIn(1), findsOneWidget);
      expect(iconIn(3), findsOneWidget);
      expect(tester.getSize(find.byType(MealCard).first).width, 320 - 32);
    });
  }
}
