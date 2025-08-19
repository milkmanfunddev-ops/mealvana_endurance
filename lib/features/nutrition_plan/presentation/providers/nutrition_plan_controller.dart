import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:mealvana_endurance/features/nutrition_plan/domain/nutrition_plan.dart';
import '../../../content/application/content_service.dart';
import '../../../content/domain/content_keys.dart';
import '../../application/nutrition_plan_service.dart';

part 'nutrition_plan_controller.g.dart';

/// Controller for managing nutrition plan generation and display
@riverpod
class NutritionPlanController extends _$NutritionPlanController {
  NutritionPlanService get _nutritionPlanService => ref.read(nutritionPlanServiceProvider);
  ContentService get _contentService => ref.read(contentServiceProvider);

  @override
  FutureOr<NutritionPlan?> build() {
    // Initialize with the latest nutrition plan or null
    return _nutritionPlanService.getLatestNutritionPlan();
  }

  /// Generate a new nutrition plan
  Future<NutritionPlan?> generatePlan({
    required double distanceMiles,
    required double paceMinutesPerMile,
  }) async {
    state = const AsyncLoading();

    state = await AsyncValue.guard(() async {
      final plan = await _nutritionPlanService.generateNutritionPlan(
        distanceMiles: distanceMiles,
        paceMinutesPerMile: paceMinutesPerMile,
      );

      return plan;
    });

    return state.valueOrNull;
  }


  /// Update an existing plan with new parameters
  Future<void> updatePlan({
    required double distanceMiles,
    required double paceMinutesPerMile,
    double timeBeforeRunHours = 2.0,
    String? gutTrainingLevel,
  }) async {
    state = await AsyncValue.guard(() async {
      final updatedPlan = await _nutritionPlanService.updateNutritionPlan(
        distanceMiles: distanceMiles,
        paceMinutesPerMile: paceMinutesPerMile,
        timeBeforeRunHours: timeBeforeRunHours,
        gutTrainingLevel: gutTrainingLevel,
      );
      return updatedPlan;
    });
  }

  /// Delete a plan
  Future<void> deletePlan(String planId) async {
    final currentPlan = state.valueOrNull;
    
    state = await AsyncValue.guard(() async {
      await _nutritionPlanService.deleteNutritionPlan(planId);
      // If we just deleted the current plan, return null
      if (currentPlan?.id == planId) {
        return null;
      }
      return currentPlan;
    });
  }

  /// Get nutrition recommendations for current plan
  List<String> getRecommendations() {
    final plan = state.valueOrNull;
    if (plan == null) return [];
    
    return _nutritionPlanService.getNutritionRecommendations(plan);
  }

  /// Validate current plan for safety
  bool validateCurrentPlan() {
    final plan = state.valueOrNull;
    if (plan == null) return false;
    
    return _nutritionPlanService.validateNutritionPlan(plan);
  }

  /// Get plan statistics for the user
  Future<Map<String, dynamic>> getPlanStatistics() async {
    return await _nutritionPlanService.getNutritionPlanStatistics();
  }

  /// Clear current plan (reset state)
  void clearCurrentPlan() {
    state = const AsyncData(null);
  }
  
  /// Get content-driven error message
  String getErrorMessage(String? error) {
    return _contentService.getValue(ContentKeys.errorGeneric, 
        defaultValue: error ?? 'Something went wrong. Please try again.');
  }
}

/// Provider for current nutrition plan
@riverpod
NutritionPlan? currentNutritionPlan(Ref ref) {
  final controller = ref.watch(nutritionPlanControllerProvider);
  return controller.valueOrNull;
}

/// Provider for nutrition recommendations
@riverpod
List<String> nutritionRecommendations(Ref ref) {
  final controller = ref.read(nutritionPlanControllerProvider.notifier);
  return controller.getRecommendations();
}