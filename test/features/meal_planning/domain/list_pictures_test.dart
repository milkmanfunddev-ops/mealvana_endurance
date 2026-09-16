import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/features/meal_planning/data/meal_library_remote_data_source.dart';
import 'package:mealvana_endurance/features/meal_planning/domain/list_pictures.dart';
import 'package:mealvana_endurance/features/meal_planning/domain/meal_ref.dart';

/// Two Meals in one list never show the same photograph. The Meals are built
/// from `search_meals`-shaped rows through the real mapping, because the
/// photograph's identity has to survive that trip. A Meal that loses the
/// photograph shows nothing, which is what a Meal without one shows anyway
/// (ADR 0003).
void main() {
  MealRef meal(String id, Map<String, dynamic> photo) =>
      MealLibraryRemoteDataSource.rowToMealRef({
        'source': 'library',
        'id': id,
        'name': 'Meal $id',
        'meal_type': 'breakfast',
        ...photo,
      })!;

  Map<String, dynamic> photo(String url) => {
    'photo_url': url,
    'photo_credit': 'Photo by Someone on Wikimedia Commons (CC BY 2.0)',
  };

  const porridge = 'https://upload.wikimedia.org/porridge.jpg';

  test('the second Meal wearing a photograph shows nothing', () {
    final photos = photosForList([
      meal('AB-010', photo(porridge)),
      meal('AB-096', photo(porridge)),
    ]);

    expect(photos[0].photo?.url, porridge);
    expect(photos[1].photo, isNull);
  });

  test('a stock photograph resized by its CDN is still the same photograph', () {
    final photos = photosForList([
      meal('B-040', photo('https://images.unsplash.com/photo-159030?w=1080')),
      meal('S-058', photo('https://images.unsplash.com/photo-159030?w=400')),
    ]);

    expect(photos[0].photo, isNotNull);
    expect(photos[1].photo, isNull);
  });

  test('a mirrored copy is the same photograph: its credit page says so', () {
    // "White bread & jam" wears the Wikimedia file; "White bread with jam"
    // wears our mirror of it, stored under its own id. Different addresses,
    // one photograph — 109 of the 170 kept photos are mirrors like this.
    const page =
        'https://commons.wikimedia.org/wiki/File:Homemade_White_Bread_with_Strawberry_Jam.jpg';
    final photos = photosForList([
      meal('AB-063', {
        'photo_url':
            'https://upload.wikimedia.org/wikipedia/commons/thumb/b/b0/'
            'Homemade_White_Bread_with_Strawberry_Jam.jpg/960px-Homemade.jpg',
        'photo_credit_url': page,
      }),
      meal('S-008', {
        'photo_url': 'https://vlmtsdzpnjnavdgytcmi.supabase.co/storage/v1/'
            'object/public/meal-images/meals/S-008.jpg',
        'photo_credit_url': page,
      }),
    ]);

    expect(photos[0].photo, isNotNull);
    expect(photos[1].photo, isNull);
  });

  test('two photographs from one site are still two photographs', () {
    final photos = photosForList([
      meal('AB-063', {
        'photo_url': 'https://upload.wikimedia.org/bread.jpg',
        'photo_credit_url': 'https://commons.wikimedia.org/wiki/File:Bread.jpg',
      }),
      meal('AB-064', {
        'photo_url': 'https://upload.wikimedia.org/bagel.jpg',
        'photo_credit_url': 'https://commons.wikimedia.org/wiki/File:Bagel.jpg',
      }),
    ]);

    expect(photos.map((p) => p.photo?.url), [
      'https://upload.wikimedia.org/bread.jpg',
      'https://upload.wikimedia.org/bagel.jpg',
    ]);
  });

  test('different photographs both show', () {
    final photos = photosForList([
      meal('AB-010', photo(porridge)),
      meal('AB-021', photo('https://upload.wikimedia.org/bagel.jpg')),
    ]);

    expect(photos.map((p) => p.photo?.url), [
      porridge,
      'https://upload.wikimedia.org/bagel.jpg',
    ]);
  });

  test('a Meal with no photo is a hole, not a claim on one', () {
    final photos = photosForList([
      meal('AB-002', {}),
      meal('AB-010', photo(porridge)),
      meal('AB-003', {}),
    ]);

    expect(photos.map((p) => p.photo?.url), [null, porridge, null]);
  });

  test('the same list always resolves the same way, and lists are independent', () {
    final list = [
      meal('AB-010', photo(porridge)),
      meal('AB-096', photo(porridge)),
      meal('AB-336', photo(porridge)),
    ];
    List<String?> urls(List<MealRef> meals) =>
        photosForList(meals).map((p) => p.photo?.url).toList();

    expect(urls(list), [porridge, null, null]);
    expect(urls(list), urls(list));
    // Another list showing the second Meal alone shows its photograph.
    expect(urls([list[1]]), [porridge]);
    // And the Meal itself never lost it.
    expect(list[1].photo?.url, porridge);
  });
}
