import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mealvana_endurance/features/nutrition_plan/domain/food_item_data.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../../shared/services/app_external_deps.dart';
import '../../../shared/services/logging_service.dart';
import '../../../shared/services/sentry/sentry_reporter.dart';
import '../../../shared/constants/bottle_constants.dart';
import '../../auth/application/auth_service.dart';
import '../../auth/data/user_repository.dart';
import '../../../shared/domain/activity_type.dart';
import '../../activities/domain/activity.dart' as domain;
import '../../activities/domain/brick_metadata.dart';
import '../../activities/data/activities_repository.dart';
import '../data/food_repository.dart';
import '../data/nutrition_plan_repository.dart';
import '../data/nutrition_plan_mapper.dart';
import '../domain/food_item.dart';
import '../domain/macro_targets.dart';
import '../domain/nutrition_plan.dart';
import 'client_plan/client_plan_service.dart';
import 'llm_nutrition_plan_service.dart';

/// Application service for managing nutrition plans and food data
/// Coordinates between food database, nutrition calculations, and plan storage
class NutritionPlanService {
  NutritionPlanService(this.ref);
  final Ref ref;

  /// Get repositories and services
  Future<NutritionPlanRepository> get _planRepository async =>
      await ref.read(nutritionPlanRepositoryProvider.future);
  AuthService get _authService => ref.read(authServiceProvider);
  ActivitiesRepository get _activitiesRepository =>
      ref.read(activitiesRepositoryProvider);
  // Content service removed since algorithm logic moved to Edge Functions
  FoodRepository get _foodRepository => ref.read(foodRepositoryProvider);
  LLMNutritionPlanService get _llmService =>
      ref.read(llmNutritionPlanServiceProvider);
  ClientPlanService get _clientPlanService =>
      ref.read(clientPlanServiceProvider);
  SentryReporter get _sentry => ref.read(appExternalDepsProvider).sentry;
  AppLogger get _logger => ref.read(appExternalDepsProvider).logger;

  // Nutrition calculator removed - all logic moved to Edge Functions

  /// Generate a new nutrition plan for the current user using new run-plan Edge Function
  Future<NutritionPlan> generateNutritionPlan({
    required double distanceMiles,
    required double paceMinutesPerMile,
    double timeBeforeRunHours = 2.0,
    String? gutTrainingLevel,
    double? tempF,
    double? humidity,
    String? sweatRate,
    String? giSensitivity,
    bool? allowHighCarbRun,
    String? activityId,
    bool debug = false,
  }) async {
    final user = await _authService.getCurrentUser();
    if (user == null) {
      throw Exception('No user found. Please complete onboarding first.');
    }

    // Analytics tracking is handled by the controllers with activity-level context

    final startTime = DateTime.now();

    try {
      // FIRST: Try LLM-based nutrition plan generation
      final llmPlan = await _llmService.generateLLMNutritionPlan(
        distanceMiles: distanceMiles,
        paceMinutesPerMile: paceMinutesPerMile,
        timeBeforeRunHours: timeBeforeRunHours,
        sweatRate: sweatRate,
      );

      if (llmPlan != null) {
        // LLM plan generated successfully
        final responseTime = DateTime.now().difference(startTime);

        // Save the LLM plan to local repository
        final planRepository = await _planRepository;
        await planRepository.cachePlanLocally(user.id, llmPlan);

        // Analytics tracking moved to controller level (activity-scoped)

        // Track LLM success
        _sentry.addBreadcrumb(
          message: 'LLM nutrition plan used successfully',
          category: 'nutrition_plan',
          data: {
            'plan_type': 'llm',
            'response_time_ms': responseTime.inMilliseconds.toString(),
          },
        );

        return llmPlan;
      }

      // FALLBACK: Use offline builder if LLM fails
      _sentry.addBreadcrumb(
        message: 'Falling back to offline nutrition plan',
        category: 'nutrition_plan',
        data: {'reason': 'llm_failed_or_unavailable'},
      );

      // Use fallback logic to generate plan if LLM fails or explicitly requests fallback
      return await _generateFallbackPlan(
        distanceMiles: distanceMiles,
        paceMinutesPerMile: paceMinutesPerMile,
        timeBeforeRunHours: timeBeforeRunHours,
        sweatRate: sweatRate,
        activityId: activityId,
        debug: debug,
        macroTargets:
            null, // Let fallback calculate its own targets if not provided
      );
    } catch (e, stackTrace) {
      _logger.error(
        'Error generating nutrition plan',
        context: 'NUTRITION_PLAN',
        error: e,
        stackTrace: stackTrace,
      );

      // Last resort: try offline fallback if anything goes wrong
      try {
        _sentry.addBreadcrumb(
          message: 'Exception caught, attempting offline fallback',
          category: 'nutrition_plan',
          data: {'error': e.toString()},
        );

        return await _generateFallbackPlan(
          distanceMiles: distanceMiles,
          paceMinutesPerMile: paceMinutesPerMile,
          timeBeforeRunHours: timeBeforeRunHours,
          sweatRate: sweatRate,
          activityId: activityId,
          debug: debug,
        );
      } catch (fallbackError) {
        // If fallback also fails, rethrow original error
        throw e;
      }
    }
  }

  /// Generate a nutrition plan using offline fallback (no network dependency)
  Future<NutritionPlan> _generateFallbackPlan({
    required double distanceMiles,
    required double paceMinutesPerMile,
    required double timeBeforeRunHours,
    String? sweatRate,
    String? activityId,
    bool debug = false,
    MacroTargets?
    macroTargets, // Optional: use adjusted macro targets if available
    String? userId,
  }) async {
    // Try to get user profile: prefer explicit userId lookup (auth-session-independent),
    // fall back to auth service for backward compatibility
    var user = userId != null
        ? await (await ref.read(
            userRepositoryProvider.future,
          )).getUserProfileById(userId)
        : null;
    user ??= await _authService.getCurrentUser();
    if (user == null) {
      throw Exception('No user found. Please complete onboarding first.');
    }

    final planRepository = await _planRepository;
    final resolvedMacroTargets =
        macroTargets ??
        _estimateMacroTargets(
          distanceMiles: distanceMiles,
          paceMinutesPerMile: paceMinutesPerMile,
          timeBeforeRunHours: timeBeforeRunHours,
          sweatRate: sweatRate,
          userWeightPounds: user.weightPounds,
        );

    _logger.warning(
      'LLM generation unavailable, using offline fallback plan.',
      context: 'NUTRITION_PLAN_OFFLINE',
      data: {
        'distance_miles': distanceMiles,
        'duration_h': resolvedMacroTargets.metrics.durationH,
      },
    );

    // NEW: Try client-side solver with real foods from Drift/Supabase
    try {
      final clientPlan = await _clientPlanService.generatePlan(
        userId: user.id,
        macroTargets: resolvedMacroTargets,
        activityId: activityId,
        timeBeforeRunHours: timeBeforeRunHours,
        activityType: resolvedMacroTargets.activityType,
      );

      try {
        await planRepository.cachePlanLocally(user.id, clientPlan);
      } catch (e) {
        _logger.warning(
          'Failed to cache client solver plan locally',
          context: 'NUTRITION_PLAN_OFFLINE',
          error: e,
        );
      }

      _logger.info(
        'Client solver produced plan with real foods',
        context: 'NUTRITION_PLAN_OFFLINE',
      );
      return clientPlan;
    } catch (e) {
      _logger.warning(
        'Client solver failed, using generic fallback',
        context: 'NUTRITION_PLAN_OFFLINE',
        error: e,
      );
    }

    // EXISTING: Ultimate fallback with generic text
    final offlinePlan = _buildOfflinePlanFromTargets(
      userId: user.id,
      macroTargets: resolvedMacroTargets,
      activityId: activityId,
      timeBeforeRunHours: timeBeforeRunHours,
    );

    try {
      await planRepository.cachePlanLocally(user.id, offlinePlan);
    } catch (e, stackTrace) {
      _logger.warning(
        'Failed to cache offline fallback plan locally',
        context: 'NUTRITION_PLAN_OFFLINE',
        error: e,
        stackTrace: stackTrace,
      );
    }

    return offlinePlan;
  }

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

  MacroTargets _estimateMacroTargets({
    required double distanceMiles,
    required double paceMinutesPerMile,
    required double timeBeforeRunHours,
    String? sweatRate,
    required double userWeightPounds,
  }) {
    final uuid = const Uuid();
    final distanceKm = (distanceMiles > 0 ? distanceMiles : 6.0) * 1.60934;
    final durationMinutesRaw = (distanceMiles > 0 && paceMinutesPerMile > 0)
        ? distanceMiles * paceMinutesPerMile
        : 60.0;
    final durationMinutes = durationMinutesRaw.clamp(15.0, 720.0);
    final durationH = durationMinutes / 60.0;
    final weightKg = userWeightPounds * 0.453592;

    // Simple heuristics for offline macro estimates
    final preRunCarbs = timeBeforeRunHours >= 2
        ? (distanceMiles >= 10 ? 100.0 : 70.0)
        : (distanceMiles >= 10 ? 80.0 : 55.0);
    final preRunProtein = 15.0;
    final preRunFat = 8.0;
    final preRunFluidsMl = 500.0;
    final preRunSodium = 400.0;

    final gutAdjustedCarbRate = sweatRate == 'high' ? 55.0 : 45.0;
    final duringCarbRate = gutAdjustedCarbRate;
    final duringCarbTotal = duringCarbRate * durationH;
    final duringFluidRate = 600.0;
    final duringFluidTotal = duringFluidRate * durationH;
    final duringSodiumRate = sweatRate == 'high' ? 600.0 : 400.0;
    final duringSodiumTotal = duringSodiumRate * durationH;

    final postCarbs = 60.0;
    final postProtein = 25.0;
    final postFluids = 700.0;
    final postSodium = 500.0;

    final estimatedCalories = (distanceMiles * weightKg * 1.0)
        .clamp(200, 2200)
        .toDouble();

    return MacroTargets(
      id: 'offline-macros-${uuid.v4()}',
      activityType: ActivityType.running,
      preRun: PreRunMacros(
        carbsG: preRunCarbs,
        proteinG: preRunProtein,
        fatCapG: preRunFat,
        fluidsMl: preRunFluidsMl,
        sodiumMg: preRunSodium,
      ),
      duringRun: DuringRunMacros(
        carbRateGPerH: duringCarbRate,
        carbTotalG: duringCarbTotal,
        fluidRateMlPerH: duringFluidRate,
        fluidTotalMl: duringFluidTotal,
        sodiumRateMgPerH: duringSodiumRate,
        sodiumTotalMg: duringSodiumTotal,
        massNormRateGPerH: duringCarbRate,
      ),
      postRun: PostRunMacros(
        carbsG: postCarbs,
        proteinG: postProtein,
        fluidsMl: postFluids,
        sodiumMg: postSodium,
      ),
      metrics: RunMetrics(
        distanceMi: distanceMiles,
        distanceKm: distanceKm,
        durationH: durationH,
        durationMin: durationMinutes,
        paceMinPerMile: paceMinutesPerMile,
        speedMph: durationH > 0 ? distanceMiles / durationH : 0,
        caloriesGrossKcal: estimatedCalories,
        caloriesNetKcal: estimatedCalories,
        met: 9.5,
      ),
      calculationRule: 'offline_fallback',
      timestamp: DateTime.now(),
      isUserModified: false,
      modifiedFields: const [],
    );
  }

  NutritionPlan _buildOfflinePlanFromTargets({
    required String userId,
    required MacroTargets macroTargets,
    String? activityId,
    required double timeBeforeRunHours,
  }) {
    final uuid = const Uuid();
    final now = DateTime.now();
    final activityType = macroTargets.activityType;

    final pre = macroTargets.preRun;
    final during = macroTargets.duringRun;
    final post = macroTargets.postRun;

    final gelsNeeded = ((during.carbTotalG) / 25).ceil().clamp(1, 12);
    final bottlesNeeded = ((during.fluidTotalMl) / kStandardBottleMl)
        .ceil()
        .clamp(1, 12);

    final preSection = PlanSection(
      id: 'before_run',
      title: activityType.getSectionTitle('before'),
      subtitle: '${timeBeforeRunHours.toStringAsFixed(1)} hours before',
      timing: 'Finish eating ~60-90 min before',
      foodItems: [
        FoodItemData(
          id: 'pre-simple-carbs',
          name: 'Simple carbs + electrolytes',
          quantity:
              '${pre.carbsG.round()}g carbs, ${pre.proteinG.round()}g protein',
          description:
              'Use easy carbs (bagel + banana + honey) with low fat. Sip ${pre.fluidsMl.round()} ml fluids plus electrolytes.',
        ),
      ],
      proteinTarget: pre.proteinG,
      fatTarget: pre.fatCapG,
      carbsTarget: pre.carbsG,
      sodiumTarget: pre.sodiumMg,
      fluidsTarget: pre.fluidsMl,
    );

    final duringSection = PlanSection(
      id: 'during_run',
      title: activityType.getSectionTitle('during'),
      subtitle: 'Every 20-30 min',
      timing:
          'Spread across the activity to hit ${during.carbRateGPerH.round()}g carbs/hr',
      foodItems: [
        FoodItemData(
          id: 'during-gels',
          name: 'Gels/chews',
          quantity:
              '$gelsNeeded servings (~${during.carbTotalG.round()}g carbs total)',
          description:
              'Use gels/chews; rotate flavors. Pair with sips of fluid.',
        ),
        FoodItemData(
          id: 'during-fluids',
          name: 'Fluids + electrolytes',
          quantity:
              '$bottlesNeeded bottles (~${during.fluidTotalMl.round()} ml) with ${during.sodiumTotalMg.round()} mg sodium total',
          description:
              'Mix sports drink or water + electrolyte tab; aim for small, frequent sips.',
        ),
      ],
      carbsTarget: during.carbTotalG,
      sodiumTarget: during.sodiumTotalMg,
      fluidsTarget: during.fluidTotalMl,
    );

    final postSection = PlanSection(
      id: 'after_run',
      title: activityType.getSectionTitle('after'),
      subtitle: 'Within 30 minutes',
      timing: 'Refuel quickly, then eat a full meal later',
      foodItems: [
        FoodItemData(
          id: 'post-shake',
          name: 'Carb + protein shake/snack',
          quantity:
              '${post.carbsG.round()}g carbs, ${post.proteinG.round()}g protein',
          description:
              'Chocolate milk or protein shake with fruit. Add salty snack to reach ${post.sodiumMg.round()} mg sodium.',
        ),
      ],
      proteinTarget: post.proteinG,
      carbsTarget: post.carbsG,
      sodiumTarget: post.sodiumMg,
      fluidsTarget: post.fluidsMl,
    );

    final totalCarbs = (pre.carbsG + during.carbTotalG + post.carbsG).round();
    final totalProtein = (pre.proteinG + post.proteinG).round();
    final totalFat = pre.fatCapG.round();
    final totalFluids = (pre.fluidsMl + during.fluidTotalMl + post.fluidsMl)
        .round();
    final totalSodium = (pre.sodiumMg + during.sodiumTotalMg + post.sodiumMg)
        .round();

    final macroSummary = PlanMacroSummary(
      calories: (totalCarbs * 4 + totalProtein * 4 + totalFat * 9).round(),
      carbs: totalCarbs,
      protein: totalProtein,
      fat: totalFat,
      sodium: totalSodium,
      sodiumMin: pre.sodiumLowMg?.round(),
      sodiumMax: pre.sodiumHighMg?.round(),
      fluids: (totalFluids * 0.033814).round(),
      fluidsMin: pre.fluidsLowMl != null
          ? (pre.fluidsLowMl! * 0.033814).round()
          : null,
      fluidsMax: pre.fluidsHighMl != null
          ? (pre.fluidsHighMl! * 0.033814).round()
          : null,
      carbsRange:
          'Pre ${pre.carbsG.round()}g | During ${during.carbTotalG.round()}g | Post ${post.carbsG.round()}g',
      proteinRange:
          'Pre ${pre.proteinG.round()}g | Post ${post.proteinG.round()}g',
      fatRange: 'Pre ${pre.fatCapG.round()}g | Post 0g',
    );

    return NutritionPlan(
      id: 'offline-plan-${uuid.v4()}',
      name: 'Offline Nutrition Plan',
      sections: [preSection, duringSection, postSection],
      macroTargets: macroSummary,
      notes:
          'Generated offline fallback based on your targets. Update when online for personalized foods.',
      activityId: activityId,
      createdAt: now,
      updatedAt: now,
      clientUpdatedAt: now,
      lastModifiedBy: userId,
      version: 1,
    );
  }

  /// Generate nutrition plan from adjusted macro targets with fallback
  Future<NutritionPlan> generatePlanFromMacrosWithFallback({
    required MacroTargets macroTargets,
    String? activityId,
    BrickMetadata? brickMetadata,
    String? userId,
  }) async {
    try {
      // FIRST: Try LLM-based generation using the adjusted macros
      final llmPlan = await _llmService.generateLLMNutritionPlanFromMacros(
        macroTargets: macroTargets,
        activityId: activityId,
        brickMetadata: brickMetadata,
        userId: userId,
      );

      if (llmPlan != null) {
        return llmPlan;
      }

      // FALLBACK: If LLM returns null (fallback requested), use offline builder
      // passing the adjusted macro targets to respect user's edits
      _logger.info(
        'LLM generation failed/requested fallback, using offline generation with adjusted macros',
      );

      return await _generateFallbackPlan(
        distanceMiles: macroTargets.metrics.distanceMi,
        paceMinutesPerMile:
            macroTargets.metrics.paceMinPerMile ??
            8.0, // Default to 8 min/mi if null
        timeBeforeRunHours: 2.0, // Default or extract if stored
        activityId: activityId,
        macroTargets: macroTargets, // Pass the adjusted targets!
        userId: userId,
      );
    } catch (e) {
      _logger.error(
        'Error generating plan from macros, attempting fallback',
        error: e,
      );

      // Last resort fallback
      return await _generateFallbackPlan(
        distanceMiles: macroTargets.metrics.distanceMi,
        paceMinutesPerMile:
            macroTargets.metrics.paceMinPerMile ??
            8.0, // Default to 8 min/mi if null
        timeBeforeRunHours: 2.0,
        activityId: activityId,
        macroTargets: macroTargets,
        userId: userId,
      );
    }
  }

  /// Generate nutrition plan using template-based V2 edge function.
  ///
  /// Pre-workout phase uses templates with proportional scaling and drink selection.
  /// During/after phases reuse the existing LP solver.
  /// Falls back to existing v1 flow if v2 fails.
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
    BrickMetadata? brickMetadata,
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
      final requestData = {
        'device_id': userId ?? '',
        'activity_type': macroTargets.activityType.name,
        'hours_before': hoursBefore,
        'weight_kg': weightKg,
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
        if (willingToTryFoods != null)
          'willing_to_try_foods': willingToTryFoods,
        if (durationMinutes != null) 'duration_minutes': durationMinutes,
        if (gutTrainingLevel != null) 'gut_training_level': gutTrainingLevel,
        if (macroTargets.preRunSelections != null &&
            macroTargets.preRunSelections!.isNotEmpty)
          'pre_run_selections': macroTargets.preRunSelections,
      };

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
    } catch (e) {
      _logger.error(
        '❌ [V3-FAILED] V3 edge function failed, using offline fallback. Error: $e',
        context: 'NUTRITION_PLAN_SERVICE',
        error: e,
      );

      // Fallback to offline plan (no V1 edge function - V1 is decommissioned)
      return await _generateFallbackPlan(
        distanceMiles: macroTargets.metrics.distanceMi,
        paceMinutesPerMile: macroTargets.metrics.paceMinPerMile ?? 8.0,
        timeBeforeRunHours: hoursBefore,
        activityId: activityId,
        macroTargets: macroTargets,
        userId: userId,
      );
    }
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

  /// Regenerate nutrition plan after schedule change from provider
  ///
  /// Called when an activity's schedule has changed (e.g., time, duration, distance)
  /// and the existing nutrition plan is now stale. This method:
  /// 1. Extracts parameters from the updated activity
  /// 2. Generates a new nutrition plan using the updated parameters
  /// 3. Updates the activity with the new nutrition plan
  /// 4. Clears the needsNutritionRefresh flag
  /// 5. Returns the updated activity with fresh nutrition plan
  ///
  /// User food preferences are preserved during regeneration (handled by LLM service).
  Future<domain.Activity> regenerateForScheduleChange(
    domain.Activity activity,
  ) async {
    try {
      _logger.info(
        'Regenerating nutrition plan after schedule change',
        context: 'NUTRITION_PLAN_SERVICE',
        data: {
          'activityId': activity.id,
          'activityType': activity.activityType.name,
          'provider': activity.syncedFromProvider,
        },
      );

      // Extract parameters from activity
      final distanceMiles = activity.distanceMiles ?? 0;
      final durationMinutes = activity.durationMinutes ?? 0;

      // Calculate pace from distance and duration
      final paceMinutesPerMile = distanceMiles > 0 && durationMinutes > 0
          ? durationMinutes / distanceMiles
          : 8.0; // Default to 8 min/mile if not calculable

      // Calculate time before run from scheduled date/time
      // Default to 2 hours if activity is in the future
      final now = DateTime.now();
      final timeBeforeRunHours = activity.scheduledDateTime.isAfter(now)
          ? 2.0
          : 2.0; // Always use 2 hours as default for regeneration

      // Get user for context
      final user = await _authService.getCurrentUser();
      if (user == null) {
        throw Exception('User not found during nutrition plan regeneration');
      }

      // Generate new nutrition plan with updated parameters
      // This calls the LLM service which preserves user food preferences
      final newPlan = await generateNutritionPlan(
        distanceMiles: distanceMiles,
        paceMinutesPerMile: paceMinutesPerMile,
        timeBeforeRunHours: timeBeforeRunHours,
        activityId: activity.id,
        // Use user preferences from profile
        sweatRate: user.sweatRate.value,
        gutTrainingLevel: user.gutTraining.value,
        giSensitivity:
            null, // GI sensitivity not stored as string in user profile
      );

      _logger.info(
        'Nutrition plan regenerated successfully',
        context: 'NUTRITION_PLAN_SERVICE',
        data: {'activityId': activity.id, 'planId': newPlan.id},
      );

      // Update activity with new nutrition plan data
      final updatedActivity = activity.copyWith(
        nutritionPlanData: {
          'id': newPlan.id,
          'name': newPlan.name,
          'sections': newPlan.sections
              .map(
                (s) => {
                  'id': s.id,
                  'title': s.title,
                  'subtitle': s.subtitle,
                  'timing': s.timing,
                  'food_items': s.foodItems
                      .map(
                        (f) => {
                          'id': f.id,
                          'name': f.name,
                          'quantity': f.quantity,
                          'description': f.description,
                        },
                      )
                      .toList(),
                  'carbs_target': s.carbsTarget,
                  'protein_target': s.proteinTarget,
                  'fat_target': s.fatTarget,
                  'sodium_target': s.sodiumTarget,
                  'fluids_target': s.fluidsTarget,
                },
              )
              .toList(),
          'macro_targets': newPlan.macroTargets != null
              ? {
                  'calories': newPlan.macroTargets!.calories,
                  'carbs': newPlan.macroTargets!.carbs,
                  'protein': newPlan.macroTargets!.protein,
                  'fat': newPlan.macroTargets!.fat,
                  'sodium': newPlan.macroTargets!.sodium,
                  'fluids': newPlan.macroTargets!.fluids,
                  'carbs_range': newPlan.macroTargets!.carbsRange,
                  'protein_range': newPlan.macroTargets!.proteinRange,
                  'fat_range': newPlan.macroTargets!.fatRange,
                }
              : null,
          'notes': newPlan.notes,
          'created_at': newPlan.createdAt?.toIso8601String(),
          'updated_at': newPlan.updatedAt?.toIso8601String(),
        },
      );

      // Save updated activity with new nutrition plan
      await _activitiesRepository.updateActivity(
        deviceId: user.id,
        activity: updatedActivity,
      );

      // Clear the nutrition refresh flag
      await _activitiesRepository.clearNutritionRefreshFlag(activity.id);

      _logger.info(
        'Activity updated with regenerated nutrition plan',
        context: 'NUTRITION_PLAN_SERVICE',
        data: {'activityId': activity.id, 'needsNutritionRefresh': false},
      );

      // Track analytics for regeneration
      _sentry.addBreadcrumb(
        message: 'Nutrition plan regenerated after schedule change',
        category: 'nutrition_plan',
        data: {
          'activity_id': activity.id,
          'activity_type': activity.activityType.name,
          'provider': activity.syncedFromProvider ?? 'manual',
          'distance_miles': distanceMiles.toString(),
          'duration_minutes': durationMinutes.toString(),
        },
      );

      return updatedActivity;
    } catch (e, stackTrace) {
      _logger.error(
        'Failed to regenerate nutrition plan after schedule change',
        context: 'NUTRITION_PLAN_SERVICE',
        error: e,
        stackTrace: stackTrace,
        data: {'activityId': activity.id},
      );

      // Report error to Sentry for monitoring
      await _sentry.reportCriticalError(
        e,
        stackTrace: stackTrace,
        context: 'nutrition_plan_regeneration_failed',
        tags: {
          'activity_id': activity.id,
          'operation': 'regenerate_after_schedule_change',
        },
      );

      rethrow;
    }
  }

  // All sync and versioning logic removed - Edge Functions handle storage directly
}

/// Provider for NutritionPlanService
final nutritionPlanServiceProvider = Provider<NutritionPlanService>((ref) {
  return NutritionPlanService(ref);
});
