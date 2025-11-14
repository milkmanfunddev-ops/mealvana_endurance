import 'dart:convert';
import 'package:drift/drift.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:uuid/uuid.dart';
import '../../../shared/database/app_database.dart';
import '../../../shared/database/database_provider.dart';
import '../domain/carb_loading_user_food.dart' as domain;

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
    return foods.map((food) => _convertToUserFoodDomain(food)).toList();
  }

  /// Get user foods suitable for a specific meal type
  Future<List<domain.CarbLoadingUserFood>> getUserFoodsByMealType(
    String deviceId,
    int mealTypeId,
  ) async {
    final query = _database.select(_database.carbLoadingUserFoodsTable)
      ..where((tbl) => tbl.deviceId.equals(deviceId) & tbl.isDeleted.equals(false));

    final allFoods = await query.get();

    // Filter by meal type from array column
    return allFoods
        .where((food) {
          if (food.mealTypes == null) return false;
          final mealTypes = _parseMealTypesArray(food.mealTypes);
          return mealTypes.contains(mealTypeId);
        })
        .map((food) => _convertToUserFoodDomain(food))
        .toList();
  }

  /// Get a specific user food by ID
  Future<domain.CarbLoadingUserFood?> getUserFoodById(String id) async {
    final query = _database.select(_database.carbLoadingUserFoodsTable)
      ..where((tbl) => tbl.id.equals(id) & tbl.isDeleted.equals(false));

    final food = await query.getSingleOrNull();
    if (food == null) return null;

    return _convertToUserFoodDomain(food);
  }

  /// Create a new user food
  Future<domain.CarbLoadingUserFood> createUserFood({
    required String deviceId,
    required String userId,
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
    // Generate UUID for the new food
    final id = _uuid.v4();

    // Serialize meal types to PostgreSQL array format
    final mealTypesStr = mealTypeIds.isNotEmpty ? '{${mealTypeIds.join(',')}}' : null;

    // Insert the user food
    await _database.into(_database.carbLoadingUserFoodsTable).insert(
          CarbLoadingUserFoodsTableCompanion.insert(
            id: id,
            deviceId: deviceId,
            userId: userId,
            clientFoodId: Value(clientFoodId),
            name: name,
            displayName: displayName,
            displayNamePlural: Value(displayNamePlural),
            carbsPerServing: carbsPerServing,
            imageAddress: Value(imageAddress),
            barcode: Value(barcode),
            sourceFoodId: Value(sourceFoodId),
            sourceUserFoodId: Value(sourceUserFoodId),
            mealTypes: Value(mealTypesStr),
            isDeleted: const Value(false),
          ),
        );

    // Fetch and return the created food
    final food = await (_database.select(_database.carbLoadingUserFoodsTable)
          ..where((tbl) => tbl.id.equals(id)))
        .getSingle();

    return _convertToUserFoodDomain(food);
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
    // Build companion with only provided fields
    final companion = CarbLoadingUserFoodsTableCompanion(
      name: name != null ? Value(name) : const Value.absent(),
      displayName: displayName != null ? Value(displayName) : const Value.absent(),
      displayNamePlural: displayNamePlural != null ? Value(displayNamePlural) : const Value.absent(),
      carbsPerServing: carbsPerServing != null ? Value(carbsPerServing) : const Value.absent(),
      imageAddress: imageAddress != null ? Value(imageAddress) : const Value.absent(),
      mealTypes: mealTypeIds != null
          ? Value(mealTypeIds.isNotEmpty ? '{${mealTypeIds.join(',')}}' : null)
          : const Value.absent(),
      updatedAt: Value(DateTime.now()),
    );

    // Update the user food
    await (_database.update(_database.carbLoadingUserFoodsTable)
          ..where((tbl) => tbl.id.equals(id)))
        .write(companion);

    // Fetch and return the updated food
    final food = await (_database.select(_database.carbLoadingUserFoodsTable)
          ..where((tbl) => tbl.id.equals(id)))
        .getSingle();

    return _convertToUserFoodDomain(food);
  }

  /// Soft delete a user food
  Future<void> deleteUserFood(String id) async {
    await (_database.update(_database.carbLoadingUserFoodsTable)
          ..where((tbl) => tbl.id.equals(id)))
        .write(const CarbLoadingUserFoodsTableCompanion(
      isDeleted: Value(true),
      updatedAt: Value.absent(), // Drift will auto-update
    ));
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
          tbl.displayName.contains(searchTerm));

    final foods = await query.get();
    return foods.map((food) => _convertToUserFoodDomain(food)).toList();
  }

  /// Parse meal types from array column (PostgreSQL array format: {1,2,3})
  List<int> _parseMealTypesArray(String? mealTypesStr) {
    if (mealTypesStr == null || mealTypesStr.isEmpty) return [];

    try {
      // Handle PostgreSQL array format: {1,2,3}
      if (mealTypesStr.startsWith('{') && mealTypesStr.endsWith('}')) {
        final content = mealTypesStr.substring(1, mealTypesStr.length - 1);
        if (content.isEmpty) return [];
        return content.split(',').map((s) => int.parse(s.trim())).toList();
      }

      // Handle JSON array format: [1,2,3]
      if (mealTypesStr.startsWith('[') && mealTypesStr.endsWith(']')) {
        final List<dynamic> parsed = jsonDecode(mealTypesStr);
        return parsed.map((e) => e as int).toList();
      }

      return [];
    } catch (e) {
      return [];
    }
  }

  /// Convert Drift entity to domain model
  domain.CarbLoadingUserFood _convertToUserFoodDomain(CarbLoadingUserFood food) {
    final mealTypeIds = _parseMealTypesArray(food.mealTypes);

    return domain.CarbLoadingUserFood.fromDatabase(
      id: food.id,
      userId: food.userId,
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
        .map((foods) => foods.map((food) => _convertToUserFoodDomain(food)).toList());
  }

  /// Watch user foods by meal type (for real-time updates)
  Stream<List<domain.CarbLoadingUserFood>> watchUserFoodsByMealType(
    String deviceId,
    int mealTypeId,
  ) {
    return (_database.select(_database.carbLoadingUserFoodsTable)
          ..where((tbl) => tbl.deviceId.equals(deviceId) & tbl.isDeleted.equals(false)))
        .watch()
        .map((foods) => foods
            .where((food) {
              if (food.mealTypes == null) return false;
              final mealTypes = _parseMealTypesArray(food.mealTypes);
              return mealTypes.contains(mealTypeId);
            })
            .map((food) => _convertToUserFoodDomain(food))
            .toList());
  }
}

@riverpod
CarbLoadingUserFoodRepository carbLoadingUserFoodRepository(Ref ref) {
  return CarbLoadingUserFoodRepository(ref.watch(appDatabaseProvider));
}
