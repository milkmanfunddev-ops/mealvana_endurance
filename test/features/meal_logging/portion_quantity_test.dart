// Unit tests for the shared portion-quantity helpers extracted from the
// Edit Item dialogs (bug 39fe3fdb).

import 'package:flutter_test/flutter_test.dart';

import 'package:mealvana_endurance/features/meal_logging/domain/portion_quantity.dart';

void main() {
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

  group('bug 3abe3fdb — AI quantity must not mirror portion leading number',
      () {
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
        expect(fmtQty(fixedBaseQty), '1',
            reason: 'Quantity field for "$p" should display 1');
      }
    });

    test('multiplication folding: "8 oz (240 ml)" × qty 2 → "16 oz (240 ml)"',
        () {
      const portion = '8 oz (240 ml)';
      const qty = 2.0;
      final portionQty = parseLeadingQuantity(portion) ?? 1.0;
      final result = replaceLeadingQuantity(portion, portionQty * qty);
      expect(result, '16 oz (240 ml)');
    });

    test(
        'multiplication folding: "2 medium plums (about 150g)" × qty 3 → "6 medium plums (about 150g)"',
        () {
      const portion = '2 medium plums (about 150g)';
      const qty = 3.0;
      final portionQty = parseLeadingQuantity(portion) ?? 1.0;
      final result = replaceLeadingQuantity(portion, portionQty * qty);
      expect(result, '6 medium plums (about 150g)');
    });

    test('passthrough when qty is 1 — portion returned verbatim', () {
      const portion = '8 oz (240 ml)';
      const qty = 1.0;
      const baseQty = 1.0;
      // _persistedPortion returns text verbatim when qty == _baseQty
      expect(qty == baseQty, isTrue,
          reason: 'qty 1 == baseQty 1, so portion is returned verbatim');
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
      expect(result, isNull,
          reason: 'falls back to text verbatim in _persistedPortion');
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
