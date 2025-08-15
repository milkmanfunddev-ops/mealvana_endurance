/// Data model for food items in nutrition plans
/// Used for expandable food items with details
class FoodItemData {
  const FoodItemData({
    required this.id,
    required this.name,
    required this.quantity,
    required this.iconPath,
    this.description,
    this.timing,
    this.nutritionalInfo,
    this.instructions,
  });

  final String id;
  final String name;
  final String quantity; // e.g., "1 cup", "4", "30m before"
  final String iconPath; // Asset path to food image
  final String? description; // Detailed nutritional advice
  final String? timing; // When to consume (e.g., "30-60 min pre-run")
  final NutritionalInfo? nutritionalInfo;
  final String? instructions; // Special preparation instructions

  @override
  String toString() => 'FoodItemData(id: $id, name: $name, quantity: $quantity)';
}

/// Nutritional information for food items
class NutritionalInfo {
  const NutritionalInfo({
    this.calories,
    this.carbs,
    this.protein,
    this.fat,
    this.sodium,
    this.sugar,
  });

  final int? calories;
  final int? carbs; // grams
  final int? protein; // grams
  final int? fat; // grams
  final int? sodium; // mg
  final int? sugar; // grams

  @override
  String toString() => 'NutritionalInfo(calories: $calories, carbs: ${carbs}g)';
}