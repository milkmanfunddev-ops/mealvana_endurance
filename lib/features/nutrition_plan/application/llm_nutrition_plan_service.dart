import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../domain/nutrition_plan.dart';
import '../domain/food_item_data.dart';
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
    final overviewMessage = data['overview_message'] as String;
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
        ),
      );
    }).toList();

    // Calculate total macros from phase targets
    final preRun = macroTargets['pre_run'] as Map<String, dynamic>;
    final duringRun = macroTargets['during_run'] as Map<String, dynamic>;
    final postRun = macroTargets['post_run'] as Map<String, dynamic>;

    final totalCalories = (preRun['calories'] as num).toInt() + (postRun['calories'] as num).toInt();
    final totalCarbs = (preRun['carbs_grams'] as num).toInt() + (postRun['carbs_grams'] as num).toInt();
    final totalProtein = (preRun['protein_grams'] as num).toInt() + (postRun['protein_grams'] as num).toInt();
    final totalFat = (preRun['fat_grams'] as num).toInt() + (postRun['fat_grams'] as num).toInt();

    // Create the nutrition plan
    return NutritionPlan(
      id: planId,
      name: 'AI-Generated Nutrition Plan',
      totalCalories: totalCalories,
      sections: [
        PlanSection(
          id: 'before-run',
          title: 'Before Run',
          subtitle: 'Pre-run fueling (${preRun['calories']} cal, ${preRun['carbs_grams']}g carbs)',
          timing: 'Before',
          foodItems: beforeItems,
        ),
        PlanSection(
          id: 'during-run',
          title: 'During Run',
          subtitle: 'Per hour: ${duringRun['carbs_per_hour']}g carbs, ${duringRun['fluids_per_hour_ml']}ml fluids',
          timing: 'During',
          foodItems: duringItems,
        ),
        PlanSection(
          id: 'after-run',
          title: 'After Run',
          subtitle: 'Recovery (${postRun['calories']} cal, ${postRun['protein_grams']}g protein)',
          timing: 'Within 30min',
          foodItems: afterItems,
        ),
      ],
      macroTargets: MacroTargets(
        calories: totalCalories,
        carbs: totalCarbs,
        protein: totalProtein,
        fat: totalFat,
        sodium: (duringRun['sodium_per_hour_mg'] as num?)?.toInt(),
        fluids: (duringRun['fluids_per_hour_ml'] as num?)?.toInt(),
        // Store phase-specific data in ranges for display
        carbsRange: 'Pre: ${preRun['carbs_grams']}g | During: ${duringRun['carbs_per_hour']}g/hr | Post: ${postRun['carbs_grams']}g',
        proteinRange: 'Pre: ${preRun['protein_grams']}g | Post: ${postRun['protein_grams']}g',
        fatRange: 'Pre: ${preRun['fat_grams']}g | Post: ${postRun['fat_grams']}g',
      ),
      notes: '$overviewMessage|||$detailedMessage', // Store both messages with separator
      createdAt: DateTime.now(),
    );
  }
}

/// Provider for LLMNutritionPlanService
final llmNutritionPlanServiceProvider = Provider<LLMNutritionPlanService>((ref) {
  return LLMNutritionPlanService(ref);
});