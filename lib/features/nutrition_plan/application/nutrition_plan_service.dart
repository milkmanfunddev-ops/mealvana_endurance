import 'dart:async';
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../../shared/constants/bottle_constants.dart';
import '../../../shared/domain/activity_type.dart';
import '../../../shared/services/app_external_deps.dart';
import '../../../shared/services/logging_service.dart';
import '../../auth/application/auth_service.dart';
import '../data/food_repository.dart';
import '../data/nutrition_plan_mapper.dart';
import '../domain/food_item.dart';
import '../domain/food_item_data.dart';
import '../domain/macro_targets.dart';
import '../domain/nutrition_plan.dart';
import 'client_plan/client_plan_service.dart';

/// Application service for managing nutrition plans and food data
/// Coordinates between food database, nutrition calculations, and plan storage
class NutritionPlanService {
  NutritionPlanService(this.ref);
  final Ref ref;

  AuthService get _authService => ref.read(authServiceProvider);
  // Content service removed since algorithm logic moved to Edge Functions
  FoodRepository get _foodRepository => ref.read(foodRepositoryProvider);
  ClientPlanService get _clientPlanService =>
      ref.read(clientPlanServiceProvider);
  AppLogger get _logger => ref.read(appExternalDepsProvider).logger;

  // Nutrition calculator removed - all logic moved to Edge Functions

  /// Build phase target map for the V3 plan generator.
  ///
  /// Always sends band ranges (low/high) when available. Additionally includes
  /// an `overrides` map flagging which macros have targets outside their band,
  /// so the edge function can expand the band to include the target.
  static Map<String, dynamic> _buildPhaseTargets({
    required double carbsG,
    double? proteinG,
    double? fatG,
    required double sodiumMg,
    required double waterMl,
    double? carbsLowG,
    double? carbsHighG,
    double? proteinLowG,
    double? proteinHighG,
    double? sodiumLowMg,
    double? sodiumHighMg,
    double? waterLowMl,
    double? waterHighMl,
  }) {
    final map = <String, dynamic>{
      'carbs_g': carbsG,
      'sodium_mg': sodiumMg,
      'water_ml': waterMl,
      if (proteinG != null) 'protein_g': proteinG,
      if (fatG != null) 'fat_g': fatG,
      if (carbsLowG != null) 'carbs_low_g': carbsLowG,
      if (carbsHighG != null) 'carbs_high_g': carbsHighG,
      if (proteinLowG != null) 'protein_low_g': proteinLowG,
      if (proteinHighG != null) 'protein_high_g': proteinHighG,
      if (sodiumLowMg != null) 'sodium_low_mg': sodiumLowMg,
      if (sodiumHighMg != null) 'sodium_high_mg': sodiumHighMg,
      if (waterLowMl != null) 'water_low_ml': waterLowMl,
      if (waterHighMl != null) 'water_high_ml': waterHighMl,
    };

    // Signal which macros have been overridden outside their bands so the
    // edge function can expand band bounds to include the target.
    final overrides = <String, bool>{};
    if (_isOutsideBand(carbsG, carbsLowG, carbsHighG)) {
      overrides['carbs'] = true;
    }
    if (proteinG != null &&
        _isOutsideBand(proteinG, proteinLowG, proteinHighG)) {
      overrides['protein'] = true;
    }
    if (_isOutsideBand(sodiumMg, sodiumLowMg, sodiumHighMg)) {
      overrides['sodium'] = true;
    }
    if (_isOutsideBand(waterMl, waterLowMl, waterHighMl)) {
      overrides['water'] = true;
    }
    if (overrides.isNotEmpty) {
      map['overrides'] = overrides;
    }

    return map;
  }

  /// Returns true if [target] falls outside [low, high].
  static bool _isOutsideBand(double target, double? low, double? high) {
    if (low == null || high == null) return false;
    return target < low || target > high;
  }

  /// Build the base request payload for the V3 plan generator.
  ///
  /// Extracted as a static so the payload contract can be unit tested
  /// (brick-specific keys are layered on afterwards by the caller).
  static Map<String, dynamic> buildV2RequestPayload({
    required MacroTargets macroTargets,
    required double hoursBefore,
    required double weightKg,
    String? userId,
    String? dietaryPreference,
    List<String>? allergies,
    List<String>? likedFoods,
    List<String>? dislikedFoods,
    List<String>? willingToTryFoods,
    int? durationMinutes,
    String? gutTrainingLevel,
  }) {
    return {
      'device_id': userId ?? '',
      'activity_type': macroTargets.activityType.name,
      'hours_before': hoursBefore,
      'weight_kg': weightKg,
      // Opt in to the ephemeral default-formula safety net (formula-first
      // flip). This client keeps ephemeral pin decisions invisible in the
      // pin banner + pin analytics (see pin_banner_rows_builder /
      // macro_targets_controller._emitPinEvent), so it's safe to receive
      // them. Old clients omit this flag and get byte-identical
      // pre-safety-net telemetry. 2026-07-03.
      'emit_ephemeral_default_formula': true,
      'macro_targets': <String, dynamic>{
        'pre_run': _buildPhaseTargets(
          carbsG: macroTargets.preRun.carbsG,
          proteinG: macroTargets.preRun.proteinG,
          fatG: macroTargets.preRun.fatCapG,
          sodiumMg: macroTargets.preRun.sodiumMg,
          waterMl: macroTargets.preRun.fluidsMl,
          carbsLowG: macroTargets.preRun.carbsLowG,
          carbsHighG: macroTargets.preRun.carbsHighG,
          proteinLowG: macroTargets.preRun.proteinLowG,
          proteinHighG: macroTargets.preRun.proteinHighG,
          sodiumLowMg: macroTargets.preRun.sodiumLowMg,
          sodiumHighMg: macroTargets.preRun.sodiumHighMg,
          waterLowMl: macroTargets.preRun.fluidsLowMl,
          waterHighMl: macroTargets.preRun.fluidsHighMl,
        ),
        'during_run': _buildPhaseTargets(
          carbsG: macroTargets.duringRun.carbTotalG,
          sodiumMg: macroTargets.duringRun.sodiumTotalMg,
          waterMl: macroTargets.duringRun.fluidTotalMl,
          carbsLowG: macroTargets.duringRun.carbsLowG,
          carbsHighG: macroTargets.duringRun.carbsHighG,
          sodiumLowMg: macroTargets.duringRun.sodiumLowMg,
          sodiumHighMg: macroTargets.duringRun.sodiumHighMg,
          waterLowMl: macroTargets.duringRun.fluidsLowMl,
          waterHighMl: macroTargets.duringRun.fluidsHighMl,
        ),
        'post_run': _buildPhaseTargets(
          carbsG: macroTargets.postRun.carbsG,
          proteinG: macroTargets.postRun.proteinG,
          sodiumMg: macroTargets.postRun.sodiumMg,
          waterMl: macroTargets.postRun.fluidsMl,
          carbsLowG: macroTargets.postRun.carbsLowG,
          carbsHighG: macroTargets.postRun.carbsHighG,
          proteinLowG: macroTargets.postRun.proteinLowG,
          proteinHighG: macroTargets.postRun.proteinHighG,
          sodiumLowMg: macroTargets.postRun.sodiumLowMg,
          sodiumHighMg: macroTargets.postRun.sodiumHighMg,
          waterLowMl: macroTargets.postRun.fluidsLowMl,
          waterHighMl: macroTargets.postRun.fluidsHighMl,
        ),
      },
      if (dietaryPreference != null) 'dietary_preference': dietaryPreference,
      if (allergies != null) 'allergies': allergies,
      if (likedFoods != null) 'liked_foods': likedFoods,
      if (dislikedFoods != null) 'disliked_foods': dislikedFoods,
      if (willingToTryFoods != null) 'willing_to_try_foods': willingToTryFoods,
      if (durationMinutes != null) 'duration_minutes': durationMinutes,
      // Always send a valid gut training level ('low' | 'moderate' | 'high').
      // A null/absent value makes the V3 edge function skip its formula
      // engine, producing during-phase plans that miss carb targets
      // (bug 3a3e3fdb). Defense-in-depth alongside the server-side fix.
      'gut_training_level': gutTrainingLevel ?? 'moderate',
      if (macroTargets.preRunSelections != null &&
          macroTargets.preRunSelections!.isNotEmpty)
        'pre_run_selections': macroTargets.preRunSelections,
    };
  }

  /// Generate nutrition plan using template-based V2 edge function.
  ///
  /// Pre-workout phase uses Algorithm C selections from macro generation.
  /// During phase uses the template solver with rule/LP fallback in the Edge
  /// Function. After phase uses the LP solver.
  Future<NutritionPlan> generatePlanFromMacrosV2({
    required MacroTargets macroTargets,
    required double hoursBefore,
    required double weightKg,
    String? activityId,
    String? userId,
    String? dietaryPreference,
    List<String>? allergies,
    List<String>? likedFoods,
    List<String>? dislikedFoods,
    List<String>? willingToTryFoods,
    int? durationMinutes,
    String? gutTrainingLevel,
  }) async {
    try {
      _logger.info(
        'Generating plan via V2 template system',
        context: 'NUTRITION_PLAN_SERVICE',
      );
      _logger.info(
        '🎯 OVERRIDE DEBUG [2/5]: Sending to V2 edge function: '
        'pre_carbs=${macroTargets.preRun.carbsG}, pre_protein=${macroTargets.preRun.proteinG}, pre_sodium=${macroTargets.preRun.sodiumMg}, pre_fluids=${macroTargets.preRun.fluidsMl}, '
        'during_carbs=${macroTargets.duringRun.carbTotalG}, during_sodium=${macroTargets.duringRun.sodiumTotalMg}, during_fluids=${macroTargets.duringRun.fluidTotalMl}, '
        'post_carbs=${macroTargets.postRun.carbsG}, post_protein=${macroTargets.postRun.proteinG}, post_sodium=${macroTargets.postRun.sodiumMg}, post_fluids=${macroTargets.postRun.fluidsMl}',
        context: 'NUTRITION_PLAN_SERVICE',
      );

      final supabase = ref.read(appExternalDepsProvider).supabaseClient;

      // Build the v2 request payload
      final requestData = buildV2RequestPayload(
        macroTargets: macroTargets,
        hoursBefore: hoursBefore,
        weightKg: weightKg,
        userId: userId,
        dietaryPreference: dietaryPreference,
        allergies: allergies,
        likedFoods: likedFoods,
        dislikedFoods: dislikedFoods,
        willingToTryFoods: willingToTryFoods,
        durationMinutes: durationMinutes,
        gutTrainingLevel: gutTrainingLevel,
      );

      // Add brick_segments for brick workouts
      if (macroTargets.activityType == ActivityType.brick &&
          macroTargets.brickSegments != null &&
          macroTargets.brickSegments!.isNotEmpty) {
        final segments = macroTargets.brickSegments!;
        final brickPhaseTargets = macroTargets.brickPhaseTargets;

        if (brickPhaseTargets != null &&
            brickPhaseTargets.duringSegments.isNotEmpty) {
          requestData['brick_segments'] = brickPhaseTargets.duringSegments.map((
            segmentTarget,
          ) {
            return {
              'sport': segmentTarget.sport,
              'duration_minutes': segmentTarget.durationMinutes,
              'macro_targets': {
                'carbs_g': segmentTarget.carbsG,
                if (segmentTarget.carbsLowG != null)
                  'carbs_low_g': segmentTarget.carbsLowG,
                if (segmentTarget.carbsHighG != null)
                  'carbs_high_g': segmentTarget.carbsHighG,
                'sodium_mg': segmentTarget.sodiumMg,
                if (segmentTarget.sodiumLowMg != null)
                  'sodium_low_mg': segmentTarget.sodiumLowMg,
                if (segmentTarget.sodiumHighMg != null)
                  'sodium_high_mg': segmentTarget.sodiumHighMg,
                'water_ml': segmentTarget.waterMl,
                if (segmentTarget.waterLowMl != null)
                  'water_low_ml': segmentTarget.waterLowMl,
                if (segmentTarget.waterHighMl != null)
                  'water_high_ml': segmentTarget.waterHighMl,
              },
            };
          }).toList();

          final phasesPayload = {
            'during_segments': brickPhaseTargets.duringSegments.map((
              segmentTarget,
            ) {
              return {
                'segment_order': segmentTarget.segmentOrder,
                'sport': segmentTarget.sport,
                'duration_minutes': segmentTarget.durationMinutes,
                'carbs_g': segmentTarget.carbsG,
                if (segmentTarget.carbsLowG != null)
                  'carbs_low_g': segmentTarget.carbsLowG,
                if (segmentTarget.carbsHighG != null)
                  'carbs_high_g': segmentTarget.carbsHighG,
                'sodium_mg': segmentTarget.sodiumMg,
                if (segmentTarget.sodiumLowMg != null)
                  'sodium_low_mg': segmentTarget.sodiumLowMg,
                if (segmentTarget.sodiumHighMg != null)
                  'sodium_high_mg': segmentTarget.sodiumHighMg,
                'water_ml': segmentTarget.waterMl,
                if (segmentTarget.waterLowMl != null)
                  'water_low_ml': segmentTarget.waterLowMl,
                if (segmentTarget.waterHighMl != null)
                  'water_high_ml': segmentTarget.waterHighMl,
              };
            }).toList(),
            'transitions': brickPhaseTargets.transitions.map((transition) {
              return {
                'transition_name': transition.transitionName,
                'carbs_g': transition.carbsG,
                if (transition.carbsLowG != null)
                  'carbs_low_g': transition.carbsLowG,
                if (transition.carbsHighG != null)
                  'carbs_high_g': transition.carbsHighG,
                'sodium_mg': transition.sodiumMg,
                if (transition.sodiumLowMg != null)
                  'sodium_low_mg': transition.sodiumLowMg,
                if (transition.sodiumHighMg != null)
                  'sodium_high_mg': transition.sodiumHighMg,
                'water_ml': transition.waterMl,
                if (transition.waterLowMl != null)
                  'water_low_ml': transition.waterLowMl,
                if (transition.waterHighMl != null)
                  'water_high_ml': transition.waterHighMl,
              };
            }).toList(),
          };

          (requestData['macro_targets'] as Map<String, dynamic>)['phases'] =
              phasesPayload;
          requestData['brick_phases'] = phasesPayload;
        } else {
          final totalDurationMin = segments.fold<int>(
            0,
            (sum, s) => sum + s.durationMinutes,
          );
          final segmentCount = segments.length;

          requestData['brick_segments'] = segments.map((segment) {
            final durationRatio = totalDurationMin > 0
                ? segment.durationMinutes / totalDurationMin
                : 1.0 / segmentCount;
            return {
              'sport': segment.sport,
              'duration_minutes': segment.durationMinutes,
              'macro_targets': {
                'carbs_g': macroTargets.duringRun.carbTotalG * durationRatio,
                if (macroTargets.duringRun.carbsLowG != null)
                  'carbs_low_g':
                      macroTargets.duringRun.carbsLowG! * durationRatio,
                if (macroTargets.duringRun.carbsHighG != null)
                  'carbs_high_g':
                      macroTargets.duringRun.carbsHighG! * durationRatio,
                'sodium_mg':
                    macroTargets.duringRun.sodiumTotalMg * durationRatio,
                if (macroTargets.duringRun.sodiumLowMg != null)
                  'sodium_low_mg':
                      macroTargets.duringRun.sodiumLowMg! * durationRatio,
                if (macroTargets.duringRun.sodiumHighMg != null)
                  'sodium_high_mg':
                      macroTargets.duringRun.sodiumHighMg! * durationRatio,
                'water_ml': macroTargets.duringRun.fluidTotalMl * durationRatio,
                if (macroTargets.duringRun.fluidsLowMl != null)
                  'water_low_ml':
                      macroTargets.duringRun.fluidsLowMl! * durationRatio,
                if (macroTargets.duringRun.fluidsHighMl != null)
                  'water_high_ml':
                      macroTargets.duringRun.fluidsHighMl! * durationRatio,
              },
            };
          }).toList();
        }
      }

      // Log full V3 request payload for debugging same-plan issues
      _logger.info(
        '📤 [V3-REQUEST] Full payload: '
        'activity_type=${requestData['activity_type']}, '
        'hours_before=${requestData['hours_before']}, '
        'weight_kg=${requestData['weight_kg']}, '
        'duration_minutes=${requestData['duration_minutes']}, '
        'gut_training_level=${requestData['gut_training_level']}, '
        'dietary_preference=${requestData['dietary_preference']}, '
        'pre_run={carbs_g: ${(requestData['macro_targets'] as Map?)?['pre_run']?['carbs_g']}, protein_g: ${(requestData['macro_targets'] as Map?)?['pre_run']?['protein_g']}, water_ml: ${(requestData['macro_targets'] as Map?)?['pre_run']?['water_ml']}, sodium_mg: ${(requestData['macro_targets'] as Map?)?['pre_run']?['sodium_mg']}}, '
        'during_run={carbs_g: ${(requestData['macro_targets'] as Map?)?['during_run']?['carbs_g']}, sodium_mg: ${(requestData['macro_targets'] as Map?)?['during_run']?['sodium_mg']}, water_ml: ${(requestData['macro_targets'] as Map?)?['during_run']?['water_ml']}}, '
        'post_run={carbs_g: ${(requestData['macro_targets'] as Map?)?['post_run']?['carbs_g']}, protein_g: ${(requestData['macro_targets'] as Map?)?['post_run']?['protein_g']}, sodium_mg: ${(requestData['macro_targets'] as Map?)?['post_run']?['sodium_mg']}, water_ml: ${(requestData['macro_targets'] as Map?)?['post_run']?['water_ml']}}',
        context: 'NUTRITION_PLAN_SERVICE',
      );

      // Retry transient errors (502/503/504) with exponential backoff.
      // The Supabase SDK throws FunctionException for all non-2xx responses,
      // so retry logic is handled in the FunctionException catch block.
      const maxRetries = 2;
      late final FunctionResponse response;

      for (var attempt = 0; attempt <= maxRetries; attempt++) {
        try {
          response = await supabase.functions
              .invoke('generate-nutrition-plan-v3', body: requestData)
              .timeout(const Duration(seconds: 90));
          break; // Success - exit retry loop
        } on TimeoutException {
          if (attempt < maxRetries) {
            final delayMs = (1 << attempt) * 1000;
            _logger.warning(
              'V2 timed out, retrying in ${delayMs}ms (attempt ${attempt + 1}/$maxRetries)',
              context: 'NUTRITION_PLAN_SERVICE',
            );
            await Future.delayed(Duration(milliseconds: delayMs));
            continue;
          }
          rethrow;
        } on FunctionException catch (e) {
          if (attempt < maxRetries && _isTransientError(e)) {
            final delayMs = (1 << attempt) * 1000;
            _logger.warning(
              'V2 transient error (${e.status} ${e.reasonPhrase}), retrying in ${delayMs}ms (attempt ${attempt + 1}/$maxRetries)',
              context: 'NUTRITION_PLAN_SERVICE',
            );
            await Future.delayed(Duration(milliseconds: delayMs));
            continue;
          }
          rethrow;
        }
      }

      final data = response.data as Map<String, dynamic>;
      if (data['success'] != true) {
        throw Exception(
          'V2 edge function returned success=false: ${data['error']}',
        );
      }

      // Log V3 response summary for debugging same-plan issues
      final planData = data['plan'] as Map<String, dynamic>?;
      final beforeFoods = planData?['before'];
      final duringFoods = planData?['during'];
      final afterFoods = planData?['after'];
      _logger.info(
        '📥 [V3-RESPONSE] plan_id=${data['plan_id']}, '
        'before_keys=${beforeFoods is Map ? beforeFoods.keys.toList() : 'N/A'}, '
        'during_food_count=${duringFoods is Map ? (duringFoods['foods'] as List?)?.length ?? 0 : (duringFoods is List ? duringFoods.length : 0)}, '
        'after_food_count=${afterFoods is List ? afterFoods.length : 0}',
        context: 'NUTRITION_PLAN_SERVICE',
      );

      // Parse the v2 response into NutritionPlan
      final now = DateTime.now();
      final planId = data['plan_id'] as String? ?? const Uuid().v4();

      final plan = NutritionPlanMapper.fromSupabaseJson({
        'plan_id': planId,
        'plan_name': 'Nutrition Plan',
        'plan_data':
            data, // Contains plan.before (nested), plan.during, plan.after
        'created_at': now.toIso8601String(),
        'updated_at': now.toIso8601String(),
        'activity_id': activityId,
      });

      // Log the targets on each PlanSection after V2 parse
      for (final section in plan.sections) {
        _logger.info(
          '🎯 OVERRIDE DEBUG [4/5]: V2 plan section "${section.id}": '
          'carbsTarget=${section.carbsTarget}, proteinTarget=${section.proteinTarget}, '
          'sodiumTarget=${section.sodiumTarget}, fluidsTarget=${section.fluidsTarget}',
          context: 'NUTRITION_PLAN_SERVICE',
        );
      }

      return plan;
    } catch (e, stackTrace) {
      _logger.error(
        '❌ [V3-FAILED] V3 edge function failed. Error: $e',
        context: 'NUTRITION_PLAN_SERVICE',
        error: e,
        stackTrace: stackTrace,
      );

      return _generateLocalFallbackPlanFromMacros(
        macroTargets: macroTargets,
        hoursBefore: hoursBefore,
        activityId: activityId,
        userId: userId,
        durationMinutes: durationMinutes,
        gutTrainingLevel: gutTrainingLevel,
      );
    }
  }

  Future<NutritionPlan> _generateLocalFallbackPlanFromMacros({
    required MacroTargets macroTargets,
    required double hoursBefore,
    String? activityId,
    String? userId,
    int? durationMinutes,
    String? gutTrainingLevel,
  }) async {
    final resolvedUserId = (userId != null && userId.isNotEmpty)
        ? userId
        : (await _authService.getCurrentUser())?.id;

    if (resolvedUserId != null && resolvedUserId.isNotEmpty) {
      try {
        _logger.warning(
          'Using client-side nutrition solver after V3 failure',
          context: 'NUTRITION_PLAN_SERVICE',
        );
        return await _clientPlanService.generatePlan(
          userId: resolvedUserId,
          macroTargets: macroTargets,
          activityId: activityId,
          timeBeforeRunHours: hoursBefore,
          activityType: macroTargets.activityType,
          durationMinutes: durationMinutes,
          gutTrainingLevel: gutTrainingLevel,
        );
      } catch (fallbackError) {
        _logger.warning(
          'Client-side nutrition solver failed; using generic local fallback',
          context: 'NUTRITION_PLAN_SERVICE',
          error: fallbackError,
        );
      }
    }

    return _buildGenericLocalFallbackPlanFromMacros(
      macroTargets: macroTargets,
      hoursBefore: hoursBefore,
      activityId: activityId,
      userId: resolvedUserId ?? userId,
    );
  }

  NutritionPlan _buildGenericLocalFallbackPlanFromMacros({
    required MacroTargets macroTargets,
    required double hoursBefore,
    String? activityId,
    String? userId,
  }) {
    final activityType = macroTargets.activityType;
    final pre = macroTargets.preRun;
    final during = macroTargets.duringRun;
    final post = macroTargets.postRun;
    final now = DateTime.now();

    final beforeItems = <FoodItemData>[
      if (pre.carbsG > 0 || pre.proteinG > 0 || pre.fatCapG > 0)
        _macroItem(
          id: 'fallback-before-meal',
          name: 'Pre-workout meal',
          quantity: '1 target-based serving',
          carbsG: pre.carbsG,
          proteinG: pre.proteinG,
          fatG: pre.fatCapG,
          sodiumMg: pre.sodiumMg,
          timing: 'Finish eating before the activity',
        ),
      if (pre.fluidsMl > 0)
        _waterItem(
          id: 'fallback-before-water',
          name: 'Water',
          ml: pre.fluidsMl,
          timing: 'Sip before the activity',
        ),
    ];

    final duringItems = <FoodItemData>[
      if (during.carbTotalG > 0)
        _macroItem(
          id: 'fallback-during-fuel',
          name: 'Energy gels or chews',
          quantity:
              '${max(1, (during.carbTotalG / 25).round())} target servings',
          carbsG: during.carbTotalG,
          sodiumMg: 0,
          timing: 'Spread evenly during the activity',
          timingCategory: TimingCategory.quickConsume,
        ),
      if (during.sodiumTotalMg > 0)
        _macroItem(
          id: 'fallback-during-electrolytes',
          name: 'Electrolytes',
          quantity: 'To target',
          sodiumMg: during.sodiumTotalMg,
          timing: 'Spread evenly during the activity',
          timingCategory: TimingCategory.electrolyte,
        ),
      if (during.fluidTotalMl > 0)
        _waterItem(
          id: 'fallback-during-water',
          name: 'Water',
          ml: during.fluidTotalMl,
          timing: 'Sip steadily during the activity',
          timingCategory: TimingCategory.sipThroughout,
        ),
    ];

    final afterItems = <FoodItemData>[
      if (post.carbsG > 0 || post.proteinG > 0)
        _macroItem(
          id: 'fallback-after-recovery',
          name: 'Recovery meal',
          quantity: '1 target-based serving',
          carbsG: post.carbsG,
          proteinG: post.proteinG,
          sodiumMg: post.sodiumMg,
          timing: 'Within 30 minutes',
        ),
      if (post.fluidsMl > 0)
        _waterItem(
          id: 'fallback-after-water',
          name: 'Water',
          ml: post.fluidsMl,
          timing: 'Sip after the activity',
        ),
    ];

    final sections = [
      PlanSection(
        id: 'before_run',
        title: activityType.getSectionTitle('before'),
        subtitle: '${hoursBefore.toStringAsFixed(1)} hours before',
        timing: 'Finish eating before the activity',
        foodItems: beforeItems,
        carbsTarget: pre.carbsG,
        proteinTarget: pre.proteinG,
        fatTarget: pre.fatCapG,
        sodiumTarget: pre.sodiumMg,
        fluidsTarget: pre.fluidsMl,
        carbsLowTarget: pre.carbsLowG,
        carbsHighTarget: pre.carbsHighG,
        proteinLowTarget: pre.proteinLowG,
        proteinHighTarget: pre.proteinHighG,
        sodiumLowTarget: pre.sodiumLowMg,
        sodiumHighTarget: pre.sodiumHighMg,
        fluidsLowTarget: pre.fluidsLowMl,
        fluidsHighTarget: pre.fluidsHighMl,
      ),
      PlanSection(
        id: 'during_run',
        title: activityType.getSectionTitle('during'),
        subtitle: during.carbRateGPerH > 0
            ? '${during.carbRateGPerH.round()}g carbs/hr'
            : 'As needed',
        timing: 'Spread evenly during the activity',
        foodItems: duringItems,
        carbsTarget: during.carbTotalG,
        sodiumTarget: during.sodiumTotalMg,
        fluidsTarget: during.fluidTotalMl,
        carbsLowTarget: during.carbsLowG,
        carbsHighTarget: during.carbsHighG,
        sodiumLowTarget: during.sodiumLowMg,
        sodiumHighTarget: during.sodiumHighMg,
        fluidsLowTarget: during.fluidsLowMl,
        fluidsHighTarget: during.fluidsHighMl,
      ),
      PlanSection(
        id: 'after_run',
        title: activityType.getSectionTitle('after'),
        subtitle: 'Within 30 minutes',
        timing: 'Refuel quickly, then eat a full meal later',
        foodItems: afterItems,
        carbsTarget: post.carbsG,
        proteinTarget: post.proteinG,
        sodiumTarget: post.sodiumMg,
        fluidsTarget: post.fluidsMl,
        carbsLowTarget: post.carbsLowG,
        carbsHighTarget: post.carbsHighG,
        proteinLowTarget: post.proteinLowG,
        proteinHighTarget: post.proteinHighG,
        sodiumLowTarget: post.sodiumLowMg,
        sodiumHighTarget: post.sodiumHighMg,
        fluidsLowTarget: post.fluidsLowMl,
        fluidsHighTarget: post.fluidsHighMl,
      ),
    ];

    final totalCarbs =
        pre.carbsG.round() + during.carbTotalG.round() + post.carbsG.round();
    final totalProtein = pre.proteinG.round() + post.proteinG.round();
    final totalFat = pre.fatCapG.round();
    final totalSodium =
        pre.sodiumMg.round() +
        during.sodiumTotalMg.round() +
        post.sodiumMg.round();
    final totalFluidsMl = pre.fluidsMl + during.fluidTotalMl + post.fluidsMl;

    return NutritionPlan(
      id: 'local-fallback-${const Uuid().v4()}',
      name: 'Nutrition Plan',
      sections: sections,
      macroTargets: PlanMacroSummary(
        calories: totalCarbs * 4 + totalProtein * 4 + totalFat * 9,
        carbs: totalCarbs,
        protein: totalProtein,
        fat: totalFat,
        sodium: totalSodium,
        fluids: (totalFluidsMl * 0.033814).round(),
        carbsRange:
            'Pre ${pre.carbsG.round()}g | During ${during.carbTotalG.round()}g | Post ${post.carbsG.round()}g',
        proteinRange:
            'Pre ${pre.proteinG.round()}g | Post ${post.proteinG.round()}g',
        fatRange: 'Pre ${pre.fatCapG.round()}g',
      ),
      notes:
          'Generated locally from your macro targets. Refresh when the plan generator is available.',
      activityId: activityId,
      createdAt: now,
      updatedAt: now,
      clientUpdatedAt: now,
      lastModifiedBy: userId,
      version: 1,
    );
  }

  FoodItemData _macroItem({
    required String id,
    required String name,
    required String quantity,
    double carbsG = 0,
    double proteinG = 0,
    double fatG = 0,
    double sodiumMg = 0,
    String? timing,
    TimingCategory? timingCategory,
  }) {
    return FoodItemData(
      id: id,
      name: name,
      quantity: quantity,
      timing: timing,
      nutritionalInfo: NutritionalInfo(
        calories: (carbsG * 4 + proteinG * 4 + fatG * 9).round(),
        carbs: carbsG.round(),
        protein: proteinG.round(),
        fat: fatG.round(),
        sodium: sodiumMg.round(),
      ),
      timingCategory: timingCategory,
    );
  }

  FoodItemData _waterItem({
    required String id,
    required String name,
    required double ml,
    String? timing,
    TimingCategory? timingCategory,
  }) {
    final bottleQty = ml > 0 ? ml / kStandardBottleMl : 0;
    final roundedBottles = (bottleQty * 2).round() / 2;
    final quantity = roundedBottles > 0
        ? '${_formatQuantity(roundedBottles)} bottle${roundedBottles == 1 ? '' : 's'}'
        : '${ml.round()} mL';

    return FoodItemData(
      id: id,
      name: name,
      quantity: quantity,
      timing: timing,
      nutritionalInfo: NutritionalInfo(fluids: ml),
      isDrink: true,
      timingCategory: timingCategory ?? TimingCategory.sipThroughout,
    );
  }

  String _formatQuantity(double value) {
    if (value == value.roundToDouble()) return value.round().toString();
    return value.toStringAsFixed(1);
  }

  /// Whether a [FunctionException] represents a transient error worth retrying.
  bool _isTransientError(FunctionException e) {
    if ([502, 503, 504].contains(e.status)) return true;
    final reason = (e.reasonPhrase ?? '').toLowerCase();
    return reason.contains('bad gateway') ||
        reason.contains('service unavailable') ||
        reason.contains('gateway timeout');
  }

  /// Get all available foods from the database
  Future<List<FoodItem>> getAllFoods() async {
    return await _foodRepository.getAllFoods();
  }

  /// Get foods by category
  Future<List<FoodItem>> getFoodsByCategory(FoodCategory category) async {
    return await _foodRepository.getFoodsByCategory(category);
  }

  /// Get a specific food by name (since Supabase uses names as identifiers)
  Future<FoodItem?> getFoodByName(String name) async {
    return await _foodRepository.getFoodByName(name);
  }

  /// Get foods that the current user prefers for a specific category
  Future<List<FoodItem>> getPreferredFoods(FoodCategory category) async {
    final user = await _authService.getCurrentUser();
    if (user == null) return [];

    final likedFoods = await _authService.getLikedFoods(user.id);

    return await _foodRepository.getPreferredFoods(category, likedFoods, []);
  }

  /// Search foods by query
  Future<List<FoodItem>> searchFoods(String query) async {
    return await _foodRepository.searchFoods(query);
  }

  // All sync and versioning logic removed - Edge Functions handle storage directly
}

/// Provider for NutritionPlanService
final nutritionPlanServiceProvider = Provider<NutritionPlanService>((ref) {
  return NutritionPlanService(ref);
});
