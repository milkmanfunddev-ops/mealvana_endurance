import 'dart:async';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../../../shared/database/app_database.dart' as db;
import '../../../../shared/providers/user_id_provider.dart';
import '../../../../shared/services/report/report.dart';
import '../../../../shared/services/sync/sync_coordinator.dart';
import '../../application/carb_loading_service.dart';
import '../../application/carb_loading_food_service.dart';
import '../../application/food_selection_service.dart';
import '../../data/carb_loading_repository.dart';
import '../../domain/carb_loading_food.dart';
import '../../domain/carb_loading_user_food.dart';
import '../../domain/carb_loading_day_meal.dart';
import '../../domain/meal_type.dart';
import 'carb_loading_controller.dart';

part 'carb_loading_day_detail_controller.g.dart';

/// State for carb loading day detail screen
class CarbLoadingDayDetailState {
  const CarbLoadingDayDetailState({
    required this.carbLoadingDay,
    required this.meals,
    required this.defaultFoods,
    required this.userFoods,
    this.isLoading = false,
  });

  final db.CarbLoadingDay carbLoadingDay;
  final List<CarbLoadingDayMeal> meals;
  final List<CarbLoadingFood> defaultFoods;
  final List<CarbLoadingUserFood> userFoods;
  final bool isLoading;

  /// Calculate total carbs consumed for the day
  int get totalConsumed {
    return meals.fold(0, (sum, meal) => sum + meal.carbsConsumed.toInt());
  }

  /// Get meals for a specific meal type
  List<CarbLoadingDayMeal> mealsForType(MealType type) {
    return meals.where((meal) => meal.mealType == type).toList();
  }

  /// Calculate carbs for a specific meal type
  int carbsForMealType(MealType type) {
    return mealsForType(
      type,
    ).fold(0, (sum, meal) => sum + meal.carbsConsumed.toInt());
  }

  /// Get progress percentage
  double get progress {
    if (carbLoadingDay.carbTargetGrams == 0) return 0.0;
    return (totalConsumed / carbLoadingDay.carbTargetGrams).clamp(0.0, 1.0);
  }

  CarbLoadingDayDetailState copyWith({
    db.CarbLoadingDay? carbLoadingDay,
    List<CarbLoadingDayMeal>? meals,
    List<CarbLoadingFood>? defaultFoods,
    List<CarbLoadingUserFood>? userFoods,
    bool? isLoading,
  }) {
    return CarbLoadingDayDetailState(
      carbLoadingDay: carbLoadingDay ?? this.carbLoadingDay,
      meals: meals ?? this.meals,
      defaultFoods: defaultFoods ?? this.defaultFoods,
      userFoods: userFoods ?? this.userFoods,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

@riverpod
class CarbLoadingDayDetailController extends _$CarbLoadingDayDetailController {
  CarbLoadingService get _service => ref.read(carbLoadingServiceProvider);
  CarbLoadingFoodService get _foodService =>
      ref.read(carbLoadingFoodServiceProvider);
  FoodSelectionService get _selectionService =>
      ref.read(foodSelectionServiceProvider);
  CarbLoadingRepository get _repository =>
      ref.read(carbLoadingRepositoryProvider);

  Report get _report => ref.report;

  @override
  Future<CarbLoadingDayDetailState> build(String carbLoadingDayId) async {
    // Sync carb loading data from remote if stale (respects 1-hour staleness).
    // This ensures coach-created changes are visible to athletes.
    // Dependencies are read before the first await: this auto-dispose
    // provider can be disposed mid-build.
    final report = _report;
    final repository = _repository;
    final syncCoordinator = ref.read(syncCoordinatorProvider.notifier);
    final selectionService = _selectionService;
    final foodService = _foodService;
    final userIdFuture = ref.read(userIdProvider.future);
    try {
      final userId = await userIdFuture;
      await syncCoordinator.ensureSynced(
        'carb_loading_plans',
        userId,
        repository: repository,
      );
    } catch (e, stackTrace) {
      report.degraded(
        e,
        stackTrace: stackTrace,
        area: 'carb_loading',
        message: 'Could not sync carb loading from remote; using local data',
      );
    }

    // Fetch fresh data from repository
    final carbLoadingDay = await repository.getCarbLoadingDayById(
      carbLoadingDayId,
    );
    if (carbLoadingDay == null) {
      throw Exception('Carb loading day not found: $carbLoadingDayId');
    }

    // Get device ID
    final deviceId = await userIdFuture;

    // Load meals for this day
    final meals = await selectionService.getMealsByDay(carbLoadingDayId);

    // Load available foods (both default and user foods)
    final defaultFoods = <CarbLoadingFood>[];
    final userFoods = await foodService.getAllUserFoods(deviceId);

    // Load default foods for each meal type
    for (final mealType in MealType.values) {
      final foods = await foodService.getDefaultFoodsForMealType(mealType);
      for (final food in foods) {
        if (!defaultFoods.any((f) => f.id == food.id)) {
          defaultFoods.add(food);
        }
      }
    }

    return CarbLoadingDayDetailState(
      carbLoadingDay: carbLoadingDay,
      meals: meals,
      defaultFoods: defaultFoods,
      userFoods: userFoods,
    );
  }

  /// Initialize with a specific carb loading day (legacy - now uses build())
  @Deprecated(
    'Use build() instead - controller now auto-fetches from repository',
  )
  Future<void> initialize(db.CarbLoadingDay carbLoadingDay) async {
    // Just invalidate self to trigger rebuild with fresh data
    ref.invalidateSelf();
  }

  /// Add a default food to a meal
  Future<void> addDefaultFood(MealType mealType, CarbLoadingFood food) async {
    final currentState = state.value;
    if (currentState == null) return;

    state = AsyncData(currentState.copyWith(isLoading: true));
    final selectionService = _selectionService;

    final result = await AsyncValue.guard(() async {
      await selectionService.addDefaultFoodToMeal(
        carbLoadingDayId: currentState.carbLoadingDay.id,
        mealType: mealType,
        food: food,
        quantity: 1,
      );

      // Reload meals
      final meals = await selectionService.getMealsByDay(
        currentState.carbLoadingDay.id,
      );

      return currentState.copyWith(meals: meals, isLoading: false);
    });
    if (ref.mounted) state = result;
  }

  /// Add a user food to a meal
  Future<void> addUserFood(MealType mealType, CarbLoadingUserFood food) async {
    final currentState = state.value;
    if (currentState == null) return;

    state = AsyncData(currentState.copyWith(isLoading: true));
    final selectionService = _selectionService;

    final result = await AsyncValue.guard(() async {
      await selectionService.addUserFoodToMeal(
        carbLoadingDayId: currentState.carbLoadingDay.id,
        mealType: mealType,
        food: food,
        quantity: 1,
      );

      // Reload meals
      final meals = await selectionService.getMealsByDay(
        currentState.carbLoadingDay.id,
      );

      return currentState.copyWith(meals: meals, isLoading: false);
    });
    if (ref.mounted) state = result;
  }

  /// Update quantity for a meal
  Future<void> updateQuantity(String mealId, int newQuantity) async {
    final currentState = state.value;
    if (currentState == null) return;

    if (newQuantity <= 0) {
      await removeMeal(mealId);
      return;
    }

    state = AsyncData(currentState.copyWith(isLoading: true));
    final selectionService = _selectionService;

    final result = await AsyncValue.guard(() async {
      await selectionService.updateMealQuantity(
        mealId: mealId,
        newQuantity: newQuantity,
      );

      // Reload meals
      final meals = await selectionService.getMealsByDay(
        currentState.carbLoadingDay.id,
      );

      return currentState.copyWith(meals: meals, isLoading: false);
    });
    if (ref.mounted) state = result;
  }

  /// Increment quantity for a meal
  Future<void> incrementQuantity(String mealId) async {
    final currentState = state.value;
    if (currentState == null) return;

    final meal = currentState.meals.firstWhere((m) => m.id == mealId);
    await updateQuantity(mealId, meal.quantity + 1);
  }

  /// Decrement quantity for a meal
  Future<void> decrementQuantity(String mealId) async {
    final currentState = state.value;
    if (currentState == null) return;

    final meal = currentState.meals.firstWhere((m) => m.id == mealId);
    await updateQuantity(mealId, meal.quantity - 1);
  }

  /// Remove a meal
  Future<void> removeMeal(String mealId) async {
    final currentState = state.value;
    if (currentState == null) return;

    state = AsyncData(currentState.copyWith(isLoading: true));
    final selectionService = _selectionService;

    final result = await AsyncValue.guard(() async {
      await selectionService.removeMeal(mealId);

      // Reload meals
      final meals = await selectionService.getMealsByDay(
        currentState.carbLoadingDay.id,
      );

      return currentState.copyWith(meals: meals, isLoading: false);
    });
    if (ref.mounted) state = result;
  }

  /// Clear all meals for a specific meal type
  Future<void> clearMealType(MealType mealType) async {
    final currentState = state.value;
    if (currentState == null) return;

    state = AsyncData(currentState.copyWith(isLoading: true));
    final selectionService = _selectionService;

    final result = await AsyncValue.guard(() async {
      await selectionService.clearMealsByMealType(
        carbLoadingDayId: currentState.carbLoadingDay.id,
        mealType: mealType,
      );

      // Reload meals
      final meals = await selectionService.getMealsByDay(
        currentState.carbLoadingDay.id,
      );

      return currentState.copyWith(meals: meals, isLoading: false);
    });
    if (ref.mounted) state = result;
  }

  /// Reset all progress for the day
  Future<void> resetDay() async {
    final currentState = state.value;
    if (currentState == null) return;

    state = AsyncData(currentState.copyWith(isLoading: true));
    final selectionService = _selectionService;

    final result = await AsyncValue.guard(() async {
      // Clear all meal types
      for (final mealType in MealType.values) {
        await selectionService.clearMealsByMealType(
          carbLoadingDayId: currentState.carbLoadingDay.id,
          mealType: mealType,
        );
      }

      return currentState.copyWith(meals: [], isLoading: false);
    });
    if (ref.mounted) state = result;
  }

  /// Refresh data from repository
  Future<void> refresh() async {
    ref.invalidateSelf();
  }

  /// Force refresh from Supabase (pull-to-refresh).
  Future<void> forceRefresh() async {
    final report = _report;
    final repository = _repository;
    final syncCoordinator = ref.read(syncCoordinatorProvider.notifier);
    try {
      final userId = await ref.read(userIdProvider.future);
      await syncCoordinator.forceSyncRepository(
        'carb_loading_plans',
        userId,
        repository: repository,
      );
      if (ref.mounted) ref.invalidateSelf();
    } catch (e) {
      report.degraded(e, area: 'carb_loading', message: 'Force refresh failed');
      if (ref.mounted) ref.invalidateSelf();
    }
  }

  /// Update the carb target for this day
  Future<void> updateCarbTarget({
    required double carbsPerKg,
    required int dailyTargetG,
  }) async {
    final currentState = state.value;
    if (currentState == null) return;

    state = AsyncData(currentState.copyWith(isLoading: true));
    final repository = _repository;
    final service = _service;

    final result = await AsyncValue.guard(() async {
      // Get device ID for the repository
      final deviceId = await ref.read(userIdProvider.future);

      // CRITICAL FIX: Fetch the latest day from repository to get current ID
      // (ID may have changed due to background sync rekeying)
      final latestDay = await repository.getCarbLoadingDayById(
        currentState.carbLoadingDay.id,
      );
      if (latestDay == null) {
        throw Exception(
          'Carb loading day not found - it may have been deleted',
        );
      }

      // Update the carb loading day using service-level consistency resolution
      final updatedDay = await service.updateCarbLoadingDay(
        deviceId: deviceId,
        currentUserId: deviceId,
        carbLoadingDayId: latestDay.id,
        updates: {
          'carbTargetGrams': dailyTargetG,
          'carbProtocolGPerKg': carbsPerKg,
        },
      );

      // Invalidate calendar view to refresh and show updated target
      if (ref.mounted) ref.invalidate(carbLoadingDaysForRangeProvider);

      return currentState.copyWith(
        carbLoadingDay: updatedDay,
        isLoading: false,
      );
    });
    if (ref.mounted) state = result;
  }
}
