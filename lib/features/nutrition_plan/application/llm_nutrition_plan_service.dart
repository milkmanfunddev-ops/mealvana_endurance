import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../domain/nutrition_plan.dart';
import '../domain/food_item_data.dart';
import '../domain/macro_targets.dart' as targets;
import '../../auth/application/auth_service.dart';
import '../../auth/domain/user_preferences.dart';
import '../../../shared/services/sentry_service.dart';

/// Service for generating nutrition plans using LLM (GPT-4o-mini)
class LLMNutritionPlanService {
  LLMNutritionPlanService(this.ref);
  final Ref ref;

  AuthService get _authService => ref.read(authServiceProvider);
  SentryService get _sentryService => ref.read(sentryServiceProvider);
  SupabaseClient get _supabase => Supabase.instance.client;

  /// Generate a nutrition plan using the LLM edge function
  Future<NutritionPlan?> generateLLMNutritionPlan({
    required double distanceMiles,
    required double paceMinutesPerMile,
    required double timeBeforeRunHours,
    String? sweatRate,
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

      // Prepare request data
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
      };

      // Call the edge function
      final response = await _supabase.functions.invoke(
        'generate-ai-nutrition-plan',
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
      
      if (data['success'] != true) {
        if (data['fallback_to_algorithm'] == true) {
          return null; // Indicates fallback needed
        }
        throw Exception(data['message'] ?? 'Failed to generate nutrition plan');
      }

      // Convert the LLM response to our NutritionPlan format
      final nutritionPlan = _convertLLMResponseToPlan(data, user.id);

      // Track success in Sentry
      _sentryService.addBreadcrumb(
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
      await _sentryService.reportCriticalError(
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
  NutritionPlan _convertLLMResponseToPlan(Map<String, dynamic> data, String userId) {
    final planData = data['plan'] as Map<String, dynamic>;
    final macroTargets = data['macro_targets'] as Map<String, dynamic>;
    final detailedMessage = data['detailed_message'] as String;
    final planId = data['plan_id'] as String? ?? 
                   'llm-plan-${DateTime.now().millisecondsSinceEpoch}';

    // Convert before section
    final beforeItems = (planData['before'] as List<dynamic>).map((item) {
      final itemMap = item as Map<String, dynamic>;
      return FoodItemData(
        id: itemMap['food_name'] as String, // Use food name as ID for now
        name: itemMap['food_name'] as String,
        quantity: itemMap['description'] as String, // LLM provides full description like "1 cup cooked oatmeal"
        iconPath: 'assets/images/${itemMap['food_name'].toLowerCase().replaceAll(' ', '_')}.png',
        description: itemMap['timing'] as String? ?? '',
        nutritionalInfo: NutritionalInfo(
          calories: (itemMap['calories'] as num).toInt(),
          carbs: (itemMap['carbs_grams'] as num).toInt(),
          protein: (itemMap['protein_grams'] as num).toInt(),
          fat: (itemMap['fat_grams'] as num).toInt(),
          sodium: (itemMap['sodium_mg'] as num?)?.toInt() ?? 0,
          fluids: (itemMap['fluids_ml'] as num?)?.toDouble() ?? 0.0,
        ),
      );
    }).toList();

    // Convert during section
    final duringItems = (planData['during'] as List<dynamic>).map((item) {
      final itemMap = item as Map<String, dynamic>;
      return FoodItemData(
        id: itemMap['food_name'] as String,
        name: itemMap['food_name'] as String,
        quantity: itemMap['description'] as String,
        iconPath: 'assets/images/${itemMap['food_name'].toLowerCase().replaceAll(' ', '_')}.png',
        description: itemMap['timing'] as String? ?? '',
        nutritionalInfo: NutritionalInfo(
          calories: (itemMap['calories'] as num).toInt(),
          carbs: (itemMap['carbs_grams'] as num).toInt(),
          protein: (itemMap['protein_grams'] as num).toInt(),
          fat: (itemMap['fat_grams'] as num).toInt(),
          sodium: (itemMap['sodium_mg'] as num?)?.toInt() ?? 0,
          fluids: (itemMap['fluids_ml'] as num?)?.toDouble() ?? 0.0,
        ),
      );
    }).toList();

    // Convert after section
    final afterItems = (planData['after'] as List<dynamic>).map((item) {
      final itemMap = item as Map<String, dynamic>;
      return FoodItemData(
        id: itemMap['food_name'] as String,
        name: itemMap['food_name'] as String,
        quantity: itemMap['description'] as String,
        iconPath: 'assets/images/${itemMap['food_name'].toLowerCase().replaceAll(' ', '_')}.png',
        description: itemMap['timing'] as String? ?? '',
        nutritionalInfo: NutritionalInfo(
          calories: (itemMap['calories'] as num).toInt(),
          carbs: (itemMap['carbs_grams'] as num).toInt(),
          protein: (itemMap['protein_grams'] as num).toInt(),
          fat: (itemMap['fat_grams'] as num).toInt(),
          sodium: (itemMap['sodium_mg'] as num?)?.toInt() ?? 0,
          fluids: (itemMap['fluids_ml'] as num?)?.toDouble() ?? 0.0,
        ),
      );
    }).toList();

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

    // Create the nutrition plan
    return NutritionPlan(
      id: planId,
      name: 'AI-Generated Nutrition Plan',
      totalCalories: totalCalories,
      sections: [
        PlanSection(
          id: 'before-run',
          title: 'Before Run',
          subtitle: 'Pre-run fueling (${preRunCarbs}g carbs, ${preRunProtein}g protein)',
          timing: 'Before',
          foodItems: beforeItems,
        ),
        PlanSection(
          id: 'during-run',
          title: 'During Run',
          subtitle: 'Total: ${duringRunCarbs}g carbs, ${(duringRun['water_total_ml'] as num? ?? 0).toInt()}ml fluids',
          timing: 'During',
          foodItems: duringItems,
        ),
        PlanSection(
          id: 'after-run',
          title: 'After Run',
          subtitle: 'Recovery (${postRunCarbs}g carbs, ${postRunProtein}g protein)',
          timing: 'Within 30min',
          foodItems: afterItems,
        ),
      ],
      macroTargets: MacroTargets(
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
  }

  /// Generate nutrition plan from adjusted macro targets
  Future<NutritionPlan?> generateLLMNutritionPlanFromMacros({
    required targets.MacroTargets macroTargets,
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

      // 🚨 CRITICAL DEBUG: Log the exact macro targets being sent to edge function
      print('🎯 DEBUG: MACRO TARGETS BEING SENT TO EDGE FUNCTION:');
      print('  Pre-run: ${macroTargets.preRun.carbsG}g carbs, ${macroTargets.preRun.proteinG}g protein');
      print('  During-run: ${macroTargets.duringRun.carbTotalG}g carbs total');
      print('  Post-run: ${macroTargets.postRun.carbsG}g carbs, ${macroTargets.postRun.proteinG}g protein');
      print('  TOTAL EXPECTED CARBS: ${macroTargets.preRun.carbsG + macroTargets.duringRun.carbTotalG + macroTargets.postRun.carbsG}g');

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

      // Call the edge function
      final response = await _supabase.functions.invoke(
        'generate-ai-nutrition-plan',
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
      final nutritionPlan = _convertLLMResponseToPlan(data, user.id);

      // Track success in Sentry
      _sentryService.addBreadcrumb(
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
      await _sentryService.reportCriticalError(
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