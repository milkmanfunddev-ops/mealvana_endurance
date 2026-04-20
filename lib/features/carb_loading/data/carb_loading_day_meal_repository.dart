import 'package:drift/drift.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../../shared/database/app_database.dart';
import '../../../shared/database/database_provider.dart';
import '../domain/carb_loading_day_meal.dart' as domain;

part 'carb_loading_day_meal_repository.g.dart';

/// Repository for managing carb loading day meal selections
/// Handles actual food selections per meal per day
class CarbLoadingDayMealRepository {
  const CarbLoadingDayMealRepository(this._database);

  final AppDatabase _database;

  /// Get all meals for a specific carb loading day
  Future<List<domain.CarbLoadingDayMeal>> getMealsByDay(String carbLoadingDayId) async {
    final query = _database.select(_database.carbLoadingDayMealsTable)
      ..where((tbl) => tbl.carbLoadingDayId.equals(carbLoadingDayId))
      ..orderBy([
        (tbl) => OrderingTerm(expression: tbl.mealTypeId),
      ]);

    final meals = await query.get();
    return meals.map((meal) => _convertToDayMealDomain(meal)).toList();
  }

  /// Get meals for a specific meal type on a specific day
  Future<List<domain.CarbLoadingDayMeal>> getMealsByDayAndMealType(
    String carbLoadingDayId,
    int mealTypeId,
  ) async {
    final query = _database.select(_database.carbLoadingDayMealsTable)
      ..where((tbl) =>
          tbl.carbLoadingDayId.equals(carbLoadingDayId) &
          tbl.mealTypeId.equals(mealTypeId));

    final meals = await query.get();
    return meals.map((meal) => _convertToDayMealDomain(meal)).toList();
  }

  /// Get a specific meal by ID
  Future<domain.CarbLoadingDayMeal?> getMealById(String id) async {
    final query = _database.select(_database.carbLoadingDayMealsTable)
      ..where((tbl) => tbl.id.equals(id));

    final meal = await query.getSingleOrNull();
    return meal != null ? _convertToDayMealDomain(meal) : null;
  }

  /// Add a default food to a meal
  Future<domain.CarbLoadingDayMeal> addDefaultFoodToMeal({
    required String carbLoadingDayId,
    required int mealTypeId,
    required String carbLoadingFoodId,
    required String foodDisplayName,
    required int quantity,
    required double carbsPerServing,
  }) async {
    final carbsConsumed = quantity * carbsPerServing;
    final now = DateTime.now();

    await _database.into(_database.carbLoadingDayMealsTable).insert(
          CarbLoadingDayMealsTableCompanion.insert(
            carbLoadingDayId: carbLoadingDayId,
            mealTypeId: mealTypeId,
            carbLoadingFoodId: Value(carbLoadingFoodId),
            carbLoadingUserFoodId: const Value.absent(),
            foodDisplayName: Value(foodDisplayName),
            quantity: Value(quantity),
            carbsConsumed: carbsConsumed,
            createdAt: Value(now),
            updatedAt: Value(now),
          ),
        );

    // Get the inserted meal by querying the latest one for this day/meal type
    final meal = await (_database.select(_database.carbLoadingDayMealsTable)
          ..where((tbl) =>
              tbl.carbLoadingDayId.equals(carbLoadingDayId) &
              tbl.mealTypeId.equals(mealTypeId) &
              tbl.carbLoadingFoodId.equals(carbLoadingFoodId))
          ..orderBy([(tbl) => OrderingTerm.desc(tbl.createdAt)])
          ..limit(1))
        .getSingle();

    return _convertToDayMealDomain(meal);
  }

  /// Add a user food to a meal
  Future<domain.CarbLoadingDayMeal> addUserFoodToMeal({
    required String carbLoadingDayId,
    required int mealTypeId,
    required String carbLoadingUserFoodId,
    required String foodDisplayName,
    required int quantity,
    required double carbsPerServing,
  }) async {
    final carbsConsumed = quantity * carbsPerServing;
    final now = DateTime.now();

    await _database.into(_database.carbLoadingDayMealsTable).insert(
          CarbLoadingDayMealsTableCompanion.insert(
            carbLoadingDayId: carbLoadingDayId,
            mealTypeId: mealTypeId,
            carbLoadingFoodId: const Value.absent(),
            carbLoadingUserFoodId: Value(carbLoadingUserFoodId),
            foodDisplayName: Value(foodDisplayName),
            quantity: Value(quantity),
            carbsConsumed: carbsConsumed,
            createdAt: Value(now),
            updatedAt: Value(now),
          ),
        );

    // Get the inserted meal by querying the latest one for this day/meal type
    final meal = await (_database.select(_database.carbLoadingDayMealsTable)
          ..where((tbl) =>
              tbl.carbLoadingDayId.equals(carbLoadingDayId) &
              tbl.mealTypeId.equals(mealTypeId) &
              tbl.carbLoadingUserFoodId.equals(carbLoadingUserFoodId))
          ..orderBy([(tbl) => OrderingTerm.desc(tbl.createdAt)])
          ..limit(1))
        .getSingle();

    return _convertToDayMealDomain(meal);
  }

  /// Update meal quantity
  Future<domain.CarbLoadingDayMeal> updateMealQuantity({
    required String id,
    required int newQuantity,
    required double carbsPerServing,
  }) async {
    final carbsConsumed = newQuantity * carbsPerServing;

    await (_database.update(_database.carbLoadingDayMealsTable)
          ..where((tbl) => tbl.id.equals(id)))
        .write(
      CarbLoadingDayMealsTableCompanion(
        quantity: Value(newQuantity),
        carbsConsumed: Value(carbsConsumed),
        updatedAt: Value(DateTime.now()),
      ),
    );

    final meal = await (_database.select(_database.carbLoadingDayMealsTable)
          ..where((tbl) => tbl.id.equals(id)))
        .getSingle();

    return _convertToDayMealDomain(meal);
  }

  /// Remove a meal
  Future<void> removeMeal(String id) async {
    await (_database.delete(_database.carbLoadingDayMealsTable)
          ..where((tbl) => tbl.id.equals(id)))
        .go();
  }

  /// Remove all meals for a specific day and meal type
  Future<void> removeMealsByDayAndMealType(
    String carbLoadingDayId,
    int mealTypeId,
  ) async {
    await (_database.delete(_database.carbLoadingDayMealsTable)
          ..where((tbl) =>
              tbl.carbLoadingDayId.equals(carbLoadingDayId) &
              tbl.mealTypeId.equals(mealTypeId)))
        .go();
  }

  /// Update carbs for all meals that use a specific user food
  /// Called when a user food's carbs are updated to keep meal entries in sync
  Future<int> updateCarbsForUserFood({
    required String carbLoadingUserFoodId,
    required double newCarbsPerServing,
  }) async {
    print('🔍 Looking for meals with carbLoadingUserFoodId: $carbLoadingUserFoodId');

    // Get all meals that use this user food
    final mealsQuery = _database.select(_database.carbLoadingDayMealsTable)
      ..where((tbl) => tbl.carbLoadingUserFoodId.equals(carbLoadingUserFoodId));

    final meals = await mealsQuery.get();

    print('🔍 Found ${meals.length} meals to update');
    for (final meal in meals) {
      print('  - Meal ${meal.id}: ${meal.foodDisplayName} (qty: ${meal.quantity}, old carbs: ${meal.carbsConsumed})');
    }

    // Update each meal's carbsConsumed
    for (final meal in meals) {
      final oldCarbs = meal.carbsConsumed;
      final newCarbsConsumed = meal.quantity * newCarbsPerServing;

      print('  → Updating meal ${meal.id}: $oldCarbs g → $newCarbsConsumed g');

      await (_database.update(_database.carbLoadingDayMealsTable)
            ..where((tbl) => tbl.id.equals(meal.id)))
          .write(
        CarbLoadingDayMealsTableCompanion(
          carbsConsumed: Value(newCarbsConsumed),
          updatedAt: Value(DateTime.now()),
        ),
      );
    }

    print('✅ Updated ${meals.length} meals');
    return meals.length; // Return number of meals updated
  }

  /// Calculate total carbs consumed for a specific day
  Future<double> calculateTotalCarbsForDay(String carbLoadingDayId) async {
    final query = _database.select(_database.carbLoadingDayMealsTable)
      ..where((tbl) => tbl.carbLoadingDayId.equals(carbLoadingDayId));

    final meals = await query.get();
    return meals.fold<double>(0.0, (sum, meal) => sum + meal.carbsConsumed);
  }

  /// Calculate total carbs consumed for a specific meal type on a day
  Future<double> calculateCarbsForMealType(
    String carbLoadingDayId,
    int mealTypeId,
  ) async {
    final query = _database.select(_database.carbLoadingDayMealsTable)
      ..where((tbl) =>
          tbl.carbLoadingDayId.equals(carbLoadingDayId) &
          tbl.mealTypeId.equals(mealTypeId));

    final meals = await query.get();
    return meals.fold<double>(0.0, (sum, meal) => sum + meal.carbsConsumed);
  }

  /// Replace a meal with a different food
  Future<domain.CarbLoadingDayMeal> replaceMeal({
    required String id,
    String? carbLoadingFoodId,
    String? carbLoadingUserFoodId,
    required String foodDisplayName,
    required int quantity,
    required double carbsPerServing,
  }) async {
    // Ensure exactly one food ID is provided
    assert(
      (carbLoadingFoodId != null && carbLoadingUserFoodId == null) ||
          (carbLoadingFoodId == null && carbLoadingUserFoodId != null),
      'Exactly one of carbLoadingFoodId or carbLoadingUserFoodId must be provided',
    );

    final carbsConsumed = quantity * carbsPerServing;

    await (_database.update(_database.carbLoadingDayMealsTable)
          ..where((tbl) => tbl.id.equals(id)))
        .write(
      CarbLoadingDayMealsTableCompanion(
        carbLoadingFoodId: Value(carbLoadingFoodId),
        carbLoadingUserFoodId: Value(carbLoadingUserFoodId),
        foodDisplayName: Value(foodDisplayName),
        quantity: Value(quantity),
        carbsConsumed: Value(carbsConsumed),
        updatedAt: Value(DateTime.now()),
      ),
    );

    final meal = await (_database.select(_database.carbLoadingDayMealsTable)
          ..where((tbl) => tbl.id.equals(id)))
        .getSingle();

    return _convertToDayMealDomain(meal);
  }

  /// Bulk add meals to a day
  Future<List<domain.CarbLoadingDayMeal>> bulkAddMeals({
    required String carbLoadingDayId,
    required List<({
      int mealTypeId,
      String? carbLoadingFoodId,
      String? carbLoadingUserFoodId,
      String foodDisplayName,
      int quantity,
      double carbsPerServing,
    })> meals,
  }) async {
    return await _database.transaction(() async {
      final createdMeals = <domain.CarbLoadingDayMeal>[];
      final now = DateTime.now();

      for (final meal in meals) {
        final carbsConsumed = meal.quantity * meal.carbsPerServing;

        await _database.into(_database.carbLoadingDayMealsTable).insert(
              CarbLoadingDayMealsTableCompanion.insert(
                carbLoadingDayId: carbLoadingDayId,
                mealTypeId: meal.mealTypeId,
                carbLoadingFoodId: Value(meal.carbLoadingFoodId),
                carbLoadingUserFoodId: Value(meal.carbLoadingUserFoodId),
                foodDisplayName: Value(meal.foodDisplayName),
                quantity: Value(meal.quantity),
                carbsConsumed: carbsConsumed,
                createdAt: Value(now),
                updatedAt: Value(now),
              ),
            );

        // Get the inserted meal
        final createdMeal = await (_database.select(_database.carbLoadingDayMealsTable)
              ..where((tbl) =>
                  tbl.carbLoadingDayId.equals(carbLoadingDayId) &
                  tbl.mealTypeId.equals(meal.mealTypeId))
              ..orderBy([(tbl) => OrderingTerm.desc(tbl.createdAt)])
              ..limit(1))
            .getSingle();

        createdMeals.add(_convertToDayMealDomain(createdMeal));
      }

      return createdMeals;
    });
  }

  /// Convert Drift entity to domain model
  domain.CarbLoadingDayMeal _convertToDayMealDomain(
    CarbLoadingDayMeal meal,
  ) {
    return domain.CarbLoadingDayMeal.fromDatabase(
      id: meal.id,
      carbLoadingDayId: meal.carbLoadingDayId,
      mealTypeId: meal.mealTypeId,
      carbLoadingFoodId: meal.carbLoadingFoodId,
      carbLoadingUserFoodId: meal.carbLoadingUserFoodId,
      foodDisplayName: meal.foodDisplayName,
      quantity: meal.quantity,
      carbsConsumed: meal.carbsConsumed,
      createdAt: meal.createdAt,
      updatedAt: meal.updatedAt,
    );
  }

  /// Watch meals for a specific day (for real-time updates)
  Stream<List<domain.CarbLoadingDayMeal>> watchMealsByDay(String carbLoadingDayId) {
    return (_database.select(_database.carbLoadingDayMealsTable)
          ..where((tbl) => tbl.carbLoadingDayId.equals(carbLoadingDayId))
          ..orderBy([
            (tbl) => OrderingTerm(expression: tbl.mealTypeId),
          ]))
        .watch()
        .map((meals) => meals.map((meal) => _convertToDayMealDomain(meal)).toList());
  }

  /// Watch meals for a specific meal type on a day (for real-time updates)
  Stream<List<domain.CarbLoadingDayMeal>> watchMealsByDayAndMealType(
    String carbLoadingDayId,
    int mealTypeId,
  ) {
    return (_database.select(_database.carbLoadingDayMealsTable)
          ..where((tbl) =>
              tbl.carbLoadingDayId.equals(carbLoadingDayId) &
              tbl.mealTypeId.equals(mealTypeId)))
        .watch()
        .map((meals) => meals.map((meal) => _convertToDayMealDomain(meal)).toList());
  }
}

@riverpod
CarbLoadingDayMealRepository carbLoadingDayMealRepository(Ref ref) {
  return CarbLoadingDayMealRepository(ref.watch(appDatabaseProvider));
}
