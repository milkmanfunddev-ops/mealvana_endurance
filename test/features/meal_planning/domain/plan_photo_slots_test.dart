import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/features/meal_planning/application/plan_meal_photos.dart';
import 'package:mealvana_endurance/features/meal_planning/domain/list_pictures.dart';
import 'package:mealvana_endurance/features/meal_planning/domain/meal_photo.dart';
import 'package:mealvana_endurance/features/meal_planning/domain/plan_meal.dart';

/// A plan row's picture is the library Meal's current Dish photo, looked up by
/// meal id and never stored on the plan row — so a photo added to a Meal later
/// reaches a plan already made (ADR 0003, mp-324).
///
/// The photographs are built from `meal_library`-shaped rows through the real
/// mapping, because a photograph's identity has to survive that trip.
void main() {
  PlanMeal meal(
    String id, {
    String? libraryMealId,
    String source = 'library',
    String? savedMealId,
  }) => PlanMeal.fromJson({
    'id': id,
    'planId': 'plan-1',
    'source': source,
    if (libraryMealId != null) 'libraryMealId': libraryMealId,
    if (savedMealId != null) 'savedMealId': savedMealId,
    'name': 'Meal $id',
    'mealType': 'dinner',
    'servings': 4,
    'servingsLeft': 4,
  });

  MealPhoto photo(String url, {String? page}) => MealPhoto.fromRow({
    'photo_url': url,
    'photo_credit': 'Photo by Someone on Wikimedia Commons (CC BY-SA 4.0)',
    if (page != null) 'photo_credit_url': page,
  })!;

  const avocado = 'https://upload.wikimedia.org/avocado.jpg';

  test('a row shows its library Meal\'s photo, joined by meal id', () {
    final slots = planPhotoSlotsFor(
      [meal('pm-1', libraryMealId: 'AB-001')],
      {'AB-001': photo(avocado)},
    );

    expect(slots['pm-1']?.photo?.url, avocado);
    expect(
      slots['pm-1']?.photo?.credit,
      'Photo by Someone on Wikimedia Commons (CC BY-SA 4.0)',
    );
  });

  test('a row whose Meal has no photo shows nothing', () {
    final slots = planPhotoSlotsFor([
      meal('pm-1', libraryMealId: 'AB-001'),
    ], const {});

    expect(slots['pm-1']?.photo, isNull);
  });

  test('a saved-only meal with no library link shows nothing', () {
    // Nothing to look the photo up by: the row is the athlete's own meal and
    // was never matched to a library Meal.
    final slots = planPhotoSlotsFor(
      [meal('pm-1', source: 'saved', savedMealId: 'a-uuid')],
      {'AB-001': photo(avocado)},
    );

    expect(slots['pm-1']?.photo, isNull);
  });

  test('a saved meal matched to the library shows that Meal\'s photo', () {
    final slots = planPhotoSlotsFor(
      [
        meal(
          'pm-1',
          source: 'saved',
          savedMealId: 'a-uuid',
          libraryMealId: 'AB-001',
        ),
      ],
      {'AB-001': photo(avocado)},
    );

    expect(slots['pm-1']?.photo?.url, avocado);
  });

  test('two Meals wearing mirrors of one photograph both show it', () {
    // A list of cards suppresses the repeat (`photosForList`). A plan does not:
    // a Meal shows the same picture wherever it is met (story 10), and
    // suppressing here would blank a photograph the Meal really has.
    const page = 'https://commons.wikimedia.org/wiki/File:Porridge.jpg';
    final slots = planPhotoSlotsFor(
      [
        meal('pm-1', libraryMealId: 'AB-010'),
        meal('pm-2', libraryMealId: 'AB-096'),
      ],
      {
        'AB-010': photo('https://.../AB-010/porridge.jpg', page: page),
        'AB-096': photo('https://.../AB-096/porridge.jpg', page: page),
      },
    );

    expect(slots['pm-1']?.photo, isNotNull);
    expect(slots['pm-2']?.photo, isNotNull);
  });

  test('one Meal planned twice shows its photo on both rows', () {
    // Two rows of one Meal is ordinary — that is what batch cooking is — and
    // the second row is not a repeat to be hidden.
    final slots = planPhotoSlotsFor(
      [
        meal('pm-1', libraryMealId: 'AB-001'),
        meal('pm-2', libraryMealId: 'AB-001'),
      ],
      {'AB-001': photo(avocado)},
    );

    expect(slots['pm-1']?.photo?.url, avocado);
    expect(slots['pm-2']?.photo?.url, avocado);
  });

  test('every row gets a slot, keyed by plan-meal id', () {
    final slots = planPhotoSlotsFor(
      [
        meal('pm-1', libraryMealId: 'AB-001'),
        meal('pm-2'),
        meal('pm-3', libraryMealId: 'AB-404'),
      ],
      {'AB-001': photo(avocado)},
    );

    expect(slots.keys, ['pm-1', 'pm-2', 'pm-3']);
    expect(slots['pm-1']?.photo, isNotNull);
    expect(slots['pm-2']?.photo, isNull);
    expect(slots['pm-3']?.photo, isNull);
  });

  group('the lookup key', () {
    test('is sorted and de-duplicated, so one plan asks once', () {
      final key = planPhotoIdsKey([
        meal('pm-1', libraryMealId: 'D-048'),
        meal('pm-2', libraryMealId: 'AB-001'),
        meal('pm-3', libraryMealId: 'D-048'),
      ]);

      expect(key, 'AB-001,D-048');
    });

    test('is empty when no row has a library Meal to look up', () {
      expect(
        planPhotoIdsKey([meal('pm-1', source: 'saved', savedMealId: 'a-uuid')]),
        isEmpty,
      );
      expect(planPhotoIdsKey(const []), isEmpty);
    });
  });
}
