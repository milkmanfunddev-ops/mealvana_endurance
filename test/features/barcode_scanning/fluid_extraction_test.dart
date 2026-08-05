/// Beverage fluid extraction from a scanned product.
///
/// For a drink, millilitres are the number that matters: the during-run fluid
/// plan is built from it. Getting it wrong is not cosmetic — it is the
/// difference between a hydration target and no hydration target at all.
///
/// The original implementation matched only `unit == 'ml'` and returned null
/// for anything else. Open Food Facts publishes whatever the label says, so a
/// 1 L bottle arrives as `product_quantity: 1, unit: "l"` and a small can as
/// `cl`. Both silently recorded ZERO fluid, and a beverage with no fluid looks
/// exactly like a solid food in the plan.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/features/barcode_scanning/domain/api_food_product.dart';

void main() {
  ApiFoodProduct drink({
    String? categories = 'Beverages, Sports drinks',
    double? servingQuantity,
    String? servingQuantityUnit,
    double? productQuantity,
    String? productQuantityUnit,
  }) => ApiFoodProduct(
    barcode: '5000112637922',
    productName: 'Test Drink',
    apiSource: 'open_food_facts',
    confidenceScore: 1.0,
    categories: categories,
    servingQuantity: servingQuantity,
    servingQuantityUnit: servingQuantityUnit,
    productQuantity: productQuantity,
    productQuantityUnit: productQuantityUnit,
  );

  group('only beverages report fluid', () {
    test('a non-beverage returns null even with a volume present', () {
      final bar = drink(
        categories: 'Snacks, Cereal bars',
        servingQuantity: 500,
        servingQuantityUnit: 'ml',
      );
      expect(bar.fluidMlPerServing, isNull);
    });

    test('missing categories returns null rather than guessing', () {
      final unknown = drink(
        categories: null,
        servingQuantity: 500,
        servingQuantityUnit: 'ml',
      );
      expect(unknown.fluidMlPerServing, isNull);
    });

    test('beverage detection is case-insensitive', () {
      final shouty = drink(
        categories: 'BEVERAGES',
        servingQuantity: 330,
        servingQuantityUnit: 'ml',
      );
      expect(shouty.fluidMlPerServing, 330);
    });
  });

  group('millilitres', () {
    test('are taken as-is', () {
      expect(
        drink(
          servingQuantity: 500,
          servingQuantityUnit: 'ml',
        ).fluidMlPerServing,
        500,
      );
    });

    test('unit matching ignores case and padding', () {
      expect(
        drink(
          servingQuantity: 250,
          servingQuantityUnit: '  mL ',
        ).fluidMlPerServing,
        250,
      );
    });
  });

  group('units that used to record ZERO fluid', () {
    test('litres convert (a 1 L bottle is 1000 mL, not nothing)', () {
      expect(
        drink(productQuantity: 1, productQuantityUnit: 'l').fluidMlPerServing,
        1000,
      );
    });

    test('centilitres convert (a 33 cl can is 330 mL)', () {
      expect(
        drink(productQuantity: 33, productQuantityUnit: 'cl').fluidMlPerServing,
        330,
      );
    });

    test('decilitres convert', () {
      expect(
        drink(productQuantity: 5, productQuantityUnit: 'dl').fluidMlPerServing,
        500,
      );
    });

    test('US fluid ounces convert', () {
      final v = drink(
        servingQuantity: 12,
        servingQuantityUnit: 'fl oz',
      ).fluidMlPerServing;
      expect(v, closeTo(354.9, 0.1));
    });

    test('spelled-out unit names convert', () {
      expect(
        drink(
          productQuantity: 2,
          productQuantityUnit: 'litre',
        ).fluidMlPerServing,
        2000,
      );
      expect(
        drink(
          productQuantity: 750,
          productQuantityUnit: 'milliliter',
        ).fluidMlPerServing,
        750,
      );
    });
  });

  group('serving quantity wins over product quantity', () {
    test('a per-serving volume is preferred', () {
      // A 1 L bottle with a 250 mL serving should plan around the serving.
      final bottle = drink(
        servingQuantity: 250,
        servingQuantityUnit: 'ml',
        productQuantity: 1,
        productQuantityUnit: 'l',
      );
      expect(bottle.fluidMlPerServing, 250);
    });

    test('falls back to the whole product when no serving is given', () {
      final bottle = drink(productQuantity: 1, productQuantityUnit: 'l');
      expect(bottle.fluidMlPerServing, 1000);
    });

    test('falls back when the serving unit is unusable', () {
      // A serving quantity in an unrecognised unit must not block the
      // product-level fallback.
      final bottle = drink(
        servingQuantity: 1,
        servingQuantityUnit: 'bottle',
        productQuantity: 500,
        productQuantityUnit: 'ml',
      );
      expect(bottle.fluidMlPerServing, 500);
    });
  });

  group('bad data records nothing rather than something wrong', () {
    test('an unknown unit yields null, not the raw number', () {
      // Recording "1" mL for "1 bottle" would read as a plausible — and
      // uselessly small — fluid target.
      expect(
        drink(
          servingQuantity: 1,
          servingQuantityUnit: 'bottle',
        ).fluidMlPerServing,
        isNull,
      );
    });

    test('a null or missing unit yields null', () {
      expect(drink(servingQuantity: 500).fluidMlPerServing, isNull);
    });

    test('zero and negative volumes are rejected', () {
      expect(
        drink(servingQuantity: 0, servingQuantityUnit: 'ml').fluidMlPerServing,
        isNull,
      );
      expect(
        drink(
          servingQuantity: -250,
          servingQuantityUnit: 'ml',
        ).fluidMlPerServing,
        isNull,
      );
    });

    test('a product with no volume at all yields null', () {
      expect(drink().fluidMlPerServing, isNull);
    });
  });

  group('sanity of the converted magnitudes', () {
    test('every supported unit lands in a believable range for a drink', () {
      final cases = <String, ({double qty, String unit})>{
        '500 ml bottle': (qty: 500, unit: 'ml'),
        '1 l bottle': (qty: 1, unit: 'l'),
        '33 cl can': (qty: 33, unit: 'cl'),
        '12 fl oz can': (qty: 12, unit: 'fl oz'),
      };
      cases.forEach((label, c) {
        final ml = drink(
          productQuantity: c.qty,
          productQuantityUnit: c.unit,
        ).fluidMlPerServing;
        expect(ml, isNotNull, reason: '$label produced no fluid');
        expect(
          ml,
          inInclusiveRange(100, 3000),
          reason:
              '$label converted to $ml mL, which is not a drink-sized volume',
        );
      });
    });
  });
}
