import 'dart:async';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../domain/food.dart';
import '../../domain/food_item.dart';
import '../../data/food_repository.dart';
import '../providers/nutrition_plan_controller.dart';

part 'swap_food_controller.g.dart';

/// State for the swap food screen
class SwapFoodState {
  const SwapFoodState({
    required this.availableFoods,
    required this.searchResults,
    this.selectedFood,
    this.searchQuery = '',
    this.isSearching = false,
  });
  
  final List<Food> availableFoods;
  final List<Food> searchResults;
  final Food? selectedFood;
  final String searchQuery;
  final bool isSearching;
  
  SwapFoodState copyWith({
    List<Food>? availableFoods,
    List<Food>? searchResults,
    Food? selectedFood,
    String? searchQuery,
    bool? isSearching,
  }) {
    return SwapFoodState(
      availableFoods: availableFoods ?? this.availableFoods,
      searchResults: searchResults ?? this.searchResults,
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
    // First try to get from local cache, then fall back to Supabase
    final allFoods = await _getAllFoodsWithCache();
    
    // Filter foods by category suitability
    final availableFoods = allFoods.where((food) {
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
    
    return SwapFoodState(
      availableFoods: availableFoods,
      searchResults: availableFoods, // Initially show all available foods
    );
  }
  
  Future<List<Food>> _getAllFoodsWithCache() async {
    try {
      // Use the existing FoodRepository instead of calling Supabase directly
      final foodRepository = ref.read(foodRepositoryProvider);
      final allFoodItems = await foodRepository.getAllFoods();
      
      // Convert FoodItems to Food domain objects for the swap controller
      return allFoodItems.map((foodItem) => _convertFoodItemToFood(foodItem)).toList();
    } catch (e) {
      // If remote fails, return empty list for now
      // TODO: Implement local Drift cache for foods when needed
      return [];
    }
  }
  
  /// Convert FoodItem to Food domain object
  Food _convertFoodItemToFood(FoodItem foodItem) {
    return Food(
      id: foodItem.id,
      name: foodItem.name,
      iconPath: foodItem.iconPath,
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
      state = AsyncValue.data(currentState.copyWith(
        searchQuery: '',
        searchResults: currentState.availableFoods,
        isSearching: false,
      ));
    } else {
      final filtered = currentState.availableFoods.where((food) {
        return food.name.toLowerCase().contains(query.toLowerCase());
      }).toList();
      
      state = AsyncValue.data(currentState.copyWith(
        searchQuery: query,
        searchResults: filtered,
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