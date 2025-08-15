import '../domain/food_item.dart';

/// Static database of 12 food items for MVP
/// Based on requirements from docs/requirements/README.md
class FoodDatabase {
  static const List<Map<String, dynamic>> _foodData = [
    // PRE-RUN FOODS
    {
      'id': 'oatmeal',
      'name': 'Oatmeal',
      'description': 'Instant or rolled oats with water/milk',
      'category': 'preRun',
      'servingSize': '1 cup cooked',
      'servingAmount': 1.0,
      'servingUnit': 'cup',
      'nutrition': {
        'calories': 150.0,
        'carbs': 27.0,
        'protein': 5.0,
        'fat': 3.0,
        'fiber': 4.0,
        'sodium': 10.0,
        'sugar': 1.0,
        'fluids': 6.0,
      },
      'tags': ['complex-carbs', 'fiber', 'easy-digest'],
      'additionalInfo': 'Carb up, buttercup: gentle complex carbs = smooth 2–3-hour energy. Hit \'em 30–60 min pre-run.',
    },
    {
      'id': 'waffle_pancake',
      'name': 'Waffle or Pancakes',
      'description': 'Standard breakfast waffle or small pancake',
      'category': 'preRun',
      'servingSize': '1 medium waffle/pancake',
      'servingAmount': 1.0,
      'servingUnit': 'piece',
      'nutrition': {
        'calories': 180.0,
        'carbs': 25.0,
        'protein': 4.0,
        'fat': 7.0,
        'fiber': 1.0,
        'sodium': 350.0,
        'sugar': 6.0,
        'fluids': 2.0,
      },
      'tags': ['quick-carbs', 'comfort-food'],
      'additionalInfo': 'Quick-digesting carbs for immediate energy. Best 1-2 hours before running.',
    },
    {
      'id': 'bagel_bread',
      'name': 'Bagel or Bread',
      'description': 'Half bagel or 1 slice of bread',
      'category': 'preRun',
      'servingSize': '1/2 bagel or 1 slice',
      'servingAmount': 0.5,
      'servingUnit': 'bagel',
      'nutrition': {
        'calories': 140.0,
        'carbs': 28.0,
        'protein': 5.0,
        'fat': 1.0,
        'fiber': 2.0,
        'sodium': 230.0,
        'sugar': 2.0,
        'fluids': 1.0,
      },
      'tags': ['carbs', 'portable'],
      'additionalInfo': 'Simple carbohydrates for steady energy release. Pairs well with a small amount of protein.',
    },
    {
      'id': 'peanut_butter',
      'name': 'Peanut Butter',
      'description': 'Natural or regular peanut butter',
      'category': 'preRun',
      'servingSize': '1 tablespoon',
      'servingAmount': 1.0,
      'servingUnit': 'tbsp',
      'nutrition': {
        'calories': 95.0,
        'carbs': 4.0,
        'protein': 4.0,
        'fat': 8.0,
        'fiber': 1.0,
        'sodium': 75.0,
        'sugar': 2.0,
        'fluids': 0.0,
      },
      'tags': ['protein', 'healthy-fats', 'satiety'],
      'additionalInfo': 'Provides protein and healthy fats for sustained energy. Use sparingly before runs to avoid GI issues.',
    },
    {
      'id': 'banana',
      'name': 'Banana',
      'description': 'Medium ripe banana',
      'category': 'preRun',
      'servingSize': '1 medium banana',
      'servingAmount': 1.0,
      'servingUnit': 'banana',
      'nutrition': {
        'calories': 105.0,
        'carbs': 27.0,
        'protein': 1.0,
        'fat': 0.4,
        'fiber': 3.0,
        'sodium': 1.0,
        'sugar': 14.0,
        'fluids': 5.0,
      },
      'tags': ['natural-sugar', 'potassium', 'portable'],
      'additionalInfo': 'Natural sugars and potassium for quick energy and electrolyte support. Easy to digest.',
    },
    {
      'id': 'apple',
      'name': 'Apple',
      'description': 'Medium apple with skin',
      'category': 'preRun',
      'servingSize': '1 medium apple',
      'servingAmount': 1.0,
      'servingUnit': 'apple',
      'nutrition': {
        'calories': 80.0,
        'carbs': 21.0,
        'protein': 0.5,
        'fat': 0.3,
        'fiber': 4.0,
        'sodium': 2.0,
        'sugar': 16.0,
        'fluids': 6.0,
      },
      'tags': ['natural-sugar', 'fiber', 'hydration'],
      'additionalInfo': 'Natural sugars with fiber for steady energy. High water content helps with hydration.',
    },
    {
      'id': 'juice',
      'name': 'Juice',
      'description': '100% fruit juice (orange, apple, etc.)',
      'category': 'preRun',
      'servingSize': '8 fl oz',
      'servingAmount': 8.0,
      'servingUnit': 'fl oz',
      'nutrition': {
        'calories': 110.0,
        'carbs': 26.0,
        'protein': 1.0,
        'fat': 0.0,
        'fiber': 0.0,
        'sodium': 5.0,
        'sugar': 22.0,
        'fluids': 8.0,
      },
      'tags': ['quick-carbs', 'hydration', 'fast-absorption'],
      'additionalInfo': 'Rapid carbohydrate absorption for immediate energy. Best consumed 30-60 minutes before running.',
    },
    {
      'id': 'granola_bar',
      'name': 'Granola Bar',
      'description': 'Standard granola/energy bar',
      'category': 'preRun',
      'servingSize': '1 bar (40g)',
      'servingAmount': 1.0,
      'servingUnit': 'bar',
      'nutrition': {
        'calories': 170.0,
        'carbs': 24.0,
        'protein': 3.0,
        'fat': 7.0,
        'fiber': 3.0,
        'sodium': 95.0,
        'sugar': 12.0,
        'fluids': 0.5,
      },
      'tags': ['portable', 'mixed-macros', 'convenient'],
      'additionalInfo': 'Balanced mix of carbs, protein, and fats. Convenient and shelf-stable option.',
    },
    {
      'id': 'coffee',
      'name': 'Coffee',
      'description': 'Black coffee or with minimal additions',
      'category': 'preRun',
      'servingSize': '8 fl oz cup',
      'servingAmount': 8.0,
      'servingUnit': 'fl oz',
      'nutrition': {
        'calories': 5.0,
        'carbs': 1.0,
        'protein': 0.3,
        'fat': 0.0,
        'fiber': 0.0,
        'sodium': 5.0,
        'sugar': 0.0,
        'fluids': 8.0,
      },
      'tags': ['caffeine', 'performance', 'hydration'],
      'additionalInfo': 'Caffeine can enhance performance and fat burning. Consume 30-60 minutes before running.',
    },

    // DURING-RUN FOODS
    {
      'id': 'sports_drink',
      'name': 'Sports Drink',
      'description': 'Electrolyte sports drink (Gatorade, Powerade, etc.)',
      'category': 'duringRun',
      'servingSize': '8 fl oz',
      'servingAmount': 8.0,
      'servingUnit': 'fl oz',
      'nutrition': {
        'calories': 50.0,
        'carbs': 14.0,
        'protein': 0.0,
        'fat': 0.0,
        'fiber': 0.0,
        'sodium': 110.0,
        'sugar': 14.0,
        'fluids': 8.0,
      },
      'tags': ['electrolytes', 'quick-carbs', 'hydration'],
      'additionalInfo': 'Provides carbohydrates and electrolytes during exercise. Consume every 15-20 minutes.',
    },
    {
      'id': 'energy_gel',
      'name': 'Energy Gel',
      'description': 'Sports energy gel (GU, Clif Shot, etc.)',
      'category': 'duringRun',
      'servingSize': '1 packet (32g)',
      'servingAmount': 1.0,
      'servingUnit': 'packet',
      'nutrition': {
        'calories': 100.0,
        'carbs': 25.0,
        'protein': 0.0,
        'fat': 0.0,
        'fiber': 0.0,
        'sodium': 50.0,
        'sugar': 22.0,
        'fluids': 0.0,
      },
      'tags': ['concentrated-carbs', 'portable', 'fast-absorption'],
      'additionalInfo': 'Concentrated carbohydrates for quick energy. Take with water every 30-45 minutes.',
    },
    {
      'id': 'energy_chews',
      'name': 'Energy Chews',
      'description': 'Sports energy chews (Clif Bloks, etc.)',
      'category': 'duringRun',
      'servingSize': '3 pieces',
      'servingAmount': 3.0,
      'servingUnit': 'pieces',
      'nutrition': {
        'calories': 90.0,
        'carbs': 24.0,
        'protein': 0.0,
        'fat': 0.0,
        'fiber': 0.0,
        'sodium': 70.0,
        'sugar': 16.0,
        'fluids': 0.0,
      },
      'tags': ['chewable-carbs', 'electrolytes', 'portion-control'],
      'additionalInfo': 'Easy to portion and consume while running. Chew thoroughly and follow with water.',
    },
  ];

  /// Get all food items as FoodItem objects
  static List<FoodItem> getAllFoods() {
    return _foodData.map((data) => FoodItem.fromJson(data)).toList();
  }

  /// Get foods by category
  static List<FoodItem> getFoodsByCategory(FoodCategory category) {
    return getAllFoods()
        .where((food) => food.category == category)
        .toList();
  }

  /// Get a specific food item by ID
  static FoodItem? getFoodById(String id) {
    try {
      return getAllFoods().firstWhere((food) => food.id == id);
    } catch (e) {
      return null;
    }
  }

  /// Get pre-run foods
  static List<FoodItem> getPreRunFoods() {
    return getFoodsByCategory(FoodCategory.preRun);
  }

  /// Get during-run foods
  static List<FoodItem> getDuringRunFoods() {
    return getFoodsByCategory(FoodCategory.duringRun);
  }

  /// Get post-run foods (empty for now as they're not in MVP requirements)
  static List<FoodItem> getPostRunFoods() {
    return getFoodsByCategory(FoodCategory.postRun);
  }

  /// Get foods that user likes and are available for a specific category
  static List<FoodItem> getPreferredFoods(
    FoodCategory category,
    List<String> likedFoodIds,
    List<String> willingToTryIds,
  ) {
    final categoryFoods = getFoodsByCategory(category);
    return categoryFoods.where((food) {
      return likedFoodIds.contains(food.id) || 
             willingToTryIds.contains(food.id);
    }).toList();
  }

  /// Search foods by name or tags
  static List<FoodItem> searchFoods(String query) {
    final lowercaseQuery = query.toLowerCase();
    return getAllFoods().where((food) {
      return food.name.toLowerCase().contains(lowercaseQuery) ||
             food.description.toLowerCase().contains(lowercaseQuery) ||
             food.tags.any((tag) => tag.toLowerCase().contains(lowercaseQuery));
    }).toList();
  }
}