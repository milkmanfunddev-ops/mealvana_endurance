import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/features/meal_planning/data/meal_library_remote_data_source.dart';
import 'package:mealvana_endurance/features/meal_planning/domain/meal_image.dart';
import 'package:mealvana_endurance/features/meal_planning/domain/meal_ref.dart';
import 'package:mealvana_endurance/features/meal_planning/domain/list_pictures.dart';

/// Two Meals in one list never show the same photograph. The Meals are built
/// from `search_meals`-shaped rows through the real mapping, because the
/// photograph's identity has to survive that trip.
void main() {
  MealRef meal(String id, Map<String, dynamic> image) =>
      MealLibraryRemoteDataSource.rowToMealRef({
        'source': 'library',
        'id': id,
        'name': 'Meal $id',
        'meal_type': 'breakfast',
        ...image,
      })!;

  Map<String, dynamic> dish(String url, {String? source}) => {
    'image_mode': 'dish',
    'image_url': url,
    'image_source_url': source,
    'image_credit': 'Someone · CC-BY-2.0 · Wikimedia Commons',
    'image_tiles': <dynamic>[],
  };

  const porridge = 'https://upload.wikimedia.org/porridge.jpg';

  test('the second Meal wearing a photograph shows its icon instead', () {
    final pictures = picturesForList([
      meal('AB-010', dish(porridge)),
      meal('AB-096', dish(porridge)),
    ]);

    expect(pictures[0].mode, MealImageMode.dish);
    expect(pictures[0].tiles.single.url, porridge);
    expect(pictures[1].mode, MealImageMode.none);
    expect(pictures[1].tiles, isEmpty);
  });

  test('a mirrored copy is the same photograph: its source page says so', () {
    // "White bread & jam" wears the Wikimedia file; "White bread with jam"
    // wears our mirror of it, stored under its own id.
    const page =
        'https://commons.wikimedia.org/wiki/File:Homemade_White_Bread_with_Strawberry_Jam.jpg';
    final pictures = picturesForList([
      meal(
        'AB-063',
        dish(
          'https://upload.wikimedia.org/wikipedia/commons/thumb/b/b0/Homemade_White_Bread_with_Strawberry_Jam.jpg/960px-Homemade_White_Bread_with_Strawberry_Jam.jpg',
          source: page,
        ),
      ),
      meal(
        'S-008',
        dish(
          'https://vlmtsdzpnjnavdgytcmi.supabase.co/storage/v1/object/public/meal-images/meals/S-008.jpg',
          source: page,
        ),
      ),
    ]);

    expect(pictures.map((p) => p.mode), [
      MealImageMode.dish,
      MealImageMode.none,
    ]);
  });

  test(
    'a stock photograph resized by its CDN is still the same photograph',
    () {
      final pictures = picturesForList([
        meal(
          'B-040',
          dish('https://images.unsplash.com/photo-1590301157890?w=1080'),
        ),
        meal(
          'S-058',
          dish('https://images.unsplash.com/photo-1590301157890?w=400'),
        ),
      ]);

      expect(pictures[1].mode, MealImageMode.none);
    },
  );

  test('an ingredient photograph a one-thing Meal wears counts too', () {
    // "Plain white rice" wears the rice Tile, mirrored into our storage; the
    // race-day plate wears the same Wikimedia file as its Dish photo.
    const page =
        'https://commons.wikimedia.org/wiki/File:White_rice_on_a_brown_table.jpg';
    final pictures = picturesForList([
      meal('AS-270', {
        'image_mode': 'tile',
        'image_tiles': [
          {
            'url':
                'https://vlmtsdzpnjnavdgytcmi.supabase.co/storage/v1/object/public/meal-images/ingredients/white-rice.jpg',
            'name': 'White rice',
            'sourceUrl': page,
            'provider': 'wikimedia',
          },
        ],
      }),
      meal(
        'AB-046',
        dish(
          'https://upload.wikimedia.org/wikipedia/commons/b/bd/White_rice_on_a_brown_table.jpg',
          source: page,
        ),
      ),
    ]);

    expect(pictures.map((p) => p.mode), [
      MealImageMode.tile,
      MealImageMode.none,
    ]);
  });

  test('a Meal that loses its photograph falls back to its Mosaic', () {
    final withGrid = {
      ...dish(porridge),
      'image_tiles': [
        {'url': 'https://images.pexels.com/oats.jpeg', 'name': 'Rolled oats'},
        {'url': 'https://images.pexels.com/pear.jpeg', 'name': 'Pear'},
      ],
    };
    final pictures = picturesForList([
      meal('AB-010', dish(porridge)),
      meal('AB-096', withGrid),
    ]);

    expect(pictures[1].mode, MealImageMode.mosaic);
    expect(pictures[1].tiles.map((t) => t.name), ['Rolled oats', 'Pear']);
  });

  test('Mosaics sharing an ingredient photograph keep their cells', () {
    // A Tile is reused across every Meal containing that ingredient; a grid
    // reads as a Meal's parts, not as a picture of the Meal.
    Map<String, dynamic> grid(String second) => {
      'image_mode': 'mosaic',
      'image_tiles': [
        {'url': 'https://images.pexels.com/avocado.jpeg', 'name': 'Avocado'},
        {'url': second, 'name': 'Other'},
      ],
    };
    final pictures = picturesForList([
      meal('L-001', grid('https://images.pexels.com/quinoa.jpeg')),
      meal('L-002', grid('https://images.pexels.com/toast.jpeg')),
    ]);

    expect(pictures.map((p) => p.mode), [
      MealImageMode.mosaic,
      MealImageMode.mosaic,
    ]);
  });

  test(
    'the same list always resolves the same way, and lists are independent',
    () {
      final list = [
        meal('AB-010', dish(porridge)),
        meal('AB-096', dish(porridge)),
        meal('AB-336', dish(porridge)),
      ];
      List<MealImageMode> modes(List<MealRef> meals) =>
          picturesForList(meals).map((p) => p.mode).toList();

      expect(modes(list), [
        MealImageMode.dish,
        MealImageMode.none,
        MealImageMode.none,
      ]);
      expect(modes(list), modes(list));
      // Another list showing the second Meal alone shows its photograph.
      expect(modes([list[1]]), [MealImageMode.dish]);
    },
  );

  test('a blank source page says nothing about which photograph it is', () {
    final pictures = picturesForList([
      meal('AB-010', dish(porridge, source: '')),
      meal(
        'AB-021',
        dish('https://upload.wikimedia.org/bagel.jpg', source: ''),
      ),
    ]);

    expect(pictures.map((p) => p.mode), [
      MealImageMode.dish,
      MealImageMode.dish,
    ]);
  });
}
