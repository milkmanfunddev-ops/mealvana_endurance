/// Favorite matching for logged meals.
///
/// `saved_meals` has no `source_log_id` back-link, so whether a [MealLog] is
/// already favorited is decided by a name + component signature. That makes
/// this function load-bearing in a destructive direction: [findFavoriteMatch]
/// is what un-favoriting uses to pick the [SavedMeal] row to **delete**. A
/// false positive deletes the wrong favorite.
///
/// The docs call the match "intentionally strict" — these tests hold it to
/// that, and probe the separator handling that decides whether two genuinely
/// different meals can ever produce the same key.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/features/meal_logging/domain/meal_component.dart';
import 'package:mealvana_endurance/features/meal_logging/domain/meal_favorite_match.dart';
import 'package:mealvana_endurance/features/meal_logging/domain/meal_log.dart';
import 'package:mealvana_endurance/features/meal_logging/domain/meal_log_source.dart';
import 'package:mealvana_endurance/features/meal_logging/domain/saved_meal.dart';

void main() {
  MealComponent comp(String name, String portion) =>
      MealComponent(name: name, portion: portion);

  MealLog log(String name, List<MealComponent> components) => MealLog(
    id: 'log-1',
    userId: 'u1',
    logDate: '2026-07-31',
    name: name,
    source: MealLogSource.manual,
    components: components,
    createdAt: DateTime(2026, 7, 31),
    updatedAt: DateTime(2026, 7, 31),
  );

  SavedMeal saved(String id, String name, List<MealComponent> components) =>
      SavedMeal(
        id: id,
        userId: 'u1',
        name: name,
        components: components,
        createdAt: DateTime(2026, 7, 31),
        updatedAt: DateTime(2026, 7, 31),
      );

  group('mealFavoriteMatchKey normalization', () {
    test('is case-insensitive on the meal name', () {
      expect(
        mealFavoriteMatchKey('Oatmeal Bowl', const []),
        mealFavoriteMatchKey('oatmeal bowl', const []),
      );
    });

    test('trims surrounding whitespace on names and portions', () {
      expect(
        mealFavoriteMatchKey('  Oatmeal  ', [comp('  Banana ', ' 1 medium ')]),
        mealFavoriteMatchKey('Oatmeal', [comp('Banana', '1 medium')]),
      );
    });

    test('is case-insensitive on component names and portions', () {
      expect(
        mealFavoriteMatchKey('Bowl', [comp('BANANA', '1 MEDIUM')]),
        mealFavoriteMatchKey('Bowl', [comp('banana', '1 medium')]),
      );
    });
  });

  group('mealFavoriteMatchKey discrimination', () {
    test('component order matters', () {
      final ab = mealFavoriteMatchKey('Bowl', [
        comp('Oats', '1 cup'),
        comp('Banana', '1 medium'),
      ]);
      final ba = mealFavoriteMatchKey('Bowl', [
        comp('Banana', '1 medium'),
        comp('Oats', '1 cup'),
      ]);
      expect(ab, isNot(ba));
    });

    test('a different portion is a different meal', () {
      expect(
        mealFavoriteMatchKey('Bowl', [comp('Oats', '1 cup')]),
        isNot(mealFavoriteMatchKey('Bowl', [comp('Oats', '2 cups')])),
      );
    });

    test('a different name is a different meal', () {
      expect(
        mealFavoriteMatchKey('Bowl', [comp('Oats', '1 cup')]),
        isNot(mealFavoriteMatchKey('Bowl 2', [comp('Oats', '1 cup')])),
      );
    });

    test('an extra component is a different meal', () {
      expect(
        mealFavoriteMatchKey('Bowl', [comp('Oats', '1 cup')]),
        isNot(
          mealFavoriteMatchKey('Bowl', [
            comp('Oats', '1 cup'),
            comp('Honey', '1 tsp'),
          ]),
        ),
      );
    });

    test('an empty component list is distinct from one empty component', () {
      expect(
        mealFavoriteMatchKey('Bowl', const []),
        isNot(mealFavoriteMatchKey('Bowl', [comp('', '')])),
      );
    });
  });

  group('separator handling', () {
    // The key used to be built as `name::comp|portion,comp|portion`. Food
    // names arriving from imported catalogs are not guaranteed to avoid those
    // characters, and a collision means un-favoriting deletes the wrong
    // SavedMeal row — so the encoding must stay escape-safe whatever it is.
    test('a pipe inside a component name cannot forge a portion boundary', () {
      final pipeInName = mealFavoriteMatchKey('Bowl', [comp('Oats|1 cup', '')]);
      final realBoundary = mealFavoriteMatchKey('Bowl', [
        comp('Oats', '1 cup'),
      ]);

      expect(
        pipeInName,
        isNot(realBoundary),
        reason:
            'A component literally named "Oats|1 cup" must not collide with '
            'the component "Oats" at portion "1 cup".',
      );
    });

    test('a comma inside a portion cannot forge a component boundary', () {
      final commaInPortion = mealFavoriteMatchKey('Bowl', [
        comp('Oats', '1 cup,Honey|1 tsp'),
      ]);
      final twoComponents = mealFavoriteMatchKey('Bowl', [
        comp('Oats', '1 cup'),
        comp('Honey', '1 tsp'),
      ]);

      expect(
        commaInPortion,
        isNot(twoComponents),
        reason:
            'One component whose portion contains a comma must not collide '
            'with two separate components.',
      );
    });
  });

  group('findFavoriteMatch', () {
    final oatmeal = saved('fav-1', 'Oatmeal Bowl', [
      comp('Oats', '1 cup'),
      comp('Banana', '1 medium'),
    ]);
    final smoothie = saved('fav-2', 'Green Smoothie', [
      comp('Spinach', '2 cups'),
    ]);

    test('finds the matching favorite', () {
      final match = findFavoriteMatch(
        log('Oatmeal Bowl', [
          comp('Oats', '1 cup'),
          comp('Banana', '1 medium'),
        ]),
        [smoothie, oatmeal],
      );
      expect(match?.id, 'fav-1');
    });

    test('matches through case and whitespace differences', () {
      final match = findFavoriteMatch(
        log('  oatmeal bowl ', [
          comp('OATS', ' 1 cup'),
          comp('banana', '1 MEDIUM'),
        ]),
        [oatmeal],
      );
      expect(match?.id, 'fav-1');
    });

    test('returns null when nothing matches', () {
      expect(
        findFavoriteMatch(log('Toast', [comp('Bread', '2 slices')]), [
          oatmeal,
          smoothie,
        ]),
        isNull,
      );
    });

    test('returns null against an empty favorites list', () {
      expect(
        findFavoriteMatch(log('Oatmeal Bowl', const []), const []),
        isNull,
      );
    });

    test('does not match on name alone when components differ', () {
      // The dangerous false positive: same title, different contents.
      final match = findFavoriteMatch(
        log('Oatmeal Bowl', [comp('Oats', '2 cups')]),
        [oatmeal],
      );
      expect(
        match,
        isNull,
        reason:
            'Un-favoriting keys off this result to choose a row to delete — a '
            'name-only match would delete the wrong favorite.',
      );
    });

    test('returns the first match when duplicates exist', () {
      final dupe = saved('fav-3', 'Oatmeal Bowl', [
        comp('Oats', '1 cup'),
        comp('Banana', '1 medium'),
      ]);
      final match = findFavoriteMatch(
        log('Oatmeal Bowl', [
          comp('Oats', '1 cup'),
          comp('Banana', '1 medium'),
        ]),
        [oatmeal, dupe],
      );
      expect(match?.id, 'fav-1');
    });
  });
}
