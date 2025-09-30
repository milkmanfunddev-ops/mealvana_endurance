import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../../../features/nutrition_plan/domain/food.dart';
import '../../database/database_provider.dart';
import '../../database/app_database.dart';
import '../logging_service.dart';

/// Provider for UserFoodCrudService
final userFoodCrudServiceProvider = Provider<UserFoodCrudService>((ref) {
  final database = ref.read(appDatabaseProvider);
  return UserFoodCrudService(database);
});

/// Service for managing user's custom foods
/// Handles CRUD operations for user_foods table with local-first approach
class UserFoodCrudService {
  UserFoodCrudService(this._database);

  final AppDatabase _database;
  static const _uuid = Uuid();

  /// Load user foods for a device
  Future<List<Food>> getUserFoods(String deviceId) async {
    try {
      final userFoodsData = await _database.getUserFoods(deviceId);

      // Convert to Food domain objects
      final foods = userFoodsData
          .map((userFood) => _convertUserFoodToFood(userFood))
          .toList();

      AppLogger.instance.debug('Loaded ${foods.length} user foods for device $deviceId');
      return foods;
    } catch (e) {
      AppLogger.instance.error('Error loading user foods',
        context: 'UserFoodCrudService',
        data: {'deviceId': deviceId},
        error: e,
      );
      return [];
    }
  }

  /// Save food from Open Food Facts or barcode scanning
  Future<void> saveUserFood(
    Food food,
    List<int> categoryIds, {
    String? barcode,
  }) async {
    try {
      // Get current user's device ID
      final userProfile = await _database.getCurrentUserProfile();
      final deviceId = userProfile?.id ?? 'unknown';
      final supabase = Supabase.instance.client;

      // Generate unique UUID for this food
      final foodId = _uuid.v4();

      // 1. Save to local Drift database first (for offline access)
      await _database.saveUserFood(
        deviceId: deviceId,
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
        categoryIds: categoryIds,
      );

      // 2. Sync to Supabase via edge function (for backup and cross-device sync)
      try {
        final response = await supabase.functions.invoke('save-user-food', body: {
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

        if (response.status != 200) {
          AppLogger.instance.warning('Supabase sync failed, but local save succeeded',
            context: 'UserFoodCrudService',
            data: {'response': response.data},
          );
        } else {
          AppLogger.instance.debug('Food saved to both local and Supabase: ${food.name}');
        }
      } catch (supabaseError) {
        AppLogger.instance.warning('Supabase sync failed, but local save succeeded',
          context: 'UserFoodCrudService',
          error: supabaseError,
        );
      }

      AppLogger.instance.debug('User food saved successfully: ${food.name}');
    } catch (e) {
      AppLogger.instance.error('Error saving user food',
        context: 'UserFoodCrudService',
        data: {'foodName': food.name},
        error: e,
      );
      rethrow;
    }
  }

  /// Delete user food
  Future<void> deleteUserFood(String foodId) async {
    try {
      // Get current user's device ID
      final userProfile = await _database.getCurrentUserProfile();
      final deviceId = userProfile?.id ?? 'unknown';
      final supabase = Supabase.instance.client;

      // 1. Delete from local Drift database first
      await _database.deleteUserFood(foodId);

      // 2. Sync deletion to Supabase via edge function
      try {
        final response = await supabase.functions.invoke('delete-user-food', body: {
          'device_id': deviceId,
          'food_id': foodId,
        });

        if (response.status != 200) {
          AppLogger.instance.warning('Supabase delete sync failed, but local delete succeeded',
            context: 'UserFoodCrudService',
            data: {'response': response.data},
          );
        } else {
          AppLogger.instance.debug('Food deleted from both local and Supabase: $foodId');
        }
      } catch (supabaseError) {
        AppLogger.instance.warning('Supabase delete sync failed, but local delete succeeded',
          context: 'UserFoodCrudService',
          error: supabaseError,
        );
      }

      AppLogger.instance.debug('User food deleted successfully: $foodId');
    } catch (e) {
      AppLogger.instance.error('Error deleting user food',
        context: 'UserFoodCrudService',
        data: {'foodId': foodId},
        error: e,
      );
      rethrow;
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
      AppLogger.instance.error('Error checking if food is user food',
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
}