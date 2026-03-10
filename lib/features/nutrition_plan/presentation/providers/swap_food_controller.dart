import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'dart:convert';
import '../../domain/food.dart';
import '../../data/food_repository.dart';
import '../../data/template_foods_repository.dart';
import '../providers/activity_detail_controller.dart';
import '../../../../shared/services/app_external_deps.dart';
import '../../../../shared/services/logging_service.dart';
import '../../../../shared/database/database_provider.dart';
import '../../../../shared/services/food_management/user_food_crud_service.dart';
import '../../../../shared/services/food_management/food_recommendation_service.dart';
import '../../../../shared/services/food_management/shared_food_search_service.dart';
import '../../../../shared/utils/search_strategy.dart';
import '../../../auth/application/auth_service.dart';
import '../../../auth/domain/user_preferences.dart';
import '../../../../features/coach_mode/presentation/providers/coach_activity_detail_controller.dart';
import '../../../../shared/services/sync/sync_coordinator.dart';
import '../../../../features/user_foods/data/user_foods_repository.dart';

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
    this.isCoachView = false,
  });

  final String
  activityId; // Activity ID - matches ActivityDetailController provider
  final String category; // Keep for context (before_run, during_run, after_run)
  final String?
  originalFoodId; // Food being swapped (for product type matching)
  final String?
  originalFoodName; // Food name being swapped (fallback if ID lookup fails)
  final bool isNewActivity; // Match ActivityDetailController provider instance
  final bool isCoachView;
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
    this.userFoods = const [],
    this.allUserFoods = const [],
    this.isMyFoodsExpanded = false,
  });

  final List<Food>
  recommendations; // Smart recommendations (user + generic foods)
  final List<Food> searchResults; // Current search results or recommendations
  final List<Food>? allFoodsForSearch; // All foods for searching
  final Food? selectedFood;
  final String searchQuery;
  final bool isSearching;
  final Map<String, FoodPreference> preferences; // User food preferences
  final List<dynamic>
  openFoodFactsResults; // Open Food Facts search results (FoodSearchResult)
  final bool isSearchingOpenFoodFacts;
  final Set<String> userFoodIds; // Set of food IDs that are user-created foods
  final List<Food> userFoods; // Category-filtered user foods (default) or search-filtered (during search)
  final List<Food> allUserFoods; // All user foods unfiltered (for search)
  final bool isMyFoodsExpanded; // Collapse/expand state for My Foods section

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
    List<Food>? userFoods,
    List<Food>? allUserFoods,
    bool? isMyFoodsExpanded,
  }) {
    return SwapFoodState(
      recommendations: recommendations ?? this.recommendations,
      searchResults: searchResults ?? this.searchResults,
      allFoodsForSearch: allFoodsForSearch ?? this.allFoodsForSearch,
      selectedFood: clearSelectedFood
          ? null
          : (selectedFood ?? this.selectedFood),
      searchQuery: searchQuery ?? this.searchQuery,
      isSearching: isSearching ?? this.isSearching,
      preferences: preferences ?? this.preferences,
      openFoodFactsResults: openFoodFactsResults ?? this.openFoodFactsResults,
      isSearchingOpenFoodFacts:
          isSearchingOpenFoodFacts ?? this.isSearchingOpenFoodFacts,
      userFoodIds: userFoodIds ?? this.userFoodIds,
      userFoods: userFoods ?? this.userFoods,
      allUserFoods: allUserFoods ?? this.allUserFoods,
      isMyFoodsExpanded: isMyFoodsExpanded ?? this.isMyFoodsExpanded,
    );
  }
}

/// Provider for food repository
@riverpod
FoodRepository foodRepository(Ref ref) {
  final database = ref.read(appDatabaseProvider);
  final deps = ref.read(appExternalDepsProvider);
  return FoodRepository(deps.supabaseClient, database, logger: deps.logger);
}

/// Controller for swap food functionality - takes swap parameters
@riverpod
class SwapFoodController extends _$SwapFoodController {
  /// Cached logger instance - avoids accessing ref after disposal
  /// Note: Using `late` (not `late final`) because build() can be called multiple times
  late AppLogger _logger;

  /// Search strategy helper for managing local vs OpenFoodFacts search
  final _searchStrategy = SearchStrategy();

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
    try {
      // Get current user's ID — uses Supabase auth session to find the correct
      // local profile, matching how saveUserFood() stores the user_id.
      final authService = ref.read(authServiceProvider);
      final currentUser = await authService.getCurrentUser();
      final userId = currentUser?.id ?? 'unknown';

      // Ensure user_foods are synced from remote (pulls down after re-login)
      try {
        final userFoodsRepo = await ref.read(userFoodsRepositoryProvider.future);
        await ref.read(syncCoordinatorProvider.notifier).ensureSynced(
          'user_foods',
          userId,
          repository: userFoodsRepo,
        );
      } catch (e) {
        _logger.warning(
          'User foods sync failed, continuing with cached data',
          context: 'SwapFoodController',
          data: {'error': e.toString()},
        );
      }

      // Load user preferences
      final preferences = await authService.getFoodPreferences(userId) ?? {};

      // Use recommendation service to get smart recommendations (generic foods only)
      // User foods are shown separately in the "My Foods" section
      final recommendationService = ref.read(foodRecommendationServiceProvider);

      final recommendations = await recommendationService.getRecommendations(
        productTypeId: params.originalFoodId != null
            ? await _getProductTypeId(params.originalFoodId!)
            : null,
        category: params
            .category, // Always pass category for both add and swap scenarios
        preferences: preferences,
        maxResults: 10,
        // Don't pass userId - user foods are shown in "My Foods" section instead
      );

      // Load user foods separately for the "My Foods" section
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
        userFoods: userFoods, // Show all user foods regardless of category
        allUserFoods: userFoods,
      );
    } catch (e) {
      _logger.error(
        'Error loading foods for swapping',
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
      // Try template foods first (local Drift query)
      final templateFoodsRepo = ref.read(templateFoodsRepositoryProvider);
      final allTemplateFoods = await templateFoodsRepo.getAllTemplateFoods();
      for (final tf in allTemplateFoods) {
        if (tf.id == foodId) {
          return tf.productType;
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
      _logger.error(
        'Error getting product type ID',
        context: 'SwapFoodController',
        data: {'foodId': foodId},
        error: e,
      );
      return null;
    }
  }

  /// Load all foods for search (template foods + user foods)
  Future<List<Food>> _loadAllFoodsForSearch(String userId) async {
    try {
      // Load template foods from local Drift database
      final templateFoodsRepo = ref.read(templateFoodsRepositoryProvider);
      var templateFoodEntries = await templateFoodsRepo.getAllTemplateFoods();
      if (templateFoodEntries.isEmpty) {
        final syncResult = await templateFoodsRepo.syncFromRemote(userId);
        if (syncResult.success) {
          templateFoodEntries = await templateFoodsRepo.getAllTemplateFoods();
        }
      }
      final templateFoods = templateFoodEntries
          .map(_convertTemplateFoodToFood)
          .toList();

      // Load user foods
      final userFoodService = ref.read(userFoodCrudServiceProvider);
      final userFoods = await userFoodService.getUserFoods(userId);

      // Combine all foods
      return [...templateFoods, ...userFoods];
    } catch (e) {
      _logger.error(
        'Error loading all foods for search',
        context: 'SwapFoodController',
        error: e,
      );
      return [];
    }
  }

  /// Convert a TemplateFoodEntry (Drift) to a Food domain model
  Food _convertTemplateFoodToFood(dynamic entry) {
    List<String> categories = [];
    try {
      final parsed = jsonDecode(entry.categories as String);
      if (parsed is List) {
        categories = parsed.cast<String>();
      }
    } catch (_) {}

    return Food(
      id: entry.id as String,
      name: entry.displayName as String? ?? entry.name as String,
      imageAddress: entry.imageAddress as String?,
      description: entry.description as String?,
      servingAmount: entry.servingAmount as double?,
      displayName: entry.displayName as String?,
      displayNamePlural: entry.displayNamePlural as String?,
      categories: categories,
      servingUnit: entry.servingUnit as String?,
      servingQualifier: entry.servingQualifier as String?,
      servingSize: entry.servingSize as String?,
      carbsPerServing: entry.carbsG as double?,
      proteinPerServing: entry.proteinG as double?,
      fatPerServing: entry.fatG as double?,
      caloriesPerServing: entry.calories as int?,
      sodiumMg: (entry.sodiumMg as double?)?.round(),
      fluidMlPerServing: entry.fluidMl as double?,
      caffeineMg: (entry.caffeineMg as double?)?.round(),
      potassiumMg: (entry.potassiumMg as double?)?.round(),
      productTypeId: entry.productType as String?,
      requiresPreparation: entry.requiresPreparation as bool? ?? false,
      maxServingsBefore: entry.maxServingsBefore as int?,
      maxServingsDuring: entry.maxServingsDuring as int?,
    );
  }

  /// Toggle the My Foods section expanded/collapsed state
  void toggleMyFoodsExpanded() {
    final currentState = state.value;
    if (currentState == null) return;
    state = AsyncValue.data(
      currentState.copyWith(isMyFoodsExpanded: !currentState.isMyFoodsExpanded),
    );
  }

  /// Update search query and filter foods
  void updateSearch(String query) {
    final currentState = state.value;
    if (currentState == null) return;

    if (query.isEmpty) {
      // No search - show recommendations, reset user foods to category-filtered
      _searchStrategy.cancelAutoSearch();
      state = AsyncValue.data(
        currentState.copyWith(
          searchQuery: '',
          searchResults: currentState.recommendations,
          isSearching: false,
          openFoodFactsResults: [], // Clear OpenFoodFacts results
          userFoods: currentState.allUserFoods, // Show all user foods regardless of category
          isMyFoodsExpanded: false,
          // Keep selected food when clearing search
        ),
      );
    } else {
      // Search in all foods - case-insensitive partial matching
      // Clear selected food when starting a new search
      final searchPool =
          currentState.allFoodsForSearch ?? currentState.recommendations;
      final normalizedQuery = _normalizeSearchText(query);
      final queryTokens = normalizedQuery
          .split(' ')
          .where((token) => token.isNotEmpty)
          .toList();
      final filtered = searchPool.where((food) {
        final searchText = _normalizeSearchText(
          [
            food.name,
            food.displayName,
            food.displayNamePlural,
            food.description,
            food.productTypeId,
          ].whereType<String>().join(' '),
        );
        return _matchesSearchTokens(searchText, queryTokens);
      }).toList();

      // Filter user foods by search query (no category filter during search)
      final filteredUserFoods = currentState.allUserFoods.where((food) {
        final searchText = _normalizeSearchText(
          [food.name, food.displayName, food.displayNamePlural, food.description, food.productTypeId]
              .whereType<String>().join(' '),
        );
        return _matchesSearchTokens(searchText, queryTokens);
      }).toList();

      // Remove user food IDs from general search results to avoid duplicates
      final filteredUserFoodIds = filteredUserFoods.map((f) => f.id).toSet();
      final deduplicatedFiltered = filtered
          .where((f) => !filteredUserFoodIds.contains(f.id))
          .toList();

      // Apply preference-based sorting to search results
      final recommendationService = ref.read(foodRecommendationServiceProvider);
      final sortedResults = recommendationService.sortByPreferences(
        deduplicatedFiltered,
        currentState.preferences,
        maxResults: 20, // Allow more results for search
      );

      state = AsyncValue.data(
        currentState.copyWith(
          searchQuery: query,
          searchResults: sortedResults,
          isSearching: true,
          clearSelectedFood:
              true, // Clear selected food when starting new search
          userFoods: filteredUserFoods,
          isMyFoodsExpanded: filteredUserFoods.isNotEmpty,
        ),
      );

      // No auto-search of OpenFoodFacts - user taps the button manually
    }
  }

  String _normalizeSearchText(String value) {
    return value
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9\s]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  bool _matchesSearchTokens(String haystack, List<String> queryTokens) {
    if (queryTokens.isEmpty) return true;
    for (final token in queryTokens) {
      final singular = token.endsWith('s') && token.length > 3
          ? token.substring(0, token.length - 1)
          : token;
      if (!haystack.contains(token) && !haystack.contains(singular)) {
        return false;
      }
    }
    return true;
  }

  /// Select a food and clear search
  void selectFood(Food food) {
    final currentState = state.value;
    if (currentState == null) return;

    // When selecting a food, clear the search query and show recommendations
    state = AsyncValue.data(
      currentState.copyWith(
        selectedFood: food,
        searchQuery: '',
        searchResults: currentState.recommendations,
        isSearching: false,
      ),
    );
  }

  /// Clear selection
  void clearSelection() {
    final currentState = state.value;
    if (currentState == null) return;

    state = AsyncValue.data(currentState.copyWith(clearSelectedFood: true));
  }

  /// Swap a food in the nutrition plan
  Future<void> swapFood(
    SwapFoodParams params,
    String oldFoodId,
    Food newFood,
    String category, {
    double? customAmount,
  }) async {
    _logger.info(
      'Waiting for ActivityDetailController to initialize',
      context: 'SwapFoodController',
      data: {
        'activityId': params.activityId,
        'isCoachView': params.isCoachView,
      },
    );

    // Conditionally get controller and state based on view mode
    final dynamic activityDetailController;
    final dynamic controllerState;

    if (params.isCoachView) {
      final provider = coachActivityDetailControllerProvider(params.activityId);
      controllerState = await ref.read(provider.future);
      activityDetailController = ref.read(provider.notifier);
    } else {
      final provider = activityDetailControllerProvider(
        activityId: params.activityId,
        isNewActivity: params.isNewActivity,
      );
      controllerState = await ref.read(provider.future);
      activityDetailController = ref.read(provider.notifier);
    }

    if (controllerState.nutritionPlan == null) {
      _logger.error(
        'Cannot swap food: nutrition plan not loaded after waiting',
        context: 'SwapFoodController',
        data: {'activityId': params.activityId},
      );
      throw Exception('Nutrition plan not available. Please try again.');
    }

    _logger.info(
      'ActivityDetailController ready, performing swap',
      context: 'SwapFoodController',
      data: {
        'activityId': params.activityId,
        'oldFoodId': oldFoodId,
        'newFoodName': newFood.name,
        'nutritionPlanId': controllerState.nutritionPlan!.id,
      },
    );

    _logger.info(
      'About to call swapFoodItem on controller',
      context: 'SwapFoodController',
      data: {'controllerHashCode': activityDetailController.hashCode},
    );

    await activityDetailController.swapFoodItem(
      oldFoodId,
      newFood,
      category,
      customAmount: customAmount,
    );

    _logger.info(
      'swapFoodItem returned',
      context: 'SwapFoodController',
      data: {
        'hasUnsavedChanges':
            activityDetailController.state.value?.hasUnsavedChanges,
      },
    );
  }

  /// Add a food to the nutrition plan
  Future<void> addFood(
    SwapFoodParams params,
    Food food,
    String category, {
    double? customAmount,
  }) async {
    _logger.info(
      'Waiting for ActivityDetailController to initialize',
      context: 'SwapFoodController',
      data: {
        'activityId': params.activityId,
        'isCoachView': params.isCoachView,
      },
    );

    // Conditionally get controller and state based on view mode
    final dynamic activityDetailController;
    final dynamic controllerState;

    if (params.isCoachView) {
      final provider = coachActivityDetailControllerProvider(params.activityId);
      controllerState = await ref.read(provider.future);
      activityDetailController = ref.read(provider.notifier);
    } else {
      final provider = activityDetailControllerProvider(
        activityId: params.activityId,
        isNewActivity: params.isNewActivity,
      );
      controllerState = await ref.read(provider.future);
      activityDetailController = ref.read(provider.notifier);
    }

    if (controllerState.nutritionPlan == null) {
      _logger.error(
        'Cannot add food: nutrition plan not loaded after waiting',
        context: 'SwapFoodController',
        data: {'activityId': params.activityId},
      );
      throw Exception('Nutrition plan not available. Please try again.');
    }

    _logger.info(
      'ActivityDetailController ready, performing add',
      context: 'SwapFoodController',
      data: {
        'activityId': params.activityId,
        'foodName': food.name,
        'nutritionPlanId': controllerState.nutritionPlan!.id,
      },
    );

    _logger.info(
      'About to call addFoodItem on controller',
      context: 'SwapFoodController',
      data: {'controllerHashCode': activityDetailController.hashCode},
    );

    await activityDetailController.addFoodItem(
      food,
      category,
      customAmount: customAmount,
    );

    _logger.info(
      'addFoodItem returned',
      context: 'SwapFoodController',
      data: {
        'hasUnsavedChanges':
            activityDetailController.state.value?.hasUnsavedChanges,
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
      state = AsyncValue.data(
        currentState.copyWith(isSearchingOpenFoodFacts: true),
      );

      // Search Open Food Facts (async operation)
      final results = await searchService.searchProducts(query);

      // Check if still mounted before updating state
      if (!_isMounted) {
        _logger.warning(
          'SwapFoodController disposed during Open Food Facts search',
          context: 'SwapFoodController',
          data: {'query': query},
        );
        return;
      }

      // Get fresh state after async gap
      final freshState = state.value;
      if (freshState == null) return;

      // Update state with results
      state = AsyncValue.data(
        freshState.copyWith(
          openFoodFactsResults: results,
          isSearchingOpenFoodFacts: false,
        ),
      );
    } catch (e) {
      // Check if still mounted before logging/updating state
      if (!_isMounted) return;

      _logger.error(
        'Open Food Facts search failed',
        context: 'SwapFoodController',
        data: {'query': query},
        error: e,
      );

      // Get fresh state after async gap
      final freshState = state.value;
      if (freshState == null) return;

      // Clear searching state and keep current results
      state = AsyncValue.data(
        freshState.copyWith(isSearchingOpenFoodFacts: false),
      );
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
      final food = await searchService.addSearchResultToUserFoods(
        result,
        userId,
      );

      // Check if still mounted before updating state
      if (!_isMounted) return;

      if (food != null) {
        // Get fresh state after async gap
        final freshState = state.value;
        if (freshState == null) return;

        // Auto-select the food and clear search state
        state = AsyncValue.data(
          freshState.copyWith(
            selectedFood: food,
            searchQuery: '', // Clear search query
            searchResults: freshState.recommendations, // Show recommendations
            isSearching: false,
            openFoodFactsResults: [], // Clear Open Food Facts results
          ),
        );
      } else {
        _logger.warning('Failed to add Open Food Facts result');
      }
    } catch (e) {
      // Check if still mounted before logging
      if (!_isMounted) return;

      _logger.error(
        'Error adding Open Food Facts result',
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

    state = AsyncValue.data(
      currentState.copyWith(
        openFoodFactsResults: [],
        isSearchingOpenFoodFacts: false,
      ),
    );
  }

  /// Refresh foods list and optionally select a food after refresh completes
  ///
  /// This method is called after adding a new user food (barcode scan or OpenFoodFacts import).
  /// If [selectAfterRefresh] is provided, the food will be selected after the rebuild completes.
  /// If [expandMyFoods] is true, the My Foods section will be expanded after rebuild.
  /// This prevents race conditions where the food is selected before the state is rebuilt.
  Future<void> refreshFoods({Food? selectAfterRefresh, bool expandMyFoods = false}) async {
    final currentState = state.value;
    if (currentState == null) return;

    // Re-fetch foods to include newly added user foods
    // This triggers a rebuild that will refresh recommendations
    state = AsyncValue.data(
      currentState.copyWith(
        openFoodFactsResults: [],
        isSearchingOpenFoodFacts: false,
        searchQuery: '',
      ),
    );

    // Invalidate and rebuild to refresh food data
    ref.invalidateSelf();

    // Wait for rebuild to complete before selecting food
    await future;

    // Select food after rebuild if provided
    if (selectAfterRefresh != null && _isMounted) {
      selectFood(selectAfterRefresh);
    }

    // Expand My Foods section after rebuild if requested
    if (expandMyFoods && _isMounted) {
      final freshState = state.value;
      if (freshState != null) {
        state = AsyncValue.data(
          freshState.copyWith(isMyFoodsExpanded: true),
        );
      }
    }
  }
}
