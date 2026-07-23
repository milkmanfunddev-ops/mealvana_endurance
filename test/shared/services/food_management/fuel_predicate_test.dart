import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/shared/services/food_management/fuel_predicate.dart';

void main() {
  group('isFuelProductType', () {
    test('fuel enum codes are fuel', () {
      for (final code in const [
        'gel',
        'chew',
        'drink_mix',
        'bar',
        'waffle',
        'sports_drink',
        'electrolyte_only',
        'electrolytes_fluids',
        'hydration_with_carbs',
        'quick_carbs',
        'solid_carb_snacks',
        'real_food_carbs',
        'recovery_shake',
        'protein_recovery',
        'capsule',
      ]) {
        expect(isFuelProductType(code), isTrue, reason: '$code should be fuel');
      }
    });

    test('general enum codes are NOT fuel', () {
      expect(isFuelProductType('real_food'), isFalse);
      expect(isFuelProductType('import'), isFalse);
    });

    test('null / empty / unknown is treated as general (not fuel)', () {
      expect(isFuelProductType(null), isFalse);
      expect(isFuelProductType(''), isFalse);
      expect(isFuelProductType('not_a_real_type'), isFalse);
    });

    test('legacy UUIDs normalize then classify', () {
      // gel UUID (fuel) and real_food UUID (general) from product_type_mapper.
      expect(isFuelProductType('8a847f4f-8c26-41ef-a1e2-132b404be95e'), isTrue);
      expect(
        isFuelProductType('76c16c67-1746-47d7-adea-e5fc9dcd1f4d'),
        isFalse,
      );
    });

    test('unmapped UUID normalizes to null → general', () {
      expect(
        isFuelProductType('00000000-0000-0000-0000-000000000000'),
        isFalse,
      );
    });
  });
}
