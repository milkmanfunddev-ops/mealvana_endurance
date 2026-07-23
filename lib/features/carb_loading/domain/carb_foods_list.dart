// Curated 50g carb food list from Featherstone Nutrition guide
// Each food item provides exactly 50g carbohydrates

import 'carb_loading_plan_simple.dart';

/// Static list of 50g carb foods from carb_load_guide.pdf
class CarbFoodsList {
  static const List<CarbFood> foods = [
    // Grains & Starches
    CarbFood(
      name: 'bagel',
      displayName: 'Bagel',
      category: 'grains',
      description: '1 large',
    ),
    CarbFood(
      name: 'bread',
      displayName: 'Bread',
      category: 'grains',
      description: '2 slices large',
    ),
    CarbFood(
      name: 'pasta',
      displayName: 'Pasta',
      category: 'grains',
      description: '1 heaping cup cooked',
    ),
    CarbFood(
      name: 'rice',
      displayName: 'Rice',
      category: 'grains',
      description: '1 cup cooked',
    ),
    CarbFood(
      name: 'oats',
      displayName: 'Oats',
      category: 'grains',
      description: '1 cup dry',
    ),
    CarbFood(
      name: 'cereal',
      displayName: 'Cereal',
      category: 'grains',
      description: '1.5-2 cups dry',
    ),
    CarbFood(
      name: 'baked_potato',
      displayName: 'Baked potato',
      category: 'grains',
      description: '1 large',
    ),

    // Snacks & Treats
    CarbFood(
      name: 'pretzels',
      displayName: 'Pretzels',
      category: 'snacks',
      description: '2 servings',
    ),
    CarbFood(
      name: 'graham_crackers',
      displayName: 'Graham crackers',
      category: 'snacks',
      description: '4 crackers',
    ),
    CarbFood(
      name: 'skittles_candy',
      displayName: 'Skittles/candy',
      category: 'snacks',
      description: '2 servings',
    ),

    // Fruits & Natural
    CarbFood(
      name: 'bananas',
      displayName: 'Bananas (x2)',
      category: 'fruits',
      description: '2 whole',
    ),
    CarbFood(
      name: 'pineapple',
      displayName: 'Pineapple',
      category: 'fruits',
      description: '2 cups',
    ),
    CarbFood(
      name: 'applesauce',
      displayName: 'Applesauce',
      category: 'fruits',
      description: '1 cup sweetened',
    ),
    CarbFood(
      name: 'raisins',
      displayName: 'Raisins',
      category: 'fruits',
      description: '1/2 cup',
    ),

    // Liquids & Sweeteners
    CarbFood(
      name: 'sports_drink',
      displayName: 'Sports drink',
      category: 'liquids',
      description: '2 scoops Skratch',
    ),
    CarbFood(
      name: 'juice_lemonade',
      displayName: 'Juice/lemonade',
      category: 'liquids',
      description: '16 oz',
    ),
    CarbFood(
      name: 'honey',
      displayName: 'Honey',
      category: 'liquids',
      description: '3 Tbsp',
    ),
    CarbFood(
      name: 'maple_syrup',
      displayName: 'Maple syrup',
      category: 'liquids',
      description: '1/4 cup',
    ),
  ];

  /// Get foods by category
  static List<CarbFood> getFoodsByCategory(String category) {
    return foods.where((food) => food.category == category).toList();
  }

  /// Get all available categories
  static List<String> get categories {
    return foods.map((food) => food.category).toSet().toList()..sort();
  }

  /// Get food by name
  static CarbFood? getFoodByName(String name) {
    try {
      return foods.firstWhere((food) => food.name == name);
    } catch (e) {
      return null;
    }
  }

  /// Get foods suitable for quick add buttons (most popular/common)
  static List<CarbFood> get quickAddFoods {
    return [
      getFoodByName('cereal')!,
      getFoodByName('bananas')!,
      getFoodByName('bagel')!,
      getFoodByName('juice_lemonade')!,
      getFoodByName('oats')!,
      getFoodByName('pasta')!,
      getFoodByName('rice')!,
      getFoodByName('baked_potato')!,
      getFoodByName('bread')!,
    ];
  }

  /// Calculate daily carb target based on body weight
  /// Uses Featherstone formula: 8g carbs/kg body weight
  static int calculateDailyCarbTarget(double bodyWeightKg) {
    return (bodyWeightKg * 8.0).round();
  }

  /// Calculate daily servings target based on carb target
  static int calculateDailyServingsTarget(int dailyCarbTargetG) {
    return (dailyCarbTargetG / 50).round();
  }

  /// Get carb target ranges by weight for UI display
  static String getCarbTargetRangeForWeight(double bodyWeightKg) {
    final targetCarbs = calculateDailyCarbTarget(bodyWeightKg);
    final servings = calculateDailyServingsTarget(targetCarbs);

    if (bodyWeightKg >= 50 && bodyWeightKg < 55) {
      return '400g carbs/day (8 servings of 50g)';
    } else if (bodyWeightKg >= 55 && bodyWeightKg < 59) {
      return '450g carbs/day (9 servings of 50g)';
    } else if (bodyWeightKg >= 59 && bodyWeightKg < 66) {
      return '500g carbs/day (10 servings of 50g)';
    } else if (bodyWeightKg >= 66 && bodyWeightKg < 73) {
      return '550g carbs/day (11 servings of 50g)';
    } else if (bodyWeightKg >= 73 && bodyWeightKg < 77) {
      return '600g carbs/day (12 servings of 50g)';
    } else if (bodyWeightKg >= 77 && bodyWeightKg < 82) {
      return '650g carbs/day (13 servings of 50g)';
    } else if (bodyWeightKg >= 82 && bodyWeightKg < 86) {
      return '700g carbs/day (14 servings of 50g)';
    } else if (bodyWeightKg >= 86) {
      return '750g carbs/day (15 servings of 50g)';
    } else {
      return '${targetCarbs}g carbs/day ($servings servings of 50g)';
    }
  }
}
