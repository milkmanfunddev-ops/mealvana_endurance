import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../domain/nutrition_plan.dart';
import '../domain/food_item_data.dart';
import '../domain/macro_targets.dart' as targets;
import 'food_data_transformation_service.dart';
import '../../auth/application/auth_service.dart';
import '../../auth/domain/user_preferences.dart';
import '../../../shared/services/app_external_deps.dart';
import '../../../shared/services/sentry/sentry_reporter.dart';
import '../../../shared/services/logging_service.dart';

/// Service for generating nutrition plans using LLM (GPT-4o-mini)
class LLMNutritionPlanService {
  LLMNutritionPlanService(this.ref);
  final Ref ref;

  AuthService get _authService => ref.read(authServiceProvider);
  SentryReporter get _sentry => ref.read(appExternalDepsProvider).sentry;
  FoodDataTransformationService get _transformationService => ref.read(foodDataTransformationServiceProvider);
  SupabaseClient get _supabase => ref.read(appExternalDepsProvider).supabaseClient;
  AppLogger get _logger => ref.read(appExternalDepsProvider).logger;

  /// Generate a nutrition plan using the LLM edge function
  Future<NutritionPlan?> generateLLMNutritionPlan({
    required double distanceMiles,
    required double paceMinutesPerMile,
    required double timeBeforeRunHours,
    String? sweatRate,
    int? activityId,
  }) async {
    try {
      // Get current user
      final user = await _authService.getCurrentUser();
      if (user == null) {
        throw Exception('No user found. Please complete onboarding first.');
      }

      // Get user's food preferences
      final foodPreferences = await _authService.getFoodPreferences(user.id);
      if (foodPreferences == null || foodPreferences.isEmpty) {
        throw Exception('No food preferences found. Please set your food preferences first.');
      }

      // Categorize foods by preference
      final likedFoods = <String>[];
      final willingToTryFoods = <String>[];
      final dislikedFoods = <String>[];

      foodPreferences.forEach((foodName, preference) {
        switch (preference) {
          case FoodPreference.like:
            likedFoods.add(foodName);
            break;
          case FoodPreference.willingToTry:
            willingToTryFoods.add(foodName);
            break;
          case FoodPreference.dislike:
            dislikedFoods.add(foodName);
            break;
        }
      });

      // Calculate user age
      final age = DateTime.now().year - user.birthday.year;

      // Convert units
      final weightKg = user.weightPounds * 0.453592;
      final heightCm = user.totalHeightInches * 2.54;

      // Calculate macro targets using the same logic as the algorithm would
      // These are estimates based on standard sports nutrition guidelines
      final durationHours = (distanceMiles * paceMinutesPerMile) / 60.0;
      
      // Pre-run: 1-4g carbs/kg body weight (depending on timing)
      final preRunCarbs = (weightKg * 2.0).round(); // 2g/kg as baseline
      final preRunProtein = (weightKg * 0.25).round(); // ~0.25g/kg
      final preRunFat = (preRunCarbs * 0.1).round(); // ~10% of carb calories as fat
      final preRunWater = (weightKg * 5).round(); // 5ml/kg
      final preRunSodium = 300; // baseline sodium
      
      // During-run: 30-60g carbs/hour
      final duringRunCarbsPerHour = user.gutTraining.value == 'high' ? 60 : 
                                    user.gutTraining.value == 'low' ? 30 : 45;
      final duringRunCarbs = (duringRunCarbsPerHour * durationHours).round();
      final duringRunWater = (600 * durationHours).round(); // ~600ml/hour
      final duringRunSodium = (400 * durationHours).round(); // ~400mg/hour
      
      // Post-run: 1.0-1.2g carbs/kg, 0.3g protein/kg
      final postRunCarbs = (weightKg * 1.0).round();
      final postRunProtein = (weightKg * 0.3).round();
      final postRunWater = (duringRunWater * 1.25).round(); // 125% of sweat loss
      final postRunSodium = 500; // baseline recovery sodium

      // Prepare request data with calculated macro targets
      final requestData = {
        'device_id': user.id,
        'age': age,
        'gender': user.gender.value,
        'weight_kg': weightKg,
        'height_cm': heightCm,
        'gut_training_level': user.gutTraining.value,
        'distance_miles': distanceMiles,
        'pace_minutes_per_mile': paceMinutesPerMile,
        'time_before_run_hours': timeBeforeRunHours,
        'liked_foods': likedFoods,
        'willing_to_try_foods': willingToTryFoods,
        'disliked_foods': dislikedFoods,
        if (sweatRate != null) 'sweat_rate': sweatRate,
        // Include macro targets for proper AI generation
        'macro_targets': {
          'pre_run': {
            'carbs_g': preRunCarbs,
            'protein_g': preRunProtein,
            'fat_g': preRunFat,
            'water_ml': preRunWater,
            'sodium_mg': preRunSodium,
          },
          'during_run': {
            'carbs_total_g': duringRunCarbs,
            'sodium_total_mg': duringRunSodium,
            'water_total_ml': duringRunWater,
          },
          'post_run': {
            'carbs_g': postRunCarbs,
            'protein_g': postRunProtein,
            'fat_g': 0, // Post-run typically avoids fat
            'water_ml': postRunWater,
            'sodium_mg': postRunSodium,
          },
        },
      };

      if (activityId != null) {
        requestData['activity_id'] = activityId;
      }

      // Call the edge function
      final response = await _supabase.functions.invoke(
        'generate-nutrition-plan',
        body: requestData,
      );

      // Check if response indicates we should fallback
      if (response.status >= 400) {
        final data = response.data as Map<String, dynamic>?;
        if (data?['fallback_to_algorithm'] == true) {
          return null; // Indicates fallback needed
        }
        throw Exception(data?['message'] ?? 'Failed to generate nutrition plan');
      }

      // Parse the response
      final data = response.data as Map<String, dynamic>;
      _logger.api('Edge function response received',
        endpoint: '/generate-ai-nutrition-plan',
        statusCode: response.status,
        responseData: data,
      );
      
      if (data['success'] != true) {
        if (data['fallback_to_algorithm'] == true) {
          return null; // Indicates fallback needed
        }
        throw Exception(data['message'] ?? 'Failed to generate nutrition plan');
      }

      _logger.nutritionPlan(
        'Converting LLM response to nutrition plan',
        planId: data['plan_id'] as String?,
      );

      // Convert the LLM response to our NutritionPlan format
      final nutritionPlan = await _convertLLMResponseToPlan(
        data,
        user.id,
        activityId: activityId,
      );

      _logger.nutritionPlan('Nutrition plan conversion completed',
        planId: nutritionPlan.id,
        data: {
          'sectionsCount': nutritionPlan.sections.length,
          'totalFoodItems': nutritionPlan.sections.fold<int>(0, (sum, section) => sum + section.foodItems.length),
          'sectionDetails': nutritionPlan.sections.map((section) => {
            'title': section.title,
            'itemCount': section.foodItems.length,
          }).toList(),
        },
      );

      // Track success in Sentry
      _sentry.addBreadcrumb(
        message: 'LLM nutrition plan generated successfully',
        category: 'llm_nutrition',
        data: {
          'plan_id': data['plan_id'],
          'device_id': user.id,
        },
      );

      return nutritionPlan;
    } catch (e, stackTrace) {
      // Report to Sentry
      await _sentry.reportCriticalError(
        e,
        stackTrace: stackTrace,
        context: 'llm_nutrition_plan_generation',
        tags: {
          'error_type': 'llm_generation_failure',
          'operation': 'generate_llm_nutrition_plan',
        },
      );

      // Return null to indicate fallback to algorithm
      return null;
    }
  }



  /// Convert LLM response format to our NutritionPlan domain model
  Future<NutritionPlan> _convertLLMResponseToPlan(
    Map<String, dynamic> data,
    String userId, {
    int? activityId,
  }) async {
    final planData = data['plan'] as Map<String, dynamic>;
    final macroTargets = data['macro_targets'] as Map<String, dynamic>;
    final detailedMessage = data['detailed_message'] as String? ?? 'AI-generated nutrition plan';
    final planId = data['plan_id'] as String? ?? 
                   'llm-plan-${DateTime.now().millisecondsSinceEpoch}';
                   
    final beforeItems = <FoodItemData>[];
    for (final item in planData['before'] as List<dynamic>) {
      final itemMap = item as Map<String, dynamic>;

      // Use transformation service for proper nutrition calculation
      final transformedFoodItem = await _transformationService.transformEdgeFunctionItem(itemMap);
      beforeItems.add(transformedFoodItem);
    }
    
    // Validation logging: Track sodium and fluids for before section
    final beforeSodiumTotal = beforeItems.fold<int>(0, (sum, item) => sum + (item.nutritionalInfo?.sodium ?? 0));
    final beforeFluidsTotal = beforeItems.fold<double>(0.0, (sum, item) => sum + (item.nutritionalInfo?.fluids ?? 0.0));
    
    final duringItems = <FoodItemData>[];
    for (final item in planData['during'] as List<dynamic>) {
      final itemMap = item as Map<String, dynamic>;

      // Use transformation service for proper nutrition calculation
      final transformedFoodItem = await _transformationService.transformEdgeFunctionItem(itemMap);
      duringItems.add(transformedFoodItem);
    }
    
    // Validation logging: Track sodium and fluids for during section
    final duringSodiumTotal = duringItems.fold<int>(0, (sum, item) => sum + (item.nutritionalInfo?.sodium ?? 0));
    final duringFluidsTotal = duringItems.fold<double>(0.0, (sum, item) => sum + (item.nutritionalInfo?.fluids ?? 0.0));
    
    final afterItems = <FoodItemData>[];
    for (final item in planData['after'] as List<dynamic>) {
      final itemMap = item as Map<String, dynamic>;

      // Use transformation service for proper nutrition calculation
      final transformedFoodItem = await _transformationService.transformEdgeFunctionItem(itemMap);
      afterItems.add(transformedFoodItem);
    }
    
    // Validation logging: Track sodium and fluids for after section
    final afterSodiumTotal = afterItems.fold<int>(0, (sum, item) => sum + (item.nutritionalInfo?.sodium ?? 0));
    final afterFluidsTotal = afterItems.fold<double>(0.0, (sum, item) => sum + (item.nutritionalInfo?.fluids ?? 0.0));
    

    // Calculate total macros from phase targets (using correct field names)
    final preRun = macroTargets['pre_run'] as Map<String, dynamic>;
    final duringRun = macroTargets['during_run'] as Map<String, dynamic>;
    final postRun = macroTargets['post_run'] as Map<String, dynamic>;

    // Use the correct field names that match the edge function response
    final preRunCarbs = (preRun['carbs_g'] as num).toInt();
    final preRunProtein = (preRun['protein_g'] as num).toInt();
    final preRunFat = (preRun['fat_g'] as num).toInt();
    
    final postRunCarbs = (postRun['carbs_g'] as num).toInt();
    final postRunProtein = (postRun['protein_g'] as num).toInt();
    final postRunFat = (postRun['fat_g'] as num).toInt();
    
    final duringRunCarbs = (duringRun['carbs_total_g'] as num).toInt();
    
    // Calculate totals (estimate calories if not provided)
    final totalCarbs = preRunCarbs + duringRunCarbs + postRunCarbs;
    final totalProtein = preRunProtein + postRunProtein;
    final totalFat = preRunFat + postRunFat;
    final totalCalories = (totalCarbs * 4) + (totalProtein * 4) + (totalFat * 9); // Rough calorie calculation

    // Extract macro target values for sodium and fluids
    final preRunSodium = (preRun['sodium_mg'] as num?)?.toInt() ?? 0;
    final duringRunSodium = (duringRun['sodium_total_mg'] as num?)?.toInt() ?? 0;
    final postRunSodium = (postRun['sodium_mg'] as num?)?.toInt() ?? 0;
    final totalTargetSodium = preRunSodium + duringRunSodium + postRunSodium;
    
    final preRunFluids = (preRun['water_ml'] as num?)?.toDouble() ?? 0.0;
    final duringRunFluids = (duringRun['water_total_ml'] as num?)?.toDouble() ?? 0.0;
    final postRunFluids = (postRun['water_ml'] as num?)?.toDouble() ?? 0.0;
    final totalTargetFluids = preRunFluids + duringRunFluids + postRunFluids;
    
    // Calculate actual food item totals across all phases
    final totalFoodItemSodium = beforeSodiumTotal + duringSodiumTotal + afterSodiumTotal;
    final totalFoodItemFluids = beforeFluidsTotal + duringFluidsTotal + afterFluidsTotal;
    final totalFoodItemCarbs = beforeItems.fold<int>(0, (sum, item) => sum + (item.nutritionalInfo?.carbs ?? 0)) +
                              duringItems.fold<int>(0, (sum, item) => sum + (item.nutritionalInfo?.carbs ?? 0)) +
                              afterItems.fold<int>(0, (sum, item) => sum + (item.nutritionalInfo?.carbs ?? 0));
    
    // CRITICAL VALIDATION: Log the discrepancy between macro targets and food item totals
    _logger.error('LLM Response Validation: Food Items vs Macro Targets Comparison',
      context: 'LLMNutritionPlanService',
      data: {
        'macro_targets': {
          'total_sodium_mg': totalTargetSodium,
          'total_fluids_ml': totalTargetFluids,
          'total_carbs_g': totalCarbs,
        },
        'food_items_actual': {
          'total_sodium_mg': totalFoodItemSodium,
          'total_fluids_ml': totalFoodItemFluids,
          'total_carbs_g': totalFoodItemCarbs,
        },
        'discrepancies': {
          'sodium_difference_mg': totalFoodItemSodium - totalTargetSodium,
          'fluids_difference_ml': totalFoodItemFluids - totalTargetFluids,
          'carbs_difference_g': totalFoodItemCarbs - totalCarbs,
        },
        'percentage_match': {
          'sodium_percentage': totalTargetSodium > 0 ? (totalFoodItemSodium / totalTargetSodium * 100).round() : 0,
          'fluids_percentage': totalTargetFluids > 0 ? (totalFoodItemFluids / totalTargetFluids * 100).round() : 0,
          'carbs_percentage': totalCarbs > 0 ? (totalFoodItemCarbs / totalCarbs * 100).round() : 0,
        }
      },
    );

    // Create the nutrition plan
    final plan = NutritionPlan(
      id: planId,
      name: 'AI-Generated Nutrition Plan',
      totalCalories: totalCalories,
      activityId: activityId, // Link to calendar activity
      sections: [
        PlanSection(
          id: 'before-run',
          title: 'Before Run',
          subtitle: '${preRunCarbs}g carbs, ${preRunProtein}g protein, ${preRunSodium}g sodium',
          timing: 'Before',
          foodItems: beforeItems,
          carbsTarget: preRunCarbs.toDouble(),
          proteinTarget: preRunProtein.toDouble(),
          fatTarget: (preRun['fat_total_g'] as num? ?? 5).toDouble(),
          sodiumTarget: (preRun['sodium_total_mg'] as num? ?? 200).toDouble(),
          fluidsTarget: (preRun['water_total_ml'] as num? ?? 500).toDouble(),
        ),
        PlanSection(
          id: 'during-run',
          title: 'During Run',
          subtitle: 'Total: ${duringRunCarbs}g carbs, ${(duringRun['water_total_ml'] as num? ?? 0).toInt()}ml fluids',
          timing: 'During',
          foodItems: duringItems,
          carbsTarget: duringRunCarbs.toDouble(),
          proteinTarget: 0.0,
          fatTarget: 0.0,
          sodiumTarget: (duringRun['sodium_total_mg'] as num? ?? 250).toDouble(),
          fluidsTarget: (duringRun['water_total_ml'] as num? ?? 600).toDouble(),
        ),
        PlanSection(
          id: 'after-run',
          title: 'After Run',
          subtitle: 'Recovery (${postRunCarbs}g carbs, ${postRunProtein}g protein)',
          timing: 'Within 30min',
          foodItems: afterItems,
          carbsTarget: postRunCarbs.toDouble(),
          proteinTarget: postRunProtein.toDouble(),
          fatTarget: (postRun['fat_total_g'] as num? ?? 10).toDouble(),
          sodiumTarget: (postRun['sodium_total_mg'] as num? ?? 300).toDouble(),
          fluidsTarget: ((duringRun['water_total_ml'] as num? ?? 600) * 1.25).toDouble(),
        ),
      ],
      macroTargets: PlanMacroSummary(
        calories: totalCalories,
        carbs: totalCarbs,
        protein: totalProtein,
        fat: totalFat,
        sodium: (duringRun['sodium_total_mg'] as num?)?.toInt(),
        fluids: (duringRun['water_total_ml'] as num?)?.toInt(),
        // Store phase-specific data in ranges for display (using adjusted values)
        carbsRange: 'Pre: ${preRunCarbs}g | During: ${duringRunCarbs}g total | Post: ${postRunCarbs}g',
        proteinRange: 'Pre: ${preRunProtein}g | Post: ${postRunProtein}g',
        fatRange: 'Pre: ${preRunFat}g | Post: ${postRunFat}g',
      ),
      notes: detailedMessage, // Store only the detailed message
      createdAt: DateTime.now(),
    );
    
    _logger.nutritionPlan('Nutrition plan creation completed',
      planId: plan.id,
      data: {
        'totalFoodItems': beforeItems.length + duringItems.length + afterItems.length,
        'beforeItems': beforeItems.length,
        'duringItems': duringItems.length,
        'afterItems': afterItems.length,
      },
    );
    
    return plan;
  }

  /// Generate nutrition plan from adjusted macro targets
  Future<NutritionPlan?> generateLLMNutritionPlanFromMacros({
    required targets.MacroTargets macroTargets,
    int? activityId,
  }) async {
    try {
      // Get current user
      final user = await _authService.getCurrentUser();
      if (user == null) {
        throw Exception('No user found. Please complete onboarding first.');
      }

      // Get user's food preferences
      final foodPreferences = await _authService.getFoodPreferences(user.id);
      if (foodPreferences == null || foodPreferences.isEmpty) {
        throw Exception('No food preferences found. Please set your food preferences first.');
      }

      // Categorize foods by preference
      final likedFoods = <String>[];
      final willingToTryFoods = <String>[];
      final dislikedFoods = <String>[];

      foodPreferences.forEach((foodName, preference) {
        switch (preference) {
          case FoodPreference.like:
            likedFoods.add(foodName);
            break;
          case FoodPreference.willingToTry:
            willingToTryFoods.add(foodName);
            break;
          case FoodPreference.dislike:
            dislikedFoods.add(foodName);
            break;
        }
      });

      // Calculate user age
      final age = DateTime.now().year - user.birthday.year;

      // Convert units
      final weightKg = user.weightPounds * 0.453592;
      final heightCm = user.totalHeightInches * 2.54;

      _logger.nutritionPlan('Macro targets prepared for edge function',
        data: {
          'preRunCarbs': macroTargets.preRun.carbsG,
          'preRunProtein': macroTargets.preRun.proteinG,
          'duringRunCarbsTotal': macroTargets.duringRun.carbTotalG,
          'postRunCarbs': macroTargets.postRun.carbsG,
          'postRunProtein': macroTargets.postRun.proteinG,
          'totalExpectedCarbs': macroTargets.preRun.carbsG + macroTargets.duringRun.carbTotalG + macroTargets.postRun.carbsG,
        },
      );

      // Prepare request data with macro_targets structure
      final requestData = {
        'device_id': user.id,
        'age': age,
        'gender': user.gender.value,
        'weight_kg': weightKg,
        'height_cm': heightCm,
        'gut_training_level': user.gutTraining.value,
        'distance_miles': macroTargets.metrics.distanceMi,
        'pace_minutes_per_mile': macroTargets.metrics.paceMinPerMile,
        'time_before_run_hours': 2.0, // Default value, could be made configurable
        'liked_foods': likedFoods,
        'willing_to_try_foods': willingToTryFoods,
        'disliked_foods': dislikedFoods,
        'macro_targets': {
          'pre_run': {
            'carbs_g': macroTargets.preRun.carbsG,
            'protein_g': macroTargets.preRun.proteinG,
            'fat_g': macroTargets.preRun.fatCapG,
            'water_ml': macroTargets.preRun.fluidsMl,
            'sodium_mg': macroTargets.preRun.sodiumMg,
          },
          'during_run': {
            'carbs_total_g': macroTargets.duringRun.carbTotalG,
            'sodium_total_mg': macroTargets.duringRun.sodiumTotalMg,
            'water_total_ml': macroTargets.duringRun.fluidTotalMl,
          },
          'post_run': {
            'carbs_g': macroTargets.postRun.carbsG,
            'protein_g': macroTargets.postRun.proteinG,
            'fat_g': 0.0, // Post-run doesn't have fat in the current model
            'water_ml': macroTargets.postRun.fluidsMl,
            'sodium_mg': macroTargets.postRun.sodiumMg,
          },
        },
      };

      if (activityId != null) {
        requestData['activity_id'] = activityId;
      }

      // Call the edge function
      final response = await _supabase.functions.invoke(
        'generate-nutrition-plan',
        body: requestData,
      );

      // Check if response indicates we should fallback
      if (response.status >= 400) {
        final data = response.data as Map<String, dynamic>?;
        if (data?['fallback_to_algorithm'] == true) {
          return null; // Indicates fallback needed
        }
        throw Exception(data?['message'] ?? 'Failed to generate nutrition plan');
      }

      // Parse the response
      final data = response.data as Map<String, dynamic>;

      // Convert the LLM response to our NutritionPlan format
      final nutritionPlan = await _convertLLMResponseToPlan(data, user.id, activityId: activityId);

      // Track success in Sentry
      _sentry.addBreadcrumb(
        message: 'LLM nutrition plan generated from adjusted macros successfully',
        category: 'llm_nutrition_adjusted',
        data: {
          'plan_id': data['plan_id'],
          'device_id': user.id,
          'pre_run_carbs': macroTargets.preRun.carbsG,
          'during_run_carbs': macroTargets.duringRun.carbTotalG,
          'post_run_carbs': macroTargets.postRun.carbsG,
        },
      );

      return nutritionPlan;
    } catch (e, stackTrace) {
      // Report to Sentry
      await _sentry.reportCriticalError(
        e,
        stackTrace: stackTrace,
        context: 'llm_nutrition_plan_from_macros_generation',
        tags: {
          'error_type': 'llm_generation_from_macros_failure',
          'operation': 'generate_llm_nutrition_plan_from_macros',
        },
      );

      // Return null to indicate fallback to algorithm
      return null;
    }
  }
}

/// Provider for LLMNutritionPlanService
final llmNutritionPlanServiceProvider = Provider<LLMNutritionPlanService>((ref) {
  return LLMNutritionPlanService(ref);
});
