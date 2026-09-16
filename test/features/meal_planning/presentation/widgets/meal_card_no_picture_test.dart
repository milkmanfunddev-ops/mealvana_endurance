import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/features/content/application/content_service.dart';
import 'package:mealvana_endurance/features/meal_planning/data/meal_library_remote_data_source.dart';
import 'package:mealvana_endurance/features/meal_planning/domain/meal_ref.dart';
import 'package:mealvana_endurance/features/meal_planning/presentation/widgets/meal_card.dart';
import 'package:mealvana_endurance/features/meal_planning/presentation/widgets/meal_photo_view.dart';

import '../helpers/test_content.dart';

/// A Meal shows one Dish photo or nothing (ADR 0003). Nothing means nothing:
/// no placeholder box, no Mosaic, no ingredient Tile, no icon, and no space
/// held open where a picture would have been. Meals come from
/// `search_meals`-shaped rows through the real mapping, so a row still
/// carrying the frozen pipeline's columns proves they are no longer read.
void main() {
  MealRef meal(String id, String name, Map<String, dynamic> image) =>
      MealLibraryRemoteDataSource.rowToMealRef({
        'source': 'library',
        'id': id,
        'name': name,
        'meal_type': 'breakfast',
        ...image,
      })!;

  final withPhoto = meal('AB-001', 'Avocado toast', {
    'photo_url': 'https://upload.wikimedia.org/avocado.jpg',
    'photo_credit': 'Photo by Jami430 on Wikimedia Commons (CC BY-SA 4.0)',
    'photo_credit_url': 'https://commons.wikimedia.org/wiki/File:Avocado.jpg',
  });
  final none = meal('AB-002', 'Cherry ice cream smoothie', {});

  /// The salmon salad the ADR names: the pipeline gave it a Mosaic of raw
  /// salmon, tabbouleh and a blurred jar. It shows nothing now.
  final leftoverMosaic = meal('D-100', 'Salmon, quinoa & spinach salad', {
    'image_mode': 'mosaic',
    'image_tiles': [
      {'url': 'https://images.pexels.com/salmon.jpeg', 'name': 'Salmon'},
      {'url': 'https://images.unsplash.com/quinoa.jpg', 'name': 'Quinoa'},
    ],
  });
  final leftoverWeak = meal('AB-003', 'Oats with blueberries', {
    'image_mode': 'dish',
    'image_url': 'https://images.pexels.com/oats.jpeg',
    'image_verdict': 'weak',
    'image_credit': 'Someone · Pexels',
  });
  final leftoverTile = meal('AS-270', 'Plain white rice', {
    'image_mode': 'tile',
    'image_tiles': [
      {'url': 'https://images.pexels.com/rice.jpeg', 'name': 'White rice'},
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

  Finder cardAt(int i) => find.byType(MealCard).at(i);
  Finder photoIn(int i) =>
      find.descendant(of: cardAt(i), matching: find.byType(Image));
  Finder nameIn(int i, String name) =>
      find.descendant(of: cardAt(i), matching: find.text(name));

  testWidgets('a Meal with a Dish photo shows exactly one photograph', (
    tester,
  ) async {
    await pump(tester, [withPhoto]);

    expect(photoIn(0), findsOneWidget);
    expect(tester.getSize(photoIn(0)), const Size(36, 36));
  });

  testWidgets('a Meal with no photo draws no picture and holds no space', (
    tester,
  ) async {
    await pump(tester, [withPhoto, none]);

    expect(photoIn(1), findsNothing);
    // Nothing stands in: no icon where the picture would be.
    expect(
      find.descendant(of: cardAt(1), matching: find.byType(Icon)),
      findsNothing,
    );
    // The row starts at the name, where the photo would have been.
    final photoLeft = tester.getTopLeft(photoIn(0)).dx;
    expect(
      tester.getTopLeft(nameIn(1, 'Cherry ice cream smoothie')).dx,
      photoLeft,
    );
  });

  testWidgets('leftover pipeline data — a Mosaic, a Tile, a weak photo — '
      'shows nothing', (tester) async {
    await pump(tester, [leftoverMosaic, leftoverWeak, leftoverTile]);

    expect(find.byType(Image), findsNothing);
    for (var i = 0; i < 3; i++) {
      expect(
        find.descendant(of: cardAt(i), matching: find.byType(MealPhotoThumb)),
        findsOneWidget,
        reason: 'the card still asks for a picture; the Meal has none',
      );
      expect(photoIn(i), findsNothing);
    }
  });

  testWidgets('a photograph that fails to load collapses, leaving no glyph', (
    tester,
  ) async {
    // flutter_test answers every image request with HTTP 400.
    await pump(tester, [withPhoto, none]);
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pump();
    await tester.pump();

    expect(find.byType(Image), findsNothing);
    expect(
      find.descendant(of: cardAt(0), matching: find.byType(Icon)),
      findsNothing,
    );
    // It now lays out exactly like the Meal that never had a photo.
    expect(
      tester.getTopLeft(nameIn(0, 'Avocado toast')).dx,
      tester.getTopLeft(nameIn(1, 'Cherry ice cream smoothie')).dx,
    );
  });

  testWidgets('a compact card keeps the photo footprint', (tester) async {
    await pump(tester, [withPhoto], compact: true);

    expect(tester.getSize(photoIn(0)), const Size(32, 32));
  });

  for (final brightness in Brightness.values) {
    testWidgets('a mixed list lays out at the smallest width, $brightness', (
      tester,
    ) async {
      await pump(
        tester,
        [withPhoto, none, leftoverMosaic, none],
        brightness: brightness,
      );

      expect(tester.takeException(), isNull);
      expect(find.byType(Image), findsOneWidget);
      expect(tester.getSize(cardAt(0)).width, 320 - 32);
      // Names line up whether or not the card above carried a photo.
      final left = tester.getTopLeft(nameIn(1, 'Cherry ice cream smoothie')).dx;
      expect(tester.getTopLeft(nameIn(3, 'Cherry ice cream smoothie')).dx, left);
    });
  }
}
