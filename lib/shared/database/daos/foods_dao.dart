import 'dart:convert';

import 'package:drift/drift.dart';
import '../app_database.dart';
import '../tables/foods_table.dart';
import '../tables/user_foods_table.dart';
import '../../../features/nutrition_plan/domain/food_item.dart';

part 'foods_dao.g.dart';

/// Data Access Object for foods and user foods.
///
/// This DAO handles:
/// - Food cache operations (getAllCachedFoods, cacheFoods)
/// - User food CRUD operations (save, update, delete)
/// - Food queries by category
/// - UserFood to FoodItem domain conversion
@DriftAccessor(tables: [FoodsTable, UserFoodsTable])
class FoodsDao extends DatabaseAccessor<AppDatabase> with _$FoodsDaoMixin {
  FoodsDao(super.db);

  // ==================== Food Cache Methods ====================

  /// Get count of cached foods
  Future<int> getFoodCount() async {
    final countQuery = selectOnly(foodsTable)
      ..addColumns([foodsTable.id.count()]);
    final result = await countQuery.getSingle();
    return result.read(foodsTable.id.count()) ?? 0;
  }

  /// Get all cached foods from local database
  Future<List<FoodEntry>> getAllCachedFoods() async {
    return await select(foodsTable).get();
  }

  /// Cache foods from Supabase
  Future<void> cacheFoods(List<Map<String, dynamic>> foodsData) async {
    await batch((batch) {
      for (final food in foodsData) {
        batch.insert(
          foodsTable,
          _mapToFoodEntry(food),
          mode: InsertMode.insertOrReplace,
        );
      }
    });
  }

  /// Get foods by category (using array-based categories now)
  /// TODO: Implement array-based category filtering after foods_table is updated
  Future<List<FoodEntry>> getFoodsByCategory(String categoryName) async {
    // Temporarily return all foods until array filtering is implemented
    return await select(foodsTable).get();
  }

  // ==================== User Foods Methods ====================

  /// Save a scanned food with categories and activity types arrays
  Future<void> saveUserFood({
    required String deviceId,
    required String userId,
    required String id,
    required String clientFoodId,
    String? barcode,
    required String name,
    String? displayName,
    String? displayNamePlural,
    String? description,
    String? imageAddress,
    double? servingAmount,
    String? servingUnit,
    int? caloriesPerServing,
    double? carbsPerServing,
    double? proteinPerServing,
    double? fatPerServing,
    int? sodiumMg,
    double? fluidMlPerServing,
    String? productTypeId,
    required List<String> categories,
    List<String>? activityTypes,
    DateTime? clientUpdatedAt,
  }) async {
    // Convert arrays to PostgreSQL array format for consistency with Supabase
    // Format: {value1,value2,value3} or null if empty
    final categoriesJson =
        categories.isNotEmpty ? '{${categories.join(',')}}' : null;
    final activityTypesJson =
        activityTypes != null && activityTypes.isNotEmpty
            ? '{${activityTypes.join(',')}}'
            : null;

    // Insert the user food with category and activity type arrays
    await into(userFoodsTable).insert(
      UserFoodsTableCompanion.insert(
        id: id,
        deviceId: deviceId,
        userId: userId,
        clientFoodId: Value(clientFoodId),
        barcode: Value(barcode),
        name: name,
        displayName: Value(displayName),
        displayNamePlural: Value(displayNamePlural),
        description: Value(description),
        imageAddress: Value(imageAddress),
        servingAmount: Value(servingAmount),
        servingUnit: Value(servingUnit),
        caloriesPerServing: Value(caloriesPerServing),
        carbsPerServing: Value(carbsPerServing),
        proteinPerServing: Value(proteinPerServing),
        fatPerServing: Value(fatPerServing),
        sodiumMg: Value(sodiumMg),
        fluidMlPerServing: Value(fluidMlPerServing),
        productTypeId: Value(productTypeId),
        categories: Value(categoriesJson),
        activityTypes: Value(activityTypesJson),
        clientUpdatedAt: Value(clientUpdatedAt),
        createdAt: Value(DateTime.now()),
        updatedAt: Value(DateTime.now()),
      ),
    );

    // Mark as dirty for sync - use Unix timestamp for Drift compatibility
    final nowMillis = DateTime.now().millisecondsSinceEpoch;
    await db.customStatement(
      'UPDATE user_foods SET needs_upload = 1, local_updated_at = ? WHERE id = ?',
      [nowMillis, id],
    );
  }

  /// Update an existing user food
  Future<bool> updateUserFood({
    required String id,
    String? name,
    String? displayName,
    String? displayNamePlural,
    String? description,
    double? servingAmount,
    String? servingUnit,
    int? caloriesPerServing,
    double? carbsPerServing,
    double? proteinPerServing,
    double? fatPerServing,
    int? sodiumMg,
    double? fluidMlPerServing,
    List<String>? categories,
  }) async {
    // Build update companion with only provided fields
    final companion = UserFoodsTableCompanion(
      name: name != null ? Value(name) : const Value.absent(),
      displayName:
          displayName != null ? Value(displayName) : const Value.absent(),
      displayNamePlural: displayNamePlural != null
          ? Value(displayNamePlural)
          : const Value.absent(),
      description:
          description != null ? Value(description) : const Value.absent(),
      servingAmount:
          servingAmount != null ? Value(servingAmount) : const Value.absent(),
      servingUnit:
          servingUnit != null ? Value(servingUnit) : const Value.absent(),
      caloriesPerServing: caloriesPerServing != null
          ? Value(caloriesPerServing)
          : const Value.absent(),
      carbsPerServing:
          carbsPerServing != null ? Value(carbsPerServing) : const Value.absent(),
      proteinPerServing: proteinPerServing != null
          ? Value(proteinPerServing)
          : const Value.absent(),
      fatPerServing:
          fatPerServing != null ? Value(fatPerServing) : const Value.absent(),
      sodiumMg: sodiumMg != null ? Value(sodiumMg) : const Value.absent(),
      fluidMlPerServing: fluidMlPerServing != null
          ? Value(fluidMlPerServing)
          : const Value.absent(),
      categories: categories != null
          ? Value(categories.isNotEmpty ? '{${categories.join(',')}}' : null)
          : const Value.absent(),
      updatedAt: Value(DateTime.now()),
      clientUpdatedAt: Value(DateTime.now()),
    );

    final updatedRows =
        await (update(userFoodsTable)..where((f) => f.id.equals(id)))
            .write(companion);

    // Mark as dirty for sync
    final nowMillis = DateTime.now().millisecondsSinceEpoch;
    await db.customStatement(
      'UPDATE user_foods SET needs_upload = 1, local_updated_at = ? WHERE id = ?',
      [nowMillis, id],
    );

    return updatedRows > 0;
  }

  /// Get user foods for a user
  /// Searches by both userId AND deviceId for backwards compatibility
  /// (older foods may have been saved with deviceId only)
  Future<List<UserFood>> getUserFoods(String userId) async {
    final query = select(userFoodsTable)
      ..where(
        (f) =>
            (f.userId.equals(userId) | f.deviceId.equals(userId)) &
            f.isDeleted.equals(false),
      )
      ..orderBy([(f) => OrderingTerm.desc(f.createdAt)]);

    try {
      return await query.get();
    } on FormatException {
      // Legacy rows may store timestamps as TEXT; normalize and retry
      await normalizeUserFoodTimestamps();
      return await query.get();
    }
  }

  /// Check for duplicate barcode in user foods
  Future<bool> hasUserFoodWithBarcode(String userId, String barcode) async {
    final query = select(userFoodsTable)
      ..where(
        (f) =>
            f.userId.equals(userId) &
            f.barcode.equals(barcode) &
            f.isDeleted.equals(false),
      )
      ..limit(1);

    final results = await query.get();
    return results.isNotEmpty;
  }

  /// Delete user food (soft delete for offline sync durability)
  Future<bool> deleteUserFood(String userFoodId) async {
    // Soft delete: mark is_deleted for offline sync durability
    final updatedRows = await (update(userFoodsTable)
          ..where((f) => f.id.equals(userFoodId)))
        .write(const UserFoodsTableCompanion(isDeleted: Value(true)));

    // Update sync tracking columns - use Unix timestamp for Drift compatibility
    final nowMillis = DateTime.now().millisecondsSinceEpoch;
    await db.customStatement(
      'UPDATE user_foods SET needs_upload = 1, local_updated_at = ? WHERE id = ?',
      [nowMillis, userFoodId],
    );

    return updatedRows > 0;
  }

  /// Replace all user foods for a user (used during sync from server)
  Future<void> replaceUserFoods(
    String userId,
    List<Map<String, dynamic>> remoteFoods,
  ) async {
    await db.transaction(() async {
      await (delete(userFoodsTable)..where((tbl) => tbl.userId.equals(userId)))
          .go();

      for (final food in remoteFoods) {
        try {
          final categoriesJson = food['categories'];
          final activityTypesJson = food['activity_types'];

          await into(userFoodsTable).insertOnConflictUpdate(
            UserFoodsTableCompanion(
              id: Value(food['id'] as String),
              deviceId: Value(food['device_id'] as String? ?? userId),
              userId: Value(userId),
              clientFoodId: Value(food['client_food_id'] as String?),
              barcode: Value(food['barcode'] as String?),
              name: Value(food['name'] as String),
              displayName: Value(food['display_name'] as String?),
              displayNamePlural: Value(food['display_name_plural'] as String?),
              description: Value(food['description'] as String?),
              imageAddress: Value(food['image_address'] as String?),
              servingAmount:
                  Value((food['serving_amount'] as num?)?.toDouble()),
              servingUnit: Value(food['serving_unit'] as String?),
              caloriesPerServing: Value(food['calories_per_serving'] as int?),
              carbsPerServing:
                  Value((food['carbs_per_serving'] as num?)?.toDouble()),
              proteinPerServing:
                  Value((food['protein_per_serving'] as num?)?.toDouble()),
              fatPerServing:
                  Value((food['fat_per_serving'] as num?)?.toDouble()),
              sodiumMg: Value(food['sodium_mg'] as int?),
              fluidMlPerServing:
                  Value((food['fluid_ml_per_serving'] as num?)?.toDouble()),
              productTypeId: Value(
                (food['product_type'] ?? food['product_type_id']) as String?,
              ),
              categories: Value(
                categoriesJson is List
                    ? jsonEncode(categoriesJson)
                    : categoriesJson as String?,
              ),
              activityTypes: Value(
                activityTypesJson is List
                    ? jsonEncode(activityTypesJson)
                    : activityTypesJson as String?,
              ),
              isElectrolyte: Value(_asBool(food['is_electrolyte'])),
              toExcludeFromSolver: Value(_asBool(food['to_exclude_from_solver'])),
              isDeleted: Value(_asBool(food['is_deleted'])),
              createdAt:
                  Value(_parseDate(food['created_at']) ?? DateTime.now()),
              updatedAt:
                  Value(_parseDate(food['updated_at']) ?? DateTime.now()),
              clientUpdatedAt: Value(_parseDate(food['client_updated_at'])),
              needsUpload: const Value(false),
            ),
          );
        } catch (_) {
          // Skip malformed rows but continue syncing others
        }
      }
    });
  }

  // ==================== Domain Conversion Methods ====================

  /// Convert UserFood (Drift) to FoodItem (Domain) for display
  FoodItem convertUserFoodToFoodItem(UserFood userFood) {
    // Parse categories from database string field
    final categories = _parseUserFoodCategories(userFood.categories);

    return FoodItem(
      id: userFood.id,
      name: userFood.name,
      imageAddress: userFood.imageAddress,
      description: userFood.description,
      categories: categories,
      servingAmount: userFood.servingAmount,
      displayName: userFood.displayName,
      displayNamePlural: userFood.displayNamePlural,
      carbsPerServing: userFood.carbsPerServing,
      proteinPerServing: userFood.proteinPerServing,
      fatPerServing: userFood.fatPerServing,
      caloriesPerServing: userFood.caloriesPerServing,
      fluidMlPerServing: userFood.fluidMlPerServing,
      sodiumMg: userFood.sodiumMg,
      beforeRunSuitable: true, // Default for scanned foods
      duringRunSuitable: true,
      runPortable: true,
      requiresPreparation: false,
      aidStationAvailable: false,
      maxServingsBefore: 2,
      maxServingsDuring: 1,
      toExcludeFromSolver: userFood.toExcludeFromSolver,
    );
  }

  // ==================== Private Helper Methods ====================

  /// Helper method to map Supabase food data to FoodEntry
  FoodsTableCompanion _mapToFoodEntry(Map<String, dynamic> foodData) {
    return FoodsTableCompanion.insert(
      id: foodData['id'] ?? '',
      name: Value(foodData['name']),
      displayName: Value(foodData['display_name']),
      imageAddress: Value(foodData['image_address']),
      description: Value(foodData['description']),
      instructions: Value(foodData['instructions']),
      nutritionalInfo: Value(foodData['nutritional_info']),
      servingAmount: Value(foodData['serving_amount']?.toDouble()),
      servingUnit: Value(foodData['serving_unit']),
      servingUnitPlural: Value(foodData['serving_unit_plural']),
      servingQualifier: Value(foodData['serving_qualifier']),
      servingSize: Value(foodData['serving_size']),
      servingDescription: Value(foodData['serving_description']),
      isElectrolyte: Value(foodData['is_electrolyte'] ?? false),
      maxServingsBefore: Value(foodData['max_servings_before']),
      maxServingsDuring: Value(foodData['max_servings_during']),
      maxServingsAfter: Value(foodData['max_servings_after']),
      sodiumMg: Value(foodData['sodium_mg']),
      caffeineMg: Value(foodData['caffeine_mg']),
      potassiumMg: Value(foodData['potassium_mg']),
      fatPerServing: Value(foodData['fat_per_serving']?.toDouble()),
      carbsPerServing: Value(foodData['carbs_per_serving']?.toDouble()),
      proteinPerServing: Value(foodData['protein_per_serving']?.toDouble()),
      caloriesPerServing: Value(foodData['calories_per_serving']),
      fluidMlPerServing: Value(foodData['fluid_ml_per_serving']?.toDouble()),
      productTypeId: Value(foodData['product_type_id']),
      purchaseUrl: Value(foodData['purchase_url']),
      affiliateSource: Value(foodData['affiliate_source']),
      showInPreferences: Value(foodData['show_in_preferences'] ?? false),
      preferencePriority: Value(foodData['preference_priority']),
    );
  }

  /// Normalize legacy TEXT timestamps in user_foods to Unix millis.
  /// Called from AppDatabase migration's beforeOpen to handle legacy data.
  Future<void> normalizeUserFoodTimestamps() async {
    const timestampColumns = [
      'created_at',
      'updated_at',
      'client_updated_at',
      'local_updated_at',
    ];

    await db.transaction(() async {
      for (final column in timestampColumns) {
        await db.customStatement('''
          UPDATE user_foods
          SET $column = CAST(
            strftime('%s', replace(replace($column, 'T', ' '), 'Z', ''))
            AS INTEGER
          ) * 1000
          WHERE typeof($column) = 'text'
            AND $column IS NOT NULL
            AND $column != ''
            AND strftime('%s', replace(replace($column, 'T', ' '), 'Z', '')) IS NOT NULL;
        ''');
      }
    });
  }

  /// Parse categories from UserFood database string to FoodCategory list
  /// Handles PostgreSQL array format {a,b,c} and JSON format ["a","b"]
  List<FoodCategory> _parseUserFoodCategories(String? categoriesStr) {
    if (categoriesStr == null || categoriesStr.isEmpty) {
      return [];
    }

    final trimmed = categoriesStr.trim();
    List<String> categoryStrings = [];

    // Handle PostgreSQL array format: {before_run,during_run,after_run}
    if (trimmed.startsWith('{') && trimmed.endsWith('}')) {
      final inner = trimmed.substring(1, trimmed.length - 1);
      if (inner.isNotEmpty) {
        categoryStrings = inner.split(',').map((s) => s.trim()).toList();
      }
    }
    // Handle JSON array format: ["before_run","during_run"]
    else if (trimmed.startsWith('[')) {
      try {
        final decoded = jsonDecode(trimmed);
        if (decoded is List) {
          categoryStrings = List<String>.from(decoded);
        }
      } catch (_) {
        // Fallback to comma-separated
        categoryStrings = trimmed.split(',').map((s) => s.trim()).toList();
      }
    }
    // Fallback: treat as single category or comma-separated
    else if (trimmed.contains(',')) {
      categoryStrings = trimmed.split(',').map((s) => s.trim()).toList();
    } else if (trimmed.isNotEmpty) {
      categoryStrings = [trimmed];
    }

    // Convert strings to FoodCategory enums
    return categoryStrings
        .map((str) {
          try {
            return FoodCategory.fromDbValue(str);
          } catch (_) {
            return null;
          }
        })
        .whereType<FoodCategory>()
        .toList();
  }

  /// Helper to parse boolean from dynamic value
  bool _asBool(dynamic value) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    return false;
  }

  /// Helper to parse DateTime from dynamic value
  DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is String) {
      return DateTime.tryParse(value);
    }
    return null;
  }
}
