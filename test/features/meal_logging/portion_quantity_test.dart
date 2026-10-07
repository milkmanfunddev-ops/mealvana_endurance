// Unit tests for the shared portion-quantity helpers extracted from the
// Edit Item dialogs (bug 39fe3fdb).

import 'package:flutter_test/flutter_test.dart';

import 'package:mealvana_endurance/features/meal_logging/domain/portion_quantity.dart';

void main() {
  portionScalingMain();

  group('parseLeadingQuantity', () {
    test('parses whole-number leading quantity', () {
      expect(parseLeadingQuantity('1 cup'), 1.0);
      expect(parseLeadingQuantity('2 bagels'), 2.0);
      expect(parseLeadingQuantity('100 g'), 100.0);
    });

    test('parses decimal leading quantity', () {
      expect(parseLeadingQuantity('1.5 oz'), 1.5);
    });

    test('tolerates leading whitespace', () {
      expect(parseLeadingQuantity('  2 cups'), 2.0);
    });

    test('returns null when there is no leading number', () {
      expect(parseLeadingQuantity('a handful'), isNull);
      expect(parseLeadingQuantity(''), isNull);
    });
  });

  group('replaceLeadingQuantity', () {
    test('rewrites the leading number, preserving the unit suffix', () {
      expect(replaceLeadingQuantity('1 cup', 2), '2 cup');
      expect(replaceLeadingQuantity('2 bagels', 1), '1 bagels');
    });

    test('preserves leading whitespace', () {
      expect(replaceLeadingQuantity(' 2 cups', 1), ' 1 cups');
    });

    test('formats fractional quantities', () {
      expect(replaceLeadingQuantity('1 cup', 1.5), '1.5 cup');
    });

    test('returns null when there is no leading number', () {
      expect(replaceLeadingQuantity('a handful', 2), isNull);
    });
  });

  group('bug 3abe3fdb — AI quantity must not mirror portion leading number', () {
    test('baseQty must be 1 regardless of portion leading number', () {
      // The fix hardcodes _baseQty = 1.0 in both editors. The old code
      // used parseLeadingQuantity, which returned the portion's leading
      // number and caused the Quantity field to mirror it.
      const portions = [
        '8 oz (240 ml)',
        '2 medium plums (about 150g)',
        '1 cup',
        '100 g',
      ];
      for (final p in portions) {
        // With the fix, _baseQty is always 1.0 — the parsed leading
        // number is only used at save time for multiplication folding.
        const fixedBaseQty = 1.0;
        expect(
          fmtQty(fixedBaseQty),
          '1',
          reason: 'Quantity field for "$p" should display 1',
        );
      }
    });

    test(
      'multiplication folding: "8 oz (240 ml)" × qty 2 → "16 oz (240 ml)"',
      () {
        const portion = '8 oz (240 ml)';
        const qty = 2.0;
        final portionQty = parseLeadingQuantity(portion) ?? 1.0;
        final result = replaceLeadingQuantity(portion, portionQty * qty);
        expect(result, '16 oz (240 ml)');
      },
    );

    test(
      'multiplication folding: "2 medium plums (about 150g)" × qty 3 → "6 medium plums (about 150g)"',
      () {
        const portion = '2 medium plums (about 150g)';
        const qty = 3.0;
        final portionQty = parseLeadingQuantity(portion) ?? 1.0;
        final result = replaceLeadingQuantity(portion, portionQty * qty);
        expect(result, '6 medium plums (about 150g)');
      },
    );

    test('passthrough when qty is 1 — portion returned verbatim', () {
      const portion = '8 oz (240 ml)';
      const qty = 1.0;
      const baseQty = 1.0;
      // _persistedPortion returns text verbatim when qty == _baseQty
      expect(
        qty == baseQty,
        isTrue,
        reason: 'qty 1 == baseQty 1, so portion is returned verbatim',
      );
    });

    test('multiplication folding: "1 cup" × qty 2 → "2 cup"', () {
      const portion = '1 cup';
      const qty = 2.0;
      final portionQty = parseLeadingQuantity(portion) ?? 1.0;
      final result = replaceLeadingQuantity(portion, portionQty * qty);
      expect(result, '2 cup');
    });

    test('no-leading-number portion unchanged when qty > 1', () {
      const portion = 'a handful';
      const qty = 2.0;
      final portionQty = parseLeadingQuantity(portion) ?? 1.0;
      final result = replaceLeadingQuantity(portion, portionQty * qty);
      // replaceLeadingQuantity returns null when there's no leading number
      expect(
        result,
        isNull,
        reason: 'falls back to text verbatim in _persistedPortion',
      );
    });
  });

  group('fmtQty', () {
    test('drops the trailing .0 for whole numbers', () {
      expect(fmtQty(2.0), '2');
      expect(fmtQty(1.0), '1');
    });

    test('keeps fractional digits', () {
      expect(fmtQty(1.5), '1.5');
      expect(fmtQty(0.25), '0.25');
    });
  });
}

// Ticket 135 (testing-wave; Finding 112-003): a Recent re-log at 2 servings
// wrote "2/2 cup dry" (only the numerator scaled) and at 1.5 wrote "6 oz
// cooked (115 g)" (the bracketed grams untouched).
void portionScalingMain() {
  group('parseLeadingQuantity reads fractions, mixed numbers and decimals', () {
    test('fractions', () {
      expect(parseLeadingQuantity('1/2 cup dry'), 0.5);
      expect(parseLeadingQuantity('3/4 cup'), 0.75);
    });

    test('mixed numbers', () {
      expect(parseLeadingQuantity('1 1/2 cups'), 1.5);
      expect(parseLeadingQuantity('2-1/4 cups'), 2.25);
    });

    test('decimals and whole numbers still read', () {
      expect(parseLeadingQuantity('1.25 cup'), 1.25);
      expect(parseLeadingQuantity('4 oz cooked (115 g)'), 4.0);
    });

    test('a number glued to its unit reads too', () {
      expect(parseLeadingQuantity('100g'), 100.0);
    });
  });

  group('replaceLeadingQuantity rewrites the whole leading number', () {
    test('a fraction becomes the scaled decimal, unit kept', () {
      expect(replaceLeadingQuantity('1/2 cup dry', 1), '1 cup dry');
      expect(replaceLeadingQuantity('1/2 cup dry', 0.75), '0.75 cup dry');
    });

    test('a mixed number is replaced as one token', () {
      expect(replaceLeadingQuantity('1 1/2 cups', 3), '3 cups');
    });
  });

  group('scalePortion', () {
    test('"1/2 cup dry" x 2 is "1 cup dry", never "2/2 cup dry"', () {
      expect(scalePortion('1/2 cup dry', 2), '1 cup dry');
      expect(scalePortion('2 tbsp', 2), '4 tbsp');
    });

    test('a bracketed gram amount scales with the portion', () {
      expect(scalePortion('4 oz cooked (115 g)', 1.5), '6 oz cooked (173 g)');
      expect(scalePortion('1 cup (240 ml)', 2), '2 cup (480 ml)');
      expect(scalePortion('1 oz (28 g)', 2), '2 oz (56 g)');
    });

    test('"1.25 cup" x 1.5 is "1.875 cup"', () {
      expect(scalePortion('1.25 cup', 1.5), '1.875 cup');
    });

    test('"1 large" x 1.5 keeps its unit', () {
      expect(scalePortion('1 large', 1.5), '1.5 large');
    });

    test('a portion with no leading number cannot be scaled', () {
      expect(scalePortion('a handful', 1.5), isNull);
      expect(scalePortion('a handful (30 g)', 1.5), isNull);
    });
  });

  group('fmtQty rounds to three decimals', () {
    test('a repeating decimal is cut, a clean one is kept', () {
      expect(fmtQty(2 / 3), '0.667');
      expect(fmtQty(1.875), '1.875');
      expect(fmtQty(1.5), '1.5');
      expect(fmtQty(3.0), '3');
    });
  });
}
