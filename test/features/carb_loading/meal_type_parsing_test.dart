import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/features/carb_loading/domain/meal_type.dart';

/// `parseMealTypeIds` replaced three copy-pasted `_parseMealTypesArray`
/// methods that had already drifted apart: two did a bare `int.parse()` and
/// would THROW on a name string like 'breakfast', while the third handled both.
///
/// They only ever agreed because `carb_loading_user_foods` stores ids and has
/// never synced down from Postgres — where the column is `text[]` and
/// `carb_loading_foods` genuinely stores names. These tests pin the tolerant
/// behaviour so the two shapes can't diverge again.
void main() {
  group('parseMealTypeIds — Postgres array literal', () {
    test('parses integer ids: {1,2,3}', () {
      expect(parseMealTypeIds('{1,2,3}'), [1, 2, 3]);
    });

    test(
      'parses NAME strings: {breakfast,lunch} — two old copies threw here',
      () {
        expect(parseMealTypeIds('{breakfast,lunch}'), [
          MealType.breakfast.id,
          MealType.lunch.id,
        ]);
      },
    );

    test('parses a mixed array', () {
      expect(parseMealTypeIds('{1,dinner}'), [1, MealType.dinner.id]);
    });

    test('tolerates whitespace', () {
      expect(parseMealTypeIds('{ breakfast , 2 }'), [MealType.breakfast.id, 2]);
    });

    test('empty array -> []', () {
      expect(parseMealTypeIds('{}'), <int>[]);
    });
  });

  group('parseMealTypeIds — JSON array', () {
    test('parses ints: [1,2]', () {
      expect(parseMealTypeIds('[1,2]'), [1, 2]);
    });

    test('parses names: ["breakfast","dinner"]', () {
      expect(parseMealTypeIds('["breakfast","dinner"]'), [
        MealType.breakfast.id,
        MealType.dinner.id,
      ]);
    });

    test('empty array -> []', () {
      expect(parseMealTypeIds('[]'), <int>[]);
    });
  });

  group('parseMealTypeIds — snack types (the multi-word names)', () {
    test('parses morning_snack by name', () {
      expect(parseMealTypeIds('{morning_snack}'), [MealType.morningSnack.id]);
    });

    test('parses afternoon_snack and evening_snack', () {
      expect(parseMealTypeIds('{afternoon_snack,evening_snack}'), [
        MealType.afternoonSnack.id,
        MealType.eveningSnack.id,
      ]);
    });
  });

  group('parseMealTypeIds — must never throw', () {
    test('null -> []', () => expect(parseMealTypeIds(null), <int>[]));
    test('empty string -> []', () => expect(parseMealTypeIds(''), <int>[]));

    test('unknown name falls back to breakfast, does not throw', () {
      // Matches MealType.fromName's orElse. A bad tag must not break the day.
      expect(parseMealTypeIds('{not_a_meal}'), [MealType.breakfast.id]);
    });

    test('malformed JSON -> [] rather than an exception', () {
      expect(parseMealTypeIds('[1,2'), isA<List<int>>());
    });

    test('bare single value', () {
      expect(parseMealTypeIds('lunch'), [MealType.lunch.id]);
      expect(parseMealTypeIds('3'), [3]);
    });
  });
}
