import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/nutrition_plan_repository.dart';
import '../domain/nutrition_plan.dart';
import '../domain/food_item.dart';
import '../data/food_database.dart';
import 'nutrition_calculator.dart';
import '../../auth/application/auth_service.dart';

/// Application service for managing nutrition plans and food data
/// Coordinates between food database, nutrition calculations, and plan storage
class NutritionPlanService {
  NutritionPlanService(this.ref);
  final Ref ref;

  /// Get repositories and services
  NutritionPlanRepository get _planRepository => ref.read(nutritionPlanRepositoryProvider);
  AuthService get _authService => ref.read(authServiceProvider);

  /// Generate a new nutrition plan for the current user
  Future<NutritionPlan> generateNutritionPlan({
    required double distanceMiles,
    required double paceMinutesPerMile,
  }) async {
    final user = _authService.getCurrentUser();
    if (user == null) {
      throw Exception('No user found. Please complete onboarding first.');
    }

    // Get user food preferences
    final likedFoods = _authService.getLikedFoods(user.id);

    // Calculate base nutrition requirements
    final plan = NutritionCalculator.calculateNutritionPlan(
      distanceMiles: distanceMiles,
      paceMinutesPerMile: paceMinutesPerMile,
      userProfile: user,
      likedFoods: likedFoods,
    );

    // Save the plan
    await _planRepository.savePlan(plan);
    
    return plan;
  }

  /// Get nutrition plans for the current user
  List<NutritionPlan> getUserNutritionPlans() {
    final user = _authService.getCurrentUser();
    if (user == null) return [];
    
    return _planRepository.getPlansForUser(user.id);
  }

  /// Get the most recent nutrition plan for current user
  NutritionPlan? getLatestNutritionPlan() {
    final user = _authService.getCurrentUser();
    if (user == null) return null;
    
    return _planRepository.getLatestPlanForUser(user.id);
  }

  /// Update an existing nutrition plan
  Future<void> updateNutritionPlan(NutritionPlan plan) async {
    await _planRepository.updatePlan(plan);
  }

  /// Delete a nutrition plan
  Future<void> deleteNutritionPlan(String planId) async {
    await _planRepository.deletePlan(planId);
  }

  /// Get all available foods from the database
  List<FoodItem> getAllFoods() {
    return FoodDatabase.getAllFoods();
  }

  /// Get foods by category
  List<FoodItem> getFoodsByCategory(FoodCategory category) {
    return FoodDatabase.getFoodsByCategory(category);
  }

  /// Get a specific food by ID
  FoodItem? getFoodById(String id) {
    return FoodDatabase.getFoodById(id);
  }

  /// Get foods that the current user prefers for a specific category
  List<FoodItem> getPreferredFoods(FoodCategory category) {
    final user = _authService.getCurrentUser();
    if (user == null) return [];

    final likedFoods = _authService.getLikedFoods(user.id);
    
    return FoodDatabase.getPreferredFoods(category, likedFoods, []);
  }

  /// Search foods by query
  List<FoodItem> searchFoods(String query) {
    return FoodDatabase.searchFoods(query);
  }

  /// Get nutrition plan statistics for current user
  Map<String, dynamic> getNutritionPlanStatistics() {
    final user = _authService.getCurrentUser();
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
    
    return _planRepository.getPlanStatistics(user.id);
  }

  /// Validate a nutrition plan for safety
  bool validateNutritionPlan(NutritionPlan plan) {
    return NutritionCalculator.validateNutritionPlan(plan);
  }

  /// Get nutrition recommendations for a plan
  List<String> getNutritionRecommendations(NutritionPlan plan) {
    final user = _authService.getCurrentUser();
    if (user == null) return [];
    
    return NutritionCalculator.getNutritionRecommendations(plan, user);
  }

  /// Calculate pre-run nutrition requirements
  Map<String, dynamic> calculatePreRunNutrition(double durationHours) {
    final user = _authService.getCurrentUser();
    if (user == null) throw Exception('No user found');
    
    return NutritionCalculator.calculatePreRunNutrition(user, durationHours);
  }

  /// Calculate post-run nutrition requirements
  Map<String, dynamic> calculatePostRunNutrition() {
    final user = _authService.getCurrentUser();
    if (user == null) throw Exception('No user found');
    
    return NutritionCalculator.calculatePostRunNutrition(user);
  }

  /// Get nutrition plan summary for dashboard/overview
  Map<String, dynamic> getNutritionSummary() {
    final plans = getUserNutritionPlans();
    final statistics = getNutritionPlanStatistics();
    final latestPlan = getLatestNutritionPlan();

    return {
      'totalPlans': plans.length,
      'statistics': statistics,
      'latestPlan': latestPlan,
      'hasRecentPlan': latestPlan != null,
    };
  }

  /// Clear all nutrition plans (for testing)
  Future<void> clearAllPlans() async {
    await _planRepository.clearAllPlans();
  }
}

/// Provider for NutritionPlanService
final nutritionPlanServiceProvider = Provider<NutritionPlanService>((ref) {
  return NutritionPlanService(ref);
});

/// Provider for NutritionPlanRepository
final nutritionPlanRepositoryProvider = Provider<NutritionPlanRepository>((ref) {
  // This will be overridden in main.dart after Hive initialization
  throw UnimplementedError('NutritionPlanRepository not initialized');
});

/// Provider for user's nutrition plans
final userNutritionPlansProvider = Provider<List<NutritionPlan>>((ref) {
  final service = ref.watch(nutritionPlanServiceProvider);
  return service.getUserNutritionPlans();
});

/// Provider for latest nutrition plan
final latestNutritionPlanProvider = Provider<NutritionPlan?>((ref) {
  final service = ref.watch(nutritionPlanServiceProvider);
  return service.getLatestNutritionPlan();
});