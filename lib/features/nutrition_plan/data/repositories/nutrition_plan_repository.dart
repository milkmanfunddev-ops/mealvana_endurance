import 'package:hive/hive.dart';
import '../models/nutrition_plan.dart';

/// Repository for managing nutrition plans in Hive
class NutritionPlanRepository {
  static const String _boxName = 'nutrition_plans';
  
  late Box<NutritionPlan> _planBox;
  
  /// Initialize the repository and open Hive box
  Future<void> init() async {
    _planBox = await Hive.openBox<NutritionPlan>(_boxName);
  }

  /// Save a nutrition plan
  Future<void> savePlan(NutritionPlan plan) async {
    await _planBox.put(plan.id, plan);
  }

  /// Get a nutrition plan by ID
  NutritionPlan? getPlan(String planId) {
    return _planBox.get(planId);
  }

  /// Get all nutrition plans for a specific user
  List<NutritionPlan> getPlansForUser(String userId) {
    return _planBox.values
        .where((plan) => plan.userId == userId)
        .toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt)); // Most recent first
  }

  /// Get the most recent nutrition plan for a user
  NutritionPlan? getLatestPlanForUser(String userId) {
    final userPlans = getPlansForUser(userId);
    return userPlans.isNotEmpty ? userPlans.first : null;
  }

  /// Update a nutrition plan
  Future<void> updatePlan(NutritionPlan plan) async {
    final updatedPlan = NutritionPlan(
      id: plan.id,
      userId: plan.userId,
      distanceMiles: plan.distanceMiles,
      paceMinutesPerMile: plan.paceMinutesPerMile,
      durationHours: plan.durationHours,
      totalCarbs: plan.totalCarbs,
      totalSodium: plan.totalSodium,
      totalFluids: plan.totalFluids,
      carbsPerHour: plan.carbsPerHour,
      sodiumPerHour: plan.sodiumPerHour,
      fluidsPerHour: plan.fluidsPerHour,
      preRunMeals: plan.preRunMeals,
      duringRunMeals: plan.duringRunMeals,
      postRunMeals: plan.postRunMeals,
      createdAt: plan.createdAt,
      updatedAt: DateTime.now(),
    );
    await _planBox.put(plan.id, updatedPlan);
  }

  /// Delete a nutrition plan
  Future<void> deletePlan(String planId) async {
    await _planBox.delete(planId);
  }

  /// Delete all plans for a user
  Future<void> deleteAllPlansForUser(String userId) async {
    final userPlans = getPlansForUser(userId);
    for (final plan in userPlans) {
      await _planBox.delete(plan.id);
    }
  }

  /// Get all nutrition plans (for admin/debugging)
  List<NutritionPlan> getAllPlans() {
    return _planBox.values.toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  /// Get plans by distance range
  List<NutritionPlan> getPlansByDistance(String userId, double minMiles, double maxMiles) {
    return getPlansForUser(userId)
        .where((plan) => plan.distanceMiles >= minMiles && plan.distanceMiles <= maxMiles)
        .toList();
  }

  /// Get plans by duration range
  List<NutritionPlan> getPlansByDuration(String userId, double minHours, double maxHours) {
    return getPlansForUser(userId)
        .where((plan) => plan.durationHours >= minHours && plan.durationHours <= maxHours)
        .toList();
  }

  /// Check if a plan exists
  bool planExists(String planId) {
    return _planBox.containsKey(planId);
  }

  /// Get plan count for a user
  int getPlanCount(String userId) {
    return getPlansForUser(userId).length;
  }

  /// Get plans created in the last N days
  List<NutritionPlan> getRecentPlans(String userId, int days) {
    final cutoffDate = DateTime.now().subtract(Duration(days: days));
    return getPlansForUser(userId)
        .where((plan) => plan.createdAt.isAfter(cutoffDate))
        .toList();
  }

  /// Get nutrition plan statistics for a user
  Map<String, dynamic> getPlanStatistics(String userId) {
    final plans = getPlansForUser(userId);
    
    if (plans.isEmpty) {
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

    final totalDistance = plans.fold(0.0, (sum, plan) => sum + plan.distanceMiles);
    final totalDuration = plans.fold(0.0, (sum, plan) => sum + plan.durationHours);
    final totalPace = plans.fold(0.0, (sum, plan) => sum + plan.paceMinutesPerMile);
    final totalCarbs = plans.fold(0.0, (sum, plan) => sum + plan.totalCarbs);
    final totalSodium = plans.fold(0.0, (sum, plan) => sum + plan.totalSodium);
    final totalFluids = plans.fold(0.0, (sum, plan) => sum + plan.totalFluids);

    return {
      'totalPlans': plans.length,
      'averageDistance': totalDistance / plans.length,
      'averageDuration': totalDuration / plans.length,
      'averagePace': totalPace / plans.length,
      'averageCarbs': totalCarbs / plans.length,
      'averageSodium': totalSodium / plans.length,
      'averageFluids': totalFluids / plans.length,
    };
  }

  /// Clear all nutrition plans (for testing/reset)
  Future<void> clearAllPlans() async {
    await _planBox.clear();
  }

  /// Close the repository and Hive box
  Future<void> close() async {
    await _planBox.close();
  }
}