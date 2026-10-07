/// `MealComponent.quantity` (testing-wave develop-2026-10, Finding 02-005):
/// the amount eaten sits beside the portion instead of inside its text, and a
/// stored row without it reads as one portion.
library;

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/features/meal_logging/domain/meal_component.dart';
import 'package:mealvana_endurance/features/meal_logging/domain/meal_relog.dart';

/// `meal_logs.items` of row 40600e48… as run 02 stored it (db-after.txt):
/// no `quantity` key anywhere.
const _run02Items = '''
[
  {"name": "Scrambled eggs (2 large eggs)", "fat_g": 13.8, "carb_g": 1.6,
   "portion": "2 large eggs, scrambled", "calories": 182, "protein_g": 12.6,
   "sodium_mg": 190},
  {"name": "Whole wheat toast with butter", "fat_g": 6, "carb_g": 13,
   "portion": "1 slice whole wheat bread + 1 tsp butter", "calories": 117,
   "protein_g": 3, "sodium_mg": 180},
  {"name": "Banana", "fat_g": 0.3, "carb_g": 27,
   "portion": "1 medium banana (~118g)", "calories": 105, "protein_g": 1.3,
   "sodium_mg": 1}
]
''';

void main() {
  const banana = MealComponent(
    name: 'Banana',
    portion: '1 medium banana (~118g)',
    calories: 105,
    carbG: 27.0,
    proteinG: 1.3,
    fatG: 0.3,
  );

  group('toJson', () {
    test('omits quantity at 1, so existing payloads are unchanged', () {
      expect(banana.toJson().containsKey('quantity'), isFalse);
    });

    test('writes quantity at 2', () {
      final two = banana.copyWith(quantity: 2, calories: 210);
      expect(two.toJson()['quantity'], 2.0);
      expect(MealComponent.fromJson(two.toJson()).quantity, 2.0);
    });
  });

  group('fromJson', () {
    test('a stored row with no quantity (run 02) reads as 1', () {
      final items = (jsonDecode(_run02Items) as List)
          .map((e) => MealComponent.fromJson(e as Map<String, dynamic>))
          .toList();
      expect(items, hasLength(3));
      for (final c in items) {
        expect(c.quantity, 1.0);
      }
      // The round trip writes exactly what was read: no new key.
      expect(items.last.toJson().containsKey('quantity'), isFalse);
    });

    test('an integer quantity on the wire reads as a double', () {
      final c = MealComponent.fromJson({
        'name': 'Banana',
        'portion': '1 medium banana (~118g)',
        'quantity': 2,
      });
      expect(c.quantity, 2.0);
    });
  });

  group('portionLabel', () {
    test('is the portion at quantity 1', () {
      expect(banana.portionLabel, '1 medium banana (~118g)');
    });

    test('is "2 × portion" at quantity 2, the AI text untouched', () {
      final two = banana.copyWith(quantity: 2);
      expect(two.portionLabel, '2 × 1 medium banana (~118g)');
      expect(two.portion, '1 medium banana (~118g)');
    });

    test('shows a fractional quantity without trailing zeros', () {
      expect(
        banana.copyWith(quantity: 0.5).portionLabel,
        '0.5 × 1 medium banana (~118g)',
      );
    });
  });

  test('a re-log at 2 servings keeps the item quantity', () {
    final two = banana.copyWith(quantity: 2, calories: 210);
    final relogged = scaleComponentForRelog(two, 2);
    expect(relogged.quantity, 2.0);
    expect(relogged.calories, 420);
  });
}
