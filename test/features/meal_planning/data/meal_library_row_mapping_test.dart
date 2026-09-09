import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/features/meal_planning/data/meal_library_remote_data_source.dart';
import 'package:mealvana_endurance/features/meal_planning/domain/meal_image.dart';

/// `search_meals` returns the image columns; `rowToMealRef` has to read them.
/// It did not, so every meal reaching the Meals tab fell back to
/// `MealImageMode.none` and rendered its icon — the mosaics existed in the
/// database and appeared only on the Vana agent path.
void main() {
  Map<String, dynamic> row(Map<String, dynamic> extra) => {
    'source': 'library',
    'id': 'AB-001',
    'name': 'Steel-cut oats with peanut butter & blueberries',
    'meal_type': 'breakfast',
    ...extra,
  };

  test('a dish row carries the photograph and its credit', () {
    final meal = MealLibraryRemoteDataSource.rowToMealRef(
      row({
        'image_mode': 'dish',
        'image_url': 'https://upload.wikimedia.org/oats.jpg',
        'image_credit': 'Vegan Feast Catering · CC-BY-2.0 · Wikimedia Commons',
        'image_tiles': <dynamic>[],
      }),
    )!;

    expect(meal.imageMode, MealImageMode.dish);
    expect(meal.image?.url, 'https://upload.wikimedia.org/oats.jpg');
    expect(meal.image?.credit, contains('Vegan Feast Catering'));
    expect(meal.imageTiles, isEmpty);
    expect(meal.displayTiles, hasLength(1));
  });

  test('a mosaic row carries its tiles in order, with attribution', () {
    final meal = MealLibraryRemoteDataSource.rowToMealRef(
      row({
        'image_mode': 'mosaic',
        'image_url': null,
        'image_tiles': [
          {
            'url': 'https://images.pexels.com/oats.jpg',
            'name': 'Rolled oats',
            'creator': 'A Photographer',
            'license': 'Pexels',
            'provider': 'pexels',
            'sourceUrl': 'https://www.pexels.com/photo/1',
          },
          {
            'url': 'https://images.unsplash.com/blueberries.jpg',
            'name': 'Blueberries',
            'provider': 'unsplash',
          },
        ],
      }),
    )!;

    expect(meal.imageMode, MealImageMode.mosaic);
    expect(meal.image, isNull);
    expect(meal.imageTiles.map((t) => t.name), ['Rolled oats', 'Blueberries']);
    expect(meal.imageTiles.first.creator, 'A Photographer');
    expect(meal.imageTiles.first.provider, 'pexels');
    expect(meal.displayTiles, hasLength(2));
  });

  test('a row with no image resolves to none rather than a broken tile', () {
    final meal = MealLibraryRemoteDataSource.rowToMealRef(
      row({
        'image_mode': 'none',
        'image_url': null,
        'image_tiles': <dynamic>[],
      }),
    )!;

    expect(meal.imageMode, MealImageMode.none);
    expect(meal.image, isNull);
    expect(meal.imageTiles, isEmpty);
  });

  test('missing image columns are tolerated, not thrown on', () {
    final meal = MealLibraryRemoteDataSource.rowToMealRef(row({}))!;
    expect(meal.imageMode, MealImageMode.none);
    expect(meal.image, isNull);
  });

  test('a tile with no url is dropped, never rendered as a broken image', () {
    final meal = MealLibraryRemoteDataSource.rowToMealRef(
      row({
        'image_mode': 'mosaic',
        'image_tiles': [
          {'name': 'Nothing to show'},
          {'url': 'https://images.pexels.com/oats.jpg', 'name': 'Rolled oats'},
        ],
      }),
    )!;

    expect(meal.imageTiles, hasLength(1));
    expect(meal.imageTiles.single.name, 'Rolled oats');
  });
}
