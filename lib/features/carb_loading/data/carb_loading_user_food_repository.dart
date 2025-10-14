import 'package:drift/drift.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:uuid/uuid.dart';
import '../../../shared/database/app_database.dart';
import '../../../shared/database/database_provider.dart';
import '../domain/carb_loading_user_food.dart' as domain;
import '../domain/meal_type.dart' as domain;

part 'carb_loading_user_food_repository.g.dart';

const _uuid = Uuid();

/// Repository for managing user-created carb loading foods
/// Handles CRUD operations, soft deletes, and import tracking
class CarbLoadingUserFoodRepository {
  const CarbLoadingUserFoodRepository(this._database);

  final AppDatabase _database;

  /// Get all user foods (excluding soft-deleted)
  Future<List<domain.CarbLoadingUserFood>> getAllUserFoods(String deviceId) async {
    final query = _database.select(_database.carbLoadingUserFoodsTable)
      ..where((tbl) => tbl.deviceId.equals(deviceId) & tbl.isDeleted.equals(false));

    final foods = await query.get();
    final foodsWithMealTypes = <domain.CarbLoadingUserFood>[];

    for (final food in foods) {
      final mealTypes = await _getMealTypesForUserFood(food.id);
      foodsWithMealTypes.add(_convertToUserFoodDomain(food, mealTypes));
    }

    return foodsWithMealTypes;
  }

  /// Get user foods suitable for a specific meal type
  Future<List<domain.CarbLoadingUserFood>> getUserFoodsByMealType(
    String deviceId,
    int mealTypeId,
  ) async {
    final query = _database.select(_database.carbLoadingUserFoodsTable).join([
      innerJoin(
        _database.carbLoadingUserFoodMealTypesTable,
        _database.carbLoadingUserFoodMealTypesTable.carbLoadingUserFoodId
            .equalsExp(_database.carbLoadingUserFoodsTable.id),
      ),
    ])
      ..where(
        _database.carbLoadingUserFoodsTable.deviceId.equals(deviceId) &
            _database.carbLoadingUserFoodsTable.isDeleted.equals(false) &
            _database.carbLoadingUserFoodMealTypesTable.mealTypeId
                .equals(mealTypeId),
      );

    final results = await query.get();
    final foodsWithMealTypes = <domain.CarbLoadingUserFood>[];

    for (final row in results) {
      final food = row.readTable(_database.carbLoadingUserFoodsTable);
      final mealTypes = await _getMealTypesForUserFood(food.id);
      foodsWithMealTypes.add(_convertToUserFoodDomain(food, mealTypes));
    }

    return foodsWithMealTypes;
  }

  /// Get a specific user food by ID
  Future<domain.CarbLoadingUserFood?> getUserFoodById(String id) async {
    final query = _database.select(_database.carbLoadingUserFoodsTable)
      ..where((tbl) => tbl.id.equals(id) & tbl.isDeleted.equals(false));

    final food = await query.getSingleOrNull();
    if (food == null) return null;

    final mealTypes = await _getMealTypesForUserFood(id);
    return _convertToUserFoodDomain(food, mealTypes);
  }

  /// Create a new user food
  Future<domain.CarbLoadingUserFood> createUserFood({
    required String deviceId,
    String? clientFoodId,
    required String name,
    required String displayName,
    String? displayNamePlural,
    required double carbsPerServing,
    String? imageAddress,
    String? barcode,
    String? sourceFoodId,
    String? sourceUserFoodId,
    required List<int> mealTypeIds,
  }) async {
    return await _database.transaction(() async {
      // Generate UUID for the new food
      final id = _uuid.v4();

      // Insert the user food
      await _database.into(_database.carbLoadingUserFoodsTable).insert(
            CarbLoadingUserFoodsTableCompanion.insert(
              id: id,
              deviceId: deviceId,
              clientFoodId: Value(clientFoodId),
              name: name,
              displayName: displayName,
              displayNamePlural: Value(displayNamePlural),
              carbsPerServing: carbsPerServing,
              imageAddress: Value(imageAddress),
              barcode: Value(barcode),
              sourceFoodId: Value(sourceFoodId),
              sourceUserFoodId: Value(sourceUserFoodId),
              isDeleted: const Value(false),
            ),
          );

      // Insert meal type associations
      for (final mealTypeId in mealTypeIds) {
        await _database
            .into(_database.carbLoadingUserFoodMealTypesTable)
            .insert(
              CarbLoadingUserFoodMealTypesTableCompanion.insert(
                carbLoadingUserFoodId: id,
                mealTypeId: mealTypeId,
              ),
            );
      }

      // Fetch and return the created food
      final food = await (_database.select(_database.carbLoadingUserFoodsTable)
            ..where((tbl) => tbl.id.equals(id)))
          .getSingle();

      return _convertToUserFoodDomain(food, mealTypeIds);
    });
  }

  /// Update a user food
  Future<domain.CarbLoadingUserFood> updateUserFood({
    required String id,
    String? name,
    String? displayName,
    String? displayNamePlural,
    double? carbsPerServing,
    String? imageAddress,
    List<int>? mealTypeIds,
  }) async {
    return await _database.transaction(() async {
      // Update the user food
      await (_database.update(_database.carbLoadingUserFoodsTable)
            ..where((tbl) => tbl.id.equals(id)))
          .write(
        CarbLoadingUserFoodsTableCompanion(
          name: name != null ? Value(name) : const Value.absent(),
          displayName: displayName != null ? Value(displayName) : const Value.absent(),
          displayNamePlural: displayNamePlural != null
              ? Value(displayNamePlural)
              : const Value.absent(),
          carbsPerServing: carbsPerServing != null
              ? Value(carbsPerServing)
              : const Value.absent(),
          imageAddress:
              imageAddress != null ? Value(imageAddress) : const Value.absent(),
          updatedAt: Value(DateTime.now()),
        ),
      );

      // Update meal type associations if provided
      if (mealTypeIds != null) {
        // Delete existing associations
        await (_database.delete(_database.carbLoadingUserFoodMealTypesTable)
              ..where((tbl) => tbl.carbLoadingUserFoodId.equals(id)))
            .go();

        // Insert new associations
        for (final mealTypeId in mealTypeIds) {
          await _database
              .into(_database.carbLoadingUserFoodMealTypesTable)
              .insert(
                CarbLoadingUserFoodMealTypesTableCompanion.insert(
                  carbLoadingUserFoodId: id,
                  mealTypeId: mealTypeId,
                ),
              );
        }
      }

      // Fetch and return the updated food
      final food = await (_database.select(_database.carbLoadingUserFoodsTable)
            ..where((tbl) => tbl.id.equals(id)))
          .getSingle();

      final updatedMealTypes = mealTypeIds ?? await _getMealTypesForUserFood(id);
      return _convertToUserFoodDomain(food, updatedMealTypes);
    });
  }

  /// Soft delete a user food
  Future<void> deleteUserFood(String id) async {
    await (_database.update(_database.carbLoadingUserFoodsTable)
          ..where((tbl) => tbl.id.equals(id)))
        .write(
      CarbLoadingUserFoodsTableCompanion(
        isDeleted: const Value(true),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  /// Import a food from the foods table
  Future<domain.CarbLoadingUserFood> importFromFoodsTable({
    required String deviceId,
    required String sourceFoodId,
    required String name,
    required String displayName,
    required double carbsPerServing,
    String? imageAddress,
    required List<int> mealTypeIds,
  }) async {
    return createUserFood(
      deviceId: deviceId,
      name: name,
      displayName: displayName,
      carbsPerServing: carbsPerServing,
      imageAddress: imageAddress,
      sourceFoodId: sourceFoodId,
      mealTypeIds: mealTypeIds,
    );
  }

  /// Import a food from the user_foods table
  Future<domain.CarbLoadingUserFood> importFromUserFoodsTable({
    required String deviceId,
    required String sourceUserFoodId,
    required String name,
    required String displayName,
    required double carbsPerServing,
    String? imageAddress,
    required List<int> mealTypeIds,
  }) async {
    return createUserFood(
      deviceId: deviceId,
      name: name,
      displayName: displayName,
      carbsPerServing: carbsPerServing,
      imageAddress: imageAddress,
      sourceUserFoodId: sourceUserFoodId,
      mealTypeIds: mealTypeIds,
    );
  }

  /// Create a food from barcode scan
  Future<domain.CarbLoadingUserFood> createFromBarcodeScan({
    required String deviceId,
    required String barcode,
    required String name,
    required String displayName,
    required double carbsPerServing,
    String? imageAddress,
    required List<int> mealTypeIds,
  }) async {
    return createUserFood(
      deviceId: deviceId,
      name: name,
      displayName: displayName,
      carbsPerServing: carbsPerServing,
      imageAddress: imageAddress,
      barcode: barcode,
      mealTypeIds: mealTypeIds,
    );
  }

  /// Get user food by source_food_id (for checking if food already imported)
  Future<domain.CarbLoadingUserFood?> getUserFoodBySourceFoodId(String sourceFoodId) async {
    final query = _database.select(_database.carbLoadingUserFoodsTable)
      ..where((tbl) => tbl.sourceFoodId.equals(sourceFoodId) & tbl.isDeleted.equals(false));

    final food = await query.getSingleOrNull();
    if (food == null) return null;

    final mealTypes = await _getMealTypesForUserFood(food.id);
    return _convertToUserFoodDomain(food, mealTypes);
  }

  /// Get user food by source_user_food_id (for checking if user food already imported)
  Future<domain.CarbLoadingUserFood?> getUserFoodBySourceUserFoodId(String sourceUserFoodId) async {
    final query = _database.select(_database.carbLoadingUserFoodsTable)
      ..where((tbl) => tbl.sourceUserFoodId.equals(sourceUserFoodId) & tbl.isDeleted.equals(false));

    final food = await query.getSingleOrNull();
    if (food == null) return null;

    final mealTypes = await _getMealTypesForUserFood(food.id);
    return _convertToUserFoodDomain(food, mealTypes);
  }

  /// Search user foods by name
  Future<List<domain.CarbLoadingUserFood>> searchUserFoodsByName(
    String deviceId,
    String searchTerm,
  ) async {
    final query = _database.select(_database.carbLoadingUserFoodsTable)
      ..where((tbl) =>
          tbl.deviceId.equals(deviceId) &
          tbl.isDeleted.equals(false) &
          tbl.displayName.like('%$searchTerm%'));

    final foods = await query.get();
    final foodsWithMealTypes = <domain.CarbLoadingUserFood>[];

    for (final food in foods) {
      final mealTypes = await _getMealTypesForUserFood(food.id);
      foodsWithMealTypes.add(_convertToUserFoodDomain(food, mealTypes));
    }

    return foodsWithMealTypes;
  }

  /// Get meal types associated with a user food
  Future<List<int>> _getMealTypesForUserFood(String foodId) async {
    final query =
        _database.select(_database.carbLoadingUserFoodMealTypesTable)
          ..where((tbl) => tbl.carbLoadingUserFoodId.equals(foodId));

    final associations = await query.get();
    return associations.map((a) => a.mealTypeId).toList();
  }

  /// Convert Drift entity to domain model
  domain.CarbLoadingUserFood _convertToUserFoodDomain(
    CarbLoadingUserFood food,
    List<int> mealTypeIds,
  ) {
    return domain.CarbLoadingUserFood.fromDatabase(
      id: food.id,
      deviceId: food.deviceId,
      clientFoodId: food.clientFoodId,
      name: food.name,
      displayName: food.displayName,
      displayNamePlural: food.displayNamePlural,
      carbsPerServing: food.carbsPerServing,
      imageAddress: food.imageAddress,
      barcode: food.barcode,
      sourceFoodId: food.sourceFoodId,
      sourceUserFoodId: food.sourceUserFoodId,
      isDeleted: food.isDeleted,
      createdAt: food.createdAt,
      updatedAt: food.updatedAt,
      mealTypeIds: mealTypeIds,
    );
  }

  /// Watch all user foods (for real-time updates)
  Stream<List<domain.CarbLoadingUserFood>> watchUserFoods(String deviceId) {
    return (_database.select(_database.carbLoadingUserFoodsTable)
          ..where((tbl) => tbl.deviceId.equals(deviceId) & tbl.isDeleted.equals(false)))
        .watch()
        .asyncMap(
      (foods) async {
        final foodsWithMealTypes = <domain.CarbLoadingUserFood>[];
        for (final food in foods) {
          final mealTypes = await _getMealTypesForUserFood(food.id);
          foodsWithMealTypes.add(_convertToUserFoodDomain(food, mealTypes));
        }
        return foodsWithMealTypes;
      },
    );
  }
}

@riverpod
CarbLoadingUserFoodRepository carbLoadingUserFoodRepository(Ref ref) {
  return CarbLoadingUserFoodRepository(ref.watch(appDatabaseProvider));
}
