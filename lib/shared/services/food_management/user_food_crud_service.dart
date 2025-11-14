import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../../../features/nutrition_plan/domain/food.dart';
import '../../database/database_provider.dart';
import '../../database/app_database.dart';
import '../app_external_deps.dart';
import '../logging_service.dart';

/// Provider for UserFoodCrudService
final userFoodCrudServiceProvider = Provider<UserFoodCrudService>((ref) {
  final database = ref.read(appDatabaseProvider);
  final deps = ref.read(appExternalDepsProvider);
  return UserFoodCrudService(
    database,
    deps.logger,
    deps.supabaseClient,
  );
});

/// Service for managing user's custom foods
/// Handles CRUD operations for user_foods table with local-first approach
class UserFoodCrudService {
  UserFoodCrudService(this._database, this._logger, this._supabase);

  final AppDatabase _database;
  final AppLogger _logger;
  final SupabaseClient _supabase;
  static const _uuid = Uuid();

  /// Load user foods for a device
  Future<List<Food>> getUserFoods(String deviceId) async {
    try {
      final userFoodsData = await _database.getUserFoods(deviceId);

      // Convert to Food domain objects
      final foods = userFoodsData
          .map((userFood) => _convertUserFoodToFood(userFood))
          .toList();      return foods;
    } catch (e) {
      _logger.error('Error loading user foods',
        context: 'UserFoodCrudService',
        data: {'deviceId': deviceId},
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
      // Get current user's device ID
      final userProfile = await _database.getCurrentUserProfile();
      final deviceId = userProfile?.id ?? 'unknown';
      // Generate unique UUID for this food
      final foodId = _uuid.v4();

      final categoryNames = _mapCategoryIdsToNames(categoryIds);

      // OFFLINE-FIRST: Save to Drift IMMEDIATELY with dirty flag
      await _database.saveUserFood(
        deviceId: deviceId,
        userId: deviceId,
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
        caloriesPerServing: food.caloriesPerServing,
        carbsPerServing: food.carbsPerServing,
        proteinPerServing: food.proteinPerServing,
        fatPerServing: food.fatPerServing,
        sodiumMg: food.sodiumMg,
        fluidMlPerServing: food.fluidMlPerServing,
        productTypeId: food.productTypeId,
        categories: categoryNames,
        clientUpdatedAt: DateTime.now(),
      );

      // Attempt background upload (non-blocking)
      unawaited(_uploadUserFoodToSupabase(
        deviceId: deviceId,
        foodId: foodId,
        food: food,
        categoryIds: categoryIds,
        barcode: barcode,
      ));
    } catch (e) {
      _logger.error('Error saving user food',
        context: 'UserFoodCrudService',
        data: {'foodName': food.name},
        error: e,
      );
      rethrow;
    }
  }

  /// Delete user food (offline-first pattern)
  Future<void> deleteUserFood(String foodId) async {
    try {
      // Get current user's device ID
      final userProfile = await _database.getCurrentUserProfile();
      final deviceId = userProfile?.id ?? 'unknown';

      // OFFLINE-FIRST: Delete from Drift IMMEDIATELY
      await _database.deleteUserFood(foodId);

      // Attempt background upload (non-blocking)
      unawaited(_uploadUserFoodDeletion(deviceId, foodId));
    } catch (e) {
      _logger.error('Error deleting user food',
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
    required String foodId,
    required Food food,
    required List<int> categoryIds,
    String? barcode,
  }) async {
    try {
      final response = await _supabase.functions.invoke('save-user-food', body: {
        'device_id': deviceId,
        'id': foodId,
        'client_food_id': food.id,
        'barcode': barcode,
        'name': food.name,
        'display_name': food.displayName ?? food.name,
        'display_name_plural': food.displayNamePlural ?? '${food.name}s',
        'description': food.description,
        'image_address': food.imageAddress,
        'serving_amount': food.servingAmount,
        'serving_unit': food.servingUnit,
        'calories_per_serving': food.caloriesPerServing,
        'carbs_per_serving': food.carbsPerServing,
        'protein_per_serving': food.proteinPerServing,
        'fat_per_serving': food.fatPerServing,
        'sodium_mg': food.sodiumMg,
        'fluid_ml_per_serving': food.fluidMlPerServing,
        'product_type_id': food.productTypeId,
        'category_ids': categoryIds,
      });

      if (response.status >= 200 && response.status < 300) {
        // Upload successful
      } else {
        throw Exception('Edge function failed: ${response.data}');
      }
    } catch (e) {
      _logger.warning(
        'Failed to upload user food (will retry on next sync)',
        context: 'UserFoodCrudService',
        error: e,
        data: {'foodId': foodId},
      );
      // Don't rethrow - keep dirty flag, will retry on next sync
    }
  }

  /// Upload user food deletion to Supabase in background (non-blocking)
  Future<void> _uploadUserFoodDeletion(String deviceId, String foodId) async {
    try {
      final response = await _supabase.functions.invoke('delete-user-food', body: {
        'device_id': deviceId,
        'food_id': foodId,
      });

      if (response.status < 200 || response.status >= 300) {
        _logger.warning(
          'Failed to upload user food deletion',
          context: 'UserFoodCrudService',
          data: {'foodId': foodId, 'status': response.status},
        );
      }
    } catch (e) {
      _logger.warning(
        'Failed to upload user food deletion',
        context: 'UserFoodCrudService',
        error: e,
        data: {'foodId': foodId},
      );
    }
  }


  /// Check if food exists in user_foods
  Future<bool> isUserFood(String foodId) async {
    try {
      final userProfile = await _database.getCurrentUserProfile();
      final deviceId = userProfile?.id ?? 'unknown';

      final userFoods = await _database.getUserFoods(deviceId);
      return userFoods.any((userFood) => userFood.clientFoodId == foodId || userFood.id == foodId);
    } catch (e) {
      _logger.error('Error checking if food is user food',
        context: 'UserFoodCrudService',
        data: {'foodId': foodId},
        error: e,
      );
      return false;
    }
  }

  /// Convert database UserFood to Food domain object
  Food _convertUserFoodToFood(dynamic userFood) {
    return Food(
      id: userFood.id,
      name: userFood.name,
      displayName: userFood.displayName,
      displayNamePlural: userFood.displayNamePlural,
      description: userFood.description,
      imageAddress: userFood.imageAddress,
      servingAmount: userFood.servingAmount,
      servingUnit: userFood.servingUnit,
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
      servingUnitPlural: userFood.servingUnit != null ? '${userFood.servingUnit}s' : null,
      servingQualifier: null,
    );
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
}
