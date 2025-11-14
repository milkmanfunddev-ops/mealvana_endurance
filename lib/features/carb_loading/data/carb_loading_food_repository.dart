import 'dart:convert';
import 'package:drift/drift.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../../shared/database/app_database.dart';
import '../../../shared/database/database_provider.dart';
import '../domain/carb_loading_food.dart' as domain;
import '../domain/meal_type.dart' show MealType;

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

    return foods.map((food) => _convertToFoodDomain(food)).toList();
  }

  /// Get foods suitable for a specific meal type
  /// REFACTORED: More forgiving filtering - includes foods with null/empty meal_types
  Future<List<domain.CarbLoadingFood>> getFoodsByMealType(int mealTypeId) async {
    // Query foods and filter by meal_types array column
    final query = _database.select(_database.carbLoadingFoodsTable);
    final allFoods = await query.get();

    print('[CARB_LOADING_REPO] getFoodsByMealType($mealTypeId): Found ${allFoods.length} total foods');

    // Filter foods that have this meal type in their array
    final filteredFoods = allFoods.where((food) {
      // If meal_types is null or empty, include the food (works for all meal types)
      if (food.mealTypes == null || food.mealTypes!.isEmpty) {
        print('[CARB_LOADING_REPO] Including ${food.displayName} (no meal_types restriction)');
        return true;  // Changed from false to true - more forgiving!
      }

      final mealTypes = _parseMealTypesArray(food.mealTypes);
      final matches = mealTypes.isEmpty || mealTypes.contains(mealTypeId);

      if (matches) {
        print('[CARB_LOADING_REPO] Including ${food.displayName} (meal_types: $mealTypes)');
      }

      return matches;
    }).map((food) => _convertToFoodDomain(food)).toList();

    print('[CARB_LOADING_REPO] Returning ${filteredFoods.length} foods for meal type $mealTypeId');

    return filteredFoods;
  }

  /// Get a specific food by ID
  Future<domain.CarbLoadingFood?> getFoodById(String id) async {
    final query = _database.select(_database.carbLoadingFoodsTable)
      ..where((tbl) => tbl.id.equals(id));

    final food = await query.getSingleOrNull();
    if (food == null) return null;

    return _convertToFoodDomain(food);
  }

  /// Search foods by name
  Future<List<domain.CarbLoadingFood>> searchFoodsByName(String searchTerm) async {
    final query = _database.select(_database.carbLoadingFoodsTable)
      ..where((tbl) => tbl.displayName.contains(searchTerm));

    final foods = await query.get();
    return foods.map((food) => _convertToFoodDomain(food)).toList();
  }

  /// Parse meal types from array column
  /// Production schema: meal_types text[] (e.g., {breakfast,lunch,dinner})
  /// Converts meal type names to integer IDs for domain model compatibility
  List<int> _parseMealTypesArray(String? mealTypesStr) {
    if (mealTypesStr == null || mealTypesStr.isEmpty) return [];

    try {
      // Handle PostgreSQL array format: {breakfast,lunch,dinner}
      if (mealTypesStr.startsWith('{') && mealTypesStr.endsWith('}')) {
        final content = mealTypesStr.substring(1, mealTypesStr.length - 1);
        if (content.isEmpty) return [];

        // Parse meal type names and convert to IDs
        return content.split(',').map((nameStr) {
          final trimmedName = nameStr.trim();
          // Try to parse as integer first (backward compatibility)
          final intId = int.tryParse(trimmedName);
          if (intId != null) return intId;

          // Parse as meal type name and convert to ID
          try {
            final mealType = MealType.fromName(trimmedName);
            return mealType.id;
          } catch (e) {
            // If parsing fails, return breakfast as default
            return MealType.breakfast.id;
          }
        }).toList();
      }

      // Handle JSON array format: [1,2,3] or ["breakfast","lunch"]
      if (mealTypesStr.startsWith('[') && mealTypesStr.endsWith(']')) {
        final List<dynamic> parsed = jsonDecode(mealTypesStr);
        return parsed.map((e) {
          if (e is int) return e;
          if (e is String) {
            try {
              final mealType = MealType.fromName(e);
              return mealType.id;
            } catch (err) {
              return MealType.breakfast.id;
            }
          }
          return MealType.breakfast.id;
        }).toList();
      }

      return [];
    } catch (e) {
      return [];
    }
  }

  /// Convert Drift entity to domain model
  domain.CarbLoadingFood _convertToFoodDomain(CarbLoadingFood food) {
    final mealTypeIds = _parseMealTypesArray(food.mealTypes);

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
    return _database
        .select(_database.carbLoadingFoodsTable)
        .watch()
        .map((foods) => foods.map((food) => _convertToFoodDomain(food)).toList());
  }

  /// Watch foods by meal type (for real-time updates)
  Stream<List<domain.CarbLoadingFood>> watchFoodsByMealType(int mealTypeId) {
    return _database.select(_database.carbLoadingFoodsTable).watch().map(
          (foods) => foods
              .where((food) {
                if (food.mealTypes == null) return false;
                final mealTypes = _parseMealTypesArray(food.mealTypes);
                return mealTypes.contains(mealTypeId);
              })
              .map((food) => _convertToFoodDomain(food))
              .toList(),
        );
  }
}

@riverpod
CarbLoadingFoodRepository carbLoadingFoodRepository(Ref ref) {
  return CarbLoadingFoodRepository(ref.watch(appDatabaseProvider));
}
