import 'dart:async';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../domain/food.dart';
import '../../domain/food_item.dart';
import '../../data/food_repository.dart';
import '../providers/nutrition_plan_controller.dart';
import '../../../../shared/services/logging_service.dart';

part 'swap_food_controller.g.dart';

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
    String? searchQuery,
    bool? isSearching,
  }) {
    return SwapFoodState(
      availableFoods: availableFoods ?? this.availableFoods,
      searchResults: searchResults ?? this.searchResults,
      allFoodsForSearch: allFoodsForSearch ?? this.allFoodsForSearch,
      selectedFood: selectedFood ?? this.selectedFood,
      searchQuery: searchQuery ?? this.searchQuery,
      isSearching: isSearching ?? this.isSearching,
    );
  }
}

/// Provider for food repository
@riverpod
FoodRepository foodRepository(Ref ref) {
  return FoodRepository(Supabase.instance.client);
}

/// Controller for swap food functionality - takes category as parameter
@riverpod
class SwapFoodController extends _$SwapFoodController {
  
  @override
  FutureOr<SwapFoodState> build(String category) {
    // Auto-initialize with foods for the given category
    return _loadFoodsForCategory(category);
  }
  
  Future<SwapFoodState> _loadFoodsForCategory(String category) async {
    // Load generic foods for recommendations and all foods (including branded) for search
    final genericFoods = await _getGenericFoodsWithCache();
    final allFoods = await _getAllFoodsIncludingBrandedWithCache();
    
    // Filter generic foods by category suitability for recommendations
    final availableFoods = genericFoods.where((food) {
      switch (category) {
        case 'before_run':
          return food.beforeRunSuitable;
        case 'during_run':
          return food.duringRunSuitable;
        case 'after_run':
          return true; // Assuming all foods are suitable after run
        default:
          return false;
      }
    }).toList();
    
    // Filter ALL foods (including branded) by category for search capability  
    final allCategoryFoods = allFoods.where((food) {
      switch (category) {
        case 'before_run':
          return food.beforeRunSuitable;
        case 'during_run':
          return food.duringRunSuitable;
        case 'after_run':
          return true;
        default:
          return false;
      }
    }).toList();
    
    return SwapFoodState(
      availableFoods: availableFoods, // Generic foods for recommendations
      searchResults: availableFoods, // Initially show generic foods, will be replaced on search
      allFoodsForSearch: allCategoryFoods, // All foods (including branded) for search
    );
  }
  
  /// Get generic foods only (for recommendations)
  Future<List<Food>> _getGenericFoodsWithCache() async {
    try {
      // Use the existing FoodRepository to get only generic foods
      final foodRepository = ref.read(foodRepositoryProvider);
      final genericFoodItems = await foodRepository.getAllFoods();
      
      AppLogger.instance.debug('Loaded generic foods for recommendations',
        context: 'SwapFoodController',
        data: {'count': genericFoodItems.length},
      );
      
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
      
      AppLogger.instance.debug('Loaded all foods including branded for search',
        context: 'SwapFoodController',
        data: {'count': allFoodItems.length},
      );
      
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
    AppLogger.instance.debug('Converting FoodItem to Food domain object',
      context: 'SwapFoodController',
      data: {
        'foodName': foodItem.name,
        'imageAddress': foodItem.imageAddress,
        'foodId': foodItem.id,
      },
    );
    
    return Food(
      id: foodItem.id,
      name: foodItem.name,
      imageAddress: foodItem.imageAddress,
      description: foodItem.description,
      instructions: foodItem.instructions,
      servingAmount: foodItem.servingAmount,
      servingUnit: foodItem.servingUnit,
      beforeRunSuitable: foodItem.beforeRunSuitable,
      duringRunSuitable: foodItem.duringRunSuitable,
      carbsPerServing: foodItem.carbsPerServing,
      proteinPerServing: foodItem.proteinPerServing,
      fatPerServing: foodItem.fatPerServing,
      caloriesPerServing: foodItem.caloriesPerServing,
      fluidMlPerServing: foodItem.fluidMlPerServing,
      sodiumMg: foodItem.sodiumMg,
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
      ));
    } else {
      // Search in ALL foods (including branded)
      final searchPool = currentState.allFoodsForSearch ?? currentState.availableFoods;
      final filtered = searchPool.where((food) {
        return food.name.toLowerCase().contains(query.toLowerCase());
      }).toList();
      
      AppLogger.instance.debug('Search performed',
        context: 'SwapFoodController',
        data: {
          'searchQuery': query,
          'searchPoolSize': searchPool.length,
          'resultsFound': filtered.length,
        },
      );
      
      state = AsyncValue.data(currentState.copyWith(
        searchQuery: query,
        searchResults: filtered, // Both generic AND branded foods
        isSearching: true,
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
    
    state = AsyncValue.data(currentState.copyWith(selectedFood: null));
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