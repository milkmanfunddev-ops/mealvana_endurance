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
