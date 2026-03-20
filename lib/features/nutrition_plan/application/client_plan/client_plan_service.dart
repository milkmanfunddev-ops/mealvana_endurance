import 'dart:convert';
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../../shared/domain/activity_type.dart';
import '../../../../shared/services/app_external_deps.dart';
import '../../../../shared/services/logging_service.dart';
import '../../../auth/application/auth_service.dart';
import '../../../auth/domain/user_preferences.dart';
import '../../../food_preferences/data/food_preferences_repository.dart';
import '../../data/templates_repository.dart';
import '../../domain/food_item_data.dart';
import '../../domain/macro_targets.dart';
import '../../domain/nutrition_plan.dart';
import '../../domain/solver_food.dart';
import '../../domain/solver_types.dart';
import '../../domain/sport_config.dart';
import 'client_food_pool_service.dart';
import 'client_greedy_solver.dart';

/// Orchestrates client-side nutrition plan generation.
///
/// For each phase (before/during/after), assembles a food pool and runs
/// the greedy solver to select real foods that approximate the macro targets.
/// Falls back gracefully if any phase fails (returns empty food list for
/// that phase, so the caller can use the existing generic fallback).
class ClientPlanService {
  ClientPlanService(this._ref);
  final Ref _ref;

  static const _solver = ClientGreedySolver();

  ClientFoodPoolService get _foodPool =>
      _ref.read(clientFoodPoolServiceProvider);
  TemplatesRepository get _templatesRepo =>
      _ref.read(templatesRepositoryProvider);
  AppLogger get _logger => _ref.read(appExternalDepsProvider).logger;

  /// Generate a complete nutrition plan with real food selections.
  ///
  /// Throws if the food pool is completely empty (no template or user foods
  /// available), signalling the caller to fall back to the generic plan.
  Future<NutritionPlan> generatePlan({
    required String userId,
    required MacroTargets macroTargets,
    String? activityId,
    required double timeBeforeRunHours,
    required ActivityType activityType,
  }) async {
    final uuid = const Uuid();
    final now = DateTime.now();

    _logger.info(
      'Client solver: generating plan for ${activityType.displayName}',
      context: 'CLIENT_PLAN_SERVICE',
    );

    // Before phase
    final beforeItems = await _solveBefore(
      userId: userId,
      macroTargets: macroTargets,
      activityType: activityType,
      timeBeforeRunHours: timeBeforeRunHours,
    );

    // During phase
    final duringItems = await _solveDuring(
      userId: userId,
      macroTargets: macroTargets,
      activityType: activityType,
    );

    // After phase
    final afterItems = await _solveAfter(
      userId: userId,
      macroTargets: macroTargets,
      activityType: activityType,
    );

    // If ALL phases produced zero foods, throw so caller uses generic fallback
    if (beforeItems.isEmpty && duringItems.isEmpty && afterItems.isEmpty) {
      throw Exception('Client solver: all phases empty — no foods available');
    }

    final pre = macroTargets.preRun;
    final during = macroTargets.duringRun;
    final post = macroTargets.postRun;

    final preSection = PlanSection(
      id: 'before_run',
      title: activityType.getSectionTitle('before'),
      subtitle: '${timeBeforeRunHours.toStringAsFixed(1)} hours before',
      timing: 'Finish eating ~60-90 min before',
      foodItems: beforeItems,
      carbsTarget: pre.carbsG,
      proteinTarget: pre.proteinG,
      fatTarget: pre.fatCapG,
      sodiumTarget: pre.sodiumMg,
      fluidsTarget: pre.fluidsMl,
    );

    final duringSection = PlanSection(
      id: 'during_run',
      title: activityType.getSectionTitle('during'),
      subtitle: 'Every 20-30 min',
      timing:
          'Spread across the activity to hit ${during.carbRateGPerH.round()}g carbs/hr',
      foodItems: duringItems,
      carbsTarget: during.carbTotalG,
      sodiumTarget: during.sodiumTotalMg,
      fluidsTarget: during.fluidTotalMl,
    );

    final postSection = PlanSection(
      id: 'after_run',
      title: activityType.getSectionTitle('after'),
      subtitle: 'Within 30 minutes',
      timing: 'Refuel quickly, then eat a full meal later',
      foodItems: afterItems,
      carbsTarget: post.carbsG,
      proteinTarget: post.proteinG,
      sodiumTarget: post.sodiumMg,
      fluidsTarget: post.fluidsMl,
    );

    // Build macro summary
    final totalCarbs = _sumNutrient(beforeItems, duringItems, afterItems, (n) => n.carbs ?? 0);
    final totalProtein = _sumNutrient(beforeItems, duringItems, afterItems, (n) => n.protein ?? 0);
    final totalFat = _sumNutrient(beforeItems, duringItems, afterItems, (n) => n.fat ?? 0);
    final totalSodium = _sumNutrient(beforeItems, duringItems, afterItems, (n) => n.sodium ?? 0);
    final totalFluids = _sumNutrientDouble(beforeItems, duringItems, afterItems, (n) => n.fluids ?? 0);

    final macroSummary = PlanMacroSummary(
      calories: totalCarbs * 4 + totalProtein * 4 + totalFat * 9,
      carbs: totalCarbs,
      protein: totalProtein,
      fat: totalFat,
      sodium: totalSodium,
      fluids: (totalFluids * 0.033814).round(), // ml to oz
      carbsRange:
          'Pre ${pre.carbsG.round()}g | During ${during.carbTotalG.round()}g | Post ${post.carbsG.round()}g',
      proteinRange:
          'Pre ${pre.proteinG.round()}g | Post ${post.proteinG.round()}g',
      fatRange: 'Pre ${pre.fatCapG.round()}g',
    );

    return NutritionPlan(
      id: 'client-plan-${uuid.v4()}',
      name: 'Nutrition Plan',
      sections: [preSection, duringSection, postSection],
      macroTargets: macroSummary,
      notes: 'Generated offline with your food preferences. Will refresh when online.',
      activityId: activityId,
      createdAt: now,
      updatedAt: now,
      clientUpdatedAt: now,
      lastModifiedBy: userId,
      version: 1,
    );
  }

  // ---------------------------------------------------------------------------
  // Phase solvers
  // ---------------------------------------------------------------------------

  /// Before phase: try template-based selection, fall back to greedy.
  Future<List<FoodItemData>> _solveBefore({
    required String userId,
    required MacroTargets macroTargets,
    required ActivityType activityType,
    required double timeBeforeRunHours,
  }) async {
    try {
      // Try template-based first
      final templateResult = await _tryTemplateBasedBefore(
        userId: userId,
        macroTargets: macroTargets,
        activityType: activityType,
        hoursBefore: timeBeforeRunHours,
      );
      if (templateResult != null && templateResult.isNotEmpty) {
        _logger.info(
          'Before phase: using template-based selection (${templateResult.length} foods)',
          context: 'CLIENT_PLAN_SERVICE',
        );
        return templateResult;
      }
    } catch (e) {
      _logger.warning(
        'Template-based before failed, using greedy',
        context: 'CLIENT_PLAN_SERVICE',
        error: e,
      );
    }

    // Fall back to greedy solver
    return _solvePhase(
      userId: userId,
      phase: 'before',
      targets: SolverTargets(
        carbsG: macroTargets.preRun.carbsG,
        proteinG: macroTargets.preRun.proteinG,
        fatG: macroTargets.preRun.fatCapG,
        sodiumMg: macroTargets.preRun.sodiumMg,
        fluidMl: macroTargets.preRun.fluidsMl,
      ),
      activityType: activityType,
    );
  }

  /// During phase: greedy solver focused on carbs + sodium + fluids.
  Future<List<FoodItemData>> _solveDuring({
    required String userId,
    required MacroTargets macroTargets,
    required ActivityType activityType,
  }) async {
    return _solvePhase(
      userId: userId,
      phase: 'during',
      targets: SolverTargets(
        carbsG: macroTargets.duringRun.carbTotalG,
        sodiumMg: macroTargets.duringRun.sodiumTotalMg,
        fluidMl: macroTargets.duringRun.fluidTotalMl,
      ),
      activityType: activityType,
    );
  }

  /// After phase: greedy solver with protein priority.
  Future<List<FoodItemData>> _solveAfter({
    required String userId,
    required MacroTargets macroTargets,
    required ActivityType activityType,
  }) async {
    return _solvePhase(
      userId: userId,
      phase: 'after',
      targets: SolverTargets(
        carbsG: macroTargets.postRun.carbsG,
        proteinG: macroTargets.postRun.proteinG,
        sodiumMg: macroTargets.postRun.sodiumMg,
        fluidMl: macroTargets.postRun.fluidsMl,
      ),
      activityType: activityType,
    );
  }

  /// Run the greedy solver for a single phase.
  Future<List<FoodItemData>> _solvePhase({
    required String userId,
    required String phase,
    required SolverTargets targets,
    required ActivityType activityType,
  }) async {
    try {
      final foods = await _foodPool.getFoodsForPhase(
        phase: phase,
        userId: userId,
        activityType: activityType,
      );

      if (foods.isEmpty) {
        _logger.warning(
          'No foods available for $phase phase',
          context: 'CLIENT_PLAN_SERVICE',
        );
        return [];
      }

      final config = SportPhaseConfig.forPhase(phase, activityType);
      final selections = _solver.solve(
        foods: foods,
        targets: targets,
        phase: phase,
        config: config,
      );

      _logger.info(
        '$phase phase: ${selections.length} foods selected',
        context: 'CLIENT_PLAN_SERVICE',
      );

      return selections.map((s) {
        // Find the original SolverFood to use its toFoodItemData method
        final solverFood = foods.firstWhere((f) => f.id == s.foodId);
        return solverFood.toFoodItemData(s.quantity);
      }).toList();
    } catch (e) {
      _logger.warning(
        'Greedy solver failed for $phase phase',
        context: 'CLIENT_PLAN_SERVICE',
        error: e,
      );
      return [];
    }
  }

  // ---------------------------------------------------------------------------
  // Template-based before phase
  // ---------------------------------------------------------------------------

  /// Try to select a before-phase template and scale it to targets.
  ///
  /// Returns null if no suitable template is found.
  Future<List<FoodItemData>?> _tryTemplateBasedBefore({
    required String userId,
    required MacroTargets macroTargets,
    required ActivityType activityType,
    required double hoursBefore,
  }) async {
    final templates = await _templatesRepo.getAllTemplates();
    if (templates.isEmpty) return null;

    // Determine meal type from hoursBefore
    final targetMealType = hoursBefore >= 2
        ? 'full_meal'
        : hoursBefore >= 1
            ? 'snack'
            : 'top_up';

    // Get user profile for allergen/dietary filtering
    final user = await _ref.read(authServiceProvider).getCurrentUser();
    final allergyDbValues =
        user?.allergies.map((a) => a.dbValue).toSet() ?? <String>{};
    final dietaryPref = user?.dietaryPreference;

    // Get disliked foods for filtering
    final prefsRepo =
        await _ref.read(foodPreferencesRepositoryProvider.future);
    final preferences = await prefsRepo.getFoodPreferences(userId);
    final dislikedFoodNames = preferences.entries
        .where((e) => e.value == FoodPreference.dislike)
        .map((e) => e.key)
        .toSet();

    // Filter templates
    final candidates = templates.where((t) {
      // Phase must be 'before'
      if (t.phase != 'before') return false;

      // Meal type must match (or close)
      if (t.mealType != targetMealType) return false;

      // Timing window compatibility
      final hoursBeforeMinutes = (hoursBefore * 60).round();
      if (hoursBeforeMinutes < t.timingMinMinutes) return false;
      if (hoursBeforeMinutes > t.timingMaxMinutes) return false;

      // Allergen filter
      if (allergyDbValues.isNotEmpty) {
        final templateAllergens = _parseJsonList(t.allergens);
        if (templateAllergens.any((a) => allergyDbValues.contains(a))) {
          return false;
        }
      }

      // Dietary filter
      if (dietaryPref != null) {
        final excludedDiets = _parseJsonList(t.excludedDiets);
        if (excludedDiets.contains(dietaryPref.dbValue)) return false;
      }

      // Disliked foods filter: skip template if any of its foods are disliked
      if (dislikedFoodNames.isNotEmpty) {
        final templateFoodNames = _parseJsonList(t.foodNames);
        if (templateFoodNames.any((n) => dislikedFoodNames.contains(n))) {
          return false;
        }
      }

      return true;
    }).toList();

    if (candidates.isEmpty) return null;

    // Score by carb proximity to target (prefer templates where scale 0.5-2.0x)
    final carbTarget = macroTargets.preRun.carbsG;
    candidates.sort((a, b) {
      final scaleA =
          a.totalCarbsG > 0 ? (carbTarget / a.totalCarbsG).abs() : 999.0;
      final scaleB =
          b.totalCarbsG > 0 ? (carbTarget / b.totalCarbsG).abs() : 999.0;
      // Prefer scale closest to 1.0
      return (scaleA - 1.0).abs().compareTo((scaleB - 1.0).abs());
    });

    // Use best template
    final best = candidates.first;
    final scale =
        best.totalCarbsG > 0 ? carbTarget / best.totalCarbsG : 1.0;
    final clampedScale = scale.clamp(0.5, 2.0);

    // Parse the foods JSON array and convert to FoodItemData
    List<dynamic> foodsList;
    try {
      foodsList = jsonDecode(best.foods) as List<dynamic>;
    } catch (_) {
      return null;
    }

    final result = <FoodItemData>[];
    for (final foodJson in foodsList) {
      if (foodJson is! Map<String, dynamic>) continue;

      final foodName = foodJson['food_name'] as String? ??
          foodJson['display_name'] as String? ??
          'Unknown';
      final defaultServings =
          (foodJson['default_servings'] as num?)?.toDouble() ?? 1.0;
      final scaledServings = defaultServings * clampedScale;

      // Round to 0.5 increments
      final rounded = (scaledServings * 2).round() / 2;
      final quantity = max(0.5, rounded);

      final carbsPerServing = (foodJson['carbs_g'] as num?)?.toDouble() ?? 0;
      final proteinPerServing =
          (foodJson['protein_g'] as num?)?.toDouble() ?? 0;
      final fatPerServing = (foodJson['fat_g'] as num?)?.toDouble() ?? 0;
      final sodiumPerServing =
          (foodJson['sodium_mg'] as num?)?.toDouble() ?? 0;
      final fluidPerServing =
          (foodJson['fluid_ml'] as num?)?.toDouble() ?? 0;
      final caloriesPerServing =
          (foodJson['calories'] as num?)?.toInt() ??
          (carbsPerServing * 4 + proteinPerServing * 4 + fatPerServing * 9)
              .round();

      final rawQty = SolverFood.formatQuantity(quantity);
      final displayName = foodJson['display_name'] as String? ?? foodName;
      final displayNamePlural = foodJson['display_name_plural'] as String?;
      final servingUnit = foodJson['serving_unit'] as String?;

      final quantityStr = FoodItemData.buildDisplayQuantity(
        rawQty: rawQty,
        servingUnit: servingUnit,
        displayName: displayName,
        displayNamePlural: displayNamePlural,
      );

      result.add(FoodItemData(
        id: foodJson['food_id'] as String? ?? foodName,
        name: displayName,
        quantity: quantityStr,
        imageAddress: foodJson['image_address'] as String?,
        nutritionalInfo: NutritionalInfo(
          calories: (caloriesPerServing * quantity).round(),
          carbs: (carbsPerServing * quantity).round(),
          protein: (proteinPerServing * quantity).round(),
          fat: (fatPerServing * quantity).round(),
          sodium: (sodiumPerServing * quantity).round(),
          fluids: fluidPerServing * quantity,
        ),
        displayName: displayName,
        displayNamePlural: displayNamePlural,
        servingSize: foodJson['serving_size'] as String?,
        templateId: best.id,
        scaleMultiplier: clampedScale,
      ));
    }

    return result.isEmpty ? null : result;
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  int _sumNutrient(
    List<FoodItemData> a,
    List<FoodItemData> b,
    List<FoodItemData> c,
    int Function(NutritionalInfo) getter,
  ) {
    int sum = 0;
    for (final list in [a, b, c]) {
      for (final item in list) {
        if (item.nutritionalInfo != null) {
          sum += getter(item.nutritionalInfo!);
        }
      }
    }
    return sum;
  }

  double _sumNutrientDouble(
    List<FoodItemData> a,
    List<FoodItemData> b,
    List<FoodItemData> c,
    double Function(NutritionalInfo) getter,
  ) {
    double sum = 0;
    for (final list in [a, b, c]) {
      for (final item in list) {
        if (item.nutritionalInfo != null) {
          sum += getter(item.nutritionalInfo!);
        }
      }
    }
    return sum;
  }

  List<String> _parseJsonList(String? jsonStr) {
    if (jsonStr == null || jsonStr.isEmpty) return [];
    try {
      final decoded = jsonDecode(jsonStr);
      if (decoded is List) return decoded.cast<String>();
    } catch (_) {}
    return [];
  }
}

/// Provider for [ClientPlanService].
final clientPlanServiceProvider = Provider<ClientPlanService>((ref) {
  return ClientPlanService(ref);
});
