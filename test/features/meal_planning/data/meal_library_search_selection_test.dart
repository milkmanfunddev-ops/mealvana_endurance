// `search_meals` rows become the list a caller asked for (testing-wave 94
// item 1, Finding 61-001): a caller that needs meals with numbers gets a
// list of `limit` such meals, not `limit` rows with the blank ones dropped
// afterwards. The Swap screen asked for 20 and could show far fewer.
//
// The rows are `search_meals`-shaped and go through the real `rowToMealRef`,
// so the null-ness under test is the one the database sends.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/features/meal_planning/data/meal_library_remote_data_source.dart';

Map<String, dynamic> _row(String id, {Object? kcal = 600}) => {
  'id': id,
  'name': 'Meal $id',
  'meal_type': 'dinner',
  'source': 'library',
  'library_meal_id': id,
  'contexts': const ['everyday'],
  'batch': false,
  'prep_minutes': 20,
  'kcal': kcal,
  'carbs_g': 70.0,
  'protein_g': 35.0,
  'fat_g': 15.0,
  'allergens': const <String>[],
  'diets_ok': const <String>[],
  'why': 'fits',
  'attribution': 'the library',
  'ingredients': 'rice',
  'kind': 'assembly',
  'score': 0.9,
};

void main() {
  test(
    'a blank-number row does not use up a slot when numbers are required',
    () {
      final rows = [
        _row('A', kcal: null),
        _row('B'),
        _row('C', kcal: null),
        _row('D'),
        _row('E'),
      ];

      final picked = MealLibraryRemoteDataSource.selectSearchRows(
        rows,
        limit: 3,
        requireNutritionNumbers: true,
      );

      expect(picked.map((m) => m.id), ['B', 'D', 'E']);
    },
  );

  test(
    'without the requirement a blank-number row is kept, as Browse wants',
    () {
      final picked = MealLibraryRemoteDataSource.selectSearchRows([
        _row('A', kcal: null),
        _row('B'),
      ], limit: 3);
      expect(picked.map((m) => m.id), ['A', 'B']);
    },
  );

  test('an excluded id never counts toward the limit', () {
    final picked = MealLibraryRemoteDataSource.selectSearchRows(
      [_row('A'), _row('B'), _row('C')],
      limit: 2,
      excludeIds: {'A'},
    );
    expect(picked.map((m) => m.id), ['B', 'C']);
  });

  test('the server is asked for headroom so the filtered list can fill', () {
    expect(
      MealLibraryRemoteDataSource.requestedLimit(
        limit: 20,
        excludeCount: 3,
        requireNutritionNumbers: true,
      ),
      greaterThan(23),
    );
    expect(
      MealLibraryRemoteDataSource.requestedLimit(
        limit: 20,
        excludeCount: 3,
        requireNutritionNumbers: false,
      ),
      23,
    );
  });
}
