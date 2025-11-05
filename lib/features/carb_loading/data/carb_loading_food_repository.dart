import 'package:drift/drift.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../../shared/database/app_database.dart';
import '../../../shared/database/database_provider.dart';
import '../domain/carb_loading_food.dart' as domain;

part 'carb_loading_food_repository.g.dart';

/// Repository for managing global default carb loading foods
/// Handles database queries and conversions between Drift entities and domain models
class CarbLoadingFoodRepository {
  const CarbLoadingFoodRepository(this._database);

  final AppDatabase _database;

  /// Get all default carb loading foods with their meal type associations
  Future<List<domain.CarbLoadingFood>> getAllFoods() async {
    final query = _database.select(_database.carbLoadingFoodsTable);
    final foods = await query.get();

    // Load meal types for each food
    final foodsWithMealTypes = <domain.CarbLoadingFood>[];
    for (final food in foods) {
      final mealTypes = await _getMealTypesForFood(food.id);
      foodsWithMealTypes.add(_convertToFoodDomain(food, mealTypes));
    }

    return foodsWithMealTypes;
  }

  /// Get foods suitable for a specific meal type
  Future<List<domain.CarbLoadingFood>> getFoodsByMealType(int mealTypeId) async {
    // Join carb_loading_foods with carb_loading_food_meal_types
    final query = _database.select(_database.carbLoadingFoodsTable).join([
      innerJoin(
        _database.carbLoadingFoodMealTypesTable,
        _database.carbLoadingFoodMealTypesTable.carbLoadingFoodId
            .equalsExp(_database.carbLoadingFoodsTable.id),
      ),
    ])
      ..where(
        _database.carbLoadingFoodMealTypesTable.mealTypeId.equals(mealTypeId),
      );

    final results = await query.get();
    final foodsWithMealTypes = <domain.CarbLoadingFood>[];

    for (final row in results) {
      final food = row.readTable(_database.carbLoadingFoodsTable);
      final mealTypes = await _getMealTypesForFood(food.id);
      foodsWithMealTypes.add(_convertToFoodDomain(food, mealTypes));
    }

    return foodsWithMealTypes;
  }

  /// Get a specific food by ID
  Future<domain.CarbLoadingFood?> getFoodById(String id) async {
    final query = _database.select(_database.carbLoadingFoodsTable)
      ..where((tbl) => tbl.id.equals(id));

    final food = await query.getSingleOrNull();
    if (food == null) return null;

    final mealTypes = await _getMealTypesForFood(id);
    return _convertToFoodDomain(food, mealTypes);
  }

  /// Search foods by name
  Future<List<domain.CarbLoadingFood>> searchFoodsByName(String searchTerm) async {
    final query = _database.select(_database.carbLoadingFoodsTable)
      ..where((tbl) => tbl.displayName.contains(searchTerm));

    final foods = await query.get();
    final foodsWithMealTypes = <domain.CarbLoadingFood>[];

    for (final food in foods) {
      final mealTypes = await _getMealTypesForFood(food.id);
      foodsWithMealTypes.add(_convertToFoodDomain(food, mealTypes));
    }

    return foodsWithMealTypes;
  }

  /// Get meal types associated with a food
  Future<List<int>> _getMealTypesForFood(String foodId) async {
    final query = _database.select(_database.carbLoadingFoodMealTypesTable)
      ..where((tbl) => tbl.carbLoadingFoodId.equals(foodId));

    final associations = await query.get();
    return associations.map((a) => a.mealTypeId).toList();
  }

  /// Convert Drift entity to domain model
  domain.CarbLoadingFood _convertToFoodDomain(
    CarbLoadingFood food,
    List<int> mealTypeIds,
  ) {
    return domain.CarbLoadingFood.fromDatabase(
      id: food.id,
      name: food.name,
      displayName: food.displayName,
      displayNamePlural: food.displayNamePlural,
      carbsPerServing: food.carbsPerServing,
      imageAddress: food.imageAddress,
      isDefault: food.isDefault,
      createdAt: food.createdAt,
      mealTypeIds: mealTypeIds,
    );
  }

  /// Watch all foods (for real-time updates)
  Stream<List<domain.CarbLoadingFood>> watchAllFoods() {
    return _database.select(_database.carbLoadingFoodsTable).watch().asyncMap(
      (foods) async {
        final foodsWithMealTypes = <domain.CarbLoadingFood>[];
        for (final food in foods) {
          final mealTypes = await _getMealTypesForFood(food.id);
          foodsWithMealTypes.add(_convertToFoodDomain(food, mealTypes));
        }
        return foodsWithMealTypes;
      },
    );
  }

  /// Watch foods by meal type (for real-time updates)
  Stream<List<domain.CarbLoadingFood>> watchFoodsByMealType(int mealTypeId) {
    final query = _database.select(_database.carbLoadingFoodsTable).join([
      innerJoin(
        _database.carbLoadingFoodMealTypesTable,
        _database.carbLoadingFoodMealTypesTable.carbLoadingFoodId
            .equalsExp(_database.carbLoadingFoodsTable.id),
      ),
    ])
      ..where(
        _database.carbLoadingFoodMealTypesTable.mealTypeId.equals(mealTypeId),
      );

    return query.watch().asyncMap((results) async {
      final foodsWithMealTypes = <domain.CarbLoadingFood>[];
      for (final row in results) {
        final food = row.readTable(_database.carbLoadingFoodsTable);
        final mealTypes = await _getMealTypesForFood(food.id);
        foodsWithMealTypes.add(_convertToFoodDomain(food, mealTypes));
      }
      return foodsWithMealTypes;
    });
  }
}

@riverpod
CarbLoadingFoodRepository carbLoadingFoodRepository(Ref ref) {
  return CarbLoadingFoodRepository(ref.watch(appDatabaseProvider));
}
