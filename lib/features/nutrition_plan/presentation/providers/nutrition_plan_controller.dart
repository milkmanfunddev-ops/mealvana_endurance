import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:mealvana_endurance/features/nutrition_plan/domain/nutrition_plan.dart';
import '../../../content/application/content_service.dart';
import '../../../content/domain/content_keys.dart';
import '../../application/nutrition_plan_service.dart';
import '../../domain/food_item_data.dart';
import '../../data/nutrition_plan_repository.dart';
import '../../data/macro_repository.dart';
import '../../domain/macro_targets.dart' as targets_model;
import '../../../auth/application/auth_service.dart';

part 'nutrition_plan_controller.g.dart';

/// Controller for managing nutrition plan generation and display
@riverpod
class NutritionPlanController extends _$NutritionPlanController {
  NutritionPlanService get _nutritionPlanService => ref.read(nutritionPlanServiceProvider);
  ContentService get _contentService => ref.read(contentServiceProvider);
  
  /// Save an updated plan to both local and remote storage
  Future<void> _saveUpdatedPlan(NutritionPlan updatedPlan) async {
    // Get the current user to get the device ID
    final authService = ref.read(authServiceProvider);
    final user = await authService.getCurrentUser();
    if (user == null) {
      print('Warning: No user found, cannot save plan');
      return;
    }
    
    final planRepository = await ref.read(nutritionPlanRepositoryProvider.future);
    
    // Cache locally with the correct device ID
    await planRepository.cachePlanLocally(user.id, updatedPlan);
    
    print('✅ Plan saved locally for user: ${user.id}');
    // Note: For now, we're only saving locally since remote save would require 
    // regenerating the entire plan. The local cache is sufficient for plan modifications.
  }
  
  /// Recalculate macro targets based on current food items in the plan
  MacroTargets _recalculateMacroTargets(NutritionPlan plan) {
    int totalCalories = 0;
    int totalCarbs = 0;
    int totalProtein = 0;
    int totalFat = 0;
    
    // Sum up all nutritional values from all sections
    for (final section in plan.sections) {
      for (final foodItem in section.foodItems) {
        final nutrition = foodItem.nutritionalInfo;
        if (nutrition != null) {
          totalCalories += nutrition.calories ?? 0;
          totalCarbs += nutrition.carbs ?? 0;
          totalProtein += nutrition.protein ?? 0;
          totalFat += nutrition.fat ?? 0;
        }
      }
    }
    
    // Return updated macro targets
    return MacroTargets(
      calories: totalCalories,
      carbs: totalCarbs,
      protein: totalProtein,
      fat: totalFat,
      carbsRange: plan.macroTargets?.carbsRange ?? '80-90%',
      proteinRange: plan.macroTargets?.proteinRange ?? '5-15%',
      fatRange: plan.macroTargets?.fatRange ?? '5-15%',
    );
  }

  @override
  FutureOr<NutritionPlan?> build() {
    // Initialize with the latest nutrition plan or null
    return _nutritionPlanService.getLatestNutritionPlan();
  }

  /// Get cached macro targets from repository
  Future<targets_model.MacroTargets?> getCachedMacroTargets() async {
    try {
      final macroRepository = await ref.read(macroRepositoryProvider.future);
      final targets = await macroRepository.getCachedMacroTargets();
      return targets;
    } catch (e) {
      print('Error getting cached macro targets: $e');
      return null;
    }
  }

  /// Generate a new nutrition plan
  Future<NutritionPlan?> generatePlan({
    required double distanceMiles,
    required double paceMinutesPerMile,
  }) async {
    state = const AsyncLoading();

    state = await AsyncValue.guard(() async {
      final plan = await _nutritionPlanService.generateNutritionPlan(
        distanceMiles: distanceMiles,
        paceMinutesPerMile: paceMinutesPerMile,
      );

      return plan;
    });

    return state.valueOrNull;
  }


  /// Update an existing plan with new parameters
  Future<void> updatePlan({
    required double distanceMiles,
    required double paceMinutesPerMile,
    double timeBeforeRunHours = 2.0,
    String? gutTrainingLevel,
  }) async {
    state = await AsyncValue.guard(() async {
      final updatedPlan = await _nutritionPlanService.updateNutritionPlan(
        distanceMiles: distanceMiles,
        paceMinutesPerMile: paceMinutesPerMile,
        timeBeforeRunHours: timeBeforeRunHours,
        gutTrainingLevel: gutTrainingLevel,
      );
      return updatedPlan;
    });
  }

  /// Delete a plan
  Future<void> deletePlan(String planId) async {
    final currentPlan = state.valueOrNull;
    
    state = await AsyncValue.guard(() async {
      await _nutritionPlanService.deleteNutritionPlan(planId);
      // If we just deleted the current plan, return null
      if (currentPlan?.id == planId) {
        return null;
      }
      return currentPlan;
    });
  }

  /// Get nutrition recommendations for current plan
  List<String> getRecommendations() {
    final plan = state.valueOrNull;
    if (plan == null) return [];
    
    return _nutritionPlanService.getNutritionRecommendations(plan);
  }

  /// Validate current plan for safety
  bool validateCurrentPlan() {
    final plan = state.valueOrNull;
    if (plan == null) return false;
    
    return _nutritionPlanService.validateNutritionPlan(plan);
  }

  /// Get plan statistics for the user
  Future<Map<String, dynamic>> getPlanStatistics() async {
    return await _nutritionPlanService.getNutritionPlanStatistics();
  }

  /// Clear current plan (reset state)
  void clearCurrentPlan() {
    state = const AsyncData(null);
  }
  
  /// Get content-driven error message
  /// Swap a food item in the current plan
  Future<void> swapFoodItem(String oldFoodId, dynamic newFood, String category, {double? customAmount}) async {
    final currentPlan = state.valueOrNull;
    if (currentPlan == null) return;
    
    state = const AsyncLoading();
    
    state = await AsyncValue.guard(() async {
      // Create a new plan with the swapped food
      // This is a simplified implementation - you may need to adjust based on your data model
      final updatedSections = currentPlan.sections.map((section) {
        if ((category == 'before_run' && section.title == 'Before Run') ||
            (category == 'during_run' && section.title == 'During Run') ||
            (category == 'after_run' && section.title == 'After Run')) {
          final updatedItems = section.foodItems.map((item) {
            if (item.id == oldFoodId) {
              // Create a new food item from the newFood
              final multiplier = customAmount ?? newFood.servingAmount ?? 1.0;
              return FoodItemData(
                id: newFood.id,
                name: newFood.name,
                quantity: newFood.generateQuantityDisplay(customAmount: customAmount),
                iconPath: newFood.iconPath ?? '🍽️',
                instructions: newFood.instructions,
                nutritionalInfo: NutritionalInfo(
                  calories: ((newFood.caloriesPerServing ?? 0) * multiplier).toInt(),
                  carbs: ((newFood.carbsPerServing ?? 0) * multiplier).toInt(),
                  protein: ((newFood.proteinPerServing ?? 0) * multiplier).toInt(),
                  fat: ((newFood.fatPerServing ?? 0) * multiplier).toInt(),
                  sodium: ((newFood.sodiumMg ?? 0) * multiplier).toInt(),
                  fluids: ((newFood.fluidMlPerServing ?? 0) * multiplier),
                ),
              );
            }
            return item;
          }).toList();
          
          return PlanSection(
            id: section.id,
            title: section.title,
            subtitle: section.subtitle,
            foodItems: updatedItems,
          );
        }
        return section;
      }).toList();
      
      // Recalculate macro targets based on new food items
      final updatedMacroTargets = _recalculateMacroTargets(currentPlan.copyWith(sections: updatedSections));
      
      // Create updated plan with recalculated macros
      final updatedPlan = currentPlan.copyWith(
        sections: updatedSections,
        macroTargets: updatedMacroTargets,
        totalCalories: updatedMacroTargets.calories,
        updatedAt: DateTime.now(),
      );
      
      // Save the updated plan to storage
      await _saveUpdatedPlan(updatedPlan);
      
      return updatedPlan;
    });
  }
  
  /// Add a food item to the current plan
  Future<void> addFoodItem(dynamic food, String category, {double? customAmount}) async {
    final currentPlan = state.valueOrNull;
    if (currentPlan == null) return;
    
    state = const AsyncLoading();
    
    state = await AsyncValue.guard(() async {
      // Create a new plan with the added food
      final updatedSections = currentPlan.sections.map((section) {
        if ((category == 'before_run' && section.title == 'Before Run') ||
            (category == 'during_run' && section.title == 'During Run') ||
            (category == 'after_run' && section.title == 'After Run')) {
          final multiplier = customAmount ?? food.servingAmount ?? 1.0;
          final newItem = FoodItemData(
            id: food.id,
            name: food.name,
            quantity: food.generateQuantityDisplay(customAmount: customAmount),
            iconPath: food.iconPath ?? '🍽️',
            instructions: food.instructions,
            nutritionalInfo: NutritionalInfo(
              calories: ((food.caloriesPerServing ?? 0) * multiplier).toInt(),
              carbs: ((food.carbsPerServing ?? 0) * multiplier).toInt(),
              protein: ((food.proteinPerServing ?? 0) * multiplier).toInt(),
              fat: ((food.fatPerServing ?? 0) * multiplier).toInt(),
              sodium: ((food.sodiumMg ?? 0) * multiplier).toInt(),
              fluids: ((food.fluidMlPerServing ?? 0) * multiplier),
            ),
          );
          
          return PlanSection(
            id: section.id,
            title: section.title,
            subtitle: section.subtitle,
            foodItems: [...section.foodItems, newItem],
          );
        }
        return section;
      }).toList();
      
      // Recalculate macro targets based on new food items
      final updatedMacroTargets = _recalculateMacroTargets(currentPlan.copyWith(sections: updatedSections));
      
      // Create updated plan with recalculated macros
      final updatedPlan = currentPlan.copyWith(
        sections: updatedSections,
        macroTargets: updatedMacroTargets,
        totalCalories: updatedMacroTargets.calories,
        updatedAt: DateTime.now(),
      );
      
      // Save the updated plan to storage
      await _saveUpdatedPlan(updatedPlan);
      
      return updatedPlan;
    });
  }
  
  /// Delete a food item from the current plan
  Future<void> deleteFoodItem(String foodId, String category) async {
    final currentPlan = state.valueOrNull;
    if (currentPlan == null) return;
    
    state = const AsyncLoading();
    
    state = await AsyncValue.guard(() async {
      // Create a new plan without the deleted food
      final updatedSections = currentPlan.sections.map((section) {
        if ((category == 'before_run' && section.title == 'Before Run') ||
            (category == 'during_run' && section.title == 'During Run') ||
            (category == 'after_run' && section.title == 'After Run')) {
          final updatedItems = section.foodItems.where((item) => item.id != foodId).toList();
          
          return PlanSection(
            id: section.id,
            title: section.title,
            subtitle: section.subtitle,
            foodItems: updatedItems,
          );
        }
        return section;
      }).toList();
      
      // Recalculate macro targets based on new food items
      final updatedMacroTargets = _recalculateMacroTargets(currentPlan.copyWith(sections: updatedSections));
      
      // Create updated plan with recalculated macros
      final updatedPlan = currentPlan.copyWith(
        sections: updatedSections,
        macroTargets: updatedMacroTargets,
        totalCalories: updatedMacroTargets.calories,
        updatedAt: DateTime.now(),
      );
      
      // Save the updated plan to storage
      await _saveUpdatedPlan(updatedPlan);
      
      return updatedPlan;
    });
  }

  String getErrorMessage(String? error) {
    return _contentService.getValue(ContentKeys.errorGeneric, 
        defaultValue: error ?? 'Something went wrong. Please try again.');
  }
}

/// Provider for current nutrition plan
@riverpod
NutritionPlan? currentNutritionPlan(Ref ref) {
  final controller = ref.watch(nutritionPlanControllerProvider);
  return controller.valueOrNull;
}

/// Provider for nutrition recommendations
@riverpod
List<String> nutritionRecommendations(Ref ref) {
  final controller = ref.read(nutritionPlanControllerProvider.notifier);
  return controller.getRecommendations();
}