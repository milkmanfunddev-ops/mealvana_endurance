import 'food_item_data.dart';

/// Data model for nutrition plans with before/during/after run sections
class NutritionPlan {
  const NutritionPlan({
    required this.id,
    required this.name,
    required this.sections,
    this.macroTargets,
    this.totalCalories,
    this.notes,
  });

  final String id;
  final String name; // e.g., "Long Run Nutrition Plan"
  final List<PlanSection> sections;
  final MacroTargets? macroTargets;
  final int? totalCalories;
  final String? notes;

  @override
  String toString() => 'NutritionPlan(id: $id, name: $name)';
}

/// Section within a nutrition plan (Before/During/After Run)
class PlanSection {
  const PlanSection({
    required this.id,
    required this.title,
    required this.foodItems,
    this.subtitle,
    this.timing,
  });

  final String id;
  final String title; // "Before Run", "During Run", "After Run"
  final String? subtitle; // "30-60 min pre-run"
  final String? timing;
  final List<FoodItemData> foodItems;

  @override
  String toString() => 'PlanSection(title: $title, items: ${foodItems.length})';
}

/// Macro targets for nutrition plan
class MacroTargets {
  const MacroTargets({
    required this.calories,
    required this.carbs,
    required this.protein,
    required this.fat,
    this.carbsRange,
    this.proteinRange,
    this.fatRange,
  });

  final int calories;
  final int carbs; // grams
  final int protein; // grams  
  final int fat; // grams
  final String? carbsRange; // e.g., "45-65%"
  final String? proteinRange; // e.g., "10-15%"
  final String? fatRange; // e.g., "20-35%"

  @override
  String toString() => 'MacroTargets(cal: $calories, carbs: ${carbs}g, protein: ${protein}g, fat: ${fat}g)';
}