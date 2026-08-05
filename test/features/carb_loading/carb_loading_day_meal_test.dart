/// Derived values on a carb-loading day meal.
///
/// Carb loading is a gram-target exercise: the athlete is trying to hit a
/// number over the days before a race, and every meal row contributes to it.
/// These getters are what the UI adds up and shows back, so a quiet rounding
/// or attribution mistake here misreports progress toward a target the whole
/// feature exists to serve.
///
/// `CarbLoadingDayMeal` had no test file at all.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/features/carb_loading/domain/carb_loading_day_meal.dart';
import 'package:mealvana_endurance/features/carb_loading/domain/meal_type.dart';

void main() {
  CarbLoadingDayMeal meal({
    String? defaultFoodId,
    String? userFoodId,
    int quantity = 1,
    double carbsConsumed = 60,
  }) => CarbLoadingDayMeal(
    id: 'm1',
    carbLoadingDayId: 'd1',
    mealType: MealType.breakfast,
    carbLoadingFoodId: defaultFoodId,
    carbLoadingUserFoodId: userFoodId,
    foodDisplayName: 'Bagel',
    quantity: quantity,
    carbsConsumed: carbsConsumed,
  );

  group('food attribution', () {
    test('a default-food meal reports default, not user', () {
      final m = meal(defaultFoodId: 'catalog-1');
      expect(m.isDefaultFood, isTrue);
      expect(m.isUserFood, isFalse);
      expect(m.foodId, 'catalog-1');
    });

    test('a user-food meal reports user, not default', () {
      final m = meal(userFoodId: 'mine-1');
      expect(m.isUserFood, isTrue);
      expect(m.isDefaultFood, isFalse);
      expect(m.foodId, 'mine-1');
    });

    test('a meal with neither id has no food id and claims neither kind', () {
      final m = meal();
      expect(m.isDefaultFood, isFalse);
      expect(m.isUserFood, isFalse);
      expect(m.foodId, isNull);
    });

    test('when both ids are set, the default id wins the tie', () {
      // Both flags read true here, so `isDefaultFood`/`isUserFood` are not
      // mutually exclusive by construction — pinned so the resolution order
      // (default first) cannot flip silently and re-point a row at the wrong
      // food table.
      final m = meal(defaultFoodId: 'catalog-1', userFoodId: 'mine-1');
      expect(m.isDefaultFood, isTrue);
      expect(m.isUserFood, isTrue);
      expect(m.foodId, 'catalog-1');
    });
  });

  group('carbsPerServing', () {
    test('divides the total by the number of servings', () {
      expect(meal(quantity: 3, carbsConsumed: 90).carbsPerServing, 30);
    });

    test('a single serving is the whole amount', () {
      expect(meal(quantity: 1, carbsConsumed: 45).carbsPerServing, 45);
    });

    test('a zero quantity does not divide by zero', () {
      // Guarded: returns the total rather than producing Infinity/NaN, which
      // would poison every sum it flows into.
      final m = meal(quantity: 0, carbsConsumed: 45);
      expect(m.carbsPerServing, 45);
      expect(m.carbsPerServing.isFinite, isTrue);
    });

    test('a negative quantity also avoids a nonsense result', () {
      final m = meal(quantity: -2, carbsConsumed: 45);
      expect(m.carbsPerServing.isFinite, isTrue);
      expect(
        m.carbsPerServing,
        greaterThanOrEqualTo(0),
        reason: 'A negative serving count must not yield negative carbs.',
      );
    });

    test('quantity x carbsPerServing returns the total for valid input', () {
      for (final q in [1, 2, 4, 7]) {
        final m = meal(quantity: q, carbsConsumed: 84);
        expect(m.carbsPerServing * q, closeTo(84, 0.001));
      }
    });
  });

  group('display strings', () {
    test('one serving is singular, everything else plural', () {
      expect(meal(quantity: 1).quantityDisplay, '1 serving');
      expect(meal(quantity: 2).quantityDisplay, '2 servings');
      expect(meal(quantity: 0).quantityDisplay, '0 servings');
    });

    test('whole gram amounts render exactly', () {
      expect(meal(carbsConsumed: 60).carbsDisplay, '60g carbs');
    });

    test('fractional grams are TRUNCATED, not rounded', () {
      // `.toInt()` truncates toward zero, so 49.9 g displays as 49 g. Every
      // partial gram in the plan is shown low, and the error accumulates
      // across a multi-day load where the athlete is chasing a gram target.
      //
      // Pinned as current behaviour: switching to `.round()` would flip these
      // and say so.
      expect(
        meal(carbsConsumed: 49.9).carbsDisplay,
        '49g carbs',
        reason: '49.9 g is displayed as 49 g — rounding would show 50 g.',
      );
      expect(meal(carbsConsumed: 60.7).carbsDisplay, '60g carbs');
    });

    test('the displayed number never exceeds the real amount', () {
      // The one guarantee truncation does give: it never overstates. Worth
      // pinning, because overstating carb intake is the more dangerous
      // direction for an athlete loading to a target.
      for (final grams in [0.4, 12.9, 49.9, 60.7, 199.99]) {
        final shown = int.parse(
          meal(carbsConsumed: grams).carbsDisplay.split('g').first,
        );
        expect(
          shown,
          lessThanOrEqualTo(grams.ceil()),
          reason: '$grams g displayed as $shown g',
        );
        expect(shown, lessThanOrEqualTo(grams.toInt() + 1));
      }
    });

    test('zero carbs renders as zero, not as an empty string', () {
      expect(meal(carbsConsumed: 0).carbsDisplay, '0g carbs');
    });
  });

  group('equality is by id', () {
    test('two rows with the same id are equal regardless of contents', () {
      final a = meal(quantity: 1, carbsConsumed: 10);
      final b = meal(quantity: 9, carbsConsumed: 90);
      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });
  });
}
