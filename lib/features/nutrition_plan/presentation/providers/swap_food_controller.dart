import 'dart:async';
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

/// Result returned by [SwapFoodScreen] when launched in `returnSelection`
/// mode (e.g. from the personal-formula editor). Instead of mutating an
/// activity's nutrition plan, the screen pops with the user's selected food +
/// quantity so the caller can use it however it wants.
class SwapFoodSelection {
  const SwapFoodSelection({
    required this.food,
    required this.quantity,
    required this.isUserFood,
    this.replacedFoodId,
  });

  final Food food;
  final double quantity;

  /// Whether [food] came from the user's own library (`user_foods`) vs the
  /// system catalog (`template_foods`).
  final bool isUserFood;

  /// When swapping, the id of the component food being replaced (else null).
  final String? replacedFoodId;
}

/// State for the swap food screen.
///
/// Search state (query, catalog results, OFF results) is now managed by the
/// shared [FoodSearchController]. This state only contains swap-specific data.
class SwapFoodState {
  const SwapFoodState({
    required this.recommendations,
    this.allFoodsForSearch,
    this.selectedFood,
    this.preferences = const {},
    this.userFoodIds = const {},
    this.userFoods = const [],
    this.allUserFoods = const [],
    this.isMyFoodsExpanded = false,
  });

  final List<Food>
  recommendations; // Smart recommendations (user + generic foods)
  final List<Food>? allFoodsForSearch; // All foods for searching (template + user)
  final Food? selectedFood;
  final Map<String, FoodPreference> preferences; // User food preferences
  final Set<String> userFoodIds; // Set of food IDs that are user-created foods
  final List<Food> userFoods; // User foods for display
  final List<Food> allUserFoods; // All user foods unfiltered
  final bool isMyFoodsExpanded; // Collapse/expand state for My Foods section

  SwapFoodState copyWith({
    List<Food>? recommendations,
    List<Food>? allFoodsForSearch,
    Food? selectedFood,
    bool clearSelectedFood = false,
    Map<String, FoodPreference>? preferences,
    Set<String>? userFoodIds,
    List<Food>? userFoods,
    List<Food>? allUserFoods,
    bool? isMyFoodsExpanded,
  }) {
    return SwapFoodState(
      recommendations: recommendations ?? this.recommendations,
      allFoodsForSearch: allFoodsForSearch ?? this.allFoodsForSearch,
      selectedFood: clearSelectedFood
          ? null
          : (selectedFood ?? this.selectedFood),
      preferences: preferences ?? this.preferences,
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

/// Controller for swap food functionality - takes swap parameters.
///
/// Search logic (local filtering, catalog search, Open Food Facts) is now handled
/// by the shared [FoodSearchController]. This controller manages:
/// - Food loading & recommendations
/// - Food selection
/// - Swap/add operations
/// - Refreshing food data after imports
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

      // Resolve product type ID for swap scenarios (needs to happen before recommendations)
      final String? productTypeId = params.originalFoodId != null
          ? await _getProductTypeId(params.originalFoodId!)
          : null;

      // Run independent operations in parallel:
      // 1. Load user preferences (network)
      // 2. Load user foods (local DB)
      // 3. Load template foods for search + recommendations (local DB)
      final results = await Future.wait([
        authService.getFoodPreferences(userId),
        ref.read(userFoodCrudServiceProvider).getUserFoods(userId),
        _loadTemplateFoodsAsFood(userId),
      ]);

      final preferences = results[0] as Map<String, FoodPreference>? ?? {};
      final userFoods = results[1] as List<Food>;
      final templateFoods = results[2] as List<Food>;

      final userFoodIds = userFoods.map((f) => f.id).toSet();

      // Build recommendations from pre-loaded template foods (no network call)
      final recommendationService = ref.read(foodRecommendationServiceProvider);
      final recommendations = recommendationService.sortByPreferences(
        _filterForRecommendations(
          templateFoods,
          productTypeId: productTypeId,
          category: params.category,
        ),
        preferences,
        maxResults: 10,
      );

      // Combine template + user foods for search (no duplicate getUserFoods call)
      final allFoods = [...templateFoods, ...userFoods];

      return SwapFoodState(
        recommendations: recommendations,
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
        allFoodsForSearch: [],
      );
    }
  }

  /// Load template foods from local Drift cache as Food domain objects.
  /// Falls back to remote sync if local cache is empty.
  Future<List<Food>> _loadTemplateFoodsAsFood(String userId) async {
    final templateFoodsRepo = ref.read(templateFoodsRepositoryProvider);
    var entries = await templateFoodsRepo.getAllTemplateFoods();
    if (entries.isEmpty) {
      final syncResult = await templateFoodsRepo.syncFromRemote(userId);
      if (syncResult.success) {
        entries = await templateFoodsRepo.getAllTemplateFoods();
      }
    }
    return entries.map(_convertTemplateFoodToFood).toList();
  }

  /// Filter foods for recommendations based on product type and/or category
  List<Food> _filterForRecommendations(
    List<Food> foods, {
    String? productTypeId,
    String? category,
  }) {
    // Normalize category
    String? normalizedCategory;
    if (category != null) {
      normalizedCategory = category.split(':').first.toLowerCase();
      if (normalizedCategory == 'before') normalizedCategory = 'before_run';
      if (normalizedCategory == 'during') normalizedCategory = 'during_run';
      if (normalizedCategory == 'after') normalizedCategory = 'after_run';
    }

    if (productTypeId != null) {
      var matches = foods.where((f) => f.productTypeId == productTypeId).toList();
      if (normalizedCategory != null) {
        final filtered = _filterByCat(matches, normalizedCategory);
        if (filtered.isNotEmpty) return filtered;
        // Fallback to all foods filtered by category
        return _filterByCat(foods, normalizedCategory);
      }
      return matches;
    } else if (normalizedCategory != null) {
      return _filterByCat(foods, normalizedCategory);
    }
    return foods;
  }

  List<Food> _filterByCat(List<Food> foods, String category) {
    if (category == 'after_run') return foods; // After run accepts all
    return foods.where((f) => f.categories.contains(category)).toList();
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

  /// Select a food
  void selectFood(Food food) {
    final currentState = state.value;
    if (currentState == null) return;

    state = AsyncValue.data(
      currentState.copyWith(selectedFood: food),
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

    await activityDetailController.swapFoodItem(
      oldFoodId,
      newFood,
      category,
      customAmount: customAmount,
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

    await activityDetailController.addFoodItem(
      food,
      category,
      customAmount: customAmount,
    );
  }

  /// Refresh foods list and optionally select a food after refresh completes
  ///
  /// This method is called after adding a new user food (barcode scan or OpenFoodFacts import).
  /// If [selectAfterRefresh] is provided, the food will be selected after the rebuild completes.
  /// If [expandMyFoods] is true, the My Foods section will be expanded after rebuild.
  /// This prevents race conditions where the food is selected before the state is rebuilt.
  Future<void> refreshFoods({Food? selectAfterRefresh, bool expandMyFoods = false}) async {
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
