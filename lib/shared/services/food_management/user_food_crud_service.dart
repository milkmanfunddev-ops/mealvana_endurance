import 'dart:async';
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../../../features/nutrition_plan/domain/food.dart';
import '../../database/database_provider.dart';
import '../../database/app_database.dart';
import '../app_external_deps.dart';
import '../logging_service.dart';
import '../sentry/sentry_reporter.dart';
import 'product_type_mapper.dart';

/// Provider for UserFoodCrudService
final userFoodCrudServiceProvider = Provider<UserFoodCrudService>((ref) {
  final database = ref.read(appDatabaseProvider);
  final deps = ref.read(appExternalDepsProvider);
  return UserFoodCrudService(
    database,
    deps.logger,
    deps.supabaseClient,
    deps.sentry,
  );
});

/// Service for managing user's custom foods
/// Handles CRUD operations for user_foods table with local-first approach
class UserFoodCrudService {
  UserFoodCrudService(
    this._database,
    this._logger,
    this._supabase,
    this._sentry,
  );

  final AppDatabase _database;
  final AppLogger _logger;
  final SupabaseClient _supabase;
  final SentryReporter _sentry;
  static const _uuid = Uuid();

  /// Load user foods for a user
  Future<List<Food>> getUserFoods(String userId) async {
    try {
      final userFoodsData = await _database.foodsDao.getUserFoods(userId);

      // Convert to Food domain objects
      final foods = userFoodsData
          .map((userFood) => _convertUserFoodToFood(userFood))
          .toList();
      return foods;
    } catch (e) {
      _logger.error(
        'Error loading user foods',
        context: 'UserFoodCrudService',
        data: {'userId': userId},
        error: e,
      );
      return [];
    }
  }

  /// Save food from Open Food Facts or barcode scanning (offline-first pattern)
  Future<void> saveUserFood(
    Food food,
    List<int> categoryIds, {
    String? barcode,
  }) async {
    try {
      final normalizedProductType = normalizeProductType(
        food.productTypeId,
        logger: _logger,
      );
      // Get current user's ID using Supabase auth session for correct UUID
      final currentAuthUserId = _supabase.auth.currentUser?.id;
      final userProfile = await _database.userDao.getCurrentUserProfile(
        currentAuthUserId: currentAuthUserId,
      );
      final userId = userProfile?.id ?? 'unknown';
      final deviceId =
          userProfile?.deviceId ?? userId; // Use userId as fallback
      // Generate unique UUID for this food
      final foodId = _uuid.v4();

      // Auto-assign categories from product_type if user hasn't set any
      final effectiveCategoryIds = categoryIds.isEmpty
          ? _inferCategoriesFromProductType(normalizedProductType)
          : categoryIds;
      final categoryNames = _mapCategoryIdsToNames(effectiveCategoryIds);

      // OFFLINE-FIRST: Save to Drift IMMEDIATELY with dirty flag
      await _database.foodsDao.saveUserFood(
        deviceId: deviceId, // Keep for backwards compatibility
        userId: userId, // Use actual user UUID
        id: foodId,
        clientFoodId: food.id,
        barcode: barcode,
        name: food.name,
        displayName: food.displayName,
        displayNamePlural: food.displayNamePlural,
        description: food.description,
        imageAddress: food.imageAddress,
        servingAmount: food.servingAmount,
        servingUnit: food.servingUnit,
        servingSize: food.servingSize,
        caloriesPerServing: food.caloriesPerServing,
        carbsPerServing: food.carbsPerServing,
        proteinPerServing: food.proteinPerServing,
        fatPerServing: food.fatPerServing,
        sodiumMg: food.sodiumMg,
        fluidMlPerServing: food.fluidMlPerServing,
        productTypeId: normalizedProductType,
        categories: categoryNames,
        clientUpdatedAt: DateTime.now(),
      );

      // Attempt background upload (non-blocking); needs_upload handles offline failure
      unawaited(() async {
        try {
          await _uploadUserFoodToSupabase(
            deviceId: deviceId,
            userId: userId,
            foodId: foodId,
            food: food,
            categoryNames: categoryNames,
            barcode: barcode,
          );
        } catch (e, stackTrace) {
          _logger.warning(
            'Immediate upload failed; record stays dirty for retry',
            context: 'USER_FOOD_CRUD',
            error: e,
            stackTrace: stackTrace,
            data: {'operation': 'create', 'recordId': foodId},
          );
          _sentry.reportNetworkError(
            e,
            url: 'supabase:user_foods:create',
            method: 'UPSERT',
            stackTrace: stackTrace,
          );
        }
      }());
    } catch (e) {
      _logger.error(
        'Error saving user food',
        context: 'UserFoodCrudService',
        data: {'foodName': food.name},
        error: e,
      );
      rethrow;
    }
  }

  /// Update user food (offline-first pattern)
  Future<bool> updateUserFood({
    required String foodId,
    String? name,
    String? displayName,
    String? displayNamePlural,
    String? description,
    double? servingAmount,
    String? servingUnit,
    String? servingSize,
    int? caloriesPerServing,
    double? carbsPerServing,
    double? proteinPerServing,
    double? fatPerServing,
    int? sodiumMg,
    double? fluidMlPerServing,
    String? productTypeId,
    List<int>? categoryIds,
  }) async {
    try {
      // Convert category IDs to names if provided
      final categoryNames = categoryIds != null
          ? _mapCategoryIdsToNames(categoryIds)
          : null;

      // Normalize product type if provided
      final normalizedProductType = productTypeId != null
          ? normalizeProductType(productTypeId, logger: _logger)
          : null;

      // OFFLINE-FIRST: Update Drift IMMEDIATELY
      final success = await _database.foodsDao.updateUserFood(
        id: foodId,
        name: name,
        displayName: displayName,
        displayNamePlural: displayNamePlural,
        description: description,
        servingAmount: servingAmount,
        servingUnit: servingUnit,
        servingSize: servingSize,
        caloriesPerServing: caloriesPerServing,
        carbsPerServing: carbsPerServing,
        proteinPerServing: proteinPerServing,
        fatPerServing: fatPerServing,
        sodiumMg: sodiumMg,
        fluidMlPerServing: fluidMlPerServing,
        productTypeId: normalizedProductType,
        categories: categoryNames,
      );

      if (success) {
        // Attempt background upload (non-blocking)
        unawaited(() async {
          try {
            await _uploadUserFoodUpdateToSupabase(
              foodId: foodId,
              name: name,
              displayName: displayName,
              displayNamePlural: displayNamePlural,
              description: description,
              servingAmount: servingAmount,
              servingUnit: servingUnit,
              servingSize: servingSize,
              caloriesPerServing: caloriesPerServing,
              carbsPerServing: carbsPerServing,
              proteinPerServing: proteinPerServing,
              fatPerServing: fatPerServing,
              sodiumMg: sodiumMg,
              fluidMlPerServing: fluidMlPerServing,
              productTypeId: normalizedProductType,
              categoryNames: categoryNames,
            );
          } catch (e, stackTrace) {
            _logger.warning(
              'Immediate upload failed; record stays dirty for retry',
              context: 'USER_FOOD_CRUD',
              error: e,
              stackTrace: stackTrace,
              data: {'operation': 'update', 'recordId': foodId},
            );
            _sentry.reportNetworkError(
              e,
              url: 'supabase:user_foods:update',
              method: 'UPDATE',
              stackTrace: stackTrace,
            );
          }
        }());
      }

      return success;
    } catch (e) {
      _logger.error(
        'Error updating user food',
        context: 'UserFoodCrudService',
        data: {'foodId': foodId},
        error: e,
      );
      rethrow;
    }
  }

  /// Delete user food (offline-first pattern)
  Future<void> deleteUserFood(String foodId) async {
    try {
      // Get current user's device ID using Supabase auth session
      final currentAuthUserId = _supabase.auth.currentUser?.id;
      final userProfile = await _database.userDao.getCurrentUserProfile(
        currentAuthUserId: currentAuthUserId,
      );
      final deviceId = userProfile?.id ?? 'unknown';

      // OFFLINE-FIRST: Delete from Drift IMMEDIATELY
      await _database.foodsDao.deleteUserFood(foodId);

      // Attempt background upload (non-blocking)
      unawaited(() async {
        try {
          await _uploadUserFoodDeletion(deviceId, foodId);
        } catch (e, stackTrace) {
          _logger.warning(
            'Immediate upload failed; record stays dirty for retry',
            context: 'USER_FOOD_CRUD',
            error: e,
            stackTrace: stackTrace,
            data: {'operation': 'delete', 'recordId': foodId},
          );
          _sentry.reportNetworkError(
            e,
            url: 'supabase:user_foods:delete',
            method: 'UPDATE',
            stackTrace: stackTrace,
          );
        }
      }());
    } catch (e) {
      _logger.error(
        'Error deleting user food',
        context: 'UserFoodCrudService',
        data: {'foodId': foodId},
        error: e,
      );
      rethrow;
    }
  }

  /// Upload user food to Supabase in background (non-blocking)
  Future<void> _uploadUserFoodToSupabase({
    required String deviceId,
    required String userId,
    required String foodId,
    required Food food,
    required List<String> categoryNames,
    String? barcode,
  }) async {
    final normalizedProductType = normalizeProductType(
      food.productTypeId,
      logger: _logger,
    );

    await _supabase.from('user_foods').upsert({
      'id': foodId,
      'device_id': deviceId,
      'user_id': userId,
      'client_food_id': food.id,
      'barcode': barcode,
      'name': food.name,
      'display_name': food.displayName ?? food.name,
      'display_name_plural': food.displayNamePlural ?? '${food.name}s',
      'description': food.description,
      'image_address': food.imageAddress,
      'serving_amount': food.servingAmount,
      'serving_unit': food.servingUnit,
      'serving_size': food.servingSize,
      'calories_per_serving': food.caloriesPerServing,
      'carbs_per_serving': food.carbsPerServing,
      'protein_per_serving': food.proteinPerServing,
      'fat_per_serving': food.fatPerServing,
      'sodium_mg': food.sodiumMg,
      'fluid_ml_per_serving': food.fluidMlPerServing,
      'product_type': normalizedProductType,
      'categories': categoryNames,
      'activity_types': null,
      'is_electrolyte': false,
      'to_exclude_from_solver': false,
      'is_deleted': false,
      'created_at': DateTime.now().toIso8601String(),
      'updated_at': DateTime.now().toIso8601String(),
      'client_updated_at': DateTime.now().toIso8601String(),
    });

    await _database.customStatement(
      'UPDATE user_foods SET needs_upload = 0 WHERE id = ?',
      [foodId],
    );
  }

  /// Upload user food deletion to Supabase in background (non-blocking)
  Future<void> _uploadUserFoodDeletion(String deviceId, String foodId) async {
    await _supabase
        .from('user_foods')
        .update({
          'is_deleted': true,
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('id', foodId)
        .eq('device_id', deviceId);

    await _database.customStatement(
      'UPDATE user_foods SET needs_upload = 0 WHERE id = ?',
      [foodId],
    );
  }

  /// Upload user food update to Supabase in background (non-blocking)
  Future<void> _uploadUserFoodUpdateToSupabase({
    required String foodId,
    String? name,
    String? displayName,
    String? displayNamePlural,
    String? description,
    double? servingAmount,
    String? servingUnit,
    String? servingSize,
    int? caloriesPerServing,
    double? carbsPerServing,
    double? proteinPerServing,
    double? fatPerServing,
    int? sodiumMg,
    double? fluidMlPerServing,
    String? productTypeId,
    List<String>? categoryNames,
  }) async {
    // Build update map with only provided fields
    final updateData = <String, dynamic>{
      'updated_at': DateTime.now().toIso8601String(),
      'client_updated_at': DateTime.now().toIso8601String(),
    };

    if (name != null) {
      updateData['name'] = name;
    }
    if (displayName != null) {
      updateData['display_name'] = displayName;
    }
    if (displayNamePlural != null) {
      updateData['display_name_plural'] = displayNamePlural;
    }
    if (description != null) {
      updateData['description'] = description;
    }
    if (servingAmount != null) {
      updateData['serving_amount'] = servingAmount;
    }
    if (servingUnit != null) {
      updateData['serving_unit'] = servingUnit;
    }
    if (servingSize != null) {
      updateData['serving_size'] = servingSize;
    }
    if (caloriesPerServing != null) {
      updateData['calories_per_serving'] = caloriesPerServing;
    }
    if (carbsPerServing != null) {
      updateData['carbs_per_serving'] = carbsPerServing;
    }
    if (proteinPerServing != null) {
      updateData['protein_per_serving'] = proteinPerServing;
    }
    if (fatPerServing != null) {
      updateData['fat_per_serving'] = fatPerServing;
    }
    if (sodiumMg != null) {
      updateData['sodium_mg'] = sodiumMg;
    }
    if (fluidMlPerServing != null) {
      updateData['fluid_ml_per_serving'] = fluidMlPerServing;
    }
    if (productTypeId != null) {
      updateData['product_type'] = productTypeId;
    }
    if (categoryNames != null) {
      updateData['categories'] = categoryNames;
    }

    await _supabase.from('user_foods').update(updateData).eq('id', foodId);

    await _database.customStatement(
      'UPDATE user_foods SET needs_upload = 0 WHERE id = ?',
      [foodId],
    );
  }

  /// Check if food exists in user_foods
  Future<bool> isUserFood(String foodId) async {
    try {
      final currentAuthUserId = _supabase.auth.currentUser?.id;
      final userProfile = await _database.userDao.getCurrentUserProfile(
        currentAuthUserId: currentAuthUserId,
      );
      final userId = userProfile?.id ?? 'unknown';

      final userFoods = await _database.foodsDao.getUserFoods(userId);
      return userFoods.any(
        (userFood) => userFood.clientFoodId == foodId || userFood.id == foodId,
      );
    } catch (e) {
      _logger.error(
        'Error checking if food is user food',
        context: 'UserFoodCrudService',
        data: {'foodId': foodId},
        error: e,
      );
      return false;
    }
  }

  /// Convert database UserFood to Food domain object
  Food _convertUserFoodToFood(dynamic userFood) {
    // Parse categories from string (handles both JSON and PostgreSQL array formats)
    List<String> categories = [];
    if (userFood.categories != null && userFood.categories.isNotEmpty) {
      categories = _parseCategories(userFood.categories);
    }

    return Food(
      id: userFood.id,
      name: userFood.name,
      displayName: userFood.displayName,
      displayNamePlural: userFood.displayNamePlural,
      description: userFood.description,
      imageAddress: userFood.imageAddress,
      servingAmount: userFood.servingAmount,
      servingUnit: userFood.servingUnit,
      servingSize: userFood.servingSize,
      categories: categories,
      carbsPerServing: userFood.carbsPerServing,
      proteinPerServing: userFood.proteinPerServing,
      fatPerServing: userFood.fatPerServing,
      caloriesPerServing: userFood.caloriesPerServing,
      fluidMlPerServing: userFood.fluidMlPerServing,
      sodiumMg: userFood.sodiumMg,
      productTypeId: userFood.productTypeId,
      // User foods can be suitable for any timing since user controls categories
      beforeRunSuitable: true,
      duringRunSuitable: true,
      // Default values for missing fields
      instructions: '',
      servingUnitPlural: userFood.servingUnit != null
          ? '${userFood.servingUnit}s'
          : null,
      servingQualifier: null,
    );
  }

  /// Infer default category IDs from product_type when user hasn't set categories.
  /// 1 = before_run, 2 = during_run, 3 = after_run
  List<int> _inferCategoriesFromProductType(String? productType) {
    switch (productType) {
      case 'gel':
      case 'chew':
      case 'drink_mix':
      case 'sports_drink':
      case 'hydration_with_carbs':
        return [2]; // during only
      case 'bar':
      case 'waffle':
      case 'solid_carb_snacks':
        return [1, 2]; // before + during
      case 'real_food':
      case 'real_food_carbs':
        return [1, 3]; // before + after
      case 'recovery_shake':
      case 'protein_recovery':
        return [3]; // after only
      case 'electrolyte_only':
      case 'electrolytes_fluids':
      case 'capsule':
        return [2]; // during only
      default:
        return [1, 2, 3]; // all phases (including 'import' and null)
    }
  }

  List<String> _mapCategoryIdsToNames(List<int> categoryIds) {
    return categoryIds.map((id) {
      switch (id) {
        case 1:
          return 'before_run';
        case 2:
          return 'during_run';
        case 3:
          return 'after_run';
        default:
          return 'before_run';
      }
    }).toList();
  }

  /// Parse categories from string - handles both JSON array and PostgreSQL array formats
  /// JSON format: ["before_run","during_run"]
  /// PostgreSQL format: {before_run,during_run}
  List<String> _parseCategories(String categoriesStr) {
    final trimmed = categoriesStr.trim();

    // Handle PostgreSQL array format: {before_run,during_run,after_run}
    if (trimmed.startsWith('{') && trimmed.endsWith('}')) {
      final inner = trimmed.substring(1, trimmed.length - 1);
      if (inner.isEmpty) return [];
      return inner.split(',').map((s) => s.trim()).toList();
    }

    // Handle JSON array format: ["before_run","during_run"]
    if (trimmed.startsWith('[')) {
      try {
        final decoded = jsonDecode(trimmed);
        if (decoded is List) {
          return List<String>.from(decoded);
        }
      } catch (e) {
        _logger.warning('Failed to parse JSON categories: $trimmed', error: e);
      }
    }

    // Fallback: treat as single category or comma-separated
    if (trimmed.contains(',')) {
      return trimmed.split(',').map((s) => s.trim()).toList();
    }

    return trimmed.isNotEmpty ? [trimmed] : [];
  }
}
