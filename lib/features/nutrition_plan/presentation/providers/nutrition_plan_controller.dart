import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../application/nutrition_plan_service.dart';
import '../../data/models/nutrition_plan.dart';

/// Controller for managing nutrition plan generation and display
class NutritionPlanController extends StateNotifier<AsyncValue<NutritionPlan?>> {
  NutritionPlanController(this._nutritionPlanService) : super(const AsyncData(null));

  final NutritionPlanService _nutritionPlanService;

  /// Generate a new nutrition plan
  Future<NutritionPlan?> generatePlan({
    required double distanceMiles,
    required double paceMinutesPerMile,
  }) async {
    state = const AsyncLoading();

    try {
      final plan = await _nutritionPlanService.generateNutritionPlan(
        distanceMiles: distanceMiles,
        paceMinutesPerMile: paceMinutesPerMile,
      );

      state = AsyncData(plan);
      return plan;
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
      return null;
    }
  }

  /// Get the current/latest nutrition plan
  NutritionPlan? getCurrentPlan() {
    return state.valueOrNull ?? _nutritionPlanService.getLatestNutritionPlan();
  }

  /// Update an existing plan
  Future<void> updatePlan(NutritionPlan plan) async {
    try {
      await _nutritionPlanService.updateNutritionPlan(plan);
      state = AsyncData(plan);
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
    }
  }

  /// Delete a plan
  Future<void> deletePlan(String planId) async {
    try {
      await _nutritionPlanService.deleteNutritionPlan(planId);
      // If we just deleted the current plan, clear the state
      if (state.valueOrNull?.id == planId) {
        state = const AsyncData(null);
      }
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
    }
  }

  /// Get nutrition recommendations for current plan
  List<String> getRecommendations() {
    final plan = getCurrentPlan();
    if (plan == null) return [];
    
    return _nutritionPlanService.getNutritionRecommendations(plan);
  }

  /// Validate current plan for safety
  bool validateCurrentPlan() {
    final plan = getCurrentPlan();
    if (plan == null) return false;
    
    return _nutritionPlanService.validateNutritionPlan(plan);
  }

  /// Get plan statistics for the user
  Map<String, dynamic> getPlanStatistics() {
    return _nutritionPlanService.getNutritionPlanStatistics();
  }

  /// Clear current plan (reset state)
  void clearCurrentPlan() {
    state = const AsyncData(null);
  }
}

/// Provider for nutrition plan controller
final nutritionPlanControllerProvider = 
    StateNotifierProvider<NutritionPlanController, AsyncValue<NutritionPlan?>>((ref) {
  final nutritionPlanService = ref.watch(nutritionPlanServiceProvider);
  return NutritionPlanController(nutritionPlanService);
});

/// Provider for current nutrition plan
final currentNutritionPlanProvider = Provider<NutritionPlan?>((ref) {
  final controller = ref.watch(nutritionPlanControllerProvider);
  return controller.valueOrNull;
});

/// Provider for nutrition recommendations
final nutritionRecommendationsProvider = Provider<List<String>>((ref) {
  final controller = ref.read(nutritionPlanControllerProvider.notifier);
  return controller.getRecommendations();
});