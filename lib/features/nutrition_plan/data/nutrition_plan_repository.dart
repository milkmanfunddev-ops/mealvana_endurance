import 'package:hive/hive.dart';
import '../domain/nutrition_plan.dart';
import '../domain/food_item_data.dart';

/// Repository for managing nutrition plans in Hive
class NutritionPlanRepository {
  static const String _boxName = 'nutrition_plans';
  
  late Box<Map<dynamic, dynamic>> _planBox;
  
  /// Initialize the repository and open Hive box
  Future<void> init() async {
    _planBox = await Hive.openBox<Map<dynamic, dynamic>>(_boxName);
  }

  /// Save a nutrition plan
  Future<void> savePlan(NutritionPlan plan) async {
    final planData = _planToMap(plan);
    await _planBox.put(plan.id, planData);
  }

  /// Get a nutrition plan by ID
  NutritionPlan? getPlan(String planId) {
    final planData = _planBox.get(planId);
    return planData != null ? _mapToPlan(planData) : null;
  }

  /// Get all nutrition plans for a specific user
  List<NutritionPlan> getPlansForUser(String userId) {
    // Since our current model doesn't have userId, return all plans for now
    return _planBox.values
        .map((planData) => _mapToPlan(planData))
        .toList();
  }

  /// Get the most recent nutrition plan for a user
  NutritionPlan? getLatestPlanForUser(String userId) {
    final userPlans = getPlansForUser(userId);
    return userPlans.isNotEmpty ? userPlans.last : null; // Return last created
  }

  /// Update a nutrition plan
  Future<void> updatePlan(NutritionPlan plan) async {
    await savePlan(plan); // Simple update by overwriting
  }

  /// Delete a nutrition plan
  Future<void> deletePlan(String planId) async {
    await _planBox.delete(planId);
  }

  /// Delete all plans for a user
  Future<void> deleteAllPlansForUser(String userId) async {
    final userPlans = getPlansForUser(userId);
    for (final plan in userPlans) {
      await _planBox.delete(plan.id);
    }
  }

  /// Get all nutrition plans (for admin/debugging)
  List<NutritionPlan> getAllPlans() {
    return _planBox.values
        .map((planData) => _mapToPlan(planData))
        .toList();
  }

  /// Check if a plan exists
  bool planExists(String planId) {
    return _planBox.containsKey(planId);
  }

  /// Get plan count for a user
  int getPlanCount(String userId) {
    return getPlansForUser(userId).length;
  }

  /// Get nutrition plan statistics for a user
  Map<String, dynamic> getPlanStatistics(String userId) {
    final plans = getPlansForUser(userId);
    
    if (plans.isEmpty) {
      return {
        'totalPlans': 0,
        'averageDistance': 0.0,
        'averageDuration': 0.0,
        'averagePace': 0.0,
        'averageCarbs': 0.0,
        'averageSodium': 0.0,
        'averageFluids': 0.0,
      };
    }

    // Calculate basic statistics from available data
    final totalCalories = plans.fold(0, (sum, plan) => sum + (plan.totalCalories ?? 0));

    return {
      'totalPlans': plans.length,
      'averageDistance': 0.0, // Not available in current model
      'averageDuration': 0.0, // Not available in current model
      'averagePace': 0.0, // Not available in current model
      'averageCarbs': plans.isNotEmpty 
          ? totalCalories / plans.length / 4 // Rough carb estimation
          : 0.0,
      'averageSodium': 0.0, // Not available in current model
      'averageFluids': 0.0, // Not available in current model
    };
  }

  /// Clear all nutrition plans (for testing/reset)
  Future<void> clearAllPlans() async {
    await _planBox.clear();
  }

  /// Close the repository and Hive box
  Future<void> close() async {
    await _planBox.close();
  }

  /// Convert NutritionPlan to Map for Hive storage
  Map<String, dynamic> _planToMap(NutritionPlan plan) {
    return {
      'id': plan.id,
      'name': plan.name,
      'totalCalories': plan.totalCalories,
      'notes': plan.notes,
      'macroTargets': plan.macroTargets != null ? {
        'calories': plan.macroTargets!.calories,
        'carbs': plan.macroTargets!.carbs,
        'protein': plan.macroTargets!.protein,
        'fat': plan.macroTargets!.fat,
        'carbsRange': plan.macroTargets!.carbsRange,
        'proteinRange': plan.macroTargets!.proteinRange,
        'fatRange': plan.macroTargets!.fatRange,
      } : null,
      'sections': plan.sections.map((section) => {
        'id': section.id,
        'title': section.title,
        'subtitle': section.subtitle,
        'timing': section.timing,
        'foodItems': section.foodItems.map((item) => {
          'id': item.id,
          'name': item.name,
          'quantity': item.quantity,
          'iconPath': item.iconPath,
          'description': item.description,
          'timing': item.timing,
          'instructions': item.instructions,
          'nutritionalInfo': item.nutritionalInfo != null ? {
            'calories': item.nutritionalInfo!.calories,
            'carbs': item.nutritionalInfo!.carbs,
            'protein': item.nutritionalInfo!.protein,
            'fat': item.nutritionalInfo!.fat,
            'sodium': item.nutritionalInfo!.sodium,
          } : null,
        }).toList(),
      }).toList(),
    };
  }

  /// Convert Map from Hive storage to NutritionPlan
  NutritionPlan _mapToPlan(Map<dynamic, dynamic> map) {
    return NutritionPlan(
      id: map['id'] as String,
      name: map['name'] as String,
      totalCalories: map['totalCalories'] as int?,
      notes: map['notes'] as String?,
      macroTargets: map['macroTargets'] != null 
          ? MacroTargets(
              calories: map['macroTargets']['calories'] as int,
              carbs: map['macroTargets']['carbs'] as int,
              protein: map['macroTargets']['protein'] as int,
              fat: map['macroTargets']['fat'] as int,
              carbsRange: map['macroTargets']['carbsRange'] as String?,
              proteinRange: map['macroTargets']['proteinRange'] as String?,
              fatRange: map['macroTargets']['fatRange'] as String?,
            )
          : null,
      sections: (map['sections'] as List<dynamic>).map((sectionMap) {
        return PlanSection(
          id: sectionMap['id'] as String,
          title: sectionMap['title'] as String,
          subtitle: sectionMap['subtitle'] as String?,
          timing: sectionMap['timing'] as String?,
          foodItems: (sectionMap['foodItems'] as List<dynamic>).map((itemMap) {
            return FoodItemData(
              id: itemMap['id'] as String,
              name: itemMap['name'] as String,
              quantity: itemMap['quantity'] as String,
              iconPath: itemMap['iconPath'] as String,
              description: itemMap['description'] as String?,
              timing: itemMap['timing'] as String?,
              instructions: itemMap['instructions'] as String?,
              nutritionalInfo: itemMap['nutritionalInfo'] != null
                  ? NutritionalInfo(
                      calories: itemMap['nutritionalInfo']['calories'] as int,
                      carbs: itemMap['nutritionalInfo']['carbs'] as int,
                      protein: itemMap['nutritionalInfo']['protein'] as int,
                      fat: itemMap['nutritionalInfo']['fat'] as int,
                      sodium: itemMap['nutritionalInfo']['sodium'] as int?,
                    )
                  : null,
            );
          }).toList(),
        );
      }).toList(),
    );
  }
}