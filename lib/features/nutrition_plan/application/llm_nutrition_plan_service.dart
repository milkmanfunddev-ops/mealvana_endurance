import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../domain/nutrition_plan.dart';
import '../domain/food_item_data.dart';
import '../domain/macro_targets.dart' as targets;
import 'food_data_transformation_service.dart';
import '../../auth/application/auth_service.dart';
import '../../auth/domain/user_preferences.dart';
import '../../../shared/domain/activity_type.dart';
import '../../../shared/services/app_external_deps.dart';
import '../../../shared/services/sentry/sentry_reporter.dart';
import '../../../shared/services/logging_service.dart';
import '../../activities/domain/brick_metadata.dart';

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
    String? activityId,
  }) async {
    try {
      // Get current user
      final user = await _authService.getCurrentUser();
      if (user == null) {
        throw Exception('No user found. Please complete onboarding first.');
      }

      // Get user's food preferences (fallback to safe defaults instead of throwing)
      final preferenceResult = await _resolveFoodPreferences(user.id);
      final foodPreferences = preferenceResult.preferences;

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

      // Calculate macro targets aligned with v3/v4 edge function algorithm
      // (Rachel-corrected formulas)
      final durationHours = (distanceMiles * paceMinutesPerMile) / 60.0;
      final durationMin = durationHours * 60.0;

      // Pre-run: Linear 1 g/kg per hour before, capped at 0.5-4.0 g/kg
      final carbPerKg = timeBeforeRunHours.clamp(0.5, 4.0);
      final preRunCarbs = (weightKg * carbPerKg).round();
      // Protein/fat/hydration/sodium based on meal type (matching edge function)
      final int preRunProtein;
      final int preRunFat;
      final int preRunWater;
      final int preRunSodium;
      if (timeBeforeRunHours >= 2.5) {
        // Full meal
        preRunProtein = (weightKg * 0.25).round();
        preRunFat = (weightKg * 0.4).round();
        preRunWater = (weightKg * 6.5).round();
        preRunSodium = 400;
      } else if (timeBeforeRunHours >= 1.0) {
        // Snack
        preRunProtein = (weightKg * 0.15).round();
        preRunFat = 5;
        preRunWater = (weightKg * 5.5).round();
        preRunSodium = 200;
      } else {
        // Top-up
        preRunProtein = 0;
        preRunFat = 0;
        preRunWater = (weightKg * 3.5).round();
        preRunSodium = 100;
      }

      // During-run: Duration-based bands with gut training multipliers (v3)
      final List<double> band;
      if (durationMin < 60) {
        band = [0, 30];
      } else if (durationMin < 90) {
        band = [30, 60];
      } else if (durationMin < 150) {
        band = [45, 60];
      } else if (durationMin < 240) {
        band = [60, 90];
      } else {
        band = [80, 100];
      }
      final gutMult = user.gutTraining.value == 'high' ? 1.2 :
                       user.gutTraining.value == 'low' ? 0.7 : 1.0;
      final scaledLow = band[0] * gutMult;
      final scaledHigh = band[1] * gutMult;
      // Use midpoint of scaled band as estimate (no intensity distribution available)
      final duringRunCarbsPerHour = ((scaledLow + scaledHigh) / 2).clamp(0, 70).round(); // 70 = run ceiling
      final duringRunCarbs = (duringRunCarbsPerHour * durationHours).round();
      final duringRunWater = (600 * durationHours).round(); // ~600ml/hour
      final duringRunSodium = (400 * durationHours).round(); // ~400mg/hour

      // Post-run: 1.0-1.2g carbs/kg (duration-dependent), 0.3g protein/kg
      final postRunCarbs = (weightKg * (durationHours > 2 ? 1.2 : 1.0)).round();
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
        'using_default_preferences': preferenceResult.usedDefaults,
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

      // Log edge function call for debugging (simplified logging for context)
      _logger.info('📤 Calling edge function generate-nutrition-plan', data: {
        'user_id': requestData['device_id'],
        'has_targets': requestData.containsKey('macro_targets'),
      });

      // Call the edge function
      final response = await _supabase.functions.invoke(
        'generate-nutrition-plan',
        body: requestData,
      );

      // Log response status
      _logger.info('📥 Edge function response', data: {
        'status': response.status,
        'has_data': response.data != null,
      });

      // Check if response indicates we should fallback
      if (response.status >= 400) {
        final data = response.data as Map<String, dynamic>?;
        _logger.warning('⚠️ Edge function error', data: {
          'status': response.status,
          'message': data?['message'],
          'fallback': data?['fallback_to_algorithm'],
        });
        if (data?['fallback_to_algorithm'] == true) {
          return null; // Indicates fallback needed
        }
        throw Exception(data?['message'] ?? 'Failed to generate nutrition plan');
      }

      // Parse the response
      final data = response.data as Map<String, dynamic>;
      _logger.api('Edge function response received',
        endpoint: '/generate-nutrition-plan',
        statusCode: response.status,
        responseData: data,
      );
      
      if (data['success'] != true) {
        _logger.warning('❌ Plan generation unsuccessful', data: {
          'success': data['success'],
          'message': data['message'],
          'fallback_requested': data['fallback_to_algorithm'],
        });
        if (data['fallback_to_algorithm'] == true) {
          return null; // Indicates fallback needed
        }
        throw Exception(data['message'] ?? 'Failed to generate nutrition plan');
      }

      _logger.info('✅ Plan generated successfully', data: {
        'has_plan': data.containsKey('plan'),
        'plan_type': data['plan_type'] ?? 'unknown',
      });

      _logger.nutritionPlan(
        'Converting LLM response to nutrition plan',
        planId: data['plan_id'] as String?,
      );

      // Convert the LLM response to our NutritionPlan format
      final nutritionPlan = await convertLLMResponseToPlan(
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
  /// Made public to allow reuse for algorithmic fallback responses
  ///
  /// [inputMacroTargets] - Optional MacroTargets from the Adjust Macros screen.
  /// When provided, these values are used directly for section targets instead of
  /// parsing from the edge function response (which may have field name mismatches).
  Future<NutritionPlan> convertLLMResponseToPlan(
    Map<String, dynamic> data,
    String userId, {
    String? activityId,
    targets.MacroTargets? inputMacroTargets,
    BrickMetadata? brickMetadata,
  }) async {
    // Check if this is a brick workout response
    // Primary: edge function returns activity_type: 'brick'
    // Fallback: inputMacroTargets or brickMetadata indicate brick
    final activityType = data['activity_type'] as String?;
    final isBrick = activityType == 'brick' ||
        inputMacroTargets?.activityType == ActivityType.brick ||
        brickMetadata != null;
    if (isBrick) {
      return _convertBrickResponseToPlan(data, userId, activityId: activityId, inputMacroTargets: inputMacroTargets, brickMetadata: brickMetadata);
    }

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

    // Use inputMacroTargets directly when available (from Adjust Macros screen)
    // This ensures the targets displayed match exactly what the user saw/edited
    // Fall back to parsing from response only when inputMacroTargets is not provided
    final preRunSodiumTarget = inputMacroTargets?.preRun.sodiumMg ??
        (preRun['sodium_mg'] as num? ?? 200).toDouble();
    final preRunFluidsTarget = inputMacroTargets?.preRun.fluidsMl ??
        (preRun['water_ml'] as num? ?? 500).toDouble();
    final preRunCarbsTarget = inputMacroTargets?.preRun.carbsG ?? preRunCarbs.toDouble();
    final preRunProteinTarget = inputMacroTargets?.preRun.proteinG ?? preRunProtein.toDouble();
    final preRunFatTarget = inputMacroTargets?.preRun.fatCapG ??
        (preRun['fat_g'] as num? ?? 5).toDouble();

    final duringRunSodiumTarget = inputMacroTargets?.duringRun.sodiumTotalMg ??
        (duringRun['sodium_total_mg'] as num? ?? 250).toDouble();
    final duringRunFluidsTarget = inputMacroTargets?.duringRun.fluidTotalMl ??
        (duringRun['water_total_ml'] as num? ?? 600).toDouble();
    final duringRunCarbsTarget = inputMacroTargets?.duringRun.carbTotalG ?? duringRunCarbs.toDouble();

    final postRunSodiumTarget = inputMacroTargets?.postRun.sodiumMg ??
        (postRun['sodium_mg'] as num? ?? 300).toDouble();
    final postRunFluidsTarget = inputMacroTargets?.postRun.fluidsMl ??
        (postRun['water_ml'] as num?)?.toDouble() ?? (duringRunFluidsTarget * 1.25);
    final postRunCarbsTarget = inputMacroTargets?.postRun.carbsG ?? postRunCarbs.toDouble();
    final postRunProteinTarget = inputMacroTargets?.postRun.proteinG ?? postRunProtein.toDouble();

    // Get activity type from macro targets, defaulting to running
    final planActivityType = inputMacroTargets?.activityType ?? ActivityType.running;

    // Create the nutrition plan
    final plan = NutritionPlan(
      id: planId,
      name: 'AI-Generated Nutrition Plan',
      totalCalories: totalCalories,
      activityId: activityId, // Link to calendar activity
      sections: [
        PlanSection(
          id: 'before-run',
          title: planActivityType.getSectionTitle('before'),
          subtitle: '${preRunCarbsTarget.round()}g carbs, ${preRunProteinTarget.round()}g protein, ${preRunSodiumTarget.round()}mg sodium',
          timing: 'Before',
          foodItems: beforeItems,
          carbsTarget: preRunCarbsTarget,
          proteinTarget: preRunProteinTarget,
          fatTarget: preRunFatTarget,
          sodiumTarget: preRunSodiumTarget,
          fluidsTarget: preRunFluidsTarget,
        ),
        PlanSection(
          id: 'during-run',
          title: planActivityType.getSectionTitle('during'),
          subtitle: 'Total: ${duringRunCarbsTarget.round()}g carbs, ${duringRunFluidsTarget.round()}ml fluids',
          timing: 'During',
          foodItems: duringItems,
          carbsTarget: duringRunCarbsTarget,
          proteinTarget: 0.0,
          fatTarget: 0.0,
          sodiumTarget: duringRunSodiumTarget,
          fluidsTarget: duringRunFluidsTarget,
        ),
        PlanSection(
          id: 'after-run',
          title: planActivityType.getSectionTitle('after'),
          subtitle: 'Recovery (${postRunCarbsTarget.round()}g carbs, ${postRunProteinTarget.round()}g protein)',
          timing: 'Within 30min',
          foodItems: afterItems,
          carbsTarget: postRunCarbsTarget,
          proteinTarget: postRunProteinTarget,
          fatTarget: (postRun['fat_g'] as num? ?? 10).toDouble(),
          sodiumTarget: postRunSodiumTarget,
          fluidsTarget: postRunFluidsTarget,
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
    String? activityId,
    BrickMetadata? brickMetadata,
  }) async {
    try {
      // Get current user
      final user = await _authService.getCurrentUser();
      if (user == null) {
        throw Exception('No user found. Please complete onboarding first.');
      }

      // Get user's food preferences (fallback to safe defaults instead of throwing)
      final preferenceResult = await _resolveFoodPreferences(user.id);
      final foodPreferences = preferenceResult.preferences;

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
          'activityType': macroTargets.activityType.name,
        },
      );

      // Check if this is a brick workout
      final isBrick = macroTargets.activityType == ActivityType.brick;

      // Prepare request data with macro_targets structure
      final Map<String, dynamic> requestData = {
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
        'using_default_preferences': preferenceResult.usedDefaults,
      };

      if (isBrick && macroTargets.brickSegments != null && macroTargets.brickSegments!.isNotEmpty) {
        // Brick workout - send activity_type and phases structure with actual segment data
        requestData['activity_type'] = 'brick';

        // Build during_segments with actual sport and segment info
        final segments = macroTargets.brickSegments!;
        final segmentCount = segments.length;

        // Calculate per-segment macro distribution based on duration
        final totalDurationMin = segments.fold<int>(0, (sum, s) => sum + s.durationMinutes);
        final duringSegmentsList = <Map<String, dynamic>>[];

        for (final segment in segments) {
          // Distribute macros proportionally based on segment duration
          final durationRatio = totalDurationMin > 0 ? segment.durationMinutes / totalDurationMin : 1.0 / segmentCount;

          duringSegmentsList.add({
            'segment_order': segment.order,
            'sport': segment.sport,
            'duration_minutes': segment.durationMinutes,
            'carbs_g': macroTargets.duringRun.carbTotalG * durationRatio,
            'sodium_mg': macroTargets.duringRun.sodiumTotalMg * durationRatio,
            'water_ml': macroTargets.duringRun.fluidTotalMl * durationRatio,
          });
        }

        // Build transitions (T1 between segments 1-2, T2 between segments 2-3)
        final transitionsList = <Map<String, dynamic>>[];
        for (int i = 0; i < segmentCount - 1; i++) {
          transitionsList.add({
            'transition_name': 'T${i + 1}',
            'carbs_g': 15, // Default transition carbs
            'sodium_mg': 100,
            'water_ml': 100,
          });
        }

        requestData['macro_targets'] = {
          'phases': {
            'before': {
              'carbs_g': macroTargets.preRun.carbsG,
              'protein_g': macroTargets.preRun.proteinG,
              'fat_g': macroTargets.preRun.fatCapG,
              'water_ml': macroTargets.preRun.fluidsMl,
              'sodium_mg': macroTargets.preRun.sodiumMg,
            },
            'during_segments': duringSegmentsList,
            'transitions': transitionsList,
            'after': {
              'carbs_g': macroTargets.postRun.carbsG,
              'protein_g': macroTargets.postRun.proteinG,
              'fat_g': 0.0,
              'water_ml': macroTargets.postRun.fluidsMl,
              'sodium_mg': macroTargets.postRun.sodiumMg,
            },
          },
        };

        _logger.info('📤 Brick request built with ${segments.length} segments: ${segments.map((s) => s.sport).join(", ")}');
      } else if (isBrick) {
        // Brick without segment data - fallback (shouldn't happen with proper flow)
        _logger.warning('⚠️ Brick workout without segment data - using fallback distribution');
        requestData['activity_type'] = 'brick';
        requestData['macro_targets'] = {
          'phases': {
            'before': {
              'carbs_g': macroTargets.preRun.carbsG,
              'protein_g': macroTargets.preRun.proteinG,
              'fat_g': macroTargets.preRun.fatCapG,
              'water_ml': macroTargets.preRun.fluidsMl,
              'sodium_mg': macroTargets.preRun.sodiumMg,
            },
            'during_segments': [
              {'segment_order': 1, 'sport': 'running', 'carbs_g': macroTargets.duringRun.carbTotalG / 2, 'sodium_mg': macroTargets.duringRun.sodiumTotalMg / 2, 'water_ml': macroTargets.duringRun.fluidTotalMl / 2},
              {'segment_order': 2, 'sport': 'cycling', 'carbs_g': macroTargets.duringRun.carbTotalG / 2, 'sodium_mg': macroTargets.duringRun.sodiumTotalMg / 2, 'water_ml': macroTargets.duringRun.fluidTotalMl / 2},
            ],
            'transitions': [{'transition_name': 'T1', 'carbs_g': 15, 'sodium_mg': 100, 'water_ml': 100}],
            'after': {
              'carbs_g': macroTargets.postRun.carbsG,
              'protein_g': macroTargets.postRun.proteinG,
              'fat_g': 0.0,
              'water_ml': macroTargets.postRun.fluidsMl,
              'sodium_mg': macroTargets.postRun.sodiumMg,
            },
          },
        };
      } else {
        // Single sport activity - use standard format
        requestData['macro_targets'] = {
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
        };
      }

      if (activityId != null) {
        requestData['activity_id'] = activityId;
      }

      // Log edge function call for debugging (simplified logging for context)
      _logger.info('📤 Calling edge function generate-nutrition-plan', data: {
        'user_id': requestData['device_id'],
        'has_targets': requestData.containsKey('macro_targets'),
      });

      // Call the edge function
      final response = await _supabase.functions.invoke(
        'generate-nutrition-plan',
        body: requestData,
      );

      // Log response status
      _logger.info('📥 Edge function response', data: {
        'status': response.status,
        'has_data': response.data != null,
      });

      // Check if response indicates we should fallback
      if (response.status >= 400) {
        final data = response.data as Map<String, dynamic>?;
        _logger.warning('⚠️ Edge function error', data: {
          'status': response.status,
          'message': data?['message'],
          'fallback': data?['fallback_to_algorithm'],
        });
        if (data?['fallback_to_algorithm'] == true) {
          return null; // Indicates fallback needed
        }
        throw Exception(data?['message'] ?? 'Failed to generate nutrition plan');
      }

      // Parse the response
      final data = response.data as Map<String, dynamic>;

      // Convert the LLM response to our NutritionPlan format
      // Pass the original macroTargets so section targets match exactly what user saw/edited
      final nutritionPlan = await convertLLMResponseToPlan(
        data,
        user.id,
        activityId: activityId,
        inputMacroTargets: macroTargets,
        brickMetadata: brickMetadata,
      );

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

  /// Convert brick workout response to NutritionPlan
  /// Handles the multi-phase structure: before, during_segments, transitions, after
  Future<NutritionPlan> _convertBrickResponseToPlan(
    Map<String, dynamic> data,
    String userId, {
    String? activityId,
    targets.MacroTargets? inputMacroTargets,
    BrickMetadata? brickMetadata,
  }) async {
    final planData = data['plan'] as Map<String, dynamic>;
    final detailedMessage = data['detailed_message'] as String? ?? 'Brick workout nutrition plan';
    final planId = data['plan_id'] as String? ??
                   'brick-plan-${DateTime.now().millisecondsSinceEpoch}';

    final sections = <PlanSection>[];

    // Parse per-segment and per-transition macro targets from the edge function response
    // The edge function passes through macro_targets.phases which contains:
    // - during_segments: [{segment_order, carbs_g, sodium_mg, water_ml}, ...]
    // - transitions: [{transition_name, carbs_g, sodium_mg, water_ml}, ...]
    final macroTargetsData = data['macro_targets'] as Map<String, dynamic>?;
    final phasesTargets = macroTargetsData?['phases'] as Map<String, dynamic>?;
    final segmentTargetsList = phasesTargets?['during_segments'] as List<dynamic>? ?? [];
    final transitionTargetsList = phasesTargets?['transitions'] as List<dynamic>? ?? [];

    // Build lookup maps for quick access by segment order / transition name
    final segmentTargetsMap = <int, Map<String, dynamic>>{};
    for (final seg in segmentTargetsList) {
      if (seg is Map<String, dynamic>) {
        final order = seg['segment_order'] as int?;
        if (order != null) {
          segmentTargetsMap[order] = seg;
        }
      }
    }

    final transitionTargetsMap = <String, Map<String, dynamic>>{};
    for (final trans in transitionTargetsList) {
      if (trans is Map<String, dynamic>) {
        final name = trans['transition_name'] as String?;
        if (name != null) {
          transitionTargetsMap[name] = trans;
        }
      }
    }

    // 1. Before section
    final beforeItems = <FoodItemData>[];
    final beforeList = planData['before'] as List<dynamic>? ?? [];
    for (final item in beforeList) {
      final itemMap = item as Map<String, dynamic>;
      final transformedFoodItem = await _transformationService.transformEdgeFunctionItem(itemMap);
      beforeItems.add(transformedFoodItem);
    }
    sections.add(PlanSection(
      id: 'before',
      title: 'Before Brick',
      subtitle: '1-4 hours before your workout',
      foodItems: beforeItems,
      carbsTarget: inputMacroTargets?.preRun.carbsG,
      proteinTarget: inputMacroTargets?.preRun.proteinG,
      sodiumTarget: inputMacroTargets?.preRun.sodiumMg,
      fluidsTarget: inputMacroTargets?.preRun.fluidsMl,
    ));

    // 2. During segments (keyed by segment order: "1", "2", "3")
    final duringSegmentsData = planData['during_segments'] as Map<String, dynamic>? ?? {};

    // Build sport name map from macroTargets.brickSegments if available,
    // falling back to brickMetadata.segments for sport name resolution
    final sportNameMap = <int, String>{};
    if (inputMacroTargets?.brickSegments != null) {
      for (final segment in inputMacroTargets!.brickSegments!) {
        sportNameMap[segment.order] = _getSportDisplayName(segment.sport);
      }
    }
    if (sportNameMap.isEmpty && brickMetadata != null) {
      for (final segment in brickMetadata.segments) {
        sportNameMap[segment.order] = _getSportDisplayName(segment.sport);
      }
    }

    int segmentIndex = 0;
    for (final entry in duringSegmentsData.entries) {
      final segmentOrder = entry.key;
      final segmentItems = entry.value as List<dynamic>? ?? [];

      final foodItems = <FoodItemData>[];
      for (final item in segmentItems) {
        final itemMap = item as Map<String, dynamic>;
        final transformedFoodItem = await _transformationService.transformEdgeFunctionItem(itemMap);
        foodItems.add(transformedFoodItem);
      }

      // Use actual sport name from segments, or fallback to generic name
      final orderInt = int.tryParse(segmentOrder) ?? (segmentIndex + 1);
      final sportName = sportNameMap[orderInt] ?? 'Segment $segmentOrder';

      // Look up per-segment macro targets from the edge function response
      final segTargets = segmentTargetsMap[orderInt];

      sections.add(PlanSection(
        id: 'during_segment_$segmentOrder',
        title: 'During $sportName',
        subtitle: null,
        foodItems: foodItems,
        carbsTarget: segTargets != null ? (segTargets['carbs_g'] as num?)?.toDouble() : null,
        sodiumTarget: segTargets != null ? (segTargets['sodium_mg'] as num?)?.toDouble() : null,
        fluidsTarget: segTargets != null ? (segTargets['water_ml'] as num?)?.toDouble() : null,
      ));

      // Add transition after each segment (except the last)
      final transitionsData = planData['transitions'] as Map<String, dynamic>? ?? {};
      final transitionKey = 'T${segmentIndex + 1}';
      if (transitionsData.containsKey(transitionKey)) {
        final transitionItems = transitionsData[transitionKey] as List<dynamic>? ?? [];
        final transitionFoodItems = <FoodItemData>[];
        for (final item in transitionItems) {
          final itemMap = item as Map<String, dynamic>;
          final transformedFoodItem = await _transformationService.transformEdgeFunctionItem(itemMap);
          transitionFoodItems.add(transformedFoodItem);
        }

        // Look up per-transition macro targets from the edge function response
        final transTargets = transitionTargetsMap[transitionKey];

        sections.add(PlanSection(
          id: transitionKey,
          title: 'Transition ($transitionKey)',
          subtitle: 'Quick refuel between segments',
          foodItems: transitionFoodItems,
          carbsTarget: transTargets != null ? (transTargets['carbs_g'] as num?)?.toDouble() : null,
          sodiumTarget: transTargets != null ? (transTargets['sodium_mg'] as num?)?.toDouble() : null,
          fluidsTarget: transTargets != null ? (transTargets['water_ml'] as num?)?.toDouble() : null,
        ));
      }

      segmentIndex++;
    }

    // 3. After section
    final afterItems = <FoodItemData>[];
    final afterList = planData['after'] as List<dynamic>? ?? [];
    for (final item in afterList) {
      final itemMap = item as Map<String, dynamic>;
      final transformedFoodItem = await _transformationService.transformEdgeFunctionItem(itemMap);
      afterItems.add(transformedFoodItem);
    }
    sections.add(PlanSection(
      id: 'after',
      title: 'After Brick',
      subtitle: 'Within 30-60 minutes post-workout',
      foodItems: afterItems,
      carbsTarget: inputMacroTargets?.postRun.carbsG,
      proteinTarget: inputMacroTargets?.postRun.proteinG,
      sodiumTarget: inputMacroTargets?.postRun.sodiumMg,
      fluidsTarget: inputMacroTargets?.postRun.fluidsMl,
    ));

    // Calculate totals from food items
    int totalCarbs = 0;
    int totalProtein = 0;
    int totalFat = 0;
    int totalSodium = 0;
    double totalFluids = 0;
    int totalCalories = 0;

    for (final section in sections) {
      for (final food in section.foodItems) {
        if (food.nutritionalInfo != null) {
          totalCarbs += food.nutritionalInfo!.carbs ?? 0;
          totalProtein += food.nutritionalInfo!.protein ?? 0;
          totalFat += food.nutritionalInfo!.fat ?? 0;
          totalSodium += food.nutritionalInfo!.sodium ?? 0;
          totalFluids += food.nutritionalInfo!.fluids ?? 0;
          totalCalories += food.nutritionalInfo!.calories ?? 0;
        }
      }
    }

    return NutritionPlan(
      id: planId,
      name: 'Brick Workout Nutrition Plan',
      sections: sections,
      totalCalories: totalCalories,
      notes: detailedMessage,
      activityId: activityId,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  /// Get display name for a sport type
  String _getSportDisplayName(String sport) {
    switch (sport) {
      case 'swimming':
        return 'Swim';
      case 'cycling':
        return 'Bike';
      case 'running':
        return 'Run';
      default:
        return sport.substring(0, 1).toUpperCase() + sport.substring(1);
    }
  }

  /// Resolve food preferences, falling back to a small, safe default set when none are saved.
  Future<_PreferenceResolutionResult> _resolveFoodPreferences(String userId) async {
    var preferences = await _authService.getFoodPreferences(userId);
    if (preferences != null && preferences.isNotEmpty) {
      return _PreferenceResolutionResult(preferences: preferences, usedDefaults: false);
    }

    // Use defaults instead of failing, and try to persist them for future calls.
    final defaults = _buildDefaultFoodPreferences();
    _logger.warning('No food preferences found. Using default set for LLM generation.',
      context: 'LLM_NUTRITION_PLAN',
      data: {'default_count': defaults.length},
    );

    try {
      final defaultLevels = defaults.map(
        (food, preference) =>
            MapEntry(food, sliderLevelForPreference(preference)),
      );
      await _authService.saveFoodPreferences(
        userId,
        defaults,
        sliderLevels: defaultLevels,
      );
      _logger.info('Default food preferences saved for user',
        context: 'LLM_NUTRITION_PLAN',
        data: {'user_id': userId, 'count': defaults.length},
      );
    } catch (e, stackTrace) {
      // Non-fatal: proceed with defaults even if persistence fails.
      _logger.warning('Failed to persist default food preferences',
        context: 'LLM_NUTRITION_PLAN',
        error: e,
        stackTrace: stackTrace,
      );
    }

    return _PreferenceResolutionResult(preferences: defaults, usedDefaults: true);
  }

  Map<String, FoodPreference> _buildDefaultFoodPreferences() {
    return {
      // Simple carbs
      'banana': FoodPreference.like,
      'bagel': FoodPreference.like,
      'oatmeal': FoodPreference.like,
      'energy gel': FoodPreference.like,
      'sports drink (carb + electrolytes)': FoodPreference.like,
      'chews': FoodPreference.willingToTry,
      // Hydration/electrolytes
      'water': FoodPreference.like,
      'electrolyte drink mix (electrolyte-only)': FoodPreference.like,
      'electrolyte tablet (electrolyte-only)': FoodPreference.willingToTry,
      // Recovery
      'chocolate milk': FoodPreference.like,
      'protein shake (ready-to-drink)': FoodPreference.like,
      'protein powder (whey)': FoodPreference.willingToTry,
      // Savory carb option
      'pretzels': FoodPreference.willingToTry,
    };
  }
}

class _PreferenceResolutionResult {
  const _PreferenceResolutionResult({
    required this.preferences,
    required this.usedDefaults,
  });

  final Map<String, FoodPreference> preferences;
  final bool usedDefaults;
}

/// Provider for LLMNutritionPlanService
final llmNutritionPlanServiceProvider = Provider<LLMNutritionPlanService>((ref) {
  return LLMNutritionPlanService(ref);
});
