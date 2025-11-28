import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mealvana_endurance/features/nutrition_plan/domain/food_item_data.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../../shared/services/app_external_deps.dart';
import '../../../shared/services/logging_service.dart';
import '../../../shared/services/sentry/sentry_reporter.dart';
import '../../auth/application/auth_service.dart';
import '../../../shared/domain/activity_type.dart';
import '../data/food_repository.dart';
import '../data/nutrition_plan_repository.dart';
import '../domain/food_item.dart';
import '../domain/macro_targets.dart';
import '../domain/nutrition_plan.dart';
import 'llm_nutrition_plan_service.dart';

/// Application service for managing nutrition plans and food data
/// Coordinates between food database, nutrition calculations, and plan storage
class NutritionPlanService {
  NutritionPlanService(this.ref);
  final Ref ref;

  /// Get repositories and services
  Future<NutritionPlanRepository> get _planRepository async => await ref.read(nutritionPlanRepositoryProvider.future);
  AuthService get _authService => ref.read(authServiceProvider);
  // Content service removed since algorithm logic moved to Edge Functions
  FoodRepository get _foodRepository => ref.read(foodRepositoryProvider);
  LLMNutritionPlanService get _llmService => ref.read(llmNutritionPlanServiceProvider);
  SentryReporter get _sentry => ref.read(appExternalDepsProvider).sentry;
  AppLogger get _logger => ref.read(appExternalDepsProvider).logger;
  SupabaseClient get _supabase => Supabase.instance.client;

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
    int? activityId,
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
        data: {
          'reason': 'llm_failed_or_unavailable',
        },
      );

      // Use fallback logic to generate plan if LLM fails or explicitly requests fallback
      return await _generateFallbackPlan(
        distanceMiles: distanceMiles,
        paceMinutesPerMile: paceMinutesPerMile,
        timeBeforeRunHours: timeBeforeRunHours,
        sweatRate: sweatRate,
        activityId: activityId,
        debug: debug,
        macroTargets: null, // Let fallback calculate its own targets if not provided
      );
    } catch (e, stackTrace) {
      _logger.error('Error generating nutrition plan',
        context: 'NUTRITION_PLAN',
        error: e,
        stackTrace: stackTrace
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
    int? activityId,
    bool debug = false,
    MacroTargets? macroTargets, // Optional: use adjusted macro targets if available
  }) async {
    final user = await _authService.getCurrentUser();
    if (user == null) {
      throw Exception('No user found. Please complete onboarding first.');
    }

    final planRepository = await _planRepository;
    final resolvedMacroTargets = macroTargets ??
        _estimateMacroTargets(
          distanceMiles: distanceMiles,
          paceMinutesPerMile: paceMinutesPerMile,
          timeBeforeRunHours: timeBeforeRunHours,
          sweatRate: sweatRate,
          userWeightPounds: user.weightPounds,
        );

    _logger.warning('LLM generation unavailable, using offline fallback plan.',
      context: 'NUTRITION_PLAN_OFFLINE',
      data: {
        'distance_miles': distanceMiles,
        'duration_h': resolvedMacroTargets.metrics.durationH,
      },
    );

    final offlinePlan = _buildOfflinePlanFromTargets(
      userId: user.id,
      macroTargets: resolvedMacroTargets,
      activityId: activityId,
      timeBeforeRunHours: timeBeforeRunHours,
    );

    try {
      await planRepository.cachePlanLocally(user.id, offlinePlan);
    } catch (e, stackTrace) {
      _logger.warning('Failed to cache offline fallback plan locally',
        context: 'NUTRITION_PLAN_OFFLINE',
        error: e,
        stackTrace: stackTrace,
      );
    }

    return offlinePlan;
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

    final estimatedCalories = (distanceMiles * weightKg * 1.0).clamp(200, 2200).toDouble();

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
    int? activityId,
    required double timeBeforeRunHours,
  }) {
    final uuid = const Uuid();
    final now = DateTime.now();

    final pre = macroTargets.preRun;
    final during = macroTargets.duringRun;
    final post = macroTargets.postRun;

    final gelsNeeded = ((during.carbTotalG) / 25).ceil().clamp(1, 12);
    final bottlesNeeded = ((during.fluidTotalMl) / 500).ceil().clamp(1, 12);

    final preSection = PlanSection(
      id: 'before_run',
      title: 'Before Run',
      subtitle: '${timeBeforeRunHours.toStringAsFixed(1)} hours before',
      timing: 'Finish eating ~60-90 min pre-run',
      foodItems: [
        FoodItemData(
          id: 'pre-simple-carbs',
          name: 'Simple carbs + electrolytes',
          quantity: '${pre.carbsG.round()}g carbs, ${pre.proteinG.round()}g protein',
          description: 'Use easy carbs (bagel + banana + honey) with low fat. Sip ${pre.fluidsMl.round()} ml fluids plus electrolytes.',
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
      title: 'During Run',
      subtitle: 'Every 20-30 min',
      timing: 'Spread across the run to hit ${during.carbRateGPerH.round()}g carbs/hr',
      foodItems: [
        FoodItemData(
          id: 'during-gels',
          name: 'Gels/chews',
          quantity: '$gelsNeeded servings (~${during.carbTotalG.round()}g carbs total)',
          description: 'Use gels/chews; rotate flavors. Pair with sips of fluid.',
        ),
        FoodItemData(
          id: 'during-fluids',
          name: 'Fluids + electrolytes',
          quantity: '$bottlesNeeded bottles (~${during.fluidTotalMl.round()} ml) with ${during.sodiumTotalMg.round()} mg sodium total',
          description: 'Mix sports drink or water + electrolyte tab; aim for small, frequent sips.',
        ),
      ],
      carbsTarget: during.carbTotalG,
      sodiumTarget: during.sodiumTotalMg,
      fluidsTarget: during.fluidTotalMl,
    );

    final postSection = PlanSection(
      id: 'after_run',
      title: 'After Run',
      subtitle: 'Within 30 minutes',
      timing: 'Refuel quickly, then eat a full meal later',
      foodItems: [
        FoodItemData(
          id: 'post-shake',
          name: 'Carb + protein shake/snack',
          quantity: '${post.carbsG.round()}g carbs, ${post.proteinG.round()}g protein',
          description: 'Chocolate milk or protein shake with fruit. Add salty snack to reach ${post.sodiumMg.round()} mg sodium.',
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
    final totalFluids = (pre.fluidsMl + during.fluidTotalMl + post.fluidsMl).round();
    final totalSodium = (pre.sodiumMg + during.sodiumTotalMg + post.sodiumMg).round();

    final macroSummary = PlanMacroSummary(
      calories: (totalCarbs * 4 + totalProtein * 4 + totalFat * 9).round(),
      carbs: totalCarbs,
      protein: totalProtein,
      fat: totalFat,
      sodium: totalSodium,
      fluids: (totalFluids * 0.033814).round(),
      carbsRange: 'Pre ${pre.carbsG.round()}g | During ${during.carbTotalG.round()}g | Post ${post.carbsG.round()}g',
      proteinRange: 'Pre ${pre.proteinG.round()}g | Post ${post.proteinG.round()}g',
      fatRange: 'Pre ${pre.fatCapG.round()}g | Post 0g',
    );

    return NutritionPlan(
      id: 'offline-plan-${uuid.v4()}',
      name: 'Offline Nutrition Plan',
      sections: [preSection, duringSection, postSection],
      macroTargets: macroSummary,
      notes: 'Generated offline fallback based on your targets. Update when online for personalized foods.',
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
    int? activityId,
  }) async {
    try {
      // FIRST: Try LLM-based generation using the adjusted macros
      final llmPlan = await _llmService.generateLLMNutritionPlanFromMacros(
        macroTargets: macroTargets,
        activityId: activityId,
      );

      if (llmPlan != null) {
        return llmPlan;
      }

      // FALLBACK: If LLM returns null (fallback requested), use offline builder
      // passing the adjusted macro targets to respect user's edits
      _logger.info('LLM generation failed/requested fallback, using offline generation with adjusted macros');
      
      return await _generateFallbackPlan(
        distanceMiles: macroTargets.metrics.distanceMi,
        paceMinutesPerMile: macroTargets.metrics.paceMinPerMile ?? 8.0, // Default to 8 min/mi if null
        timeBeforeRunHours: 2.0, // Default or extract if stored
        activityId: activityId,
        macroTargets: macroTargets, // Pass the adjusted targets!
      );
    } catch (e) {
      _logger.error('Error generating plan from macros, attempting fallback', error: e);
      
      // Last resort fallback
      return await _generateFallbackPlan(
        distanceMiles: macroTargets.metrics.distanceMi,
        paceMinutesPerMile: macroTargets.metrics.paceMinPerMile ?? 8.0, // Default to 8 min/mi if null
        timeBeforeRunHours: 2.0,
        activityId: activityId,
        macroTargets: macroTargets,
      );
    }
  }

  /// Get nutrition plans for the current user
  Future<List<NutritionPlan>> getUserNutritionPlans() async {
    final user = await _authService.getCurrentUser();
    if (user == null) return [];
    
    final planRepository = await _planRepository;
    return await planRepository.getNutritionPlans(user.id);
  }

  /// Get the most recent nutrition plan for current user
  /// Checks local cache first, falls back to Supabase
  Future<NutritionPlan?> getLatestNutritionPlan() async {
    final user = await _authService.getCurrentUser();
    if (user == null) return null;
    
    // Repository handles local caching internally
    final planRepository = await _planRepository;
    return await planRepository.getLatestNutritionPlan(user.id);
  }

  /// Update an existing nutrition plan via Edge Function
  Future<NutritionPlan> updateNutritionPlan({
    required double distanceMiles,
    required double paceMinutesPerMile,
    double timeBeforeRunHours = 2.0,
    String? gutTrainingLevel,
  }) async {
    // Updates now follow the exact same flow as fresh generations:
    // try LLM first, fall back to offline builder, and cache on the activity.
    return await generateNutritionPlan(
      distanceMiles: distanceMiles,
      paceMinutesPerMile: paceMinutesPerMile,
      timeBeforeRunHours: timeBeforeRunHours,
      gutTrainingLevel: gutTrainingLevel,
    );
  }

  /// Delete a nutrition plan for a specific activity
  Future<bool> deleteNutritionPlan(int activityId) async {
    final planRepository = await _planRepository;
    return await planRepository.deleteNutritionPlanForActivity(activityId);
  }

  // deleteNutritionPlan method defined above

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

  /// Get nutrition plan statistics for current user
  Future<Map<String, dynamic>> getNutritionPlanStatistics() async {
    final user = await _authService.getCurrentUser();
    if (user == null) {
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
    
    // Statistics method not implemented in repository yet
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

  /// Validate a nutrition plan for safety
  bool validateNutritionPlan(NutritionPlan plan) {
    // Simple validation since Edge Function handles complex logic
    return plan.sections.isNotEmpty && plan.macroTargets != null;
  }

  /// Get nutrition recommendations for a plan
  List<String> getNutritionRecommendations(NutritionPlan plan) {
    // Simple recommendations since Edge Function provides comprehensive plan
    List<String> recommendations = [];
    
    if (plan.sections.length >= 3) {
      recommendations.add('Follow the timing guidelines for optimal performance');
    }
    
    final duringSection = plan.sections.where((s) => s.title.contains('During')).firstOrNull;
    if (duringSection != null && duringSection.foodItems.isNotEmpty) {
      recommendations.add('Start fueling within the first 30-45 minutes of your run');
    }
    
    recommendations.add('Monitor hydration levels and adjust intake based on conditions');
    
    return recommendations;
  }

  /// Calculate pre-run nutrition requirements (simplified)
  Future<int> calculatePreRunNutrition(double timeBeforeRunHours) async {
    // Simplified calculation - Edge Function handles full logic
    final user = await _authService.getCurrentUser();
    if (user == null) throw Exception('No user found');
    
    final bodyWeightKg = user.weightPounds * 0.453592;
    
    if (timeBeforeRunHours >= 1.0) {
      return (timeBeforeRunHours.clamp(1.0, 4.0) * bodyWeightKg).round();
    } else {
      return (0.5 * bodyWeightKg).round();
    }
  }

  /// Calculate pre-run hydration requirements (simplified)
  Future<int> calculatePreRunHydration(double timeBeforeRunHours) async {
    // Simplified calculation - Edge Function handles full logic
    final user = await _authService.getCurrentUser();
    if (user == null) throw Exception('No user found');
    
    final bodyWeightKg = user.weightPounds * 0.453592;
    
    if (timeBeforeRunHours >= 2.0) {
      return (bodyWeightKg * 6.0).round(); // 6ml per kg
    } else if (timeBeforeRunHours >= 1.0) {
      return (bodyWeightKg * 4.0).round(); // 4ml per kg
    } else {
      return (bodyWeightKg * 2.0).round(); // 2ml per kg
    }
  }

  /// Get nutrition plan summary for dashboard/overview
  Future<Map<String, dynamic>> getNutritionSummary() async {
    final plans = await getUserNutritionPlans();
    final statistics = await getNutritionPlanStatistics();
    final latestPlan = await getLatestNutritionPlan();

    return {
      'totalPlans': plans.length,
      'statistics': statistics,
      'latestPlan': latestPlan,
      'hasRecentPlan': latestPlan != null,
    };
  }

  /// Clear all nutrition plans (for testing)
  Future<bool> clearAllPlans() async {
    final user = await _authService.getCurrentUser();
    if (user == null) return false;
    
    final planRepository = await _planRepository;
    return await planRepository.clearAllNutritionPlans(user.id);
  }

  // All sync and versioning logic removed - Edge Functions handle storage directly
}

/// Provider for NutritionPlanService
final nutritionPlanServiceProvider = Provider<NutritionPlanService>((ref) {
  return NutritionPlanService(ref);
});

/// Provider for user's nutrition plans
final userNutritionPlansProvider = FutureProvider<List<NutritionPlan>>((ref) async {
  final service = ref.watch(nutritionPlanServiceProvider);
  return await service.getUserNutritionPlans();
});

/// Provider for latest nutrition plan
final latestNutritionPlanProvider = FutureProvider<NutritionPlan?>((ref) async {
  final service = ref.watch(nutritionPlanServiceProvider);
  return await service.getLatestNutritionPlan();
});
