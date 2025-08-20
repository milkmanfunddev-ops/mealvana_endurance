import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/nutrition_plan_repository.dart';
import '../data/nutrition_plan_local_cache.dart';
import '../domain/nutrition_plan.dart';
import '../domain/food_item.dart';
import '../data/food_repository.dart';
// nutrition_calculator.dart - removed since logic moved to Edge Functions
import '../../auth/application/auth_service.dart';
// content_service.dart - removed since algorithm logic moved to Edge Functions
import '../../../shared/services/analytics_service.dart';

/// Application service for managing nutrition plans and food data
/// Coordinates between food database, nutrition calculations, and plan storage
class NutritionPlanService {
  NutritionPlanService(this.ref);
  final Ref ref;

  /// Get repositories and services
  NutritionPlanRepository get _planRepository => ref.read(nutritionPlanRepositoryProvider);
  NutritionPlanLocalCache get _localCache => ref.read(nutritionPlanLocalCacheProvider);
  AuthService get _authService => ref.read(authServiceProvider);
  // Content service removed since algorithm logic moved to Edge Functions
  FoodRepository get _foodRepository => ref.read(foodRepositoryProvider);
  AnalyticsService get _analyticsService => ref.read(analyticsServiceProvider);
  
  // Nutrition calculator removed - all logic moved to Edge Functions

  /// Generate a new nutrition plan for the current user using Edge Function
  Future<NutritionPlan> generateNutritionPlan({
    required double distanceMiles,
    required double paceMinutesPerMile,
    double timeBeforeRunHours = 2.0,
    String? gutTrainingLevel,
  }) async {
    final user = await _authService.getCurrentUser();
    if (user == null) {
      throw Exception('No user found. Please complete onboarding first.');
    }

    // Track plan generation started
    await _analyticsService.trackNutritionPlanGenerationStarted(
      distanceMiles: distanceMiles,
      paceMinutesPerMile: paceMinutesPerMile,
      timeBeforeRunHours: timeBeforeRunHours,
      gutTrainingLevel: gutTrainingLevel,
    );

    final startTime = DateTime.now();
    
    try {
      // Call Edge Function to create nutrition plan with all business logic server-side
      final result = await _planRepository.createNutritionPlan(
        deviceId: user.id,
        distanceMiles: distanceMiles,
        paceMinutesPerMile: paceMinutesPerMile,
        timeBeforeRunHours: timeBeforeRunHours,
        gutTrainingLevel: gutTrainingLevel,
      );

      final responseTime = DateTime.now().difference(startTime);

      if (result.success && result.plan != null) {
        final plan = result.plan!;
        
        // Track successful plan generation
        await _analyticsService.trackNutritionPlanGenerated(
          distanceMiles: distanceMiles,
          paceMinutesPerMile: paceMinutesPerMile,
          totalCalories: plan.totalCalories ?? 0,
          totalCarbs: plan.macroTargets?.carbs ?? 0,
          beforeRunItems: plan.sections.where((s) => s.title.contains('Before')).firstOrNull?.foodItems.length ?? 0,
          duringRunItems: plan.sections.where((s) => s.title.contains('During')).firstOrNull?.foodItems.length ?? 0,
          afterRunItems: plan.sections.where((s) => s.title.contains('After')).firstOrNull?.foodItems.length ?? 0,
          isFirstPlan: await _isFirstPlan(),
        );
        
        // Track Edge Function performance
        await _analyticsService.trackEdgeFunctionPerformance(
          functionName: 'create-nutrition-plan',
          responseTime: responseTime,
          success: true,
        );
        
        // Cache the plan locally
        await _localCache.saveLatestPlan(plan);
        
        return plan;
      } else {
        // Track failed generation
        await _analyticsService.trackNutritionPlanGenerationFailed(
          errorMessage: result.message ?? 'Unknown error',
          distanceMiles: distanceMiles,
          paceMinutesPerMile: paceMinutesPerMile,
        );
        
        // Track Edge Function performance
        await _analyticsService.trackEdgeFunctionPerformance(
          functionName: 'create-nutrition-plan',
          responseTime: responseTime,
          success: false,
          errorMessage: result.message,
        );
        
        throw Exception(result.message ?? 'Failed to generate nutrition plan');
      }
    } catch (e) {
      final responseTime = DateTime.now().difference(startTime);
      
      // Track failed generation
      await _analyticsService.trackNutritionPlanGenerationFailed(
        errorMessage: e.toString(),
        distanceMiles: distanceMiles,
        paceMinutesPerMile: paceMinutesPerMile,
      );
      
      // Track Edge Function performance
      await _analyticsService.trackEdgeFunctionPerformance(
        functionName: 'create-nutrition-plan',
        responseTime: responseTime,
        success: false,
        errorMessage: e.toString(),
      );
      
      rethrow;
    }
  }
  
  /// Check if this is the user's first nutrition plan
  Future<bool> _isFirstPlan() async {
    final user = await _authService.getCurrentUser();
    if (user == null) return false;
    
    final plans = await getUserNutritionPlans();
    return plans.isEmpty;
  }

  /// Get nutrition plans for the current user
  Future<List<NutritionPlan>> getUserNutritionPlans() async {
    final user = await _authService.getCurrentUser();
    if (user == null) return [];
    
    return await _planRepository.getNutritionPlans(user.id);
  }

  /// Get the most recent nutrition plan for current user
  /// Checks local cache first, falls back to Supabase
  Future<NutritionPlan?> getLatestNutritionPlan() async {
    final user = await _authService.getCurrentUser();
    if (user == null) return null;
    
    // Try to get from local cache first
    final cachedPlan = await _localCache.getLatestPlan();
    if (cachedPlan != null) {
      return cachedPlan;
    }
    
    // If not in cache, try to get from Supabase
    final remotePlan = await _planRepository.getLatestNutritionPlan(user.id);
    if (remotePlan != null) {
      // Cache the plan for next time
      await _localCache.saveLatestPlan(remotePlan);
    }
    
    return remotePlan;
  }

  /// Update an existing nutrition plan via Edge Function
  Future<NutritionPlan> updateNutritionPlan({
    required double distanceMiles,
    required double paceMinutesPerMile,
    double timeBeforeRunHours = 2.0,
    String? gutTrainingLevel,
  }) async {
    final user = await _authService.getCurrentUser();
    if (user == null) {
      throw Exception('No user found. Please complete onboarding first.');
    }

    final result = await _planRepository.updateNutritionPlan(
      deviceId: user.id,
      distanceMiles: distanceMiles,
      paceMinutesPerMile: paceMinutesPerMile,
      timeBeforeRunHours: timeBeforeRunHours,
      gutTrainingLevel: gutTrainingLevel,
    );

    if (result.success && result.plan != null) {
      return result.plan!;
    } else {
      throw Exception(result.message ?? 'Failed to update nutrition plan');
    }
  }

  /// Delete a nutrition plan
  Future<bool> deleteNutritionPlan(String planId) async {
    final user = await _authService.getCurrentUser();
    if (user == null) return false;
    
    return await _planRepository.deleteNutritionPlan(user.id, planId);
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

    final likedFoods = _authService.getLikedFoods(user.id);
    
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
    
    return await _planRepository.getNutritionPlanStatistics(user.id);
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
    
    return await _planRepository.clearAllNutritionPlans(user.id);
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