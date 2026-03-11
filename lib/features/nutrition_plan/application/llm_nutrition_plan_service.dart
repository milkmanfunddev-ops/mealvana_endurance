import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../domain/nutrition_plan.dart';
import '../domain/macro_targets.dart' as targets;
import 'llm_response_parser.dart';
import 'food_preference_resolver.dart';
import '../../auth/application/auth_service.dart';
import '../../auth/data/user_repository.dart';
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
  LLMResponseParser get _responseParser => ref.read(llmResponseParserProvider);
  FoodPreferenceResolver get _preferenceResolver => ref.read(foodPreferenceResolverProvider);
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
      final preferenceResult = await _preferenceResolver.resolveFoodPreferences(user.id);
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
      final nutritionPlan = await _responseParser.convertLLMResponseToPlan(
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


  /// Generate nutrition plan from adjusted macro targets
  Future<NutritionPlan?> generateLLMNutritionPlanFromMacros({
    required targets.MacroTargets macroTargets,
    String? activityId,
    BrickMetadata? brickMetadata,
    String? userId,
  }) async {
    try {
      // Get current user: prefer explicit userId lookup (auth-session-independent),
      // fall back to auth service for backward compatibility
      var user = userId != null
          ? await (await ref.read(userRepositoryProvider.future)).getUserProfileById(userId)
          : null;
      user ??= await _authService.getCurrentUser();
      if (user == null) {
        throw Exception('No user found. Please complete onboarding first.');
      }

      // Get user's food preferences (fallback to safe defaults instead of throwing)
      final preferenceResult = await _preferenceResolver.resolveFoodPreferences(user.id);
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
      final nutritionPlan = await _responseParser.convertLLMResponseToPlan(
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

}

/// Provider for LLMNutritionPlanService
final llmNutritionPlanServiceProvider = Provider<LLMNutritionPlanService>((ref) {
  return LLMNutritionPlanService(ref);
});
