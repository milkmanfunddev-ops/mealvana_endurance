import 'dart:async';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../domain/food.dart';
import '../../domain/food_item.dart';
import '../../data/food_repository.dart';
import '../providers/activity_detail_controller.dart';
import '../../../../shared/services/app_external_deps.dart';
import '../../../../shared/services/logging_service.dart';
import '../../../../shared/database/database_provider.dart';
import '../../../../shared/services/food_management/user_food_crud_service.dart';
import '../../../../shared/services/food_management/food_recommendation_service.dart';
import '../../../../shared/services/food_management/shared_food_search_service.dart';
import '../../../auth/application/auth_service.dart';
import '../../../auth/domain/user_preferences.dart';

part 'swap_food_controller.g.dart';

/// Parameters for the swap food controller
///
/// SIMPLIFIED: Uses activityId plus the current isNewActivity flag to match the
/// ActivityDetailController provider instance and avoid mismatches.
class SwapFoodParams {
  const SwapFoodParams({
    required this.activityId,
    required this.category,
    this.originalFoodId,
    this.originalFoodName,
    this.isNewActivity = false,
  });

  final int activityId; // Activity ID - matches ActivityDetailController provider
  final String category; // Keep for context (before_run, during_run, after_run)
  final String? originalFoodId; // Food being swapped (for product type matching)
  final String? originalFoodName; // Food name being swapped (fallback if ID lookup fails)
  final bool isNewActivity; // Match ActivityDetailController provider instance
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
    this.userFoodIds = const {},
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
  final Set<String> userFoodIds; // Set of food IDs that are user-created foods

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
    Set<String>? userFoodIds,
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
      userFoodIds: userFoodIds ?? this.userFoodIds,
    );
  }
}

/// Provider for food repository
@riverpod
FoodRepository foodRepository(Ref ref) {
  final database = ref.read(appDatabaseProvider);
  final deps = ref.read(appExternalDepsProvider);
  return FoodRepository(
    deps.supabaseClient,
    database,
    logger: deps.logger,
  );
}

/// Controller for swap food functionality - takes swap parameters
@riverpod
class SwapFoodController extends _$SwapFoodController {
  /// Cached logger instance - avoids accessing ref after disposal
  /// Note: Using `late` (not `late final`) because build() can be called multiple times
  late AppLogger _logger;

  /// Helper to check if provider is still mounted before state updates
  bool get _isMounted {
    try {
      // Accessing state when unmounted throws
      state;
      return true;
    } catch (_) {
      return false;
    }
  }

  @override
  FutureOr<SwapFoodState> build(SwapFoodParams params) async {
    // Cache logger immediately in build() to avoid UnmountedRefException
    _logger = ref.read(appExternalDepsProvider).logger;

    // Auto-initialize with foods based on original food's product type
    return await _loadFoodsForSwapping(params);
  }

  Future<SwapFoodState> _loadFoodsForSwapping(SwapFoodParams params) async {
    try {      // Get current user's device ID and preferences
      final authService = ref.read(authServiceProvider);
      final currentUser = await authService.getCurrentUser();
      final userId = currentUser?.id ?? 'unknown';

      // Load user preferences
      final preferences = await authService.getFoodPreferences(userId) ?? {};

      // Use recommendation service to get smart recommendations
      final recommendationService = ref.read(foodRecommendationServiceProvider);

      final recommendations = await recommendationService.getRecommendations(
        productTypeId: params.originalFoodId != null ? await _getProductTypeId(params.originalFoodId!) : null,
        category: params.category, // Always pass category for both add and swap scenarios
        preferences: preferences,
        maxResults: 10,
        userId: userId,
      );

      // Load all foods for search (generic + user foods) and collect user food IDs
      final userFoodService = ref.read(userFoodCrudServiceProvider);
      final userFoods = await userFoodService.getUserFoods(userId);
      final userFoodIds = userFoods.map((f) => f.id).toSet();

      // Load all foods for search (generic + user foods)
      final allFoods = await _loadAllFoodsForSearch(userId);

      return SwapFoodState(
        recommendations: recommendations,
        searchResults: recommendations, // Initially show recommendations
        allFoodsForSearch: allFoods,
        preferences: preferences,
        userFoodIds: userFoodIds,
      );

    } catch (e) {
      _logger.error('Error loading foods for swapping',
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
      final userId = currentUser?.id ?? 'unknown';

      final userFoods = await userFoodService.getUserFoods(userId);
      for (final food in userFoods) {
        if (food.id == foodId) {
          return food.productTypeId;
        }
      }

      _logger.warning('Product type not found for food ID: $foodId');
      return null;
    } catch (e) {
      _logger.error('Error getting product type ID',
        context: 'SwapFoodController',
        data: {'foodId': foodId},
        error: e,
      );
      return null;
    }
  }

  /// Load all foods for search (generic + user foods)
  Future<List<Food>> _loadAllFoodsForSearch(String userId) async {
    try {
      // Load generic foods
      final foodRepository = ref.read(foodRepositoryProvider);
      final genericFoodItems = await foodRepository.getAllFoods();
      final genericFoods = genericFoodItems.map((item) => _convertFoodItemToFood(item)).toList();

      // Load user foods
      final userFoodService = ref.read(userFoodCrudServiceProvider);
      final userFoods = await userFoodService.getUserFoods(userId);

      // Combine all foods
      final allFoods = [...genericFoods, ...userFoods];      return allFoods;
    } catch (e) {
      _logger.error('Error loading all foods for search',
        context: 'SwapFoodController',
        error: e,
      );
      return [];
    }
  }
  
  /// Convert FoodItem to Food domain object
  Food _convertFoodItemToFood(FoodItem foodItem) {
    // Convert FoodCategory enums to strings
    final categories = foodItem.categories.map((cat) => cat.dbValue).toList();

    return Food(
      id: foodItem.id,
      name: foodItem.name,
      imageAddress: foodItem.imageAddress,
      description: foodItem.description,
      instructions: foodItem.instructions,
      servingAmount: foodItem.servingAmount,
      displayName: foodItem.displayName,
      displayNamePlural: foodItem.displayNamePlural,
      categories: categories,
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
    final currentState = state.value;
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
  
  /// Select a food and clear search
  void selectFood(Food food) {
    final currentState = state.value;
    if (currentState == null) return;

    // When selecting a food, clear the search query and show recommendations
    state = AsyncValue.data(currentState.copyWith(
      selectedFood: food,
      searchQuery: '',
      searchResults: currentState.recommendations,
      isSearching: false,
    ));
  }
  
  /// Clear selection
  void clearSelection() {
    final currentState = state.value;
    if (currentState == null) return;

    state = AsyncValue.data(currentState.copyWith(clearSelectedFood: true));
  }
  
  /// Swap a food in the nutrition plan
  Future<void> swapFood(SwapFoodParams params, String oldFoodId, Food newFood, String category, {double? customAmount}) async {
    // CRITICAL: Wait for the ActivityDetailController to finish loading before swapping
    // This prevents race conditions where we try to swap before the nutrition plan is loaded
    _logger.info('Waiting for ActivityDetailController to initialize',
      context: 'SwapFoodController',
      data: {'activityId': params.activityId},
    );

    // Store the provider reference to ensure we use the same instance
    final provider = activityDetailControllerProvider(
      activityId: params.activityId,
      isNewActivity: params.isNewActivity,
    );

    // Wait for the provider's async build() to complete
    final controllerState = await ref.read(provider.future);

    if (controllerState.nutritionPlan == null) {
      _logger.error('Cannot swap food: nutrition plan not loaded after waiting',
        context: 'SwapFoodController',
        data: {'activityId': params.activityId},
      );
      throw Exception('Nutrition plan not available. Please try again.');
    }

    _logger.info('ActivityDetailController ready, performing swap',
      context: 'SwapFoodController',
      data: {
        'activityId': params.activityId,
        'oldFoodId': oldFoodId,
        'newFoodName': newFood.name,
        'nutritionPlanId': controllerState.nutritionPlan!.id,
      },
    );

    // Use the SAME provider instance to get the notifier
    final activityDetailController = ref.read(provider.notifier);

    _logger.info('About to call swapFoodItem on controller',
      context: 'SwapFoodController',
      data: {
        'controllerHashCode': activityDetailController.hashCode,
        'controllerStateIsNull': activityDetailController.state.value == null,
        'controllerNutritionPlanIsNull': activityDetailController.state.value?.nutritionPlan == null,
      },
    );

    await activityDetailController.swapFoodItem(oldFoodId, newFood, category, customAmount: customAmount);

    _logger.info('swapFoodItem returned',
      context: 'SwapFoodController',
      data: {
        'hasUnsavedChanges': activityDetailController.state.value?.hasUnsavedChanges,
      },
    );
  }

  /// Add a food to the nutrition plan
  Future<void> addFood(SwapFoodParams params, Food food, String category, {double? customAmount}) async {
    // CRITICAL: Wait for the ActivityDetailController to finish loading before adding
    // This prevents race conditions where we try to add before the nutrition plan is loaded
    _logger.info('Waiting for ActivityDetailController to initialize',
      context: 'SwapFoodController',
      data: {'activityId': params.activityId},
    );

    // Store the provider reference to ensure we use the same instance
    final provider = activityDetailControllerProvider(
      activityId: params.activityId,
      isNewActivity: params.isNewActivity,
    );

    // Wait for the provider's async build() to complete
    final controllerState = await ref.read(provider.future);

    if (controllerState.nutritionPlan == null) {
      _logger.error('Cannot add food: nutrition plan not loaded after waiting',
        context: 'SwapFoodController',
        data: {'activityId': params.activityId},
      );
      throw Exception('Nutrition plan not available. Please try again.');
    }

    _logger.info('ActivityDetailController ready, performing add',
      context: 'SwapFoodController',
      data: {
        'activityId': params.activityId,
        'foodName': food.name,
        'nutritionPlanId': controllerState.nutritionPlan!.id,
      },
    );

    // Use the SAME provider instance to get the notifier
    final activityDetailController = ref.read(provider.notifier);

    _logger.info('About to call addFoodItem on controller',
      context: 'SwapFoodController',
      data: {
        'controllerHashCode': activityDetailController.hashCode,
        'controllerStateIsNull': activityDetailController.state.value == null,
        'controllerNutritionPlanIsNull': activityDetailController.state.value?.nutritionPlan == null,
      },
    );

    await activityDetailController.addFoodItem(food, category, customAmount: customAmount);

    _logger.info('addFoodItem returned',
      context: 'SwapFoodController',
      data: {
        'hasUnsavedChanges': activityDetailController.state.value?.hasUnsavedChanges,
      },
    );
  }

  /// Search Open Food Facts and update state
  Future<void> searchOpenFoodFacts(String query) async {
    final currentState = state.value;
    if (currentState == null || query.isEmpty) return;

    // Cache services before async gap to avoid ref access after disposal
    final searchService = ref.read(sharedFoodSearchServiceProvider);

    try {
      // Set searching state
      state = AsyncValue.data(currentState.copyWith(
        isSearchingOpenFoodFacts: true,
      ));

      // Search Open Food Facts (async operation)
      final results = await searchService.searchProducts(query);

      // Check if still mounted before updating state
      if (!_isMounted) {
        _logger.warning('SwapFoodController disposed during Open Food Facts search',
          context: 'SwapFoodController',
          data: {'query': query},
        );
        return;
      }

      // Get fresh state after async gap
      final freshState = state.value;
      if (freshState == null) return;

      // Update state with results
      state = AsyncValue.data(freshState.copyWith(
        openFoodFactsResults: results,
        isSearchingOpenFoodFacts: false,
      ));

    } catch (e) {
      // Check if still mounted before logging/updating state
      if (!_isMounted) return;

      _logger.error('Open Food Facts search failed',
        context: 'SwapFoodController',
        data: {'query': query},
        error: e,
      );

      // Get fresh state after async gap
      final freshState = state.value;
      if (freshState == null) return;

      // Clear searching state and keep current results
      state = AsyncValue.data(freshState.copyWith(
        isSearchingOpenFoodFacts: false,
      ));
    }
  }

  /// Add Open Food Facts result to user foods and select it
  Future<void> addOpenFoodFactsResult(dynamic result) async {
    final currentState = state.value;
    if (currentState == null) return;

    // Cache services before async gap to avoid ref access after disposal
    final authService = ref.read(authServiceProvider);
    final searchService = ref.read(sharedFoodSearchServiceProvider);

    try {
      // Get current user's device ID
      final currentUser = await authService.getCurrentUser();
      final userId = currentUser?.id ?? 'unknown';

      // Add to user foods using shared service
      final food = await searchService.addSearchResultToUserFoods(result, userId);

      // Check if still mounted before updating state
      if (!_isMounted) return;

      if (food != null) {
        // Get fresh state after async gap
        final freshState = state.value;
        if (freshState == null) return;

        // Auto-select the food and clear search state
        state = AsyncValue.data(freshState.copyWith(
          selectedFood: food,
          searchQuery: '', // Clear search query
          searchResults: freshState.recommendations, // Show recommendations
          isSearching: false,
          openFoodFactsResults: [], // Clear Open Food Facts results
        ));
      } else {
        _logger.warning('Failed to add Open Food Facts result');
      }

    } catch (e) {
      // Check if still mounted before logging
      if (!_isMounted) return;

      _logger.error('Error adding Open Food Facts result',
        context: 'SwapFoodController',
        data: {'productId': result.id},
        error: e,
      );
    }
  }

  /// Clear Open Food Facts search results
  void clearOpenFoodFactsResults() {
    final currentState = state.value;
    if (currentState == null) return;

    state = AsyncValue.data(currentState.copyWith(
      openFoodFactsResults: [],
      isSearchingOpenFoodFacts: false,
    ));
  }

  /// Refresh foods list (called after adding new user food)
  Future<void> refreshFoods() async {
    final currentState = state.value;
    if (currentState == null) return;

    // Re-fetch foods to include newly added user foods
    // This triggers a rebuild that will refresh recommendations
    state = AsyncValue.data(currentState.copyWith(
      openFoodFactsResults: [],
      isSearchingOpenFoodFacts: false,
      searchQuery: '',
    ));

    // Invalidate and rebuild to refresh food data
    ref.invalidateSelf();
  }
}
