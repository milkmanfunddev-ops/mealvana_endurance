import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:drift/drift.dart';
import '../domain/food_item.dart';
import '../../../shared/services/app_external_deps.dart';
import '../../../shared/services/logging_service.dart';
import '../../../shared/database/app_database.dart';
import '../../../shared/database/database_provider.dart';

/// Repository for accessing food data from Supabase
/// Replaces the hardcoded FoodDatabase with dynamic data
class FoodRepository {
  FoodRepository(this._supabase, this._database, {AppLogger? logger})
      : _logger = logger ?? const NoopAppLogger();

  final SupabaseClient _supabase;
  final AppDatabase _database;
  final AppLogger _logger;

  /// Get all foods using get-foods Edge Function
  /// Use this for "Recommended Alternatives"
  /// Also syncs the foods to local database for offline access
  Future<List<FoodItem>> getAllFoods() async {
    try {
      // Call get-foods Edge Function without category to get all foods
      final response = await _supabase.functions.invoke('get-foods', body: {
        'category': null,  // No category filter - get all foods
        'generic_only': false,  // Get all foods
      });

      if (response.status != 200) {
        throw Exception('Edge Function error: ${response.data?['error'] ?? 'Unknown error'}');
      }

      final data = response.data;
      if (data == null || data['foods'] == null) {
        throw Exception('Invalid response from get-foods Edge Function');
      }

      final List<dynamic> foodsData = data['foods'] as List<dynamic>;

      final genericFoodsData = foodsData;

      final foods = genericFoodsData.map((json) => _mapEdgeFunctionFoodToFoodItem(json)).toList();

      // Sync foods to local database for offline access
      await _syncFoodsToLocalDatabase(genericFoodsData);      return foods;
    } catch (e) {
      _logger.error('Error fetching generic foods from get-foods Edge Function',
        context: 'FoodRepository',
        error: e,
      );
      // Fallback to empty list - app should still work without foods
      return [];
    }
  }

  /// Get primary foods for the preferences screen (curated foods with show_in_preferences=true)
  Future<List<FoodItem>> getPrimaryFoodsForPreferences() async {
    try {
      _logger.info('[FOOD_REPO] Fetching primary foods from Supabase (show_in_preferences=true)...');

      final response = await _supabase
          .from('foods')
          .select('''
            id,
            name,
            display_name,
            display_name_plural,
            image_address,
            serving_amount,
            max_servings_before,
            max_servings_during,
            max_servings_after,
            carbs_per_serving,
            protein_per_serving,
            fat_per_serving,
            calories_per_serving,
            fluid_ml_per_serving,
            sodium_mg,
            caffeine_mg,
            potassium_mg,
            product_type,
            show_in_preferences,
            is_electrolyte,
            to_exclude_from_solver,
            created_at
          ''')
          .eq('show_in_preferences', true)
          .order('name', ascending: true)
          .timeout(
            const Duration(seconds: 10),
            onTimeout: () {
              _logger.error('[FOOD_REPO] Supabase foods query timed out after 10 seconds');
              throw TimeoutException('Failed to load foods from Supabase');
            },
          );

      final List<dynamic> data = response as List<dynamic>;
      _logger.info('[FOOD_REPO] Successfully fetched ${data.length} primary foods from Supabase');
      return data.map((json) => _mapSupabaseFoodToFoodItem(json)).toList();
    } catch (e) {
      _logger.error('Error fetching primary preference foods from Supabase',
        context: 'FoodRepository',
        error: e,
      );
      // Fallback to empty list
      return [];
    }
  }

  /// Get additional foods for expanded options (show_in_preferences=false)
  Future<List<FoodItem>> getAdditionalFoodsForPreferences() async {
    try {
      _logger.info('[FOOD_REPO] Fetching additional foods from Supabase (show_in_preferences=false)...');

      final response = await _supabase
          .from('foods')
          .select('''
            id,
            name,
            display_name,
            display_name_plural,
            image_address,
            serving_amount,
            max_servings_before,
            max_servings_during,
            max_servings_after,
            carbs_per_serving,
            protein_per_serving,
            fat_per_serving,
            calories_per_serving,
            fluid_ml_per_serving,
            sodium_mg,
            caffeine_mg,
            potassium_mg,
            product_type,
            show_in_preferences,
            is_electrolyte,
            to_exclude_from_solver,
            created_at
          ''')
          .eq('show_in_preferences', false)
          .order('name', ascending: true)
          .timeout(
            const Duration(seconds: 10),
            onTimeout: () {
              _logger.error('[FOOD_REPO] Additional foods query timed out after 10 seconds');
              throw TimeoutException('Failed to load additional foods from Supabase');
            },
          );

      final List<dynamic> data = response as List<dynamic>;
      _logger.info('[FOOD_REPO] Successfully fetched ${data.length} additional foods from Supabase');

      return data.map((json) => _mapSupabaseFoodToFoodItem(json)).toList();
    } catch (e) {
      _logger.error('[FOOD_REPO] Error fetching additional preference foods from Supabase: $e',
        context: 'FoodRepository',
        error: e,
      );
      // Fallback to empty list
      return [];
    }
  }

  /// Get foods for the preferences screen (backward compatibility)
  /// @deprecated Use getPrimaryFoodsForPreferences() instead
  Future<List<FoodItem>> getFoodsForPreferences() async {
    return getPrimaryFoodsForPreferences();
  }


  /// Get foods by category (filtered by suitability flags)
  /// Since the Supabase schema doesn't have category join tables, we filter by suitability
  Future<List<FoodItem>> getFoodsByCategory(FoodCategory category) async {
    try {
      // Get all foods first
      final allFoods = await getAllFoods();

      // Filter based on category suitability
      final filteredFoods = allFoods.where((food) {
        switch (category) {
          case FoodCategory.beforeRun:
            return food.beforeRunSuitable;
          case FoodCategory.duringRun:
            return food.duringRunSuitable;
          case FoodCategory.afterRun:
            return true; // All foods are suitable after run
        }
      }).toList();      return filteredFoods;
    } catch (e) {
      _logger.error('Error fetching foods by category',
        context: 'FoodRepository',
        data: {'category': category.name},
        error: e,
      );
      return [];
    }
  }

  /// Get a specific food by ID from local database
  /// Checks both regular foods table and user_foods table
  Future<FoodItem?> getFoodById(String id) async {
    try {
      // 🐛 DIAGNOSTIC: Log total food count before querying specific food
      final allFoods = await _database.select(_database.foodsTable).get();
      final totalFoods = allFoods.length;
      _logger.debug('🔍 [FOOD_LOOKUP] Searching for food $id (total foods in table: $totalFoods)',
        context: 'FoodRepository',
        data: {'foodId': id, 'totalFoodsCount': totalFoods},
      );

      // First try to get from regular foods table
      final foodEntry = await (_database.select(_database.foodsTable)
        ..where((f) => f.id.equals(id)))
        .getSingleOrNull();

      if (foodEntry != null) {
        _logger.debug('✅ [FOOD_LOOKUP] Found food in foods table: ${foodEntry.name}',
          context: 'FoodRepository',
          data: {'foodId': id, 'foodName': foodEntry.name},
        );
        // Log sports drink data from local Drift database
        if (foodEntry.name?.toLowerCase().contains('sports drink') == true) {        }
        return _mapLocalFoodToFoodItem(foodEntry);
      }

      // If not found in foods table, try user_foods table using primary key
      final userFoodEntry = await (_database.select(_database.userFoodsTable)
        ..where((f) => f.id.equals(id)))
        .getSingleOrNull();

      if (userFoodEntry != null) {
        _logger.debug('✅ [FOOD_LOOKUP] Found food in user_foods table: ${userFoodEntry.name}',
          context: 'FoodRepository',
          data: {'foodId': id, 'foodName': userFoodEntry.name},
        );
        return _mapUserFoodToFoodItem(userFoodEntry);
      }

      _logger.warning('⚠️ [FOOD_LOOKUP] Food not found in either table (searched $totalFoods foods)',
        context: 'FoodRepository',
        data: {'foodId': id, 'totalFoodsInTable': totalFoods},
      );
      return null;
    } catch (e) {
      _logger.error('Error fetching food by ID from local database',
        context: 'FoodRepository',
        data: {'foodId': id},
        error: e,
      );
      return null;
    }
  }

  /// Get a specific food by name from local database
  Future<FoodItem?> getFoodByName(String name) async {
    try {
      // Try to get from local database first
      final foodEntry = await (_database.select(_database.foodsTable)
        ..where((f) => f.name.equals(name)))
        .getSingleOrNull();

      if (foodEntry != null) {
        return _mapLocalFoodToFoodItem(foodEntry);
      }

      _logger.warning('Food not found in local database',
        context: 'FoodRepository',
        data: {'foodName': name},
      );
      return null;
    } catch (e) {
      _logger.error('Error fetching food by name from local database',
        context: 'FoodRepository',
        data: {'foodName': name},
        error: e,
      );
      return null;
    }
  }

  /// Get preferred foods based on user likes (filtered by category and preferences)
  Future<List<FoodItem>> getPreferredFoods(
    FoodCategory category,
    List<String> likedFoodNames,
    List<String> willingToTryNames,
  ) async {
    try {
      final categoryFoods = await getFoodsByCategory(category);
      final preferredFoods = categoryFoods.where((food) {
        return likedFoodNames.contains(food.name) ||
               willingToTryNames.contains(food.name);
      }).toList();      return preferredFoods;
    } catch (e) {
      _logger.error('Error fetching preferred foods',
        context: 'FoodRepository',
        data: {'category': category.name},
        error: e,
      );
      return [];
    }
  }

  /// Search foods by name (uses local database)
  Future<List<FoodItem>> searchFoods(String query) async {
    try {
      if (query.isEmpty) return [];

      final lowerQuery = query.toLowerCase();

      // Search in local database
      final foodEntries = await (_database.select(_database.foodsTable)
        ..where((f) => f.name.like('%$lowerQuery%')))
        .get();

      final foods = foodEntries.map((entry) => _mapLocalFoodToFoodItem(entry)).toList();      return foods;
    } catch (e) {
      _logger.error('Error searching foods',
        context: 'FoodRepository',
        data: {'searchQuery': query},
        error: e,
      );
      return [];
    }
  }

  /// Map Supabase food data to FoodItem domain object
  FoodItem _mapSupabaseFoodToFoodItem(Map<String, dynamic> json) {
    // Extract nutrition values directly from explicit columns
    final calories = (json['calories_per_serving'] as num?)?.toDouble() ?? 0.0;
    final carbs = (json['carbs_per_serving'] as num?)?.toDouble() ?? 0.0;
    final protein = (json['protein_per_serving'] as num?)?.toDouble() ?? 0.0;
    final fat = (json['fat_per_serving'] as num?)?.toDouble() ?? 0.0;
    final sodium = (json['sodium_mg'] as num?)?.toDouble() ?? 0.0;
    final fluids = (json['fluid_ml_per_serving'] as num?)?.toDouble() ?? 0.0;

    // Simplified serving approach - always 1.0 for new simplified approach
    final servingAmount = (json['serving_amount'] as num?)?.toDouble() ?? 1.0;

    // Deprecated legacy fields - set to null for simplified approach
    const String? servingUnit = null;
    const String? servingUnitPlural = null;
    const String? servingQualifier = null;
    const String? servingSize = null; // Deprecated

    // Since the Supabase schema doesn't have these columns, set sensible defaults
    const bool beforeRunSuitable = true; // Default to true
    const bool duringRunSuitable = false; // Default to false for safety
    const bool runPortable = true;
    const bool requiresPreparation = false;
    const bool aidStationAvailable = false;

    // Debug logging
    final imageAddress = json['image_address'] as String?;

    return FoodItem(
      id: json['id'] as String,
      name: json['name'] as String,
      imageAddress: imageAddress,
      description: null, // Not available in Supabase schema
      instructions: null, // Not available in Supabase schema
      categories: [], // Would need separate query for categories
      servingSize: servingSize,
      servingAmount: servingAmount,
      servingUnit: servingUnit,
      servingUnitPlural: servingUnitPlural,
      servingQualifier: servingQualifier,
      beforeRunSuitable: beforeRunSuitable,
      duringRunSuitable: duringRunSuitable,
      runPortable: runPortable,
      requiresPreparation: requiresPreparation,
      aidStationAvailable: aidStationAvailable,
      maxServingsBefore: json['max_servings_before'] as int?,
      maxServingsDuring: json['max_servings_during'] as int?,
      carbsPerServing: (json['carbs_per_serving'] as num?)?.toDouble(),
      proteinPerServing: (json['protein_per_serving'] as num?)?.toDouble(),
      fatPerServing: (json['fat_per_serving'] as num?)?.toDouble(),
      caloriesPerServing: json['calories_per_serving'] as int?,
      fluidMlPerServing: (json['fluid_ml_per_serving'] as num?)?.toDouble(),
      sodiumMg: json['sodium_mg'] as int?,
      caffeineMg: json['caffeine_mg'] as int?,
      potassiumMg: json['potassium_mg'] as int?,
      productTypeId: json['product_type']?.toString(),
      nutrition: NutritionInfo(
        calories: calories,
        carbs: carbs,
        protein: protein,
        fat: fat,
        sodium: sodium,
        fiber: 0.0, // Not stored separately in database
        sugar: 0.0, // Not stored separately in database
        fluids: fluids,
      ),
      tags: _generateTagsFromNutrition(carbs, protein, fat),
      displayName: json['display_name'] as String?,
      displayNamePlural: json['display_name_plural'] as String?,
      displayOverride: null, // Removed - no longer needed in simplified approach
      toExcludeFromSolver: json['to_exclude_from_solver'] == true,
    );
  }

  /// Map Edge Function food data to FoodItem domain object
  FoodItem _mapEdgeFunctionFoodToFoodItem(Map<String, dynamic> json) {
    // Extract nutrition values directly from explicit columns
    final calories = (json['calories_per_serving'] as num?)?.toDouble() ?? 0.0;
    final carbs = (json['carbs_per_serving'] as num?)?.toDouble() ?? 0.0;
    final protein = (json['protein_per_serving'] as num?)?.toDouble() ?? 0.0;
    final fat = (json['fat_per_serving'] as num?)?.toDouble() ?? 0.0;
    final sodium = (json['sodium_mg'] as num?)?.toDouble() ?? 0.0;
    final fluids = (json['fluid_ml_per_serving'] as num?)?.toDouble() ?? 0.0;

    // Simplified serving approach - always 1.0 for new simplified approach
    final servingAmount = (json['serving_amount'] as num?)?.toDouble() ?? 1.0;

    // Deprecated legacy fields - set to null for simplified approach
    const String? servingUnit = null;
    const String? servingUnitPlural = null;
    const String? servingQualifier = null;
    const String? servingSize = null; // Deprecated

    // Extract suitability flags from Edge Function response
    final beforeRunSuitable = json['before_run_suitable'] as bool? ?? true;
    final duringRunSuitable = json['during_run_suitable'] as bool? ?? false;
    final runPortable = json['run_portable'] as bool? ?? true;
    final requiresPreparation = json['requires_preparation'] as bool? ?? false;
    final aidStationAvailable = json['aid_station_available'] as bool? ?? false;

    // Debug logging
    final imageAddress = json['image_address'] as String?;

    return FoodItem(
      id: json['id'] as String,
      name: json['name'] as String,
      imageAddress: imageAddress,
      description: json['description'] as String?,
      instructions: json['instructions'] as String?,
      categories: [], // Would need separate query for categories
      servingSize: servingSize,
      servingAmount: servingAmount,
      servingUnit: servingUnit,
      servingUnitPlural: servingUnitPlural,
      servingQualifier: servingQualifier,
      beforeRunSuitable: beforeRunSuitable,
      duringRunSuitable: duringRunSuitable,
      runPortable: runPortable,
      requiresPreparation: requiresPreparation,
      aidStationAvailable: aidStationAvailable,
      maxServingsBefore: json['max_servings_before'] as int?,
      maxServingsDuring: json['max_servings_during'] as int?,
      carbsPerServing: (json['carbs_per_serving'] as num?)?.toDouble(),
      proteinPerServing: (json['protein_per_serving'] as num?)?.toDouble(),
      fatPerServing: (json['fat_per_serving'] as num?)?.toDouble(),
      caloriesPerServing: json['calories_per_serving'] as int?,
      fluidMlPerServing: (json['fluid_ml_per_serving'] as num?)?.toDouble(),
      sodiumMg: json['sodium_mg'] as int?,
      caffeineMg: json['caffeine_mg'] as int?,
      potassiumMg: json['potassium_mg'] as int?,
      productTypeId: json['product_type']?.toString(),
      nutrition: NutritionInfo(
        calories: calories,
        carbs: carbs,
        protein: protein,
        fat: fat,
        sodium: sodium,
        fiber: 0.0, // Not stored separately in database
        sugar: 0.0, // Not stored separately in database
        fluids: fluids,
      ),
      tags: _generateTagsFromNutrition(carbs, protein, fat),
      displayName: json['display_name'] as String?,
      displayNamePlural: json['display_name_plural'] as String?,
      displayOverride: null, // Removed - no longer needed in simplified approach
      toExcludeFromSolver: json['to_exclude_from_solver'] == true,
    );
  }

  /// Map local Drift food entry to FoodItem
  FoodItem _mapLocalFoodToFoodItem(FoodEntry entry) {
    // Use explicit columns from Drift database
    final carbs = entry.carbsPerServing?.toDouble();
    final protein = entry.proteinPerServing?.toDouble();
    final fat = entry.fatPerServing?.toDouble();
    final calories = entry.caloriesPerServing;
    final sodium = entry.sodiumMg?.toDouble();
    final fluids = entry.fluidMlPerServing?.toDouble();

    // Parse categories array to determine suitability
    final categoryStrings = _parseCategoriesArray(entry.categories);

    final beforeRunSuitable = categoryStrings.contains('before_run');
    final duringRunSuitable = categoryStrings.contains('during_run');
    final mappedCategories = categoryStrings
        .map((value) => FoodCategory.fromDbValue(value))
        .toList();

    return FoodItem(
      id: entry.id,
      name: entry.name ?? '',
      imageAddress: entry.imageAddress,
      description: entry.description ?? '',
      instructions: entry.instructions,
      servingAmount: 1.0, // Always 1.0 in simplified approach
      servingUnit: null, // Deprecated - use displayName instead
      servingUnitPlural: null, // Deprecated - use displayNamePlural instead
      servingQualifier: null, // Deprecated - included in displayName
      beforeRunSuitable: beforeRunSuitable,
      duringRunSuitable: duringRunSuitable,
      runPortable: true, // Default to true (no longer stored in schema)
      requiresPreparation: false, // Default to false (no longer stored in schema)
      aidStationAvailable: false, // Default to false (no longer stored in schema)
      maxServingsBefore: entry.maxServingsBefore,
      maxServingsDuring: entry.maxServingsDuring,
      carbsPerServing: carbs,
      proteinPerServing: protein,
      fatPerServing: fat,
      caloriesPerServing: calories,
      fluidMlPerServing: fluids,
      sodiumMg: entry.sodiumMg,
      caffeineMg: entry.caffeineMg,
      potassiumMg: entry.potassiumMg,
      productTypeId: null, // Removed field, use productType instead
      nutrition: NutritionInfo(
        calories: (calories?.round() ?? 0).toDouble(),
        carbs: (carbs?.round() ?? 0).toDouble(),
        protein: (protein?.round() ?? 0).toDouble(),
        fat: (fat?.round() ?? 0).toDouble(),
        sodium: (sodium?.round() ?? 0).toDouble(),
        fiber: 0.0, // Not stored separately in local database
        sugar: 0.0, // Not stored separately in local database
        fluids: (fluids?.round() ?? 0).toDouble(),
      ),
      tags: _generateTagsFromNutrition(carbs ?? 0, protein ?? 0, fat ?? 0),
      displayName: entry.displayName,
      displayNamePlural: entry.displayNamePlural,
      displayOverride: null, // Removed - no longer needed in simplified approach
      categories: mappedCategories,
      toExcludeFromSolver: entry.toExcludeFromSolver,
    );
  }

  /// Map user food entry to FoodItem
  FoodItem _mapUserFoodToFoodItem(UserFood entry) {
    // Use explicit columns from user food entry
    final carbs = entry.carbsPerServing;
    final protein = entry.proteinPerServing;
    final fat = entry.fatPerServing;
    final calories = entry.caloriesPerServing;
    final sodium = entry.sodiumMg?.toDouble();
    final fluids = entry.fluidMlPerServing;

    return FoodItem(
      id: entry.clientFoodId ?? '',
      name: entry.name,
      imageAddress: entry.imageAddress,
      description: entry.description ?? '',
      instructions: null, // User foods don't have instructions
      servingAmount: entry.servingAmount ?? 1.0,
      servingUnit: entry.servingUnit,
      servingUnitPlural: null, // Not stored in user foods
      servingQualifier: null, // Not stored in user foods
      beforeRunSuitable: true, // Default to true for user-added foods
      duringRunSuitable: false, // Default to false for safety
      runPortable: true, // Default to true
      requiresPreparation: false, // Default to false
      aidStationAvailable: false, // Default to false
      maxServingsBefore: null, // Not stored in user foods
      maxServingsDuring: null, // Not stored in user foods
      carbsPerServing: carbs,
      proteinPerServing: protein,
      fatPerServing: fat,
      caloriesPerServing: calories,
      fluidMlPerServing: fluids,
      sodiumMg: entry.sodiumMg,
      caffeineMg: null, // Not stored in user foods
      potassiumMg: null, // Not stored in user foods
      productTypeId: entry.productTypeId,
      nutrition: NutritionInfo(
        calories: (calories?.round() ?? 0).toDouble(),
        carbs: (carbs?.round() ?? 0).toDouble(),
        protein: (protein?.round() ?? 0).toDouble(),
        fat: (fat?.round() ?? 0).toDouble(),
        sodium: (sodium?.round() ?? 0).toDouble(),
        fiber: 0.0, // Not stored separately in user foods
        sugar: 0.0, // Not stored separately in user foods
        fluids: (fluids?.round() ?? 0).toDouble(),
      ),
      tags: _generateTagsFromNutrition(carbs ?? 0, protein ?? 0, fat ?? 0),
      displayName: entry.displayName,
      displayNamePlural: entry.displayNamePlural,
      displayOverride: null, // Not used
      categories: [], // Categories would need to be fetched separately
      toExcludeFromSolver: entry.toExcludeFromSolver == true,
    );
  }

  /// Get food by barcode - checks user_foods table
  Future<FoodItem?> getFoodByBarcode(String barcode) async {
    try {
      final userFoodEntry = await (_database.select(_database.userFoodsTable)
        ..where((f) => f.barcode.equals(barcode)))
        .getSingleOrNull();

      if (userFoodEntry != null) {
        // Get categories for this user food
        final categories = await getUserFoodCategories(userFoodEntry.id);

        // Map to FoodItem with updated suitability based on categories
        final carbs = userFoodEntry.carbsPerServing;
        final protein = userFoodEntry.proteinPerServing;
        final fat = userFoodEntry.fatPerServing;
        final calories = userFoodEntry.caloriesPerServing;
        final sodium = userFoodEntry.sodiumMg?.toDouble();
        final fluids = userFoodEntry.fluidMlPerServing;

        return FoodItem(
          id: userFoodEntry.clientFoodId ?? '',
          name: userFoodEntry.name,
          imageAddress: userFoodEntry.imageAddress,
          description: userFoodEntry.description ?? '',
          instructions: null,
          servingAmount: userFoodEntry.servingAmount ?? 1.0,
          servingUnit: userFoodEntry.servingUnit,
          servingUnitPlural: null,
          servingQualifier: null,
          // Use categories to determine suitability
          beforeRunSuitable: categories.contains(1), // category_id = 1
          duringRunSuitable: categories.contains(2), // category_id = 2
          runPortable: true,
          requiresPreparation: false,
          aidStationAvailable: false,
          maxServingsBefore: null,
          maxServingsDuring: null,
          carbsPerServing: carbs,
          proteinPerServing: protein,
          fatPerServing: fat,
          caloriesPerServing: calories,
          fluidMlPerServing: fluids,
          sodiumMg: userFoodEntry.sodiumMg,
          caffeineMg: null,
          potassiumMg: null,
          productTypeId: userFoodEntry.productTypeId,
          nutrition: NutritionInfo(
            calories: (calories?.round() ?? 0).toDouble(),
            carbs: (carbs?.round() ?? 0).toDouble(),
            protein: (protein?.round() ?? 0).toDouble(),
            fat: (fat?.round() ?? 0).toDouble(),
            sodium: (sodium?.round() ?? 0).toDouble(),
            fiber: 0.0,
            sugar: 0.0,
            fluids: (fluids?.round() ?? 0).toDouble(),
          ),
          tags: _generateTagsFromNutrition(carbs ?? 0, protein ?? 0, fat ?? 0),
          displayName: userFoodEntry.displayName,
          displayNamePlural: userFoodEntry.displayNamePlural,
          displayOverride: null,
          categories: [],
          toExcludeFromSolver: userFoodEntry.toExcludeFromSolver == true,
        );
      }
      return null;
    } catch (e) {
      _logger.error('Error fetching food by barcode',
        context: 'FoodRepository',
        data: {'barcode': barcode},
        error: e,
      );
      return null;
    }
  }

  /// Get categories for a regular food
  /// Categories are now stored as array column in the foods table
  /// Returns category strings: "before_run", "during_run", "after_run"
  Future<List<String>> getFoodCategories(String foodId) async {
    try {
      final food = await (_database.select(_database.foodsTable)
        ..where((f) => f.id.equals(foodId)))
        .getSingleOrNull();

      if (food == null || food.categories == null) return [];

      return _parseCategoriesArray(food.categories);
    } catch (e) {
      _logger.error('Error fetching food categories',
        context: 'FoodRepository',
        data: {'foodId': foodId},
        error: e,
      );
      return [];
    }
  }

  /// Get categories for a user food
  /// Categories are now stored as array column in the user_foods table
  /// Returns category strings: "before_run", "during_run", "after_run"
  Future<List<String>> getUserFoodCategories(String userFoodId) async {
    try {
      final userFood = await (_database.select(_database.userFoodsTable)
        ..where((uf) => uf.id.equals(userFoodId)))
        .getSingleOrNull();

      if (userFood == null || userFood.categories == null) return [];

      return _parseCategoriesArray(userFood.categories);
    } catch (e) {
      _logger.error('Error fetching user food categories',
        context: 'FoodRepository',
        data: {'userFoodId': userFoodId},
        error: e,
      );
      return [];
    }
  }

  /// Generate tags based on nutritional profile
  List<String> _generateTagsFromNutrition(double carbs, double protein, double fat) {
    final tags = <String>[];

    if (carbs > 20) tags.add('high-carbs');
    if (carbs > 0 && carbs <= 5) tags.add('low-carbs');
    if (protein > 10) tags.add('high-protein');
    if (fat > 10) tags.add('high-fat');
    if (fat <= 2) tags.add('low-fat');

    return tags;
  }

  /// Parse categories from array column - supports both old integer format and new string format
  /// Old format: {1,2,3} or [1,2,3] where 1=before_run, 2=during_run, 3=after_run
  /// New format: {"before_run","during_run"} or ["before_run","during_run"]
  List<String> _parseCategoriesArray(String? categoriesStr) {
    if (categoriesStr == null || categoriesStr.isEmpty) return [];

    try {
      // Handle PostgreSQL array format: {"before_run","during_run"} or {1,2,3}
      if (categoriesStr.startsWith('{') && categoriesStr.endsWith('}')) {
        final content = categoriesStr.substring(1, categoriesStr.length - 1);
        if (content.isEmpty) return [];

        return content.split(',').map((s) {
          final trimmed = s.trim().replaceAll('"', '');
          // Try to parse as int for backward compatibility
          final intValue = int.tryParse(trimmed);
          if (intValue != null) {
            // Convert old integer IDs to new string format
            switch (intValue) {
              case 1:
                return 'before_run';
              case 2:
                return 'during_run';
              case 3:
                return 'after_run';
              default:
                return 'before_run';
            }
          }
          return trimmed; // Already a string
        }).toList();
      }

      // Handle JSON array format: ["before_run","during_run"] or [1,2,3]
      if (categoriesStr.startsWith('[') && categoriesStr.endsWith(']')) {
        final List<dynamic> parsed = jsonDecode(categoriesStr);
        return parsed.map((e) {
          if (e is String) {
            return e; // Already a string
          } else if (e is int) {
            // Convert old integer IDs to new string format
            switch (e) {
              case 1:
                return 'before_run';
              case 2:
                return 'during_run';
              case 3:
                return 'after_run';
              default:
                return 'before_run';
            }
          }
          return 'before_run'; // Fallback
        }).toList();
      }

      return [];
    } catch (e) {
      _logger.error('Error parsing categories array',
        context: 'FoodRepository',
        data: {'categoriesStr': categoriesStr},
        error: e,
      );
      return [];
    }
  }

  /// Sync foods from Supabase response to local database
  /// This ensures that food IDs returned by edge functions can be resolved locally
  Future<void> _syncFoodsToLocalDatabase(List<dynamic> supabaseFoodsData) async {
    try {
      // Clear existing foods to avoid duplicates
      await _database.delete(_database.foodsTable).go();

      // Log each food being synced for debugging
      for (final json in supabaseFoodsData) {
        if ((json['name'] as String).toLowerCase().contains('sports drink')) {        }
      }

      // Convert Supabase data to FoodsTableCompanion objects for insertion
      final foodsToInsert = supabaseFoodsData.map((json) {
        // Helper function to convert array columns to JSON strings for SQLite storage
        String? arrayToJsonString(dynamic value) {
          if (value == null) return null;
          if (value is String) return value;
          if (value is List) return jsonEncode(value);
          return null;
        }

        return FoodsTableCompanion.insert(
          id: json['id'] as String,
          name: Value(json['name'] as String?),
          imageAddress: Value(json['image_address'] as String?),
          description: Value(json['description'] as String?),
          instructions: Value(null), // Not available in Supabase schema
          servingAmount: Value((json['serving_amount'] as num?)?.toDouble() ?? 1.0),
          // Deprecated fields removed: servingUnit, servingUnitPlural, servingQualifier
          // Boolean suitability fields replaced with categories array
          categories: Value(arrayToJsonString(json['categories'])), // Array column - convert to JSON string
          activityTypes: Value(arrayToJsonString(json['activity_types'])), // Array column - convert to JSON string
          maxServingsBefore: Value(json['max_servings_before'] as int?),
          maxServingsDuring: Value(json['max_servings_during'] as int?),
          carbsPerServing: Value((json['carbs_per_serving'] as num?)?.toDouble()),
          proteinPerServing: Value((json['protein_per_serving'] as num?)?.toDouble()),
          fatPerServing: Value((json['fat_per_serving'] as num?)?.toDouble()),
          caloriesPerServing: Value(json['calories_per_serving'] as int?),
          fluidMlPerServing: Value((json['fluid_ml_per_serving'] as num?)?.toDouble()),
          sodiumMg: Value(json['sodium_mg'] as int?),
          caffeineMg: Value(json['caffeine_mg'] as int?),
          potassiumMg: Value(json['potassium_mg'] as int?),
          // Deprecated field removed: servingSize
          showInPreferences: Value(json['show_in_preferences'] == true),
          preferencePriority: Value(999), // Default since not in Supabase schema
          displayName: Value(json['display_name'] as String?),
          displayNamePlural: Value(json['display_name_plural'] as String?),
          isElectrolyte: Value(json['is_electrolyte'] == true),
          toExcludeFromSolver: Value(json['to_exclude_from_solver'] == true),
          createdAt: Value(DateTime.tryParse(json['created_at'] as String? ?? '') ?? DateTime.now()),
        );
      }).toList();

      // Batch insert all foods
      await _database.batch((batch) {
        for (final food in foodsToInsert) {
          batch.insert(_database.foodsTable, food);
        }
      });    } catch (e) {
      _logger.error('Error syncing foods to local database',
        context: 'FoodRepository',
        error: e,
      );
      // Don't rethrow - app should continue even if sync fails
    }
  }

  /// Sync nutrition foods from pre-downloaded data (from sync-all-data edge function)
  /// This method is called during app startup after sync-all-data returns
  /// Updates seed database with latest food data from server
  Future<void> syncFromDownloadedData({
    required List<dynamic> foods,
  }) async {
    try {
      _logger.info(
        'Syncing nutrition foods from downloaded data',
        context: 'FOOD_REPOSITORY',
        data: {'count': foods.length},
      );

      // Reuse existing sync logic that clears and repopulates foods table
      await _syncFoodsToLocalDatabase(foods);

      _logger.info(
        'Nutrition foods sync completed',
        context: 'FOOD_REPOSITORY',
        data: {'count': foods.length},
      );
    } catch (e, stackTrace) {
      _logger.error(
        'Nutrition foods sync failed',
        context: 'FOOD_REPOSITORY',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }
}

/// Riverpod provider for FoodRepository
final foodRepositoryProvider = Provider<FoodRepository>((ref) {
  final database = ref.watch(appDatabaseProvider);
  final logger = ref.watch(appLoggerProvider);
  final supabase = ref.watch(appExternalDepsProvider).supabaseClient;
  return FoodRepository(supabase, database, logger: logger);
});

/// Provider for all foods (cached)
final allFoodsProvider = FutureProvider<List<FoodItem>>((ref) async {
  final repository = ref.read(foodRepositoryProvider);
  return await repository.getAllFoods();
});

/// Provider for foods by category
final foodsByCategoryProvider = FutureProvider.family<List<FoodItem>, FoodCategory>((ref, category) async {
  final repository = ref.read(foodRepositoryProvider);
  return await repository.getFoodsByCategory(category);
});

/// Provider for foods for preferences screen (curated foods)
final preferenceFoodsProvider = FutureProvider<List<FoodItem>>((ref) async {
  final repository = ref.read(foodRepositoryProvider);
  return await repository.getFoodsForPreferences();
});
