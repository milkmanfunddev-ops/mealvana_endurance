import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/services/app_external_deps.dart';
import '../../../shared/services/sentry/sentry_reporter.dart';
import '../../auth/application/auth_service.dart';
import '../data/food_repository.dart';
import '../data/nutrition_plan_repository.dart';
import '../domain/food_item.dart';
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
    bool debug = false,
  }) async {
    final user = await _authService.getCurrentUser();
    if (user == null) {
      throw Exception('No user found. Please complete onboarding first.');
    }

    // Analytics tracking will be done at the controller level with proper plan_id threading

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
        
        // Analytics tracking moved to controller level
        
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

      // FALLBACK: Use algorithmic run-plan Edge Function if LLM fails
      _sentry.addBreadcrumb(
        message: 'Falling back to algorithmic nutrition plan',
        category: 'nutrition_plan',
        data: {
          'reason': 'llm_failed_or_unavailable',
        },
      );

      // Convert distance/pace to weight/duration for new run-plan Edge Function
      final weightKg = user.weightPounds * 0.453592; // Convert pounds to kg
      final durationMin = (distanceMiles * paceMinutesPerMile).round(); // Total duration in minutes
      final preWindowMin = (timeBeforeRunHours * 60).round(); // Convert hours to minutes
      final paceMinPerKm = paceMinutesPerMile / 1.60934; // Convert pace to min/km for optional ACSM calculation
      
      // Use user's gut training level if not overridden
      final effectiveGutTraining = gutTrainingLevel ?? user.gutTrainingLevel.name;

      // Call new run-plan Edge Function
      final planRepository = await _planRepository;
      final result = await planRepository.createNutritionPlanV2(
        deviceId: user.id,
        weightKg: weightKg,
        durationMin: durationMin,
        preWindowMin: preWindowMin,
        gutTraining: effectiveGutTraining,
        giSensitivity: giSensitivity,
        tempF: tempF,
        humidity: humidity,
        sweatRate: sweatRate,
        allowHighCarbRun: allowHighCarbRun,
        paceMinPerKm: paceMinPerKm,
        debug: debug,
      );

      if (result.success && result.plan != null) {
        final plan = result.plan!;
        
        // Track successful plan generation
        // Analytics tracking moved to controller level

        // Plan is already cached locally in the repository
        
        return plan;
      } else {
        // Analytics tracking moved to controller level
        throw Exception(result.message ?? 'Failed to generate nutrition plan');
      }
    } catch (e) {
      // Analytics tracking moved to controller level
      rethrow;
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
    final user = await _authService.getCurrentUser();
    if (user == null) {
      throw Exception('No user found. Please complete onboarding first.');
    }

    final planRepository = await _planRepository;
    final result = await planRepository.updateNutritionPlan(
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
    
    final planRepository = await _planRepository;
    return await planRepository.deleteNutritionPlan(user.id, planId);
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
