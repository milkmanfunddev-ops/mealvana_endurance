import 'dart:convert';
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
    required String userId,
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

    return _userFoodRepository.createUserFood(
      deviceId: deviceId,
      userId: userId,
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
    required String userId,
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
        : sourceUserFood.name;

    return _userFoodRepository.createUserFood(
      deviceId: deviceId,
      userId: userId,
      sourceUserFoodId: sourceUserFoodId,
      name: sourceUserFood.name,
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
    required String userId,
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

    return _userFoodRepository.createUserFood(
      deviceId: deviceId,
      userId: userId,
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
    required String userId,
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
      userId: userId,
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
    // Get all matching foods by search term
    final query = _database.select(_database.foodsTable)
      ..where((tbl) => tbl.displayName.contains(searchTerm));

    final foods = await query.get();

    // If category filter is provided, filter by categories array column
    if (categoryId != null) {
      return foods.where((food) {
        if (food.categories == null) return false;
        final categories = _parseCategoriesArray(food.categories);
        return categories.contains(categoryId);
      }).toList();
    }

    return foods;
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
  /// Whether [foodId] actually exists in the `foods` table.
  ///
  /// A barcode scan produces a [Food] that exists in neither `foods` nor
  /// `user_foods` — it was just fetched from the catalog/USDA/Open Food Facts.
  /// Callers must check this before [importFromFoodsTable], which throws
  /// ArgumentError('Source food not found') for exactly that case.
  Future<bool> existsInFoodsTable(String foodId) async {
    final row = await (_database.select(_database.foodsTable)
          ..where((tbl) => tbl.id.equals(foodId)))
        .getSingleOrNull();
    return row != null;
  }

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
    return foods.map((food) => _convertToUserFoodDomain(food)).toList();
  }

  /// Get all foods imported from user_foods table
  Future<List<domain.CarbLoadingUserFood>> getImportedUserFoods(String deviceId) async {
    final query = _database.select(_database.carbLoadingUserFoodsTable)
      ..where((tbl) =>
          tbl.deviceId.equals(deviceId) &
          tbl.sourceUserFoodId.isNotNull() &
          tbl.isDeleted.equals(false));

    final foods = await query.get();
    return foods.map((food) => _convertToUserFoodDomain(food)).toList();
  }

  /// Get all foods created from barcode scans
  Future<List<domain.CarbLoadingUserFood>> getScannedFoods(String deviceId) async {
    final query = _database.select(_database.carbLoadingUserFoodsTable)
      ..where((tbl) =>
          tbl.deviceId.equals(deviceId) &
          tbl.barcode.isNotNull() &
          tbl.isDeleted.equals(false));

    final foods = await query.get();
    return foods.map((food) => _convertToUserFoodDomain(food)).toList();
  }

  /// Parse categories from array column (PostgreSQL array format: {1,2,3})
  List<int> _parseCategoriesArray(String? categoriesStr) {
    if (categoriesStr == null || categoriesStr.isEmpty) return [];

    try {
      // Handle PostgreSQL array format: {1,2,3}
      if (categoriesStr.startsWith('{') && categoriesStr.endsWith('}')) {
        final content = categoriesStr.substring(1, categoriesStr.length - 1);
        if (content.isEmpty) return [];
        return content.split(',').map((s) => int.parse(s.trim())).toList();
      }

      // Handle JSON array format: [1,2,3]
      if (categoriesStr.startsWith('[') && categoriesStr.endsWith(']')) {
        final List<dynamic> parsed = jsonDecode(categoriesStr);
        return parsed.map((e) => e as int).toList();
      }

      return [];
    } catch (e) {
      return [];
    }
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

  /// Helper: Convert Drift entity to domain model
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
}

@riverpod
FoodImportService foodImportService(Ref ref) {
  return FoodImportService(
    database: ref.watch(appDatabaseProvider),
    userFoodRepository: ref.watch(carbLoadingUserFoodRepositoryProvider),
  );
}
