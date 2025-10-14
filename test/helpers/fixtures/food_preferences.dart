/// Test fixtures for food preferences
///
/// Standard preference sets for testing food selection algorithms
library;

/// Food preference test scenarios
class FoodPreferenceFixtures {
  /// Standard runner - likes common endurance foods
  static Map<String, String> get standard => {
        // Pre-run favorites
        'Oatmeal': 'like',
        'Banana': 'like',
        'Toast with peanut butter': 'like',
        'Bagel': 'like',

        // During-run favorites
        'Gels': 'like',
        'Energy chews': 'like',
        'Sports drink': 'like',

        // Dislikes
        'Orange juice': 'dislike',
        'Milk': 'dislike',
      };

  /// Picky eater - many dislikes, few likes
  static Map<String, String> get picky => {
        // Limited likes
        'Banana': 'like',
        'Sports drink': 'like',
        'Gels': 'willing_to_try',

        // Many dislikes
        'Oatmeal': 'dislike',
        'Bagel': 'dislike',
        'Orange juice': 'dislike',
        'Milk': 'dislike',
        'Energy bar': 'dislike',
        'Toast': 'dislike',
        'Peanut butter': 'dislike',
        'Energy chews': 'dislike',
      };

  /// Adventurous eater - willing to try everything
  static Map<String, String> get adventurous => {
        'Oatmeal': 'willing_to_try',
        'Banana': 'willing_to_try',
        'Toast with peanut butter': 'willing_to_try',
        'Bagel': 'willing_to_try',
        'Gels': 'willing_to_try',
        'Energy chews': 'willing_to_try',
        'Sports drink': 'willing_to_try',
        'Energy bar': 'willing_to_try',
        'Waffle': 'willing_to_try',
      };

  /// Whole food focused - likes natural foods, dislikes processed
  static Map<String, String> get wholeFood => {
        // Likes natural foods
        'Banana': 'like',
        'Oatmeal': 'like',
        'Toast': 'like',
        'Dates': 'like',
        'Coconut water': 'like',

        // Dislikes processed options
        'Gels': 'dislike',
        'Energy chews': 'dislike',
        'Sports drink': 'dislike',
        'Energy bar': 'dislike',
      };

  /// Gel-only during run - prefers simple fueling
  static Map<String, String> get gelOnly => {
        // Pre-run variety OK
        'Oatmeal': 'like',
        'Banana': 'like',
        'Bagel': 'like',

        // During-run: gels preferred
        'Gels': 'like',
        'Energy chews': 'dislike',
        'Sports drink': 'like',
        'Energy bar': 'dislike',
        'Banana (during run)': 'dislike',
      };

  /// Dairy-free - no milk products
  static Map<String, String> get dairyFree => {
        'Oatmeal': 'like',
        'Banana': 'like',
        'Toast': 'like',
        'Gels': 'like',

        // No dairy
        'Milk': 'dislike',
        'Yogurt': 'dislike',
        'Cheese': 'dislike',
        'Protein shake (whey)': 'dislike',
      };

  /// Gluten-free - no wheat products
  static Map<String, String> get glutenFree => {
        'Banana': 'like',
        'Rice': 'like',
        'Potato': 'like',
        'Gels': 'like',

        // No gluten
        'Bagel': 'dislike',
        'Toast': 'dislike',
        'Oatmeal': 'dislike', // Unless certified GF
        'Energy bar': 'dislike', // Most contain gluten
      };

  /// Vegan - plant-based only
  static Map<String, String> get vegan => {
        'Oatmeal': 'like',
        'Banana': 'like',
        'Toast with peanut butter': 'like',
        'Dates': 'like',
        'Gels': 'like', // Most are vegan

        // No animal products
        'Milk': 'dislike',
        'Yogurt': 'dislike',
        'Honey': 'dislike',
        'Eggs': 'dislike',
      };

  /// Empty preferences - no saved preferences (new user)
  static Map<String, String> get empty => {};

  /// Get all preference scenarios
  static Map<String, Map<String, String>> get all => {
        'standard': standard,
        'picky': picky,
        'adventurous': adventurous,
        'wholeFood': wholeFood,
        'gelOnly': gelOnly,
        'dairyFree': dairyFree,
        'glutenFree': glutenFree,
        'vegan': vegan,
        'empty': empty,
      };
}

/// Expected food selections based on preferences
class ExpectedFoodSelections {
  /// Foods that should appear for standard preferences
  static List<String> get standardPreRun => [
        'Oatmeal',
        'Banana',
        'Toast with peanut butter',
        'Bagel',
      ];

  static List<String> get standardDuringRun => [
        'Gels',
        'Energy chews',
        'Sports drink',
      ];

  /// Foods that should NOT appear for picky eater
  static List<String> get pickyAvoid => [
        'Oatmeal',
        'Bagel',
        'Orange juice',
        'Energy bar',
        'Toast',
      ];

  /// Foods that MUST appear for whole food preference
  static List<String> get wholeFoodRequired => [
        'Banana',
        'Oatmeal',
        'Dates',
      ];

  /// Foods that MUST NOT appear for whole food preference
  static List<String> get wholeFoodForbidden => [
        'Gels',
        'Energy chews',
        'Sports drink',
        'Energy bar',
      ];

  /// Foods safe for dairy-free
  static List<String> get dairyFreeSafe => [
        'Oatmeal',
        'Banana',
        'Toast',
        'Gels',
        'Sports drink',
      ];

  /// Foods to avoid for dairy-free
  static List<String> get dairyFreeAvoid => [
        'Milk',
        'Yogurt',
        'Cheese',
        'Protein shake (whey)',
      ];

  /// Foods safe for gluten-free
  static List<String> get glutenFreeSafe => [
        'Banana',
        'Rice',
        'Potato',
        'Gels',
        'Sports drink',
      ];

  /// Foods to avoid for gluten-free
  static List<String> get glutenFreeAvoid => [
        'Bagel',
        'Toast',
        'Oatmeal',
        'Energy bar',
      ];
}

/// Helper to convert preference strings to enum format for edge functions
class PreferenceConverter {
  /// Convert Map to underscore format expected by edge functions
  ///
  /// Example: `{'Banana': 'like'}` -> `{'Banana': 'like'}`
  /// Example: `{'Oatmeal': 'willingToTry'}` -> `{'Oatmeal': 'willing_to_try'}`
  static Map<String, String> toEdgeFunctionFormat(Map<String, String> preferences) {
    return preferences.map((key, value) {
      // Already in correct format if contains underscore
      if (value.contains('_')) return MapEntry(key, value);

      // Convert camelCase to snake_case
      final snakeCase = value.replaceAllMapped(
        RegExp(r'[A-Z]'),
        (match) => '_${match.group(0)!.toLowerCase()}',
      );

      return MapEntry(key, snakeCase);
    });
  }

  /// Convert from database enum to string format
  static String fromEnum(dynamic preferenceEnum) {
    if (preferenceEnum == null) return 'willing_to_try';

    final str = preferenceEnum.toString();
    if (str.contains('.')) {
      // Handle enum format: Preference.like -> like
      return str.split('.').last;
    }
    return str;
  }
}
