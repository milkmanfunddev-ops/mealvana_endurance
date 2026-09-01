import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/features/meal_planning/domain/meal_icon.dart';
import 'package:mealvana_endurance/features/meal_planning/domain/meal_icon_classifier.dart';

/// Table mirrors the tier comments and regex lists in the prototype's
/// `lib/vana/meal-icon.ts`. If a case here changes, the TS must change too.
void main() {
  group('MealIconClassifier.classify by name', () {
    const cases = <String, MealIcon>{
      // Tier 0 — headline dishes beat everything else in the name.
      'Chicken noodle soup': MealIcon.soup,
      'Jacket potato with beans': MealIcon.potato,
      'Margherita pizza': MealIcon.pizza,
      'Banana smoothie': MealIcon.drink,
      'Chocolate milk': MealIcon.drink,
      'Beef chilli': MealIcon.soup,
      'Thai green curry with rice': MealIcon.soup,
      'Lentil dal': MealIcon.soup,
      'Chicken pho': MealIcon.soup,
      'Corned beef hash': MealIcon.potato,
      'Shrimp ramen': MealIcon.soup,
      'Chickpea curry': MealIcon.soup,
      // Tier 1 — dish form; earliest match in the text wins.
      'Spaghetti bolognese': MealIcon.pasta,
      'Mac and cheese': MealIcon.pasta,
      'Chicken burrito': MealIcon.wrap,
      'Veggie quesadilla': MealIcon.wrap,
      'Black bean tacos': MealIcon.wrap,
      'Chicken caesar wrap': MealIcon.wrap,
      'Tuna sandwich': MealIcon.bread,
      'Avocado toast': MealIcon.bread,
      'Hummus with pita': MealIcon.bread,
      'Rice cakes with peanut butter': MealIcon.bread,
      'Bread roll': MealIcon.bread,
      'Caesar salad with chicken': MealIcon.salad,
      'Poke bowl': MealIcon.salad,
      'Greek yogurt with granola': MealIcon.yogurt,
      'Granola with yogurt': MealIcon.oats,
      'Overnight oats': MealIcon.oats,
      'Rolled oats with berries': MealIcon.oats,
      'Cottage cheese with pineapple': MealIcon.yogurt,
      'Salted pretzels': MealIcon.snack,
      'Energy gel': MealIcon.snack,
      'Blueberry pancakes': MealIcon.baked,
      'Banana bread': MealIcon.baked,
      'Frittata': MealIcon.baked,
      // Tier 2 — protein.
      'Grilled chicken with rice': MealIcon.chicken,
      'Turkey meatballs': MealIcon.chicken,
      'Steak and sweet potato': MealIcon.meat,
      'Pulled pork': MealIcon.meat,
      'Salmon with quinoa': MealIcon.fish,
      'Scrambled eggs': MealIcon.egg,
      'Tofu stir fry': MealIcon.tofu,
      // Tier 3 — starch base.
      'Sweet potato fries': MealIcon.potato,
      'Quinoa bowl': MealIcon.bowl,
      'Vegetable risotto': MealIcon.bowl,
      // Tier 4 — fruit, nuts, dairy, snacks, sweets, veg.
      'Apple with peanut butter': MealIcon.fruit,
      'Trail mix': MealIcon.nuts,
      'Cheddar cheese': MealIcon.yogurt,
      'Dark chocolate': MealIcon.sweet,
      'Cake with cream': MealIcon.sweet,
      'Clif bar': MealIcon.snack,
      'Steamed broccoli': MealIcon.salad,
      // Nothing matches.
      'Water': MealIcon.utensils,
      'Mystery dish': MealIcon.utensils,
    };

    for (final entry in cases.entries) {
      test('"${entry.key}" → ${entry.value.wire}', () {
        expect(MealIconClassifier.classify(name: entry.key), entry.value);
      });
    }

    test('is case-insensitive', () {
      expect(
        MealIconClassifier.classify(name: 'CHICKEN BURRITO'),
        MealIcon.wrap,
      );
    });
  });

  group('MealIconClassifier fallbacks', () {
    test('falls back to the ingredient line when the name is silent', () {
      expect(
        MealIconClassifier.classify(
          name: 'Sunday special',
          ingredients: 'chicken, rice, broccoli',
        ),
        MealIcon.chicken,
      );
    });

    test('ingredient line runs the same tiers in order', () {
      expect(
        MealIconClassifier.classify(
          name: 'Leftovers',
          ingredients: 'rice, kale, chicken noodle soup',
        ),
        MealIcon.soup,
      );
    });

    test('pattern hints', () {
      expect(
        MealIconClassifier.classify(
          name: 'Combo',
          pattern: 'protein + starch + veg',
        ),
        MealIcon.chicken,
      );
      expect(
        MealIconClassifier.classify(name: 'Combo', pattern: 'starch + veg'),
        MealIcon.bowl,
      );
      expect(
        MealIconClassifier.classify(name: 'Combo', pattern: 'grain + veg'),
        MealIcon.bowl,
      );
      expect(
        MealIconClassifier.classify(name: 'Combo', pattern: 'fruit'),
        MealIcon.fruit,
      );
      expect(
        MealIconClassifier.classify(name: 'Combo', pattern: 'veg'),
        MealIcon.salad,
      );
      expect(
        MealIconClassifier.classify(name: 'Combo', pattern: 'greens'),
        MealIcon.salad,
      );
      expect(
        MealIconClassifier.classify(name: 'Combo', pattern: 'other'),
        MealIcon.utensils,
      );
    });

    test('empty everything → utensils', () {
      expect(MealIconClassifier.classify(name: ''), MealIcon.utensils);
    });
  });

  group('MealIconClassifier.resolve', () {
    test('a valid stored key wins over classification', () {
      expect(
        MealIconClassifier.resolve('pizza', name: 'Grilled chicken'),
        MealIcon.pizza,
      );
    });

    test('an unknown stored key falls back to classification', () {
      expect(
        MealIconClassifier.resolve('spaceship', name: 'Grilled chicken'),
        MealIcon.chicken,
      );
    });

    test('a null stored key classifies', () {
      expect(
        MealIconClassifier.resolve(null, name: 'Grilled chicken'),
        MealIcon.chicken,
      );
    });

    test('every MealIcon key round-trips through resolve', () {
      for (final icon in MealIcon.values) {
        expect(MealIconClassifier.resolve(icon.wire, name: 'x'), icon);
      }
      expect(MealIcon.values, hasLength(23));
    });
  });
}
