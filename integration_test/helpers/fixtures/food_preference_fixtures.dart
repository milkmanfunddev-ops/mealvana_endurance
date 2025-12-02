/// Test food preference fixtures for integration testing
/// Provides a variety of food preference sets covering different dietary restrictions
class FoodPreferenceFixtures {
  /// Standard preferences - balanced mix of likes and dislikes
  static Map<String, List<String>> get standard => {
        'liked': [
          'banana',
          'oatmeal',
          'peanut butter',
          'honey',
          'sports drink',
          'energy gel',
          'orange',
          'granola bar',
        ],
        'disliked': [
          'coconut',
          'dates',
          'fig',
          'pretzels',
        ],
      };

  /// Vegan preferences - no animal products
  static Map<String, List<String>> get vegan => {
        'liked': [
          'banana',
          'oatmeal',
          'almond butter',
          'dates',
          'rice',
          'quinoa',
          'orange',
          'apple',
        ],
        'disliked': [
          'honey', // Not vegan
          'milk',
          'yogurt',
          'cheese',
          'egg',
          'whey protein',
        ],
      };

  /// Gluten-free preferences
  static Map<String, List<String>> get glutenFree => {
        'liked': [
          'banana',
          'rice',
          'potato',
          'sweet potato',
          'quinoa',
          'orange',
          'apple',
          'sports drink',
        ],
        'disliked': [
          'oatmeal', // May contain gluten
          'bread',
          'pasta',
          'granola bar',
          'pretzels',
        ],
      };

  /// Dairy-free preferences
  static Map<String, List<String>> get dairyFree => {
        'liked': [
          'banana',
          'oatmeal',
          'peanut butter',
          'almond butter',
          'rice',
          'pasta',
          'orange',
          'sports drink',
        ],
        'disliked': [
          'milk',
          'yogurt',
          'cheese',
          'whey protein',
        ],
      };

  /// Picky eater - many dislikes
  static Map<String, List<String>> get pickyEater => {
        'liked': [
          'banana',
          'white bread',
          'sports drink',
          'energy gel',
        ],
        'disliked': [
          'oatmeal',
          'dates',
          'fig',
          'pretzels',
          'coconut',
          'sweet potato',
          'quinoa',
          'almond butter',
          'peanut butter',
        ],
      };

  /// Adventurous eater - many likes, few dislikes
  static Map<String, List<String>> get adventurous => {
        'liked': [
          'banana',
          'oatmeal',
          'peanut butter',
          'almond butter',
          'honey',
          'dates',
          'fig',
          'rice',
          'quinoa',
          'pasta',
          'potato',
          'sweet potato',
          'orange',
          'apple',
          'granola bar',
          'energy gel',
          'sports drink',
        ],
        'disliked': [
          'coconut', // Only one dislike
        ],
      };

  /// No preferences - empty lists
  static Map<String, List<String>> get none => {
        'liked': <String>[],
        'disliked': <String>[],
      };

  /// Helper to get all preference sets
  static Map<String, Map<String, List<String>>> get all => {
        'standard': standard,
        'vegan': vegan,
        'glutenFree': glutenFree,
        'dairyFree': dairyFree,
        'pickyEater': pickyEater,
        'adventurous': adventurous,
        'none': none,
      };

  /// Helper to create custom preferences
  static Map<String, List<String>> custom({
    List<String>? liked,
    List<String>? disliked,
  }) {
    return {
      'liked': liked ?? [],
      'disliked': disliked ?? [],
    };
  }

  /// Helper to check if a food is in the liked list
  static bool isLiked(Map<String, List<String>> preferences, String food) {
    return preferences['liked']?.contains(food.toLowerCase()) ?? false;
  }

  /// Helper to check if a food is in the disliked list
  static bool isDisliked(Map<String, List<String>> preferences, String food) {
    return preferences['disliked']?.contains(food.toLowerCase()) ?? false;
  }

  /// Helper to check if a food is neutral (neither liked nor disliked)
  static bool isNeutral(Map<String, List<String>> preferences, String food) {
    return !isLiked(preferences, food) && !isDisliked(preferences, food);
  }
}
