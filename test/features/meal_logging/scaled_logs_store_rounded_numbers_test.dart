// Ticket 135 (testing-wave; Findings 112-002, 112-003, 112-004, 112-012,
// 112-014): what a scaled quick log stores.
//
// - An item scaled by 1.5 keeps its unit ("1 large" -> "1.5 large"), and a
//   fraction or a bracketed gram amount scales readably.
// - Scaled items and summed totals are rounded (macros one decimal, sodium a
//   whole mg) so the row never carries 60.449999999999996; null stays null.
// - A 2-serving log divides back to its per-serving base for Recent.
// - Every quick assembly item with a matching single ingredient has sodium;
//   one without keeps null (unknown, not 0).
//
// The items are producer-shaped: the Egg and Chicken rows come from
// `common_ingredients.dart`, the Built bowl items from the dev row 5c0c96f4
// as its `items` JSON decoded them (Finding 112-004).

import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/features/meal_logging/domain/common_ingredients.dart';
import 'package:mealvana_endurance/features/meal_logging/domain/consumed_totals.dart';
import 'package:mealvana_endurance/features/meal_logging/domain/meal_component.dart';
import 'package:mealvana_endurance/features/meal_logging/domain/meal_log.dart';
import 'package:mealvana_endurance/features/meal_logging/domain/meal_log_source.dart';
import 'package:mealvana_endurance/features/meal_logging/domain/meal_relog.dart';
import 'package:mealvana_endurance/features/meal_logging/domain/quick_assembly.dart';

MealComponent _ingredient(String name) =>
    kCommonIngredients.firstWhere((c) => c.name == name);

/// Row 5c0c96f4's first item as the `items` JSON decodes it.
final _chickenFromRow = MealComponent.fromJson({
  'name': 'Chicken breast',
  'portion': '4 oz cooked (115 g)',
  'calories': 187,
  'carb_g': 0,
  'protein_g': 40.3,
  'fat_g': 0.6,
  'sodium_mg': 87,
});

void main() {
  group('112-002: a single ingredient keeps its unit', () {
    test('Egg at 1.5 servings is "1.5 large", not "1.5 servings"', () {
      final scaled = scaleComponentForRelog(_ingredient('Egg'), 1.5);
      expect(scaled.portion, '1.5 large');
      expect(scaled.calories, 108);
    });

    test('at 1 serving the item is untouched', () {
      final egg = _ingredient('Egg');
      expect(identical(scaleComponentForRelog(egg, 1), egg), isTrue);
      expect(egg.portion, '1 large');
    });
  });

  group('112-003: Recent re-log portions scale readably', () {
    test('"1/2 cup dry" x 2 is "1 cup dry"; "2 tbsp" x 2 is "4 tbsp"', () {
      const oats = MealComponent(name: 'Rolled oats', portion: '1/2 cup dry');
      const raisins = MealComponent(name: 'Raisins', portion: '2 tbsp');
      expect(scaleComponentForRelog(oats, 2).portion, '1 cup dry');
      expect(scaleComponentForRelog(raisins, 2).portion, '4 tbsp');
    });

    test('"4 oz cooked (115 g)" x 1.5 scales the grams too', () {
      expect(
        scaleComponentForRelog(_chickenFromRow, 1.5).portion,
        '6 oz cooked (173 g)',
      );
    });

    test('a portion that cannot be parsed falls back to "1.5 × …"', () {
      const mix = MealComponent(name: 'Trail mix', portion: 'a handful');
      expect(scaleComponentForRelog(mix, 1.5).portion, '1.5 × a handful');
    });
  });

  group('112-004: scaled numbers are rounded before the write', () {
    test('items: macros to one decimal, sodium to a whole mg', () {
      final scaled = scaleComponentForRelog(_chickenFromRow, 1.5);
      expect(scaled.proteinG, 60.5, reason: 'was 60.449999999999996 (60.45)');
      expect(scaled.fatG, 0.9, reason: 'was 0.8999999999999999');
      expect(scaled.sodiumMg, 131, reason: '130.5 mg rounds to a whole mg');
      expect(scaled.carbG, 0);
    });

    test('Egg at 1.5: carbs 0.6, not 0.6000000000000001', () {
      final scaled = scaleComponentForRelog(_ingredient('Egg'), 1.5);
      expect(scaled.carbG, 0.6);
      expect(scaled.sodiumMg, 107, reason: '106.5 mg');
    });

    test('row totals are rounded the same way', () {
      final totals = MealTotals.ofComponents([
        scaleComponentForRelog(_chickenFromRow, 1.5),
        const MealComponent(
          name: 'Quinoa',
          portion: '1.25 cup',
          carbG: 0.4,
          fatG: 0.2,
        ),
      ]);
      expect(totals.carbsG, 0.4);
      expect(
        totals.fatG,
        1.1,
        reason: '0.9 + 0.2 = 1.1, not 1.1000000000000001',
      );
      expect(totals.proteinG, 60.5);
      expect(totals.sodiumMg, 131);
    });

    test('null stays null', () {
      const noNumbers = MealComponent(name: 'Mystery', portion: '1 cup');
      final scaled = scaleComponentForRelog(noNumbers, 2);
      expect(scaled.calories, isNull);
      expect(scaled.carbG, isNull);
      expect(scaled.proteinG, isNull);
      expect(scaled.fatG, isNull);
      expect(scaled.sodiumMg, isNull);
      final totals = MealTotals.ofComponents([scaled]);
      expect(totals.sodiumMg, isNull);
      expect(totals.carbsG, isNull);
    });
  });

  group('112-012: a log made at 2 servings divides back to its base', () {
    final twoServings = MealLog(
      id: '5543d340-0000-4000-8000-000000000001',
      userId: 'u',
      logDate: '2026-09-25',
      name: 'Oatmeal + raisins',
      source: MealLogSource.manual,
      components: const [
        MealComponent(
          name: 'Rolled oats',
          portion: '1 cup dry',
          calories: 300,
          carbG: 54,
          proteinG: 10,
          fatG: 5,
          sodiumMg: 0,
        ),
        MealComponent(
          name: 'Raisins',
          portion: '4 tbsp',
          calories: 108,
          carbG: 28,
          proteinG: 1.2,
          fatG: 0.2,
        ),
      ],
      calories: 408,
      carbsG: 82,
      proteinG: 11.2,
      fatG: 5.2,
      sodiumMg: 0,
      servings: 2,
      createdAt: DateTime.utc(2026, 9, 25, 23, 24, 41),
      updatedAt: DateTime.utc(2026, 9, 25, 23, 24, 41),
    );

    test('perServing halves items and totals and reads as 1 serving', () {
      final base = twoServings.perServing();
      expect(base.servings, 1);
      expect(base.calories, 204);
      expect(base.carbsG, 41);
      expect(base.proteinG, 5.6);
      expect(base.fatG, 2.6);
      expect(base.sodiumMg, 0);
      expect(base.components.map((c) => c.portion), ['0.5 cup dry', '2 tbsp']);
      expect(base.components.first.calories, 150);
      expect(base.components.last.sodiumMg, isNull);
    });

    test('a 1-serving log is its own base', () {
      final one = twoServings.copyWith(servings: 1);
      expect(identical(one.perServing(), one), isTrue);
    });

    test('servings always crosses the wire, so a mixed batch never writes NULL', () {
      expect(twoServings.toSupabaseJson()['servings'], 2);
      expect(twoServings.copyWith(servings: 1).toSupabaseJson()['servings'], 1);
      expect(
        MealLog.fromSupabaseJson({
          ...twoServings.toSupabaseJson(),
          'created_at': '2026-09-25T23:24:41+00:00',
          'updated_at': '2026-09-25T23:24:41+00:00',
        })!.servings,
        2,
      );
      final withoutColumn = twoServings.toSupabaseJson()
        ..remove('servings')
        ..['created_at'] = '2026-09-25T23:24:41+00:00'
        ..['updated_at'] = '2026-09-25T23:24:41+00:00';
      expect(MealLog.fromSupabaseJson(withoutColumn)!.servings, 1);
    });
  });

  group(
    '112-014: quick assemblies carry sodium from the single ingredients',
    () {
      // Item name -> the ingredient it is taken from, with the portion factor.
      const matches = <String, (String, double)>{
        'Banana': ('Banana', 1),
        'Peanut butter': ('Peanut butter', 1),
        'Greek yogurt': ('Greek yogurt (plain)', 1),
        'Honey': ('Honey', 1),
        'Almond butter': ('Almond butter', 1),
        'Rolled oats': ('Rolled oats', 1),
        'Eggs': ('Egg', 2),
        'Whole-grain toast': ('Whole wheat bread', 2),
        'Cottage cheese': ('Cottage cheese', 1),
        'Whey protein shake': ('Whey protein powder', 1),
        'Apple': ('Apple', 1),
        'Cheddar cheese': ('Cheddar cheese', 1),
      };
      const unmatched = {
        'Rice cake',
        'Raisins',
        'Mixed berries',
        'Low-fat chocolate milk',
        'Medjool dates',
      };

      test('every item with a matching ingredient has its sodium', () {
        for (final assembly in kQuickAssemblies) {
          for (final item in assembly.components) {
            final match = matches[item.name];
            if (match == null) {
              expect(
                unmatched,
                contains(item.name),
                reason: '${item.name} is neither matched nor listed unmatched',
              );
              expect(item.sodiumMg, isNull, reason: item.name);
              continue;
            }
            final (ingredient, factor) = match;
            expect(
              item.sodiumMg,
              _ingredient(ingredient).sodiumMg! * factor,
              reason: '${assembly.name}: ${item.name}',
            );
          }
        }
      });

      test('a combo total no longer reads as sodium unknown', () {
        final eggsToast = kQuickAssemblies.firstWhere(
          (a) => a.name == 'Eggs + toast',
        );
        expect(MealTotals.ofComponents(eggsToast.components).sodiumMg, 430);
      });
    },
  );
}
