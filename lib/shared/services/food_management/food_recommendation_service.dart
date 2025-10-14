import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../features/nutrition_plan/domain/food.dart';
import '../../../features/auth/domain/user_preferences.dart';
import '../app_external_deps.dart';
import '../logging_service.dart';
import 'user_food_crud_service.dart';
import '../../../features/nutrition_plan/data/food_repository.dart';

/// Provider for FoodRecommendationService
final foodRecommendationServiceProvider = Provider<FoodRecommendationService>((ref) {
  final userFoodService = ref.read(userFoodCrudServiceProvider);
  final foodRepository = ref.read(foodRepositoryProvider);
  final logger = ref.read(appExternalDepsProvider).logger;
  return FoodRecommendationService(
    userFoodService,
    foodRepository,
    logger,
  );
});

/// Service for generating smart food recommendations
/// Combines user foods and generic foods with preference-based sorting

class FoodRecommendationService {
  FoodRecommendationService(this._userFoodService, this._foodRepository, this._logger);

  final UserFoodCrudService _userFoodService;
  final FoodRepository _foodRepository;
  final AppLogger _logger;

  /// Get smart recommendations for food selection
  /// Combines user foods and generic foods based on context
  Future<List<Food>> getRecommendations({
    String? productTypeId,     // For swap scenarios (match same product type)
    String? category,           // For add scenarios (match timing category)
    Map<String, FoodPreference> preferences = const {},
    int maxResults = 10,
    String? deviceId,
  }) async {
    try {
      _logger.debug('Getting recommendations',
        context: 'FoodRecommendationService',
        data: {
          'productTypeId': productTypeId,
          'category': category,
          'maxResults': maxResults,
        },
      );

      // Load both user foods and generic foods
      final userFoods = deviceId != null
          ? await _userFoodService.getUserFoods(deviceId)
          : <Food>[];

      final genericFoodItems = await _foodRepository.getAllFoods();
      final genericFoods = genericFoodItems.map((item) => _convertFoodItemToFood(item)).toList();

      // Combine all foods
      final allFoods = [...userFoods, ...genericFoods];

      // Filter based on context
      List<Food> filteredFoods;

      if (productTypeId != null) {
        // Swap scenario: match product type
        filteredFoods = allFoods.where((food) =>
          food.productTypeId == productTypeId
        ).toList();

        _logger.debug('Filtered by product type: ${filteredFoods.length} foods');
      } else if (category != null) {
        // Add scenario: match category/timing suitability
        filteredFoods = _filterByCategory(allFoods, category);

        _logger.debug('Filtered by category $category: ${filteredFoods.length} foods');
      } else {
        // No specific filtering
        filteredFoods = allFoods;
      }

      // Apply preference-based sorting and limiting
      final recommendations = sortByPreferences(
        filteredFoods,
        preferences,
        maxResults: maxResults,
      );

      _logger.debug('Generated ${recommendations.length} recommendations');
      return recommendations;

    } catch (e) {
      _logger.error('Error getting recommendations',
        context: 'FoodRecommendationService',
        error: e,
      );
      return [];
    }
  }

  /// Apply preference-based sorting to food list
  /// Priority: Love → Willing to Try → Neutral → Avoided (grayed)
  List<Food> sortByPreferences(
    List<Food> foods,
    Map<String, FoodPreference> preferences, {
    int? maxResults,
  }) {
    // Separate foods by preference
    final lovedFoods = <Food>[];
    final willingFoods = <Food>[];
    final neutralFoods = <Food>[];
    final avoidedFoods = <Food>[];

    for (final food in foods) {
      final preference = preferences[food.name];

      switch (preference) {
        case FoodPreference.like:
          lovedFoods.add(food);
          break;
        case FoodPreference.willingToTry:
          willingFoods.add(food);
          break;
        case FoodPreference.dislike:
          avoidedFoods.add(food);
          break;
        case null:
          neutralFoods.add(food);
          break;
      }
    }

    // Sort each group alphabetically for consistency
    lovedFoods.sort((a, b) => a.name.compareTo(b.name));
    willingFoods.sort((a, b) => a.name.compareTo(b.name));
    neutralFoods.sort((a, b) => a.name.compareTo(b.name));
    avoidedFoods.sort((a, b) => a.name.compareTo(b.name));

    // Combine in priority order
    final sortedFoods = [
      ...lovedFoods,
      ...willingFoods,
      ...neutralFoods,
      ...avoidedFoods,  // Include but will be grayed out in UI
    ];

    // Apply max results if specified
    if (maxResults != null && sortedFoods.length > maxResults) {
      return sortedFoods.take(maxResults).toList();
    }

    return sortedFoods;
  }

  /// Filter foods by category/timing suitability
  List<Food> _filterByCategory(List<Food> foods, String category) {
    return foods.where((food) {
      switch (category.toLowerCase()) {
        case 'before_run':
        case 'before':
          return food.beforeRunSuitable;
        case 'during_run':
        case 'during':
          return food.duringRunSuitable;
        case 'after_run':
        case 'after':
          return true; // All foods suitable after run
        default:
          return true; // Unknown category, include all
      }
    }).toList();
  }

  /// Check if a food should be shown as avoided (grayed out)
  bool isAvoided(Food food, Map<String, FoodPreference> preferences) {
    return preferences[food.name] == FoodPreference.dislike;
  }

  /// Get preference display info for a food
  FoodPreferenceInfo getPreferenceInfo(Food food, Map<String, FoodPreference> preferences) {
    final preference = preferences[food.name];

    return FoodPreferenceInfo(
      preference: preference ?? FoodPreference.willingToTry,
      isAvoided: preference == FoodPreference.dislike,
      priority: _getPreferencePriority(preference),
    );
  }

  /// Get numeric priority for sorting (lower = higher priority)
  int _getPreferencePriority(FoodPreference? preference) {
    switch (preference) {
      case FoodPreference.like:
        return 1;
      case FoodPreference.willingToTry:
        return 2;
      case null:
        return 3;
      case FoodPreference.dislike:
        return 4;
    }
  }

  /// Convert FoodItem to Food domain object
  Food _convertFoodItemToFood(dynamic foodItem) {
    return Food(
      id: foodItem.id,
      name: foodItem.name,
      displayName: foodItem.displayName,
      displayNamePlural: foodItem.displayNamePlural,
      description: foodItem.description,
      imageAddress: foodItem.imageAddress,
      instructions: foodItem.instructions ?? '',
      servingAmount: foodItem.servingAmount,
      servingUnit: foodItem.servingUnit,
      servingUnitPlural: foodItem.servingUnitPlural,
      servingQualifier: foodItem.servingQualifier,
      beforeRunSuitable: foodItem.beforeRunSuitable,
      duringRunSuitable: foodItem.duringRunSuitable,
      carbsPerServing: foodItem.carbsPerServing,
      proteinPerServing: foodItem.proteinPerServing,
      fatPerServing: foodItem.fatPerServing,
      caloriesPerServing: foodItem.caloriesPerServing,
      fluidMlPerServing: foodItem.fluidMlPerServing,
      sodiumMg: foodItem.sodiumMg,
      productTypeId: foodItem.productTypeId,
    );
  }
}

/// Information about food preference for UI display
class FoodPreferenceInfo {
  const FoodPreferenceInfo({
    required this.preference,
    required this.isAvoided,
    required this.priority,
  });

  final FoodPreference preference;
  final bool isAvoided;
  final int priority;  // Lower = higher priority
}
