import 'dart:async';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../domain/food.dart';
import '../../domain/food_item.dart';
import '../../data/food_repository.dart';
import '../providers/nutrition_plan_controller.dart';
import '../../../../shared/services/logging_service.dart';
import '../../../../shared/database/database_provider.dart';

part 'swap_food_controller.g.dart';

/// Parameters for the swap food controller
class SwapFoodParams {
  const SwapFoodParams({
    required this.category,
    this.originalFoodId,
    this.originalFoodName,
  });

  final String category; // Keep for context (before_run, during_run, after_run)
  final String? originalFoodId; // Food being swapped (for product type matching)
  final String? originalFoodName; // Food name being swapped (fallback if ID lookup fails)
}

/// State for the swap food screen
class SwapFoodState {
  const SwapFoodState({
    required this.availableFoods,
    required this.searchResults,
    this.allFoodsForSearch,
    this.selectedFood,
    this.searchQuery = '',
    this.isSearching = false,
  });

  final List<Food> availableFoods; // Generic foods for recommendations
  final List<Food> searchResults; // Current search results or recommendations
  final List<Food>? allFoodsForSearch; // All foods (including branded) for searching
  final Food? selectedFood;
  final String searchQuery;
  final bool isSearching;
  
  SwapFoodState copyWith({
    List<Food>? availableFoods,
    List<Food>? searchResults,
    List<Food>? allFoodsForSearch,
    Food? selectedFood,
    bool clearSelectedFood = false,
    String? searchQuery,
    bool? isSearching,
  }) {
    return SwapFoodState(
      availableFoods: availableFoods ?? this.availableFoods,
      searchResults: searchResults ?? this.searchResults,
      allFoodsForSearch: allFoodsForSearch ?? this.allFoodsForSearch,
      selectedFood: clearSelectedFood ? null : (selectedFood ?? this.selectedFood),
      searchQuery: searchQuery ?? this.searchQuery,
      isSearching: isSearching ?? this.isSearching,
    );
  }
}

/// Provider for food repository
@riverpod
FoodRepository foodRepository(Ref ref) {
  final database = ref.read(appDatabaseProvider);
  return FoodRepository(Supabase.instance.client, database);
}

/// Controller for swap food functionality - takes swap parameters
@riverpod
class SwapFoodController extends _$SwapFoodController {

  @override
  FutureOr<SwapFoodState> build(SwapFoodParams params) async {
    // Auto-initialize with foods based on original food's product type
    return await _loadFoodsForSwapping(params);
  }
  
  Future<SwapFoodState> _loadFoodsForSwapping(SwapFoodParams params) async {
    // Load all foods (no category restrictions)
    AppLogger.instance.debug('Loading generic foods for swap food page');
    final genericFoods = await _getGenericFoodsWithCache();
    AppLogger.instance.debug('Loaded ${genericFoods.length} generic foods');

    AppLogger.instance.debug('Loading all foods including branded');
    final allFoods = await _getAllFoodsIncludingBrandedWithCache();
    AppLogger.instance.debug('Loaded ${allFoods.length} total foods (including branded)');

    // Find the original food to get its product type
    Food? originalFood;
    if (params.originalFoodId != null) {
      originalFood = allFoods.where((food) => food.id == params.originalFoodId).firstOrNull;
      AppLogger.instance.debug('Found original food: ${originalFood?.name}, productTypeId: ${originalFood?.productTypeId}');
    } else {
      AppLogger.instance.debug('No original food ID provided - this is an "Add" operation');
    }

    // Get recommendations based on same product type
    AppLogger.instance.debug('Getting product type recommendations');
    final availableFoods = await _getRecommendationsByProductType(
      originalFood,
      genericFoods,
      allFoods,
    );
    AppLogger.instance.debug('Got ${availableFoods.length} recommendations');

    return SwapFoodState(
      availableFoods: availableFoods, // Recommendations (same product type)
      searchResults: availableFoods, // Initially show recommendations
      allFoodsForSearch: allFoods, // All foods for search (no category restrictions)
    );
  }

  /// Get up to 3 recommendations of the same product type
  /// Prioritize generic foods, then branded foods if needed
  Future<List<Food>> _getRecommendationsByProductType(
    Food? originalFood,
    List<Food> genericFoods,
    List<Food> allFoods,
  ) async {
    // If no original food or no product type, return empty recommendations
    if (originalFood == null || originalFood.productTypeId == null) {
      return [];
    }

    try {
      final targetProductTypeId = originalFood.productTypeId!;

      // First, get generic foods with same product type (excluding the original food)
      final genericMatches = genericFoods.where((food) =>
        food.productTypeId == targetProductTypeId &&
        food.id != originalFood.id
      ).toList();

      final recommendations = <Food>[];

      // Add up to 3 generic foods first
      recommendations.addAll(genericMatches.take(3));

      // If we need more recommendations to reach 3, add branded foods
      if (recommendations.length < 3) {
        final brandedMatches = allFoods.where((food) =>
          food.productTypeId == targetProductTypeId &&
          food.id != originalFood.id && // Exclude the original food
          !genericFoods.contains(food) // Exclude generic foods we already added
        ).toList();

        final remaining = 3 - recommendations.length;
        recommendations.addAll(brandedMatches.take(remaining));
      }

      return recommendations;

    } catch (e) {
      AppLogger.instance.error('Error getting recommendations by product type',
        context: 'SwapFoodController',
        error: e,
      );
      return [];
    }
  }
  
  /// Get generic foods only (for recommendations)
  Future<List<Food>> _getGenericFoodsWithCache() async {
    try {
      // Use the existing FoodRepository to get only generic foods
      final foodRepository = ref.read(foodRepositoryProvider);
      final genericFoodItems = await foodRepository.getAllFoods();
      
      // Convert FoodItems to Food domain objects for the swap controller
      return genericFoodItems.map((foodItem) => _convertFoodItemToFood(foodItem)).toList();
    } catch (e) {
      AppLogger.instance.error('Error loading generic foods',
        context: 'SwapFoodController',
        error: e,
      );
      return [];
    }
  }
  
  /// Get ALL foods including branded (for search)
  Future<List<Food>> _getAllFoodsIncludingBrandedWithCache() async {
    try {
      // Use the new method to get ALL foods including branded
      final foodRepository = ref.read(foodRepositoryProvider);
      final allFoodItems = await foodRepository.getAllFoodsIncludingBranded();
      
      
      // Convert FoodItems to Food domain objects for the swap controller
      return allFoodItems.map((foodItem) => _convertFoodItemToFood(foodItem)).toList();
    } catch (e) {
      AppLogger.instance.error('Error loading all foods including branded',
        context: 'SwapFoodController',
        error: e,
      );
      return [];
    }
  }
  
  /// Convert FoodItem to Food domain object
  Food _convertFoodItemToFood(FoodItem foodItem) {
    return Food(
      id: foodItem.id,
      name: foodItem.name,
      imageAddress: foodItem.imageAddress,
      description: foodItem.description,
      instructions: foodItem.instructions,
      servingAmount: foodItem.servingAmount,
      displayName: foodItem.displayName,
      displayNamePlural: foodItem.displayNamePlural,
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
  
  /// Update search query and filter foods
  void updateSearch(String query) {
    final currentState = state.valueOrNull;
    if (currentState == null) return;

    if (query.isEmpty) {
      // No search - show recommended alternatives (generic foods)
      state = AsyncValue.data(currentState.copyWith(
        searchQuery: '',
        searchResults: currentState.availableFoods, // Generic foods
        isSearching: false,
        // Keep selected food when clearing search
      ));
    } else {
      // Search in ALL foods (including branded) - case-insensitive partial matching
      // Clear selected food when starting a new search
      final searchPool = currentState.allFoodsForSearch ?? currentState.availableFoods;
      final filtered = searchPool.where((food) {
        return food.name.toLowerCase().contains(query.toLowerCase());
      }).toList();

      state = AsyncValue.data(currentState.copyWith(
        searchQuery: query,
        searchResults: filtered, // Both generic AND branded foods
        isSearching: true,
        clearSelectedFood: true, // Clear selected food when starting new search
      ));
    }
  }
  
  /// Select a food
  void selectFood(Food food) {
    final currentState = state.valueOrNull;
    if (currentState == null) return;
    
    state = AsyncValue.data(currentState.copyWith(selectedFood: food));
  }
  
  /// Clear selection
  void clearSelection() {
    final currentState = state.valueOrNull;
    if (currentState == null) return;

    state = AsyncValue.data(currentState.copyWith(clearSelectedFood: true));
  }
  
  /// Swap a food in the nutrition plan
  Future<void> swapFood(String oldFoodId, Food newFood, String category, {double? customAmount}) async {
    final planController = ref.read(nutritionPlanControllerProvider.notifier);
    await planController.swapFoodItem(oldFoodId, newFood, category, customAmount: customAmount);
  }

  /// Add a food to the nutrition plan
  Future<void> addFood(Food food, String category, {double? customAmount}) async {
    final planController = ref.read(nutritionPlanControllerProvider.notifier);
    await planController.addFoodItem(food, category, customAmount: customAmount);
  }
}