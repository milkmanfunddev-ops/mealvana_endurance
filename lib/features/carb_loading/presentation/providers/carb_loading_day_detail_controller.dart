import 'dart:async';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../../../shared/database/app_database.dart' as db;
import '../../../../shared/providers/user_id_provider.dart';
import '../../application/carb_loading_food_service.dart';
import '../../application/food_selection_service.dart';
import '../../data/carb_loading_repository.dart';
import '../../domain/carb_loading_food.dart';
import '../../domain/carb_loading_user_food.dart';
import '../../domain/carb_loading_day_meal.dart';
import '../../domain/meal_type.dart';

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
    return mealsForType(type).fold(0, (sum, meal) => sum + meal.carbsConsumed.toInt());
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
  CarbLoadingFoodService get _foodService => ref.read(carbLoadingFoodServiceProvider);
  FoodSelectionService get _selectionService => ref.read(foodSelectionServiceProvider);
  CarbLoadingRepository get _repository => ref.read(carbLoadingRepositoryProvider);

  @override
  Future<CarbLoadingDayDetailState> build(int carbLoadingDayId) async {
    // Fetch fresh data from repository
    final carbLoadingDay = await _repository.getCarbLoadingDayById(carbLoadingDayId);
    if (carbLoadingDay == null) {
      throw Exception('Carb loading day not found: $carbLoadingDayId');
    }

    // Get device ID
    final deviceId = await ref.read(userIdProvider.future);

    // Load meals for this day
    final meals = await _selectionService.getMealsByDay(carbLoadingDayId);

    // Load available foods (both default and user foods)
    final defaultFoods = <CarbLoadingFood>[];
    final userFoods = await _foodService.getAllUserFoods(deviceId);

    // Load default foods for each meal type
    for (final mealType in MealType.values) {
      final foods = await _foodService.getDefaultFoodsForMealType(mealType);
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
  @Deprecated('Use build() instead - controller now auto-fetches from repository')
  Future<void> initialize(db.CarbLoadingDay carbLoadingDay) async {
    // Just invalidate self to trigger rebuild with fresh data
    ref.invalidateSelf();
  }

  /// Add a default food to a meal
  Future<void> addDefaultFood(MealType mealType, CarbLoadingFood food) async {
    final currentState = state.value;
    if (currentState == null) return;

    state = AsyncData(currentState.copyWith(isLoading: true));

    state = await AsyncValue.guard(() async {
      await _selectionService.addDefaultFoodToMeal(
        carbLoadingDayId: currentState.carbLoadingDay.id,
        mealType: mealType,
        food: food,
        quantity: 1,
      );

      // Reload meals
      final meals = await _selectionService.getMealsByDay(currentState.carbLoadingDay.id);

      return currentState.copyWith(
        meals: meals,
        isLoading: false,
      );
    });
  }

  /// Add a user food to a meal
  Future<void> addUserFood(MealType mealType, CarbLoadingUserFood food) async {
    final currentState = state.value;
    if (currentState == null) return;

    state = AsyncData(currentState.copyWith(isLoading: true));

    state = await AsyncValue.guard(() async {
      await _selectionService.addUserFoodToMeal(
        carbLoadingDayId: currentState.carbLoadingDay.id,
        mealType: mealType,
        food: food,
        quantity: 1,
      );

      // Reload meals
      final meals = await _selectionService.getMealsByDay(currentState.carbLoadingDay.id);

      return currentState.copyWith(
        meals: meals,
        isLoading: false,
      );
    });
  }

  /// Update quantity for a meal
  Future<void> updateQuantity(int mealId, int newQuantity) async {
    final currentState = state.value;
    if (currentState == null) return;

    if (newQuantity <= 0) {
      await removeMeal(mealId);
      return;
    }

    state = AsyncData(currentState.copyWith(isLoading: true));

    state = await AsyncValue.guard(() async {
      await _selectionService.updateMealQuantity(
        mealId: mealId,
        newQuantity: newQuantity,
      );

      // Reload meals
      final meals = await _selectionService.getMealsByDay(currentState.carbLoadingDay.id);

      return currentState.copyWith(
        meals: meals,
        isLoading: false,
      );
    });
  }

  /// Increment quantity for a meal
  Future<void> incrementQuantity(int mealId) async {
    final currentState = state.value;
    if (currentState == null) return;

    final meal = currentState.meals.firstWhere((m) => m.id == mealId);
    await updateQuantity(mealId, meal.quantity + 1);
  }

  /// Decrement quantity for a meal
  Future<void> decrementQuantity(int mealId) async {
    final currentState = state.value;
    if (currentState == null) return;

    final meal = currentState.meals.firstWhere((m) => m.id == mealId);
    await updateQuantity(mealId, meal.quantity - 1);
  }

  /// Remove a meal
  Future<void> removeMeal(int mealId) async {
    final currentState = state.value;
    if (currentState == null) return;

    state = AsyncData(currentState.copyWith(isLoading: true));

    state = await AsyncValue.guard(() async {
      await _selectionService.removeMeal(mealId);

      // Reload meals
      final meals = await _selectionService.getMealsByDay(currentState.carbLoadingDay.id);

      return currentState.copyWith(
        meals: meals,
        isLoading: false,
      );
    });
  }

  /// Clear all meals for a specific meal type
  Future<void> clearMealType(MealType mealType) async {
    final currentState = state.value;
    if (currentState == null) return;

    state = AsyncData(currentState.copyWith(isLoading: true));

    state = await AsyncValue.guard(() async {
      await _selectionService.clearMealsByMealType(
        carbLoadingDayId: currentState.carbLoadingDay.id,
        mealType: mealType,
      );

      // Reload meals
      final meals = await _selectionService.getMealsByDay(currentState.carbLoadingDay.id);

      return currentState.copyWith(
        meals: meals,
        isLoading: false,
      );
    });
  }

  /// Reset all progress for the day
  Future<void> resetDay() async {
    final currentState = state.value;
    if (currentState == null) return;

    state = AsyncData(currentState.copyWith(isLoading: true));

    state = await AsyncValue.guard(() async {
      // Clear all meal types
      for (final mealType in MealType.values) {
        await _selectionService.clearMealsByMealType(
          carbLoadingDayId: currentState.carbLoadingDay.id,
          mealType: mealType,
        );
      }

      return currentState.copyWith(
        meals: [],
        isLoading: false,
      );
    });
  }

  /// Refresh data from repository
  Future<void> refresh() async {
    ref.invalidateSelf();
  }

  /// Update the carb target for this day
  Future<void> updateCarbTarget({
    required double carbsPerKg,
    required int dailyTargetG,
  }) async {
    final currentState = state.value;
    if (currentState == null) return;

    state = AsyncData(currentState.copyWith(isLoading: true));

    state = await AsyncValue.guard(() async {
      // Get device ID for the repository
      final deviceId = await ref.read(userIdProvider.future);

      // Update the carb loading day in the repository
      final updatedDay = await _repository.updateCarbLoadingDay(
        deviceId: deviceId,
        carbLoadingDayId: currentState.carbLoadingDay.id,
        updates: {
          'carbTargetGrams': dailyTargetG,
          'carbProtocolGPerKg': carbsPerKg,
        },
      );

      return currentState.copyWith(
        carbLoadingDay: updatedDay,
        isLoading: false,
      );
    });
  }
}
