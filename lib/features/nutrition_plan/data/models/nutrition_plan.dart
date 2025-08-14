import 'package:hive/hive.dart';
import 'food_item.dart';

part 'nutrition_plan.g.dart';

@HiveType(typeId: 7)
class NutritionPlan extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String userId;

  @HiveField(2)
  final double distanceMiles;

  @HiveField(3)
  final double paceMinutesPerMile;

  @HiveField(4)
  final double durationHours;

  /// Calculated nutritional requirements
  @HiveField(5)
  final double totalCarbs;

  @HiveField(6)
  final double totalSodium;

  @HiveField(7)
  final double totalFluids;

  @HiveField(8)
  final double carbsPerHour;

  @HiveField(9)
  final double sodiumPerHour;

  @HiveField(10)
  final double fluidsPerHour;

  /// Meal plan components
  @HiveField(11)
  final List<PlannedMeal> preRunMeals;

  @HiveField(12)
  final List<PlannedMeal> duringRunMeals;

  @HiveField(13)
  final List<PlannedMeal> postRunMeals;

  @HiveField(14)
  final DateTime createdAt;

  @HiveField(15)
  final DateTime updatedAt;

  NutritionPlan({
    required this.id,
    required this.userId,
    required this.distanceMiles,
    required this.paceMinutesPerMile,
    required this.durationHours,
    required this.totalCarbs,
    required this.totalSodium,
    required this.totalFluids,
    required this.carbsPerHour,
    required this.sodiumPerHour,
    required this.fluidsPerHour,
    required this.preRunMeals,
    required this.duringRunMeals,
    required this.postRunMeals,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Get total nutritional information for all planned meals
  NutritionInfo get totalNutrition {
    double calories = 0;
    double carbs = 0;
    double protein = 0;
    double fat = 0;
    double fiber = 0;
    double sodium = 0;
    double sugar = 0;
    double fluids = 0;

    for (final meals in [preRunMeals, duringRunMeals, postRunMeals]) {
      for (final meal in meals) {
        final nutrition = meal.totalNutrition;
        calories += nutrition.calories;
        carbs += nutrition.carbs;
        protein += nutrition.protein;
        fat += nutrition.fat;
        fiber += nutrition.fiber;
        sodium += nutrition.sodium;
        sugar += nutrition.sugar;
        fluids += nutrition.fluids;
      }
    }

    return NutritionInfo(
      calories: calories,
      carbs: carbs,
      protein: protein,
      fat: fat,
      fiber: fiber,
      sodium: sodium,
      sugar: sugar,
      fluids: fluids,
    );
  }
}

@HiveType(typeId: 8)
class PlannedMeal extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String name;

  @HiveField(2)
  final List<FoodServing> servings;

  /// When to consume relative to run (negative for before, positive for during/after)
  @HiveField(3)
  final int timingMinutes;

  @HiveField(4)
  final String timingLabel;

  PlannedMeal({
    required this.id,
    required this.name,
    required this.servings,
    required this.timingMinutes,
    required this.timingLabel,
  });

  /// Calculate total nutrition for this meal
  NutritionInfo get totalNutrition {
    double calories = 0;
    double carbs = 0;
    double protein = 0;
    double fat = 0;
    double fiber = 0;
    double sodium = 0;
    double sugar = 0;
    double fluids = 0;

    for (final serving in servings) {
      final nutrition = serving.nutrition;
      calories += nutrition.calories;
      carbs += nutrition.carbs;
      protein += nutrition.protein;
      fat += nutrition.fat;
      fiber += nutrition.fiber;
      sodium += nutrition.sodium;
      sugar += nutrition.sugar;
      fluids += nutrition.fluids;
    }

    return NutritionInfo(
      calories: calories,
      carbs: carbs,
      protein: protein,
      fat: fat,
      fiber: fiber,
      sodium: sodium,
      sugar: sugar,
      fluids: fluids,
    );
  }
}

@HiveType(typeId: 9)
class FoodServing extends HiveObject {
  @HiveField(0)
  final String foodId;

  @HiveField(1)
  final String foodName;

  @HiveField(2)
  final double servingMultiplier;

  @HiveField(3)
  final String servingDescription;

  /// Base nutrition info per standard serving
  @HiveField(4)
  final NutritionInfo baseNutrition;

  FoodServing({
    required this.foodId,
    required this.foodName,
    required this.servingMultiplier,
    required this.servingDescription,
    required this.baseNutrition,
  });

  /// Calculate nutrition for this specific serving size
  NutritionInfo get nutrition {
    return NutritionInfo(
      calories: baseNutrition.calories * servingMultiplier,
      carbs: baseNutrition.carbs * servingMultiplier,
      protein: baseNutrition.protein * servingMultiplier,
      fat: baseNutrition.fat * servingMultiplier,
      fiber: baseNutrition.fiber * servingMultiplier,
      sodium: baseNutrition.sodium * servingMultiplier,
      sugar: baseNutrition.sugar * servingMultiplier,
      fluids: baseNutrition.fluids * servingMultiplier,
    );
  }
}