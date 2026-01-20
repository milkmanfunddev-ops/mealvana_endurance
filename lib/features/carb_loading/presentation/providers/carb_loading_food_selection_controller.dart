import 'package:drift/drift.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../application/carb_loading_food_service.dart';
import '../../application/food_import_service.dart';
import '../../application/food_selection_service.dart';
import '../../data/carb_loading_food_repository.dart';
import '../../domain/carb_loading_food.dart';
import '../../domain/carb_loading_user_food.dart';
import '../../domain/carb_loading_day_meal.dart';
import '../../domain/meal_type.dart';
import '../../../nutrition_plan/domain/food.dart';
import '../../../nutrition_plan/data/food_repository.dart';
import '../../../barcode_scanning/application/open_food_facts_search_service.dart';
import '../../../../shared/database/app_database.dart' as db;
import '../../../../shared/database/database_provider.dart';
import '../../../../shared/providers/user_id_provider.dart';
import '../../../../shared/services/sync/sync_coordinator.dart';
import '../../../../shared/utils/search_strategy.dart';

part 'carb_loading_food_selection_controller.g.dart';

/// State for carb loading food selection screen
class CarbLoadingFoodSelectionState {
  const CarbLoadingFoodSelectionState({
    required this.carbLoadingDayId,
    required this.mealType,
    this.carbLoadingFoods = const [],
    this.carbLoadingUserFoods = const [],
    this.nutritionPlanFoods = const [],
    this.nutritionPlanUserFoods = const [],
    this.searchQuery = '',
    this.searchResults = const [],
    this.openFoodFactsResults = const [],
    this.selectedFood,
    this.selectedQuantity = 1.0,
    this.isSearchingOpenFoodFacts = false,
  });

  final String carbLoadingDayId;
  final MealType mealType;

  // All available food sources
  final List<CarbLoadingFood> carbLoadingFoods;
  final List<CarbLoadingUserFood> carbLoadingUserFoods;
  final List<Food> nutritionPlanFoods;
  final List<db.UserFood> nutritionPlanUserFoods;

  // Search state
  final String searchQuery;
  final List<dynamic> searchResults; // Mixed list of all food types
  final List<FoodSearchResult> openFoodFactsResults;

  // Selection state
  final dynamic selectedFood; // Can be any food type
  final double selectedQuantity;
  final bool isSearchingOpenFoodFacts;

  CarbLoadingFoodSelectionState copyWith({
    String? carbLoadingDayId,
    MealType? mealType,
    List<CarbLoadingFood>? carbLoadingFoods,
    List<CarbLoadingUserFood>? carbLoadingUserFoods,
    List<Food>? nutritionPlanFoods,
    List<db.UserFood>? nutritionPlanUserFoods,
    String? searchQuery,
    List<dynamic>? searchResults,
    List<FoodSearchResult>? openFoodFactsResults,
    dynamic selectedFood,
    double? selectedQuantity,
    bool? isSearchingOpenFoodFacts,
    bool clearSelectedFood = false,
  }) {
    return CarbLoadingFoodSelectionState(
      carbLoadingDayId: carbLoadingDayId ?? this.carbLoadingDayId,
      mealType: mealType ?? this.mealType,
      carbLoadingFoods: carbLoadingFoods ?? this.carbLoadingFoods,
      carbLoadingUserFoods: carbLoadingUserFoods ?? this.carbLoadingUserFoods,
      nutritionPlanFoods: nutritionPlanFoods ?? this.nutritionPlanFoods,
      nutritionPlanUserFoods: nutritionPlanUserFoods ?? this.nutritionPlanUserFoods,
      searchQuery: searchQuery ?? this.searchQuery,
      searchResults: searchResults ?? this.searchResults,
      openFoodFactsResults: openFoodFactsResults ?? this.openFoodFactsResults,
      selectedFood: clearSelectedFood ? null : (selectedFood ?? this.selectedFood),
      selectedQuantity: selectedQuantity ?? this.selectedQuantity,
      isSearchingOpenFoodFacts: isSearchingOpenFoodFacts ?? this.isSearchingOpenFoodFacts,
    );
  }
}

/// Parameters for the controller
class CarbLoadingFoodSelectionParams {
  const CarbLoadingFoodSelectionParams({
    required this.carbLoadingDayId,
    required this.mealType,
  });

  final String carbLoadingDayId;
  final MealType mealType;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CarbLoadingFoodSelectionParams &&
          runtimeType == other.runtimeType &&
          carbLoadingDayId == other.carbLoadingDayId &&
          mealType == other.mealType;

  @override
  int get hashCode => carbLoadingDayId.hashCode ^ mealType.hashCode;
}

@riverpod
class CarbLoadingFoodSelectionController extends _$CarbLoadingFoodSelectionController {
  CarbLoadingFoodService get _carbLoadingFoodService =>
      ref.read(carbLoadingFoodServiceProvider);
  FoodImportService get _importService =>
      ref.read(foodImportServiceProvider);
  FoodSelectionService get _selectionService =>
      ref.read(foodSelectionServiceProvider);
  FoodRepository get _foodRepository =>
      ref.read(foodRepositoryProvider);
  OpenFoodFactsSearchService get _openFoodFactsService =>
      ref.read(openFoodFactsSearchServiceProvider);

  // Search strategy helper for managing local vs OpenFoodFacts search
  final _searchStrategy = SearchStrategy();

  @override
  Future<CarbLoadingFoodSelectionState> build(CarbLoadingFoodSelectionParams params) async {
    // Load all food sources
    final deviceId = await ref.read(userIdProvider.future);
    final database = ref.read(appDatabaseProvider);
    final syncCoordinator = ref.read(syncCoordinatorProvider.notifier);
    final carbLoadingFoodRepo = ref.read(carbLoadingFoodRepositoryProvider);

    // Ensure carb loading foods are synced (global table, userId ignored but required by interface)
    await syncCoordinator.ensureSynced(
      'carb_loading_foods',
      deviceId,
      repository: carbLoadingFoodRepo,
    );

    // Load carb loading specific foods
    final carbLoadingFoods = await _carbLoadingFoodService.getDefaultFoodsForMealType(params.mealType);
    final carbLoadingUserFoods = await _carbLoadingFoodService.getAllUserFoods(deviceId);

    // Load nutrition plan foods (for importing) - convert FoodItems to Foods
    final foodItems = await _foodRepository.getAllFoods();
    final nutritionPlanFoods = foodItems.map((item) => Food(
      id: item.id,
      name: item.name,
      imageAddress: item.imageAddress,
      description: item.description,
      instructions: item.instructions,
      servingAmount: item.servingAmount,
      displayName: item.displayName,
      displayNamePlural: item.displayNamePlural,
      servingUnit: item.servingUnit,
      servingUnitPlural: item.servingUnitPlural,
      servingQualifier: item.servingQualifier,
      servingSize: item.servingSize,
      carbsPerServing: item.carbsPerServing,
      proteinPerServing: item.proteinPerServing,
      fatPerServing: item.fatPerServing,
      caloriesPerServing: item.caloriesPerServing,
      fluidMlPerServing: item.fluidMlPerServing,
      sodiumMg: item.sodiumMg,
      caffeineMg: item.caffeineMg,
      potassiumMg: item.potassiumMg,
      productTypeId: item.productTypeId,
      beforeRunSuitable: item.beforeRunSuitable,
      duringRunSuitable: item.duringRunSuitable,
      runPortable: item.runPortable,
      requiresPreparation: item.requiresPreparation,
      aidStationAvailable: item.aidStationAvailable,
      maxServingsBefore: item.maxServingsBefore,
      maxServingsDuring: item.maxServingsDuring,
    )).toList();

    // Load user's custom nutrition foods
    final userFoodsQuery = database.select(database.userFoodsTable)
      ..where((tbl) => tbl.deviceId.equals(deviceId) & tbl.isDeleted.equals(false));
    final nutritionPlanUserFoods = await userFoodsQuery.get();

    // Initialize with all foods as search results
    final allFoods = <dynamic>[
      ...carbLoadingFoods,
      ...carbLoadingUserFoods.where((f) => !f.isDeleted),
      ...nutritionPlanFoods,
      ...nutritionPlanUserFoods,
    ];

    return CarbLoadingFoodSelectionState(
      carbLoadingDayId: params.carbLoadingDayId,
      mealType: params.mealType,
      carbLoadingFoods: carbLoadingFoods,
      carbLoadingUserFoods: carbLoadingUserFoods,
      nutritionPlanFoods: nutritionPlanFoods,
      nutritionPlanUserFoods: nutritionPlanUserFoods,
      searchResults: allFoods,
    );
  }

  /// Update search query and filter local foods
  void updateSearch(String query) {
    final currentState = state.value;
    if (currentState == null) return;

    final lowerQuery = query.toLowerCase();

    // Filter all food sources by query
    final filteredFoods = <dynamic>[];

    if (query.isEmpty) {
      // Show all foods when no search query
      filteredFoods.addAll(currentState.carbLoadingFoods);
      filteredFoods.addAll(currentState.carbLoadingUserFoods.where((f) => !f.isDeleted));
      filteredFoods.addAll(currentState.nutritionPlanFoods);
      filteredFoods.addAll(currentState.nutritionPlanUserFoods);

      // Clear OpenFoodFacts results and cancel any pending search
      _searchStrategy.cancelAutoSearch();
      state = AsyncData(currentState.copyWith(
        searchQuery: query,
        searchResults: filteredFoods,
        openFoodFactsResults: [],
      ));
    } else {
      // Filter carb loading foods
      filteredFoods.addAll(
        currentState.carbLoadingFoods.where((food) =>
          food.displayName.toLowerCase().contains(lowerQuery) ||
          food.name.toLowerCase().contains(lowerQuery)
        ),
      );

      // Filter carb loading user foods
      filteredFoods.addAll(
        currentState.carbLoadingUserFoods.where((food) =>
          !food.isDeleted &&
          (food.displayName.toLowerCase().contains(lowerQuery) ||
           food.name.toLowerCase().contains(lowerQuery))
        ),
      );

      // Filter nutrition plan foods
      filteredFoods.addAll(
        currentState.nutritionPlanFoods.where((food) =>
          (food.displayName?.toLowerCase().contains(lowerQuery) ?? false) ||
          food.name.toLowerCase().contains(lowerQuery)
        ),
      );

      // Filter nutrition plan user foods
      filteredFoods.addAll(
        currentState.nutritionPlanUserFoods.where((food) =>
          (food.displayName?.toLowerCase().contains(lowerQuery) ?? false) ||
          food.name.toLowerCase().contains(lowerQuery)
        ),
      );

      state = AsyncData(currentState.copyWith(
        searchQuery: query,
        searchResults: filteredFoods,
      ));

      // Use search strategy to determine if we should auto-search OpenFoodFacts
      if (_searchStrategy.shouldAutoSearch(filteredFoods.length)) {
        _searchStrategy.scheduleAutoSearch(
          query: query,
          getCurrentQuery: () => state.value?.searchQuery ?? '',
          onSearch: searchOpenFoodFacts,
        );
      }
    }
  }

  /// Search Open Food Facts API
  Future<void> searchOpenFoodFacts(String query) async {
    final currentState = state.value;
    if (currentState == null) return;

    state = AsyncData(currentState.copyWith(isSearchingOpenFoodFacts: true));

    try {
      final results = await _openFoodFactsService.searchProducts(query);

      if (state.value != null) {
        state = AsyncData(state.value!.copyWith(
          openFoodFactsResults: results,
          isSearchingOpenFoodFacts: false,
        ));
      }
    } catch (e) {
      if (state.value != null) {
        state = AsyncData(state.value!.copyWith(
          openFoodFactsResults: [],
          isSearchingOpenFoodFacts: false,
        ));
      }
    }
  }

  /// Clear Open Food Facts search results
  void clearOpenFoodFactsResults() {
    final currentState = state.value;
    if (currentState == null) return;

    state = AsyncData(currentState.copyWith(
      openFoodFactsResults: [],
    ));
  }

  /// Select a food (any type)
  void selectFood(dynamic food) {
    final currentState = state.value;
    if (currentState == null) return;

    // Determine default quantity based on food type
    double defaultQuantity = 1.0;
    if (food is Food && food.servingAmount != null) {
      defaultQuantity = food.servingAmount!;
    } else if (food is CarbLoadingFood) {
      defaultQuantity = 1.0;
    }

    state = AsyncData(currentState.copyWith(
      selectedFood: food,
      selectedQuantity: defaultQuantity,
    ));
  }

  /// Update selected quantity
  void updateQuantity(double newQuantity) {
    final currentState = state.value;
    if (currentState == null || newQuantity <= 0) return;

    state = AsyncData(currentState.copyWith(
      selectedQuantity: newQuantity,
    ));
  }

  /// Increment quantity by 0.5
  void incrementQuantity() {
    final currentState = state.value;
    if (currentState == null) return;

    state = AsyncData(currentState.copyWith(
      selectedQuantity: currentState.selectedQuantity + 0.5,
    ));
  }

  /// Decrement quantity by 0.5 (minimum 0.5)
  void decrementQuantity() {
    final currentState = state.value;
    if (currentState == null || currentState.selectedQuantity <= 0.5) return;

    state = AsyncData(currentState.copyWith(
      selectedQuantity: currentState.selectedQuantity - 0.5,
    ));
  }

  /// Add selected food to the meal
  /// Handles importing from nutrition plan tables if needed
  /// Increments quantity if food already exists in the meal
  Future<void> addFoodToMeal() async {
    final currentState = state.value;
    if (currentState == null || currentState.selectedFood == null) return;

    state = const AsyncLoading();

    state = await AsyncValue.guard(() async {
      final deviceId = await ref.read(userIdProvider.future);
      final selectedFood = currentState.selectedFood;
      final quantity = currentState.selectedQuantity.round();

      // Get existing meals for this day and meal type to check for duplicates
      final existingMeals = await _selectionService.getMealsByDayAndMealType(
        carbLoadingDayId: currentState.carbLoadingDayId,
        mealType: currentState.mealType,
      );

      // Handle different food types
      if (selectedFood is CarbLoadingFood) {
        // Check if this food already exists in the meal
        final existingMeal = existingMeals.cast<CarbLoadingDayMeal?>().firstWhere(
          (m) => m != null && m.carbLoadingFoodId == selectedFood.id,
          orElse: () => null,
        );

        if (existingMeal != null) {
          // Increment existing quantity
          await _selectionService.updateMealQuantity(
            mealId: existingMeal.id,
            newQuantity: existingMeal.quantity + quantity,
          );
        } else {
          // Add new meal
          await _selectionService.addDefaultFoodToMeal(
            carbLoadingDayId: currentState.carbLoadingDayId,
            mealType: currentState.mealType,
            food: selectedFood,
            quantity: quantity,
          );
        }
      } else if (selectedFood is CarbLoadingUserFood) {
        // Update meal types if this meal type is not already included
        CarbLoadingUserFood foodToAdd = selectedFood;
        if (!selectedFood.mealTypes.contains(currentState.mealType)) {
          // Add this meal type to the food
          final updatedMealTypes = [...selectedFood.mealTypes, currentState.mealType];
          foodToAdd = await _carbLoadingFoodService.updateUserFood(
            id: selectedFood.id,
            mealTypes: updatedMealTypes,
          );
        }

        // Check if this food already exists in the meal
        final existingMeal = existingMeals.cast<CarbLoadingDayMeal?>().firstWhere(
          (m) => m != null && m.carbLoadingUserFoodId == foodToAdd.id,
          orElse: () => null,
        );

        if (existingMeal != null) {
          // Increment existing quantity
          await _selectionService.updateMealQuantity(
            mealId: existingMeal.id,
            newQuantity: existingMeal.quantity + quantity,
          );
        } else {
          // Add new meal
          await _selectionService.addUserFoodToMeal(
            carbLoadingDayId: currentState.carbLoadingDayId,
            mealType: currentState.mealType,
            food: foodToAdd,
            quantity: quantity,
          );
        }
      } else if (selectedFood is Food) {
        // Check if this food is already imported
        final alreadyImported = await _importService.isFoodAlreadyImported(
          deviceId: deviceId,
          sourceFoodId: selectedFood.id,
        );

        CarbLoadingUserFood importedFood;
        if (alreadyImported) {
          // Reuse existing imported food and update meal types if needed
          final existingFoods = await _carbLoadingFoodService.getAllUserFoods(deviceId);
          final existingFood = existingFoods.firstWhere(
            (f) => f.sourceFoodId == selectedFood.id && !f.isDeleted,
          );

          // Check if current meal type is already in the food's meal types
          if (!existingFood.mealTypes.contains(currentState.mealType)) {
            // Add this meal type to the food
            final updatedMealTypes = [...existingFood.mealTypes, currentState.mealType];
            importedFood = await _carbLoadingFoodService.updateUserFood(
              id: existingFood.id,
              mealTypes: updatedMealTypes,
            );
          } else {
            importedFood = existingFood;
          }
        } else {
          // Import from nutrition plan foods table
          importedFood = await _importService.importFromFoodsTable(
            deviceId: deviceId,
            userId: deviceId, // TODO: Replace with actual userId once user authentication is implemented
            sourceFoodId: selectedFood.id,
            mealTypes: [currentState.mealType],
          );
        }

        // Check if this imported food already exists in the meal
        final existingMeal = existingMeals.cast<CarbLoadingDayMeal?>().firstWhere(
          (m) => m != null && m.carbLoadingUserFoodId == importedFood.id,
          orElse: () => null,
        );

        if (existingMeal != null) {
          // Increment existing quantity
          await _selectionService.updateMealQuantity(
            mealId: existingMeal.id,
            newQuantity: existingMeal.quantity + quantity,
          );
        } else {
          // Add the imported food to the meal
          await _selectionService.addUserFoodToMeal(
            carbLoadingDayId: currentState.carbLoadingDayId,
            mealType: currentState.mealType,
            food: importedFood,
            quantity: quantity,
          );
        }
      } else if (selectedFood is db.UserFood) {
        // Check if this user food is already imported
        final alreadyImported = await _importService.isUserFoodAlreadyImported(
          deviceId: deviceId,
          sourceUserFoodId: selectedFood.id,
        );

        CarbLoadingUserFood importedFood;
        if (alreadyImported) {
          // Reuse existing imported food and update meal types if needed
          final existingFoods = await _carbLoadingFoodService.getAllUserFoods(deviceId);
          final existingFood = existingFoods.firstWhere(
            (f) => f.sourceUserFoodId == selectedFood.id && !f.isDeleted,
          );

          // Check if current meal type is already in the food's meal types
          if (!existingFood.mealTypes.contains(currentState.mealType)) {
            // Add this meal type to the food
            final updatedMealTypes = [...existingFood.mealTypes, currentState.mealType];
            importedFood = await _carbLoadingFoodService.updateUserFood(
              id: existingFood.id,
              mealTypes: updatedMealTypes,
            );
          } else {
            importedFood = existingFood;
          }
        } else {
          // Import from user_foods table
          importedFood = await _importService.importFromUserFoodsTable(
            deviceId: deviceId,
            userId: deviceId, // TODO: Replace with actual userId once user authentication is implemented
            sourceUserFoodId: selectedFood.id,
            mealTypes: [currentState.mealType],
          );
        }

        // Check if this imported food already exists in the meal
        final existingMeal = existingMeals.cast<CarbLoadingDayMeal?>().firstWhere(
          (m) => m != null && m.carbLoadingUserFoodId == importedFood.id,
          orElse: () => null,
        );

        if (existingMeal != null) {
          // Increment existing quantity
          await _selectionService.updateMealQuantity(
            mealId: existingMeal.id,
            newQuantity: existingMeal.quantity + quantity,
          );
        } else {
          // Add the imported food to the meal
          await _selectionService.addUserFoodToMeal(
            carbLoadingDayId: currentState.carbLoadingDayId,
            mealType: currentState.mealType,
            food: importedFood,
            quantity: quantity,
          );
        }
      }

      // Return state with cleared selection
      return currentState.copyWith(
        clearSelectedFood: true,
        selectedQuantity: 1.0,
      );
    });
  }

  /// Add food from Open Food Facts result
  /// Creates a new carb_loading_user_food entry or updates existing one with new meal type
  Future<CarbLoadingUserFood> addFromOpenFoodFacts(FoodSearchResult result) async {
    final deviceId = await ref.read(userIdProvider.future);
    final currentState = state.value;
    if (currentState == null) return Future.error('State not initialized');

    // Check if this barcode is already imported
    final alreadyImported = await _importService.isBarcodeAlreadyImported(
      deviceId: deviceId,
      barcode: result.id,
    );

    CarbLoadingUserFood importedFood;
    if (alreadyImported) {
      // Reuse existing imported food and update meal types if needed
      final existingFoods = await _carbLoadingFoodService.getAllUserFoods(deviceId);
      final existingFood = existingFoods.firstWhere(
        (f) => f.barcode == result.id && !f.isDeleted,
      );

      // Check if current meal type is already in the food's meal types
      if (!existingFood.mealTypes.contains(currentState.mealType)) {
        // Add this meal type to the food
        final updatedMealTypes = [...existingFood.mealTypes, currentState.mealType];
        importedFood = await _carbLoadingFoodService.updateUserFood(
          id: existingFood.id,
          mealTypes: updatedMealTypes,
        );
      } else {
        importedFood = existingFood;
      }
    } else {
      // Create carb loading user food from OFF search result
      // Note: We'll need to fetch detailed nutrition info or use default values
      importedFood = await _importService.createFromBarcodeScan(
        deviceId: deviceId,
        userId: deviceId, // TODO: Replace with actual userId once user authentication is implemented
        barcode: result.id,
        productName: result.name,
        carbsPerServing: 30.0, // Default - user can edit later
        imageUrl: result.imageUrl,
        mealTypes: [currentState.mealType],
      );
    }

    return importedFood;
  }
}
