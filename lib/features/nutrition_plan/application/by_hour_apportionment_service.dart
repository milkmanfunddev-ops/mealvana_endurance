import '../domain/food_item_data.dart';

/// Utility methods for by-hour view quantity parsing and timing categorization.
///
/// The auto-apportionment algorithm (apportion/reapportion) has been removed
/// in favor of user-driven placement via ByHourSyncService.
class ByHourApportionmentService {
  /// Parse the numeric quantity from a food item's quantity string.
  /// e.g., "3 servings" → 3.0, "1.5 gels" → 1.5, "1" → 1.0
  static double parseQuantity(FoodItemData food) {
    final match = RegExp(r'^([\d.]+)').firstMatch(food.quantity);
    if (match != null) {
      return double.tryParse(match.group(1)!) ?? 1.0;
    }
    return 1.0;
  }

  /// Resolve timing category for a food item, with fallback for null.
  static TimingCategory resolveTimingCategory(FoodItemData food) {
    if (food.timingCategory != null) return food.timingCategory!;
    // Legacy fallback: use isDrink heuristic
    return food.isDrink
        ? TimingCategory.sipThroughout
        : TimingCategory.slowConsume;
  }
}
