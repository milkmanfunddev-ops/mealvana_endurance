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
import '../../../../shared/services/food_management/user_food_crud_service.dart';
import '../../../../shared/services/food_management/food_recommendation_service.dart';
import '../../../../shared/services/food_management/shared_food_search_service.dart';
import '../../../auth/application/auth_service.dart';
import '../../../auth/domain/user_preferences.dart';

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
    required this.recommendations,
    required this.searchResults,
    this.allFoodsForSearch,
    this.selectedFood,
    this.searchQuery = '',
    this.isSearching = false,
    this.preferences = const {},
    this.openFoodFactsResults = const [],
    this.isSearchingOpenFoodFacts = false,
  });

  final List<Food> recommendations; // Smart recommendations (user + generic foods)
  final List<Food> searchResults; // Current search results or recommendations
  final List<Food>? allFoodsForSearch; // All foods for searching
  final Food? selectedFood;
  final String searchQuery;
  final bool isSearching;
  final Map<String, FoodPreference> preferences; // User food preferences
  final List<dynamic> openFoodFactsResults; // Open Food Facts search results (FoodSearchResult)
  final bool isSearchingOpenFoodFacts;
  
  SwapFoodState copyWith({
    List<Food>? recommendations,
    List<Food>? searchResults,
    List<Food>? allFoodsForSearch,
    Food? selectedFood,
    bool clearSelectedFood = false,
    String? searchQuery,
    bool? isSearching,
    Map<String, FoodPreference>? preferences,
    List<dynamic>? openFoodFactsResults,
    bool? isSearchingOpenFoodFacts,
  }) {
    return SwapFoodState(
      recommendations: recommendations ?? this.recommendations,
      searchResults: searchResults ?? this.searchResults,
      allFoodsForSearch: allFoodsForSearch ?? this.allFoodsForSearch,
      selectedFood: clearSelectedFood ? null : (selectedFood ?? this.selectedFood),
      searchQuery: searchQuery ?? this.searchQuery,
      isSearching: isSearching ?? this.isSearching,
      preferences: preferences ?? this.preferences,
      openFoodFactsResults: openFoodFactsResults ?? this.openFoodFactsResults,
      isSearchingOpenFoodFacts: isSearchingOpenFoodFacts ?? this.isSearchingOpenFoodFacts,
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
    try {
      AppLogger.instance.debug('Loading foods for swapping',
        context: 'SwapFoodController',
        data: {'category': params.category, 'originalFoodId': params.originalFoodId},
      );

      // Get current user's device ID and preferences
      final authService = ref.read(authServiceProvider);
      final currentUser = await authService.getCurrentUser();
      final deviceId = currentUser?.id ?? 'unknown';

      // Load user preferences
      final preferences = await authService.getFoodPreferences(deviceId) ?? {};

      // Use recommendation service to get smart recommendations
      final recommendationService = ref.read(foodRecommendationServiceProvider);

      final recommendations = await recommendationService.getRecommendations(
        productTypeId: params.originalFoodId != null ? await _getProductTypeId(params.originalFoodId!) : null,
        category: params.originalFoodId == null ? params.category : null, // Use category for "add" scenarios
        preferences: preferences,
        maxResults: 10,
        deviceId: deviceId,
      );

      AppLogger.instance.debug('Generated ${recommendations.length} recommendations');

      // Load all foods for search (generic + user foods)
      final allFoods = await _loadAllFoodsForSearch(deviceId);

      return SwapFoodState(
        recommendations: recommendations,
        searchResults: recommendations, // Initially show recommendations
        allFoodsForSearch: allFoods,
        preferences: preferences,
      );

    } catch (e) {
      AppLogger.instance.error('Error loading foods for swapping',
        context: 'SwapFoodController',
        error: e,
      );

      // Return empty state on error
      return const SwapFoodState(
        recommendations: [],
        searchResults: [],
        allFoodsForSearch: [],
      );
    }
  }

  /// Get product type ID for a food
  Future<String?> _getProductTypeId(String foodId) async {
    try {
      // Try to find the food in all available sources
      final foodRepository = ref.read(foodRepositoryProvider);
      final genericFoodItems = await foodRepository.getAllFoods();

      // Search in generic foods first
      for (final foodItem in genericFoodItems) {
        if (foodItem.id == foodId) {
          return foodItem.productTypeId;
        }
      }

      // Search in user foods
      final userFoodService = ref.read(userFoodCrudServiceProvider);
      final authService = ref.read(authServiceProvider);
      final currentUser = await authService.getCurrentUser();
      final deviceId = currentUser?.id ?? 'unknown';

      final userFoods = await userFoodService.getUserFoods(deviceId);
      for (final food in userFoods) {
        if (food.id == foodId) {
          return food.productTypeId;
        }
      }

      AppLogger.instance.warning('Product type not found for food ID: $foodId');
      return null;
    } catch (e) {
      AppLogger.instance.error('Error getting product type ID',
        context: 'SwapFoodController',
        data: {'foodId': foodId},
        error: e,
      );
      return null;
    }
  }

  /// Load all foods for search (generic + user foods)
  Future<List<Food>> _loadAllFoodsForSearch(String deviceId) async {
    try {
      // Load generic foods
      final foodRepository = ref.read(foodRepositoryProvider);
      final genericFoodItems = await foodRepository.getAllFoods();
      final genericFoods = genericFoodItems.map((item) => _convertFoodItemToFood(item)).toList();

      // Load user foods
      final userFoodService = ref.read(userFoodCrudServiceProvider);
      final userFoods = await userFoodService.getUserFoods(deviceId);

      // Combine all foods
      final allFoods = [...genericFoods, ...userFoods];

      AppLogger.instance.debug('Loaded ${allFoods.length} total foods for search (${genericFoods.length} generic + ${userFoods.length} user)');
      return allFoods;
    } catch (e) {
      AppLogger.instance.error('Error loading all foods for search',
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
      // No search - show recommendations
      state = AsyncValue.data(currentState.copyWith(
        searchQuery: '',
        searchResults: currentState.recommendations,
        isSearching: false,
        // Keep selected food when clearing search
      ));
    } else {
      // Search in all foods - case-insensitive partial matching
      // Clear selected food when starting a new search
      final searchPool = currentState.allFoodsForSearch ?? currentState.recommendations;
      final filtered = searchPool.where((food) {
        return food.name.toLowerCase().contains(query.toLowerCase()) ||
               (food.displayName?.toLowerCase().contains(query.toLowerCase()) ?? false);
      }).toList();

      // Apply preference-based sorting to search results
      final recommendationService = ref.read(foodRecommendationServiceProvider);
      final sortedResults = recommendationService.sortByPreferences(
        filtered,
        currentState.preferences,
        maxResults: 20, // Allow more results for search
      );

      state = AsyncValue.data(currentState.copyWith(
        searchQuery: query,
        searchResults: sortedResults,
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

  /// Search Open Food Facts and update state
  Future<void> searchOpenFoodFacts(String query) async {
    final currentState = state.valueOrNull;
    if (currentState == null || query.isEmpty) return;

    try {
      // Set searching state
      state = AsyncValue.data(currentState.copyWith(
        isSearchingOpenFoodFacts: true,
      ));

      AppLogger.instance.debug('Searching Open Food Facts',
        context: 'SwapFoodController',
        data: {'query': query},
      );

      // Search Open Food Facts
      final searchService = ref.read(sharedFoodSearchServiceProvider);
      final results = await searchService.searchProducts(query);

      AppLogger.instance.debug('Open Food Facts search completed',
        context: 'SwapFoodController',
        data: {'query': query, 'resultCount': results.length},
      );

      // Update state with results
      state = AsyncValue.data(currentState.copyWith(
        openFoodFactsResults: results,
        isSearchingOpenFoodFacts: false,
      ));

    } catch (e) {
      AppLogger.instance.error('Open Food Facts search failed',
        context: 'SwapFoodController',
        data: {'query': query},
        error: e,
      );

      // Clear searching state and keep current results
      state = AsyncValue.data(currentState.copyWith(
        isSearchingOpenFoodFacts: false,
      ));
    }
  }

  /// Add Open Food Facts result to user foods and select it
  Future<void> addOpenFoodFactsResult(dynamic result) async {
    final currentState = state.valueOrNull;
    if (currentState == null) return;

    try {
      AppLogger.instance.debug('Adding Open Food Facts result to user foods',
        context: 'SwapFoodController',
        data: {'productId': result.id},
      );

      // Get current user's device ID
      final authService = ref.read(authServiceProvider);
      final currentUser = await authService.getCurrentUser();
      final deviceId = currentUser?.id ?? 'unknown';

      // Add to user foods using shared service
      final searchService = ref.read(sharedFoodSearchServiceProvider);
      final food = await searchService.addSearchResultToUserFoods(result, deviceId);

      if (food != null) {
        // Auto-select the food
        state = AsyncValue.data(currentState.copyWith(
          selectedFood: food,
          openFoodFactsResults: [], // Clear search results
        ));

        AppLogger.instance.debug('Successfully added and selected Open Food Facts result',
          context: 'SwapFoodController',
          data: {'foodId': food.id, 'name': food.name},
        );
      } else {
        AppLogger.instance.warning('Failed to add Open Food Facts result');
      }

    } catch (e) {
      AppLogger.instance.error('Error adding Open Food Facts result',
        context: 'SwapFoodController',
        data: {'productId': result.id},
        error: e,
      );
    }
  }

  /// Clear Open Food Facts search results
  void clearOpenFoodFactsResults() {
    final currentState = state.valueOrNull;
    if (currentState == null) return;

    state = AsyncValue.data(currentState.copyWith(
      openFoodFactsResults: [],
      isSearchingOpenFoodFacts: false,
    ));
  }
}