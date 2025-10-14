import 'dart:async';
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
import '../../../../shared/services/logging_service.dart';
import '../../../../shared/services/app_external_deps.dart';
import '../../../../shared/services/analytics/analytics_tracker.dart';
import '../../../../shared/services/analytics/analytics_events.dart';
import '../../../../shared/database/database_provider.dart';
import 'package:mealvana_endurance/core/utils/debug_logger.dart';

part 'nutrition_plan_controller.g.dart';

/// State class combining nutrition plan and its save status
class NutritionPlanState {
  const NutritionPlanState({
    this.plan,
    this.isSaved = true,
    this.isLoading = false,
    this.error,
    this.planId,
  });

  final NutritionPlan? plan;
  final bool isSaved;
  final bool isLoading;
  final String? error;
  final String? planId; // UUID v4 for North-Star metric threading

  NutritionPlanState copyWith({
    NutritionPlan? plan,
    bool? isSaved,
    bool? isLoading,
    String? error,
    String? planId,
  }) {
    return NutritionPlanState(
      plan: plan ?? this.plan,
      isSaved: isSaved ?? this.isSaved,
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
      planId: planId ?? this.planId,
    );
  }

  @override
  String toString() => 'NutritionPlanState(plan: ${plan?.id}, isSaved: $isSaved, isLoading: $isLoading, error: $error)';
}


/// Controller for managing nutrition plan generation and display with save state
@riverpod  
class NutritionPlanController extends _$NutritionPlanController {
  NutritionPlanService get _nutritionPlanService => ref.read(nutritionPlanServiceProvider);
  ContentService get _contentService => ref.read(contentServiceProvider);
  AnalyticsTracker get _analytics => ref.read(appExternalDepsProvider).analytics;
  AppLogger get _logger => ref.read(appExternalDepsProvider).logger;
  AuthService get _authService => ref.read(authServiceProvider);
  
  /// Save an updated plan to both local and remote storage
  Future<void> _saveUpdatedPlan(NutritionPlan updatedPlan) async {
    // Get the current user to get the device ID
    final authService = ref.read(authServiceProvider);
    final user = await authService.getCurrentUser();
    if (user == null) {
      DebugLogger.warning('Warning: No user found, cannot save plan');
      return;
    }
    
    final planRepository = await ref.read(nutritionPlanRepositoryProvider.future);
    
    // Cache locally with the correct device ID
    await planRepository.cachePlanLocally(user.id, updatedPlan);
    
    DebugLogger.info('✅ Plan saved locally for user: ${user.id}');
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
  FutureOr<NutritionPlanState> build() async {
    DebugLogger.info('🔍 DEBUG: NutritionPlanController.build() called');
    
    // First try to get a temporarily saved plan (unsaved plan)
    final tempPlan = await _getTempPlan();
    if (tempPlan != null) {
      DebugLogger.info('🔍 DEBUG: Found temp plan: ${tempPlan.id}, returning as unsaved');
      return NutritionPlanState(plan: tempPlan, isSaved: false);
    }
    
    DebugLogger.info('🔍 DEBUG: No temp plan found, getting latest saved plan');
    // Otherwise get the latest saved nutrition plan  
    final savedPlan = await _nutritionPlanService.getLatestNutritionPlan();
    if (savedPlan != null) {
      DebugLogger.info('🔍 DEBUG: Found saved plan: ${savedPlan.id}, returning as saved');
      return NutritionPlanState(plan: savedPlan, isSaved: true);
    } else {
      DebugLogger.info('🔍 DEBUG: No plan found');
      return const NutritionPlanState(plan: null, isSaved: true);
    }
  }

  /// Get temporarily stored plan (unsaved plan that persists through app reload)
  Future<NutritionPlan?> _getTempPlan() async {
    try {
      final authService = ref.read(authServiceProvider);
      final user = await authService.getCurrentUser();
      if (user == null) {
        DebugLogger.info('🔍 DEBUG: No user found for temp plan check');
        return null;
      }

      DebugLogger.info('🔍 DEBUG: Checking for temp plan for user: ${user.id}');
      final planRepository = await ref.read(nutritionPlanRepositoryProvider.future);
      final tempPlan = await planRepository.getTempPlan(user.id);
      
      if (tempPlan != null) {
        DebugLogger.info('🔍 DEBUG: Found temp plan: ${tempPlan.id}');
      } else {
        DebugLogger.info('🔍 DEBUG: No temp plan found');
      }
      
      return tempPlan;
    } catch (error) {
      DebugLogger.error('Error getting temp plan: $error');
      return null;
    }
  }

  /// Save plan temporarily (survives app restart until officially saved)
  Future<void> _saveTempPlan(NutritionPlan plan) async {
    try {
      final authService = ref.read(authServiceProvider);
      final user = await authService.getCurrentUser();
      if (user == null) {
        DebugLogger.info('🔍 DEBUG: Cannot save temp plan - no user');
        return;
      }

      DebugLogger.info('🔍 DEBUG: Saving temp plan ${plan.id} for user: ${user.id}');
      final planRepository = await ref.read(nutritionPlanRepositoryProvider.future);
      await planRepository.saveTempPlan(user.id, plan);
      DebugLogger.info('🔍 DEBUG: Temp plan saved successfully');
    } catch (error) {
      DebugLogger.error('Error saving temp plan: $error');
    }
  }

  /// Clear temporary plan (called when plan is officially saved)
  Future<void> _clearTempPlan() async {
    try {
      final authService = ref.read(authServiceProvider);
      final user = await authService.getCurrentUser();
      if (user == null) return;

      final planRepository = await ref.read(nutritionPlanRepositoryProvider.future);
      await planRepository.clearTempPlan(user.id);
    } catch (error) {
      DebugLogger.error('Error clearing temp plan: $error');
    }
  }


  /// Set a new generated plan (marks as unsaved and saves temporarily)
  Future<void> setGeneratedPlan(NutritionPlan plan, {String? planId}) async {
    DebugLogger.info('🔍 DEBUG: setGeneratedPlan() called for plan: ${plan.id}');
    DebugLogger.info('🔍 DEBUG: planId for North-Star: $planId');
    
    // Set state to show plan as unsaved with planId
    state = AsyncValue.data(NutritionPlanState(plan: plan, isSaved: false, planId: planId));
    
    // Save temporarily so it persists through app reload
    DebugLogger.info('🔍 DEBUG: Saving plan temporarily');
    await _saveTempPlan(plan);
    
    // Remove from permanent local storage if it was cached there
    try {
      final authService = ref.read(authServiceProvider);
      final user = await authService.getCurrentUser();
      if (user != null) {
        final database = ref.read(appDatabaseProvider);
        // Delete the plan from permanent local storage so it's only in temp storage
        DebugLogger.info('🔍 DEBUG: Removing plan from permanent local storage');
        await database.deleteNutritionPlan(plan.id);
      }
    } catch (error) {
      DebugLogger.error('Note: Could not remove plan from permanent local storage: $error');
    }
    DebugLogger.info('🔍 DEBUG: setGeneratedPlan() completed');
  }

  /// Save the current plan permanently (move from temp to permanent storage)
  Future<bool> savePlan() async {
    final currentState = state.value;
    if (currentState?.plan == null) {
      DebugLogger.info('🔍 DEBUG: savePlan() - No plan to save');
      return false;
    }

    try {
      DebugLogger.info('🔍 DEBUG: savePlan() called for plan: ${currentState!.plan!.id}');
      
      // Save to permanent storage
      final authService = ref.read(authServiceProvider);
      final user = await authService.getCurrentUser();
      if (user == null) {
        DebugLogger.info('🔍 DEBUG: savePlan() - No user found');
        return false;
      }

      final planRepository = await ref.read(nutritionPlanRepositoryProvider.future);
      await planRepository.cachePlanLocally(user.id, currentState.plan!);
      
      // Track North-Star metric: plan_saved
      if (currentState.planId != null) {
        // TODO: Add macro coverage analytics tracking in future version
        // This would calculate carbsCoveragePct, sodiumCoveragePct, fluidsCoveragePct
        // by summing nutritional values from plan sections and comparing to macro targets

        // Track plan_saved event with proper properties
        final deviceId = user.id;

        // Calculate time since generation (assuming it was just generated)
        // In a real implementation, you'd store the generation start time
        const timeSinceGeneration = 0; // Placeholder - should track actual time

        // Check if this is the user's first plan
        final userPlans = await planRepository.getNutritionPlans(user.id);
        final totalPlansSaved = userPlans.length;
        final isFirstPlan = totalPlansSaved <= 1; // Current plan is already saved

        await _analytics.trackPlanSaved(
          deviceId: deviceId,
          planId: currentState.planId!,
          timeSinceGenerationStarted: timeSinceGeneration,
          isFirstPlan: isFirstPlan,
          totalPlansSaved: totalPlansSaved,
        );
        
        DebugLogger.info('📊 DEBUG: Tracked plan_saved event for planId: ${currentState.planId}');
      }
      
      // Clear temp storage
      await _clearTempPlan();
      
      // Update state to show as saved
      state = AsyncValue.data(currentState.copyWith(isSaved: true));
      
      DebugLogger.info('🔍 DEBUG: savePlan() completed successfully');
      return true;
    } catch (error) {
      DebugLogger.info('🔍 DEBUG: savePlan() failed: $error');
      return false;
    }
  }

  /// Get cached macro targets from repository
  Future<targets_model.MacroTargets?> getCachedMacroTargets() async {
    try {
      final macroRepository = await ref.read(macroRepositoryProvider.future);
      final targets = await macroRepository.getCachedMacroTargets();
      return targets;
    } catch (e) {
      DebugLogger.error('Error getting cached macro targets: $e');
      return null;
    }
  }

  /// Generate a new nutrition plan
  Future<NutritionPlan?> generatePlan({
    required double distanceMiles,
    required double paceMinutesPerMile,
  }) async {
    state = const AsyncValue.loading();

    try {
      final plan = await _nutritionPlanService.generateNutritionPlan(
        distanceMiles: distanceMiles,
        paceMinutesPerMile: paceMinutesPerMile,
      );

      // Use setGeneratedPlan to mark as unsaved
      await setGeneratedPlan(plan);
      return plan;
        } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
      return null;
    }
  }


  /// Update an existing plan with new parameters
  Future<void> updatePlan({
    required double distanceMiles,
    required double paceMinutesPerMile,
    double timeBeforeRunHours = 2.0,
    String? gutTrainingLevel,
  }) async {
    try {
      final updatedPlan = await _nutritionPlanService.updateNutritionPlan(
        distanceMiles: distanceMiles,
        paceMinutesPerMile: paceMinutesPerMile,
        timeBeforeRunHours: timeBeforeRunHours,
        gutTrainingLevel: gutTrainingLevel,
      );
      
      // Mark updated plan as unsaved
      await setGeneratedPlan(updatedPlan);
        } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
    }
  }

  /// Delete a plan
  Future<void> deletePlan(String planId) async {
    final currentState = state.value;
    
    state = await AsyncValue.guard(() async {
      await _nutritionPlanService.deleteNutritionPlan(planId);
      // If we just deleted the current plan, return empty state
      if (currentState?.plan?.id == planId) {
        return const NutritionPlanState(plan: null, isSaved: true);
      }
      return currentState ?? const NutritionPlanState(plan: null, isSaved: true);
    });
  }

  /// Get nutrition recommendations for current plan
  List<String> getRecommendations() {
    final currentState = state.value;
    if (currentState?.plan == null) return [];
    
    return _nutritionPlanService.getNutritionRecommendations(currentState!.plan!);
  }

  /// Validate current plan for safety
  bool validateCurrentPlan() {
    final currentState = state.value;
    if (currentState?.plan == null) return false;
    
    return _nutritionPlanService.validateNutritionPlan(currentState!.plan!);
  }

  /// Get plan statistics for the user
  Future<Map<String, dynamic>> getPlanStatistics() async {
    return await _nutritionPlanService.getNutritionPlanStatistics();
  }

  /// Clear current plan (reset state)
  void clearCurrentPlan() {
    state = const AsyncData(NutritionPlanState(plan: null, isSaved: true));
  }
  
  /// Get content-driven error message
  /// Swap a food item in the current plan
  Future<void> swapFoodItem(String oldFoodId, dynamic newFood, String category, {double? customAmount}) async {
    final currentState = state.value;
    if (currentState?.plan == null) return;
    
    final currentPlan = currentState!.plan!;
    
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
                imageAddress: newFood.imageAddress,
                description: newFood.description,
                instructions: newFood.instructions,
                displayName: newFood.displayName,
                displayNamePlural: newFood.displayNamePlural,
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
          
          return section.copyWith(
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

      // Track plan_item_swapped event
      final user = await _authService.getCurrentUser();
      final deviceId = user?.id ?? 'unknown';

      // Find the old item name for tracking
      String oldItemName = oldFoodId;
      for (final section in currentPlan.sections) {
        for (final item in section.foodItems) {
          if (item.id == oldFoodId) {
            oldItemName = item.name;
            break;
          }
        }
      }

      await _analytics.trackPlanItemSwapped(
        deviceId: deviceId,
        planId: updatedPlan.id,
        oldItemName: oldItemName,
        newItemName: newFood.name,
        phase: category, // before_run, during_run, or after_run
      );

      return NutritionPlanState(plan: updatedPlan, isSaved: currentState.isSaved);
    });
  }
  
  /// Add a food item to the current plan
  Future<void> addFoodItem(dynamic food, String category, {double? customAmount}) async {
    final currentState = state.value;
    if (currentState == null || currentState.plan == null) return;

    final currentPlan = currentState.plan!;
    
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
            imageAddress: food.imageAddress,
            description: food.description,
            instructions: food.instructions,
            displayName: food.displayName,
            displayNamePlural: food.displayNamePlural,
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

      // Track item_added event
      final multiplier = customAmount ?? food.servingAmount ?? 1.0;
      await _analytics.track('plan_item_added', properties: {
        'plan_id': updatedPlan.id,
        'screen': 'plan_screen',
        'experiment_variant': 'auto_items_v1',
        'section': _mapCategoryToSection(category),
        'item_name': food.name,
        'item_source': 'generic',
        'carbs_g': (food.carbsPerServing ?? 0) * multiplier,
        'protein_g': (food.proteinPerServing ?? 0) * multiplier,
        'fluids_ml': (food.fluidMlPerServing ?? 0) * multiplier,
        'sodium_mg': (food.sodiumMg ?? 0) * multiplier,
      });

      return NutritionPlanState(plan: updatedPlan, isSaved: currentState.isSaved);
    });
  }

  /// Delete a food item from the current plan
  Future<void> deleteFoodItem(String foodId, String category) async {
    final currentState = state.value;
    if (currentState == null || currentState.plan == null) return;

    final currentPlan = currentState.plan!;
    
    state = const AsyncLoading();
    
    state = await AsyncValue.guard(() async {
      // Find the item being deleted for analytics tracking
      String? deletedItemName;
      for (final section in currentPlan.sections) {
        if ((category == 'before_run' && section.title == 'Before Run') ||
            (category == 'during_run' && section.title == 'During Run') ||
            (category == 'after_run' && section.title == 'After Run')) {
          final itemToDelete = section.foodItems.firstWhere(
            (item) => item.id == foodId,
            orElse: () => FoodItemData(id: '', name: 'Unknown', quantity: ''),
          );
          deletedItemName = itemToDelete.name;
          break;
        }
      }

      // Create a new plan without the deleted food
      final updatedSections = currentPlan.sections.map((section) {
        if ((category == 'before_run' && section.title == 'Before Run') ||
            (category == 'during_run' && section.title == 'During Run') ||
            (category == 'after_run' && section.title == 'After Run')) {
          final updatedItems = section.foodItems.where((item) => item.id != foodId).toList();

          return section.copyWith(
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

      // Track item_removed event
      if (deletedItemName != null) {
        await _analytics.track('plan_item_removed', properties: {
          'plan_id': updatedPlan.id,
          'screen': 'plan_screen',
          'experiment_variant': 'auto_items_v1',
          'section': _mapCategoryToSection(category),
          'item_name': deletedItemName,
        });
      }

      return NutritionPlanState(plan: updatedPlan, isSaved: currentState.isSaved);
    });
  }

  /// Update the quantity of an existing food item
  Future<void> updateFoodQuantity(String foodId, String category, double newQuantity) async {
    final currentState = state.value;
    if (currentState == null || currentState.plan == null) return;

    final currentPlan = currentState.plan!;

    // Capture old quantity and item name for analytics tracking
    String? itemName;
    double? oldQuantity;

    for (final section in currentPlan.sections) {
      if ((category == 'before_run' && section.title == 'Before Run') ||
          (category == 'during_run' && section.title == 'During Run') ||
          (category == 'after_run' && section.title == 'After Run')) {
        final item = section.foodItems.firstWhere(
          (item) => item.id == foodId,
          orElse: () => FoodItemData(id: '', name: 'Unknown', quantity: ''),
        );
        if (item.id == foodId) {
          itemName = item.name;
          // Extract the current quantity from the quantity string (e.g., "2.5 cups" -> 2.5)
          final currentQuantityMatch = RegExp(r'^([\d.]+)').firstMatch(item.quantity);
          oldQuantity = currentQuantityMatch != null
              ? double.tryParse(currentQuantityMatch.group(1)!) ?? 1.0
              : 1.0;
          break;
        }
      }
    }

    // Don't set loading state to avoid UI rebuilds during quantity editing
    // state = const AsyncLoading();

    try {
      // Create a new plan with the updated food quantity
      final updatedSections = currentPlan.sections.map((section) {
        if ((category == 'before_run' && section.title == 'Before Run') ||
            (category == 'during_run' && section.title == 'During Run') ||
            (category == 'after_run' && section.title == 'After Run')) {
          final updatedItems = section.foodItems.map((item) {
            if (item.id == foodId) {
              // We need to recalculate nutrition based on the original serving data
              // For now, we'll proportionally scale the current nutrition values
              final currentNutrition = item.nutritionalInfo;
              if (currentNutrition != null) {
                // Extract the current quantity from the quantity string (e.g., "2.5 cups" -> 2.5)
                final currentQuantityMatch = RegExp(r'^([\d.]+)').firstMatch(item.quantity);
                final currentQuantity = currentQuantityMatch != null 
                    ? double.tryParse(currentQuantityMatch.group(1)!) ?? 1.0
                    : 1.0;
                
                final scaleFactor = newQuantity / currentQuantity;
                
                // Generate new quantity display string using proper plural logic
                final quantityStr = newQuantity == newQuantity.toInt() ? newQuantity.toInt().toString() : newQuantity.toStringAsFixed(1);
                final isPlural = newQuantity != 1.0;

                // DEBUG: Let's see what display name data we have
                DebugLogger.info('🔍 DEBUG updateFoodQuantity for ${item.name}:');
                DebugLogger.debug('  - displayName: "${item.displayName}"');
                DebugLogger.debug('  - displayNamePlural: "${item.displayNamePlural}"');
                DebugLogger.debug('  - newQuantity: $newQuantity, isPlural: $isPlural');

                // Use appropriate display name based on NEW quantity (not old quantity)
                String displayName;
                if (isPlural && item.displayNamePlural?.isNotEmpty == true) {
                  displayName = item.displayNamePlural!;
                  DebugLogger.debug('  - Using plural: "$displayName"');
                } else if (item.displayName?.isNotEmpty == true) {
                  displayName = item.displayName!;
                  DebugLogger.debug('  - Using singular: "$displayName"');
                } else {
                  displayName = item.name;
                  DebugLogger.debug('  - Using fallback name: "$displayName"');
                }

                // SIMPLE: Always use format "<quantity> <display_name>"
                // Don't try to parse units - just use the display name based on quantity
                final newQuantityDisplay = '$quantityStr $displayName';
                DebugLogger.debug('  - Final display: "$newQuantityDisplay"');
                
                return FoodItemData(
                  id: item.id,
                  name: item.name,
                  quantity: newQuantityDisplay,
                  imageAddress: item.imageAddress,
                  instructions: item.instructions,
                  description: item.description,
                  displayName: item.displayName,
                  displayNamePlural: item.displayNamePlural,
                  nutritionalInfo: NutritionalInfo(
                    calories: (currentNutrition.calories! * scaleFactor).round(),
                    carbs: (currentNutrition.carbs! * scaleFactor).round(),
                    protein: (currentNutrition.protein! * scaleFactor).round(),
                    fat: (currentNutrition.fat! * scaleFactor).round(),
                    sodium: (currentNutrition.sodium! * scaleFactor).round(),
                    fluids: currentNutrition.fluids! * scaleFactor,
                  ),
                );
              }
            }
            return item;
          }).toList();
          
          return section.copyWith(
            foodItems: updatedItems,
          );
        }
        return section;
      }).toList();
      
      // Recalculate macro targets based on updated food items
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

      // Track item_quantity_changed event
      if (itemName != null && oldQuantity != null) {
        await _analytics.track('plan_item_quantity_changed', properties: {
          'plan_id': updatedPlan.id,
          'screen': 'plan_screen',
          'experiment_variant': 'auto_items_v1',
          'section': _mapCategoryToSection(category),
          'item_name': itemName,
          'old_qty': oldQuantity,
          'new_qty': newQuantity,
          'qty_unit': 'servings',
        });
      }

      // Update state without loading state to prevent UI rebuilds
      state = AsyncData(NutritionPlanState(plan: updatedPlan, isSaved: currentState.isSaved));
    } catch (error, stackTrace) {
      // Handle errors without changing to error state to prevent rebuilds
      _logger.error('Failed to update food quantity', error: error, stackTrace: stackTrace);
    }
  }

  /// Update the run date/time for the current plan
  Future<void> updateRunDateTime(String planId, DateTime runDateTime) async {
    final currentState = state.value;
    if (currentState == null || currentState.plan == null) return;

    final currentPlan = currentState.plan!;
    
    // Don't set loading state for this minor update
    try {
      // Update the plan with new run date/time
      final updatedPlan = currentPlan.copyWith(
        runDateTime: runDateTime,
        updatedAt: DateTime.now(),
      );
      
      // Save the updated plan to local storage
      await _saveUpdatedPlan(updatedPlan);
      
      // Update state to reflect the change
      state = AsyncData(NutritionPlanState(plan: updatedPlan, isSaved: currentState.isSaved));
      
      DebugLogger.info('✅ Updated run date/time for plan $planId');
    } catch (error, stackTrace) {
      _logger.error('Failed to update run date/time', error: error, stackTrace: stackTrace);
    }
  }

  String getErrorMessage(String? error) {
    return _contentService.getValue(ContentKeys.errorGeneric,
        defaultValue: error ?? 'Something went wrong. Please try again.');
  }

  /// Helper method to map category strings to analytics section names
  String _mapCategoryToSection(String category) {
    switch (category) {
      case 'before_run':
        return 'pre';
      case 'during_run':
        return 'during';
      case 'after_run':
        return 'post';
      default:
        return category;
    }
  }
}

/// Provider for current nutrition plan
@riverpod
NutritionPlan? currentNutritionPlan(Ref ref) {
  final controller = ref.watch(nutritionPlanControllerProvider);
  return controller.value?.plan;
}

/// Provider for nutrition recommendations
@riverpod
List<String> nutritionRecommendations(Ref ref) {
  final controller = ref.read(nutritionPlanControllerProvider.notifier);
  return controller.getRecommendations();
}
