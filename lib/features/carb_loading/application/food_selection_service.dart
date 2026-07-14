import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../../shared/services/analytics/analytics_tracker.dart';
import '../data/carb_loading_day_meal_repository.dart';
import '../domain/carb_loading_day_meal.dart';
import '../domain/carb_loading_food.dart';
import '../domain/carb_loading_user_food.dart';
import '../domain/meal_type.dart';
import 'carb_loading_food_service.dart';

part 'food_selection_service.g.dart';

/// Service for managing food selections in carb loading day meals
/// Handles adding, removing, and updating meal selections
class FoodSelectionService {
  const FoodSelectionService({
    required CarbLoadingDayMealRepository dayMealRepository,
    required CarbLoadingFoodService foodService,
    required AnalyticsTracker analytics,
  })  : _dayMealRepository = dayMealRepository,
        _foodService = foodService,
        _analytics = analytics;

  final CarbLoadingDayMealRepository _dayMealRepository;
  final CarbLoadingFoodService _foodService;
  final AnalyticsTracker _analytics;

  /// `carb_loading_food_added` fires here, in the service, rather than in a
  /// controller. Two independent add paths exist — the day-detail controller
  /// and the food-selection controller — and both bottom out here, so this is
  /// the only point that sees every add. Instrumenting a single controller
  /// would silently undercount.
  void _trackFoodAdded({
    required String carbLoadingDayId,
    required MealType mealType,
    required String foodName,
    required String foodId,
    required int quantity,
    required double carbsPerServing,
    required bool isUserFood,
  }) {
    try {
      _analytics.track(
        'carb_loading_food_added',
        properties: {
          'day_id': carbLoadingDayId,
          'meal_type': mealType.name,
          'food_name': foodName,
          'food_id': foodId,
          'quantity': quantity,
          'carbs_per_serving': carbsPerServing,
          'is_user_food': isUserFood,
        },
      );
    } catch (_) {}
  }

  /// Add a default food to a meal
  Future<CarbLoadingDayMeal> addDefaultFoodToMeal({
    required String carbLoadingDayId,
    required MealType mealType,
    required CarbLoadingFood food,
    int quantity = 1,
  }) async {
    // Validate food is suitable for meal type
    if (!food.isSuitableForMeal(mealType)) {
      throw ArgumentError(
        '${food.displayName} is not suitable for ${mealType.displayName}',
      );
    }

    final meal = await _dayMealRepository.addDefaultFoodToMeal(
      carbLoadingDayId: carbLoadingDayId,
      mealTypeId: mealType.id,
      carbLoadingFoodId: food.id,
      foodDisplayName: food.displayName,
      quantity: quantity,
      carbsPerServing: food.carbsPerServing,
    );

    // After the write, so a failed add doesn't report as a successful one.
    _trackFoodAdded(
      carbLoadingDayId: carbLoadingDayId,
      mealType: mealType,
      foodName: food.displayName,
      foodId: food.id,
      quantity: quantity,
      carbsPerServing: food.carbsPerServing,
      isUserFood: false,
    );

    return meal;
  }

  /// Add a user food to a meal
  Future<CarbLoadingDayMeal> addUserFoodToMeal({
    required String carbLoadingDayId,
    required MealType mealType,
    required CarbLoadingUserFood food,
    int quantity = 1,
  }) async {
    // Validate food is suitable for meal type
    if (!food.isSuitableForMeal(mealType)) {
      throw ArgumentError(
        '${food.displayName} is not suitable for ${mealType.displayName}',
      );
    }

    final meal = await _dayMealRepository.addUserFoodToMeal(
      carbLoadingDayId: carbLoadingDayId,
      mealTypeId: mealType.id,
      carbLoadingUserFoodId: food.id,
      foodDisplayName: food.displayName,
      quantity: quantity,
      carbsPerServing: food.carbsPerServing,
    );

    _trackFoodAdded(
      carbLoadingDayId: carbLoadingDayId,
      mealType: mealType,
      foodName: food.displayName,
      foodId: food.id,
      quantity: quantity,
      carbsPerServing: food.carbsPerServing,
      isUserFood: true,
    );

    return meal;
  }

  /// Add any food (default or user) to a meal
  Future<CarbLoadingDayMeal> addFoodToMeal({
    required String carbLoadingDayId,
    required MealType mealType,
    required dynamic food,
    int quantity = 1,
  }) async {
    if (food is CarbLoadingFood) {
      return addDefaultFoodToMeal(
        carbLoadingDayId: carbLoadingDayId,
        mealType: mealType,
        food: food,
        quantity: quantity,
      );
    } else if (food is CarbLoadingUserFood) {
      return addUserFoodToMeal(
        carbLoadingDayId: carbLoadingDayId,
        mealType: mealType,
        food: food,
        quantity: quantity,
      );
    } else {
      throw ArgumentError('Invalid food type');
    }
  }

  /// Update the quantity of a meal
  Future<CarbLoadingDayMeal> updateMealQuantity({
    required String mealId,
    required int newQuantity,
  }) async {
    if (newQuantity < 1) {
      throw ArgumentError('Quantity must be at least 1');
    }

    // Get the current meal to retrieve carbs per serving
    final currentMeal = await _dayMealRepository.getMealById(mealId);
    if (currentMeal == null) {
      throw ArgumentError('Meal not found');
    }

    return _dayMealRepository.updateMealQuantity(
      id: mealId,
      newQuantity: newQuantity,
      carbsPerServing: currentMeal.carbsPerServing,
    );
  }

  /// Remove a meal
  Future<void> removeMeal(String mealId) async {
    return _dayMealRepository.removeMeal(mealId);
  }

  /// Replace a meal with a different food
  Future<CarbLoadingDayMeal> replaceMeal({
    required String mealId,
    required dynamic newFood,
    int quantity = 1,
  }) async {
    if (newFood is CarbLoadingFood) {
      return _dayMealRepository.replaceMeal(
        id: mealId,
        carbLoadingFoodId: newFood.id,
        carbLoadingUserFoodId: null,
        foodDisplayName: newFood.displayName,
        quantity: quantity,
        carbsPerServing: newFood.carbsPerServing,
      );
    } else if (newFood is CarbLoadingUserFood) {
      return _dayMealRepository.replaceMeal(
        id: mealId,
        carbLoadingFoodId: null,
        carbLoadingUserFoodId: newFood.id,
        foodDisplayName: newFood.displayName,
        quantity: quantity,
        carbsPerServing: newFood.carbsPerServing,
      );
    } else {
      throw ArgumentError('Invalid food type');
    }
  }

  /// Get all meals for a specific day
  Future<List<CarbLoadingDayMeal>> getMealsByDay(String carbLoadingDayId) async {
    return _dayMealRepository.getMealsByDay(carbLoadingDayId);
  }

  /// Get meals for a specific meal type on a day
  Future<List<CarbLoadingDayMeal>> getMealsByDayAndMealType({
    required String carbLoadingDayId,
    required MealType mealType,
  }) async {
    return _dayMealRepository.getMealsByDayAndMealType(
      carbLoadingDayId,
      mealType.id,
    );
  }

  /// Calculate total carbs consumed for a day
  Future<double> calculateTotalCarbsForDay(String carbLoadingDayId) async {
    return _dayMealRepository.calculateTotalCarbsForDay(carbLoadingDayId);
  }

  /// Calculate carbs consumed for a specific meal type on a day
  Future<double> calculateCarbsForMealType({
    required String carbLoadingDayId,
    required MealType mealType,
  }) async {
    return _dayMealRepository.calculateCarbsForMealType(
      carbLoadingDayId,
      mealType.id,
    );
  }

  /// Get meals grouped by meal type for a day
  Future<Map<MealType, List<CarbLoadingDayMeal>>> getMealsGroupedByMealType(
    String carbLoadingDayId,
  ) async {
    final allMeals = await _dayMealRepository.getMealsByDay(carbLoadingDayId);
    final grouped = <MealType, List<CarbLoadingDayMeal>>{};

    for (final mealType in MealType.values) {
      grouped[mealType] = allMeals
          .where((meal) => meal.mealType == mealType)
          .toList();
    }

    return grouped;
  }

  /// Clear all meals for a specific meal type on a day
  Future<void> clearMealsByMealType({
    required String carbLoadingDayId,
    required MealType mealType,
  }) async {
    return _dayMealRepository.removeMealsByDayAndMealType(
      carbLoadingDayId,
      mealType.id,
    );
  }

  /// Bulk add multiple foods to different meals
  Future<List<CarbLoadingDayMeal>> bulkAddFoods({
    required String carbLoadingDayId,
    required List<({
      MealType mealType,
      dynamic food,
      int quantity,
    })> foodSelections,
  }) async {
    final meals = foodSelections.map((selection) {
      final food = selection.food;
      final carbsPerServing = _foodService.getCarbsPerServing(food);
      final displayName = _foodService.getDisplayName(food);

      String? defaultFoodId;
      String? userFoodId;

      if (food is CarbLoadingFood) {
        defaultFoodId = food.id;
      } else if (food is CarbLoadingUserFood) {
        userFoodId = food.id;
      }

      return (
        mealTypeId: selection.mealType.id,
        carbLoadingFoodId: defaultFoodId,
        carbLoadingUserFoodId: userFoodId,
        foodDisplayName: displayName,
        quantity: selection.quantity,
        carbsPerServing: carbsPerServing,
      );
    }).toList();

    return _dayMealRepository.bulkAddMeals(
      carbLoadingDayId: carbLoadingDayId,
      meals: meals,
    );
  }

  /// Watch meals for a day (for real-time UI updates)
  Stream<List<CarbLoadingDayMeal>> watchMealsByDay(String carbLoadingDayId) {
    return _dayMealRepository.watchMealsByDay(carbLoadingDayId);
  }

  /// Watch meals for a specific meal type on a day
  Stream<List<CarbLoadingDayMeal>> watchMealsByDayAndMealType({
    required String carbLoadingDayId,
    required MealType mealType,
  }) {
    return _dayMealRepository.watchMealsByDayAndMealType(
      carbLoadingDayId,
      mealType.id,
    );
  }

  /// Calculate progress towards carb target
  Future<({double consumed, double remaining, double percentage})>
      calculateProgress({
    required String carbLoadingDayId,
    required double targetCarbs,
  }) async {
    final consumed = await calculateTotalCarbsForDay(carbLoadingDayId);
    final remaining = (targetCarbs - consumed).clamp(0.0, targetCarbs);
    final percentage = targetCarbs > 0 ? (consumed / targetCarbs * 100).clamp(0.0, 100.0) : 0.0;

    return (consumed: consumed, remaining: remaining, percentage: percentage);
  }

  /// Increment meal quantity by 1
  Future<CarbLoadingDayMeal> incrementMealQuantity(String mealId) async {
    final meal = await _dayMealRepository.getMealById(mealId);
    if (meal == null) {
      throw ArgumentError('Meal not found');
    }

    return updateMealQuantity(
      mealId: mealId,
      newQuantity: meal.quantity + 1,
    );
  }

  /// Decrement meal quantity by 1 (minimum 1)
  Future<CarbLoadingDayMeal> decrementMealQuantity(String mealId) async{
    final meal = await _dayMealRepository.getMealById(mealId);
    if (meal == null) {
      throw ArgumentError('Meal not found');
    }

    final newQuantity = (meal.quantity - 1).clamp(1, meal.quantity);
    return updateMealQuantity(
      mealId: mealId,
      newQuantity: newQuantity,
    );
  }
}

@riverpod
FoodSelectionService foodSelectionService(Ref ref) {
  return FoodSelectionService(
    dayMealRepository: ref.watch(carbLoadingDayMealRepositoryProvider),
    foodService: ref.watch(carbLoadingFoodServiceProvider),
    analytics: ref.watch(analyticsTrackerProvider),
  );
}
