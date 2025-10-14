import 'package:drift/drift.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../../shared/database/app_database.dart';
import '../../../shared/database/database_provider.dart';
import '../data/carb_loading_user_food_repository.dart';
import '../domain/carb_loading_user_food.dart' as domain;
import '../domain/meal_type.dart' as domain;

part 'food_import_service.g.dart';

/// Service for importing foods from other tables into carb loading user foods
/// Supports importing from foods table, user_foods table, and barcode scanning
class FoodImportService {
  const FoodImportService({
    required AppDatabase database,
    required CarbLoadingUserFoodRepository userFoodRepository,
  })  : _database = database,
        _userFoodRepository = userFoodRepository;

  final AppDatabase _database;
  final CarbLoadingUserFoodRepository _userFoodRepository;

  /// Import a food from the foods table
  Future<domain.CarbLoadingUserFood> importFromFoodsTable({
    required String deviceId,
    required String sourceFoodId,
    required List<domain.MealType> mealTypes,
  }) async {
    // Fetch the source food from foods table
    final sourceFood = await (_database.select(_database.foodsTable)
          ..where((tbl) => tbl.id.equals(sourceFoodId)))
        .getSingleOrNull();

    if (sourceFood == null) {
      throw ArgumentError('Source food not found');
    }

    // Calculate carbs per serving (we only track carbs for carb loading)
    final carbsPerServing = sourceFood.carbsPerServing ?? 0.0;

    // Use the food's existing display name or generate one
    final displayName = sourceFood.displayName != null && sourceFood.displayName!.isNotEmpty
        ? sourceFood.displayName!
        : (sourceFood.name ?? '');

    return _userFoodRepository.importFromFoodsTable(
      deviceId: deviceId,
      sourceFoodId: sourceFoodId,
      name: sourceFood.name ?? '',
      displayName: displayName,
      carbsPerServing: carbsPerServing,
      imageAddress: sourceFood.imageAddress,
      mealTypeIds: mealTypes.map((mt) => mt.id).toList(),
    );
  }

  /// Import a food from the user_foods table
  Future<domain.CarbLoadingUserFood> importFromUserFoodsTable({
    required String deviceId,
    required String sourceUserFoodId,
    required List<domain.MealType> mealTypes,
  }) async {
    // Fetch the source user food from user_foods table
    final sourceUserFood = await (_database.select(_database.userFoodsTable)
          ..where((tbl) => tbl.id.equals(sourceUserFoodId)))
        .getSingleOrNull();

    if (sourceUserFood == null) {
      throw ArgumentError('Source user food not found');
    }

    // Calculate carbs per serving
    final carbsPerServing = sourceUserFood.carbsPerServing ?? 0.0;

    // Use the food's existing display name or generate one
    final displayName = sourceUserFood.displayName != null && sourceUserFood.displayName!.isNotEmpty
        ? sourceUserFood.displayName!
        : (sourceUserFood.name ?? '');

    return _userFoodRepository.importFromUserFoodsTable(
      deviceId: deviceId,
      sourceUserFoodId: sourceUserFoodId,
      name: sourceUserFood.name ?? '',
      displayName: displayName,
      carbsPerServing: carbsPerServing,
      imageAddress: sourceUserFood.imageAddress,
      mealTypeIds: mealTypes.map((mt) => mt.id).toList(),
    );
  }

  /// Create a food from barcode scan result
  /// This assumes barcode data has already been fetched via barcode scanning service
  Future<domain.CarbLoadingUserFood> createFromBarcodeScan({
    required String deviceId,
    required String barcode,
    required String productName,
    required double carbsPerServing,
    String? imageUrl,
    required List<domain.MealType> mealTypes,
  }) async {
    // Generate display name with serving info if not included
    final displayName = productName;

    // Use product name as internal name (lowercase, no spaces)
    final name = productName.toLowerCase().replaceAll(' ', '_');

    return _userFoodRepository.createFromBarcodeScan(
      deviceId: deviceId,
      barcode: barcode,
      name: name,
      displayName: displayName,
      carbsPerServing: carbsPerServing,
      imageAddress: imageUrl,
      mealTypeIds: mealTypes.map((mt) => mt.id).toList(),
    );
  }

  /// Create a custom carb loading food from manual entry
  Future<domain.CarbLoadingUserFood> createCustomFood({
    required String deviceId,
    required String name,
    required String displayName,
    String? displayNamePlural,
    required double carbsPerServing,
    String? imageAddress,
    String? barcode,
    required List<domain.MealType> mealTypes,
  }) async {
    return _userFoodRepository.createUserFood(
      deviceId: deviceId,
      name: name,
      displayName: displayName,
      displayNamePlural: displayNamePlural,
      carbsPerServing: carbsPerServing,
      imageAddress: imageAddress,
      barcode: barcode,
      mealTypeIds: mealTypes.map((mt) => mt.id).toList(),
    );
  }

  /// Search foods table for foods to import
  Future<List<FoodEntry>> searchFoodsForImport({
    required String searchTerm,
    int? categoryId,
  }) async {
    if (categoryId != null) {
      // Join with food_categories to filter by category
      final joinQuery = _database.select(_database.foodsTable).join([
        innerJoin(
          _database.foodCategoriesTable,
          _database.foodCategoriesTable.foodId.equalsExp(_database.foodsTable.id),
        ),
      ])
        ..where(
          _database.foodsTable.displayName.contains(searchTerm) &
              _database.foodCategoriesTable.categoryId.equals(categoryId),
        );

      final results = await joinQuery.get();
      return results.map((row) => row.readTable(_database.foodsTable)).toList();
    }

    final query = _database.select(_database.foodsTable)
      ..where((tbl) => tbl.displayName.contains(searchTerm));

    return query.get();
  }

  /// Search user_foods table for foods to import
  Future<List<UserFood>> searchUserFoodsForImport({
    required String deviceId,
    required String searchTerm,
  }) async {
    final query = _database.select(_database.userFoodsTable)
      ..where((tbl) =>
          tbl.deviceId.equals(deviceId) &
          tbl.displayName.contains(searchTerm) &
          tbl.isDeleted.equals(false));

    return query.get();
  }

  /// Check if a food from foods table is already imported
  Future<bool> isFoodAlreadyImported({
    required String deviceId,
    required String sourceFoodId,
  }) async {
    final query = _database.select(_database.carbLoadingUserFoodsTable)
      ..where((tbl) =>
          tbl.deviceId.equals(deviceId) &
          tbl.sourceFoodId.equals(sourceFoodId) &
          tbl.isDeleted.equals(false));

    final existing = await query.getSingleOrNull();
    return existing != null;
  }

  /// Check if a user food is already imported
  Future<bool> isUserFoodAlreadyImported({
    required String deviceId,
    required String sourceUserFoodId,
  }) async {
    final query = _database.select(_database.carbLoadingUserFoodsTable)
      ..where((tbl) =>
          tbl.deviceId.equals(deviceId) &
          tbl.sourceUserFoodId.equals(sourceUserFoodId) &
          tbl.isDeleted.equals(false));

    final existing = await query.getSingleOrNull();
    return existing != null;
  }

  /// Check if a barcode is already imported
  Future<bool> isBarcodeAlreadyImported({
    required String deviceId,
    required String barcode,
  }) async {
    final query = _database.select(_database.carbLoadingUserFoodsTable)
      ..where((tbl) =>
          tbl.deviceId.equals(deviceId) &
          tbl.barcode.equals(barcode) &
          tbl.isDeleted.equals(false));

    final existing = await query.getSingleOrNull();
    return existing != null;
  }

  /// Get all foods imported from foods table
  Future<List<domain.CarbLoadingUserFood>> getImportedFoods(String deviceId) async {
    final query = _database.select(_database.carbLoadingUserFoodsTable)
      ..where((tbl) =>
          tbl.deviceId.equals(deviceId) &
          tbl.sourceFoodId.isNotNull() &
          tbl.isDeleted.equals(false));

    final foods = await query.get();
    final foodsWithMealTypes = <domain.CarbLoadingUserFood>[];

    for (final food in foods) {
      final mealTypes = await _getMealTypesForUserFood(food.id);
      foodsWithMealTypes.add(_convertToUserFoodDomain(food, mealTypes));
    }

    return foodsWithMealTypes;
  }

  /// Get all foods imported from user_foods table
  Future<List<domain.CarbLoadingUserFood>> getImportedUserFoods(String deviceId) async {
    final query = _database.select(_database.carbLoadingUserFoodsTable)
      ..where((tbl) =>
          tbl.deviceId.equals(deviceId) &
          tbl.sourceUserFoodId.isNotNull() &
          tbl.isDeleted.equals(false));

    final foods = await query.get();
    final foodsWithMealTypes = <domain.CarbLoadingUserFood>[];

    for (final food in foods) {
      final mealTypes = await _getMealTypesForUserFood(food.id);
      foodsWithMealTypes.add(_convertToUserFoodDomain(food, mealTypes));
    }

    return foodsWithMealTypes;
  }

  /// Get all foods created from barcode scans
  Future<List<domain.CarbLoadingUserFood>> getScannedFoods(String deviceId) async {
    final query = _database.select(_database.carbLoadingUserFoodsTable)
      ..where((tbl) =>
          tbl.deviceId.equals(deviceId) &
          tbl.barcode.isNotNull() &
          tbl.isDeleted.equals(false));

    final foods = await query.get();
    final foodsWithMealTypes = <domain.CarbLoadingUserFood>[];

    for (final food in foods) {
      final mealTypes = await _getMealTypesForUserFood(food.id);
      foodsWithMealTypes.add(_convertToUserFoodDomain(food, mealTypes));
    }

    return foodsWithMealTypes;
  }

  /// Helper: Get meal types for a user food
  Future<List<int>> _getMealTypesForUserFood(String foodId) async {
    final query =
        _database.select(_database.carbLoadingUserFoodMealTypesTable)
          ..where((tbl) => tbl.carbLoadingUserFoodId.equals(foodId));

    final associations = await query.get();
    return associations.map((a) => a.mealTypeId).toList();
  }

  /// Helper: Convert Drift entity to domain model
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
}

@riverpod
FoodImportService foodImportService(Ref ref) {
  return FoodImportService(
    database: ref.watch(appDatabaseProvider),
    userFoodRepository: ref.watch(carbLoadingUserFoodRepositoryProvider),
  );
}
