import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/features/meal_planning/data/meal_library_remote_data_source.dart';

/// `search_meals` returns the Meal's current Dish photo in its own three
/// columns; `rowToMealRef` reads those and nothing else. The frozen pipeline's
/// columns still ride along on the row (ADR 0003 keeps the data), so the tests
/// that matter here are the ones proving they are ignored.
void main() {
  Map<String, dynamic> row(Map<String, dynamic> extra) => {
    'source': 'library',
    'id': 'AB-001',
    'name': 'Steel-cut oats with peanut butter & blueberries',
    'meal_type': 'breakfast',
    ...extra,
  };

  test('a row with a photo carries its address, credit and credit link', () {
    final meal = MealLibraryRemoteDataSource.rowToMealRef(
      row({
        'photo_url': 'https://upload.wikimedia.org/oats.jpg',
        'photo_credit': 'Photo by Vegan Feast Catering on Wikimedia Commons '
            '(CC BY 2.0)',
        'photo_credit_url':
            'https://commons.wikimedia.org/wiki/File:Steel_cut_oats.jpg',
      }),
    )!;

    expect(meal.photo?.url, 'https://upload.wikimedia.org/oats.jpg');
    expect(meal.photo?.credit, contains('Vegan Feast Catering'));
    expect(
      meal.photo?.creditUrl,
      'https://commons.wikimedia.org/wiki/File:Steel_cut_oats.jpg',
    );
  });

  test('a photo with no credit is a photo all the same', () {
    final meal = MealLibraryRemoteDataSource.rowToMealRef(
      row({
        'photo_url':
            'https://vlmtsdzpnjnavdgytcmi.supabase.co/storage/v1/object/'
            'public/meal-images/photos/AB-001.jpg',
        'photo_credit': null,
        'photo_credit_url': null,
      }),
    )!;

    expect(meal.photo, isNotNull);
    expect(meal.photo?.credit, isNull);
    expect(meal.photo?.creditUrl, isNull);
  });

  test('a row with no photo shows nothing', () {
    final meal = MealLibraryRemoteDataSource.rowToMealRef(row({}))!;
    expect(meal.photo, isNull);
  });

  test('an empty address is no photo, not a broken one', () {
    final meal = MealLibraryRemoteDataSource.rowToMealRef(
      row({'photo_url': '   ', 'photo_credit': 'Someone'}),
    )!;
    expect(meal.photo, isNull);
  });

  test('a leftover Mosaic is not a picture', () {
    final meal = MealLibraryRemoteDataSource.rowToMealRef(
      row({
        'image_mode': 'mosaic',
        'image_tiles': [
          {'url': 'https://images.pexels.com/oats.jpg', 'name': 'Rolled oats'},
          {'url': 'https://images.unsplash.com/blue.jpg', 'name': 'Blueberries'},
        ],
      }),
    )!;

    expect(meal.photo, isNull);
  });

  test('a leftover ingredient Tile is not a picture', () {
    final meal = MealLibraryRemoteDataSource.rowToMealRef(
      row({
        'image_mode': 'tile',
        'image_tiles': [
          {'url': 'https://images.pexels.com/rice.jpg', 'name': 'White rice'},
        ],
      }),
    )!;

    expect(meal.photo, isNull);
  });

  test('a photograph the Judge called weak is not a picture', () {
    // The switchover left `weak` photos in image_url and copied nothing.
    final meal = MealLibraryRemoteDataSource.rowToMealRef(
      row({
        'image_mode': 'dish',
        'image_url': 'https://images.pexels.com/something-else.jpeg',
        'image_verdict': 'weak',
        'image_credit': 'Someone · Pexels',
        'image_source_url': 'https://www.pexels.com/photo/1',
      }),
    )!;

    expect(meal.photo, isNull);
  });

  test('a Meal that kept its photo carries it beside the old columns', () {
    // The switchover copied a `dish` + `ok` photograph across; both sets of
    // columns arrive, and only the new ones are read.
    final meal = MealLibraryRemoteDataSource.rowToMealRef(
      row({
        'image_mode': 'dish',
        'image_url': 'https://upload.wikimedia.org/oats.jpg',
        'image_credit': 'Vegan Feast Catering · CC-BY-2.0 · Wikimedia Commons',
        'photo_url': 'https://upload.wikimedia.org/oats.jpg',
        'photo_credit':
            'Photo by Vegan Feast Catering on Wikimedia Commons (CC BY 2.0)',
      }),
    )!;

    expect(meal.photo?.url, 'https://upload.wikimedia.org/oats.jpg');
    expect(meal.photo?.credit, startsWith('Photo by'));
  });
}
