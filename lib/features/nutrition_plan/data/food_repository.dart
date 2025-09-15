import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:drift/drift.dart';
import '../domain/food_item.dart';
import '../../../shared/services/logging_service.dart';
import '../../../shared/database/app_database.dart';
import '../../../shared/database/database_provider.dart';

/// Repository for accessing food data from Supabase
/// Replaces the hardcoded FoodDatabase with dynamic data
class FoodRepository {
  FoodRepository(this._supabase, this._database);

  final SupabaseClient _supabase;
  final AppDatabase _database;

  /// Get all generic foods from Supabase (brand_id IS NULL)
  /// Use this for "Recommended Alternatives" - generic foods only
  /// Also syncs the foods to local database for offline access
  Future<List<FoodItem>> getAllFoods() async {
    try {
      final response = await _supabase
          .from('foods')
          .select('''
            id,
            name,
            display_name,
            image_address,
            description,
            instructions,
            nutritional_info,
            serving_amount,
            serving_unit,
            serving_unit_plural,
            serving_qualifier,
            before_run_suitable,
            during_run_suitable,
            run_portable,
            requires_preparation,
            aid_station_available,
            max_servings_before,
            max_servings_during,
            carbs_per_serving,
            protein_per_serving,
            fat_per_serving,
            calories_per_serving,
            fluid_ml_per_serving,
            sodium_mg,
            caffeine_mg,
            potassium_mg,
            serving_size,
            brand_id,
            show_in_preferences,
            preference_priority,
            created_at,
            food_categories (
              category_id
            ),
            display_name_plural,
            display_override,
            to_exclude_from_solver,
            is_electrolyte
          ''')
          .isFilter('brand_id', null)  // Only get generic foods (no brand)
          .order('name', ascending: true);

      final List<dynamic> data = response as List<dynamic>;
      final foods = data.map((json) => _mapSupabaseFoodToFoodItem(json)).toList();

      // Sync foods to local database for offline access
      await _syncFoodsToLocalDatabase(data);

      AppLogger.instance.debug('Synced ${foods.length} generic foods to local database');

      return foods;
    } catch (e) {
      AppLogger.instance.error('Error fetching generic foods from Supabase',
        context: 'FoodRepository',
        error: e,
      );
      // Fallback to empty list - app should still work without foods
      return [];
    }
  }

  /// Get foods for the preferences screen (curated 12 foods ordered by priority)
  Future<List<FoodItem>> getFoodsForPreferences() async {
    try {
      final response = await _supabase
          .from('foods')
          .select('''
            id,
            name,
            image_address,
            description,
            instructions,
            nutritional_info,
            serving_amount,
            serving_unit,
            serving_unit_plural,
            serving_qualifier,
            before_run_suitable,
            during_run_suitable,
            run_portable,
            requires_preparation,
            aid_station_available,
            max_servings_before,
            max_servings_during,
            carbs_per_serving,
            protein_per_serving,
            fat_per_serving,
            calories_per_serving,
            fluid_ml_per_serving,
            sodium_mg,
            caffeine_mg,
            potassium_mg,
            serving_size,
            brand_id,
            show_in_preferences,
            preference_priority,
            created_at,
            food_categories (
              category_id
            )
          ''')
          .eq('show_in_preferences', true)
          .isFilter('brand_id', null)  // Only get generic foods (no brand)
          .order('preference_priority', ascending: true)
          .order('name', ascending: true);
      
      final List<dynamic> data = response as List<dynamic>;
      return data.map((json) => _mapSupabaseFoodToFoodItem(json)).toList();
    } catch (e) {
      AppLogger.instance.error('Error fetching preference foods from Supabase',
        context: 'FoodRepository',
        error: e,
      );
      // Fallback to regular foods if preferences query fails
      return await getAllFoods();
    }
  }

  /// Get foods by category using the new join table with category_id
  Future<List<FoodItem>> getFoodsByCategory(FoodCategory category) async {
    try {
      // First get the category ID
      final categoryId = _getCategoryId(category);
      
      final response = await _supabase
          .from('foods')
          .select('''
            id,
            name,
            image_address,
            description,
            instructions,
            nutritional_info,
            serving_amount,
            serving_unit,
            serving_unit_plural,
            serving_qualifier,
            before_run_suitable,
            during_run_suitable,
            run_portable,
            requires_preparation,
            aid_station_available,
            max_servings_before,
            max_servings_during,
            carbs_per_serving,
            protein_per_serving,
            fat_per_serving,
            calories_per_serving,
            fluid_ml_per_serving,
            sodium_mg,
            caffeine_mg,
            potassium_mg,
            serving_size,
            created_at,
            food_categories!inner (
              category_id
            )
          ''')
          .eq('food_categories.category_id', categoryId)
          .order('name', ascending: true);
      
      final List<dynamic> data = response as List<dynamic>;
      return data.map((json) => _mapSupabaseFoodToFoodItem(json)).toList();
    } catch (e) {
      AppLogger.instance.error('Error fetching foods by category from Supabase',
        context: 'FoodRepository',
        data: {'category': category.dbValue},
        error: e,
      );
      return [];
    }
  }

  /// Get a specific food by name with its categories
  Future<FoodItem?> getFoodByName(String name) async {
    try {
      final response = await _supabase
          .from('foods')
          .select('''
            id,
            name,
            image_address,
            description,
            instructions,
            nutritional_info,
            serving_amount,
            serving_unit,
            serving_unit_plural,
            serving_qualifier,
            before_run_suitable,
            during_run_suitable,
            run_portable,
            requires_preparation,
            aid_station_available,
            max_servings_before,
            max_servings_during,
            carbs_per_serving,
            protein_per_serving,
            fat_per_serving,
            calories_per_serving,
            fluid_ml_per_serving,
            sodium_mg,
            caffeine_mg,
            potassium_mg,
            serving_size,
            created_at,
            food_categories (
              category_id
            )
          ''')
          .eq('name', name)
          .maybeSingle();

      if (response != null) {
        return _mapSupabaseFoodToFoodItem(response);
      }
      return null;
    } catch (e) {
      AppLogger.instance.error('Error fetching food by name from Supabase',
        context: 'FoodRepository',
        data: {'foodName': name},
        error: e,
      );
      return null;
    }
  }

  /// Get a specific food by ID from local database
  Future<FoodItem?> getFoodById(String id) async {
    try {
      // First try to get from local database
      final foodEntry = await (_database.select(_database.foodsTable)
        ..where((f) => f.id.equals(id)))
        .getSingleOrNull();

      if (foodEntry != null) {
        return _mapLocalFoodToFoodItem(foodEntry);
      }

      AppLogger.instance.warning('Food not found in local database',
        context: 'FoodRepository',
        data: {'foodId': id},
      );
      return null;
    } catch (e) {
      AppLogger.instance.error('Error fetching food by ID from local database',
        context: 'FoodRepository',
        data: {'foodId': id},
        error: e,
      );
      return null;
    }
  }

  /// Get ALL foods from Supabase including both generic and branded
  /// Use this for search functionality to include branded foods
  /// Also syncs ALL foods to local database for offline access
  Future<List<FoodItem>> getAllFoodsIncludingBranded() async {
    try {
      final response = await _supabase
          .from('foods')
          .select('''
            id,
            name,
            image_address,
            description,
            instructions,
            nutritional_info,
            serving_amount,
            serving_unit,
            serving_unit_plural,
            serving_qualifier,
            before_run_suitable,
            during_run_suitable,
            run_portable,
            requires_preparation,
            aid_station_available,
            max_servings_before,
            max_servings_during,
            carbs_per_serving,
            protein_per_serving,
            fat_per_serving,
            calories_per_serving,
            fluid_ml_per_serving,
            sodium_mg,
            caffeine_mg,
            potassium_mg,
            serving_size,
            brand_id,
            show_in_preferences,
            preference_priority,
            created_at,
            food_categories (
              category_id
            ),
            display_name_plural,
            display_override,
            to_exclude_from_solver
          ''')
          // NO brand_id filter - include both generic (null) and branded (not null)
          .order('name', ascending: true);

      final List<dynamic> data = response as List<dynamic>;
      final foods = data.map((json) => _mapSupabaseFoodToFoodItem(json)).toList();

      // Sync ALL foods to local database for offline access
      await _syncFoodsToLocalDatabase(data);

      AppLogger.instance.debug('Synced ${foods.length} foods (including branded) to local database');

      return foods;
    } catch (e) {
      AppLogger.instance.error('Error fetching all foods including branded from Supabase',
        context: 'FoodRepository',
        error: e,
      );
      return [];
    }
  }

  /// Search foods by name or description with categories
  Future<List<FoodItem>> searchFoods(String query) async {
    try {
      final lowerQuery = query.toLowerCase();
      final response = await _supabase
          .from('foods')
          .select('''
            id,
            name,
            image_address,
            description,
            instructions,
            nutritional_info,
            serving_amount,
            serving_unit,
            serving_unit_plural,
            serving_qualifier,
            before_run_suitable,
            during_run_suitable,
            run_portable,
            requires_preparation,
            aid_station_available,
            max_servings_before,
            max_servings_during,
            carbs_per_serving,
            protein_per_serving,
            fat_per_serving,
            calories_per_serving,
            fluid_ml_per_serving,
            sodium_mg,
            caffeine_mg,
            potassium_mg,
            serving_size,
            created_at,
            food_categories (
              category_id
            )
          ''')
          .or('name.ilike.%$lowerQuery%,description.ilike.%$lowerQuery%')
          .order('name', ascending: true);
      
      final List<dynamic> data = response as List<dynamic>;
      return data.map((json) => _mapSupabaseFoodToFoodItem(json)).toList();
    } catch (e) {
      AppLogger.instance.error('Error searching foods in Supabase',
        context: 'FoodRepository',
        data: {'searchQuery': query},
        error: e,
      );
      return [];
    }
  }

  /// Get preferred foods based on user likes (now works with multi-category foods)
  Future<List<FoodItem>> getPreferredFoods(
    FoodCategory category,
    List<String> likedFoodNames,
    List<String> willingToTryNames,
  ) async {
    final categoryFoods = await getFoodsByCategory(category);
    return categoryFoods.where((food) {
      return likedFoodNames.contains(food.name) || 
             willingToTryNames.contains(food.name);
    }).toList();
  }

  /// Get all foods that can be used for multiple categories
  Future<List<FoodItem>> getFoodsForCategories(List<FoodCategory> categories) async {
    final allFoods = await getAllFoods();
    return allFoods.where((food) {
      return categories.any((category) => food.belongsToCategory(category));
    }).toList();
  }

  /// Map Supabase food data to FoodItem domain object
  FoodItem _mapSupabaseFoodToFoodItem(Map<String, dynamic> json) {
    final nutritionalInfo = json['nutritional_info'] as Map<String, dynamic>? ?? {};
    
    // Extract nutrition values with defaults for legacy compatibility
    final calories = _extractNutritionValue(nutritionalInfo, ['calories', 'calories_per_serving'], 0.0);
    final carbs = _extractNutritionValue(nutritionalInfo, ['carbs_per_serving', 'carbs'], 0.0);
    final protein = _extractNutritionValue(nutritionalInfo, ['protein_per_serving', 'protein'], 0.0);
    final fat = _extractNutritionValue(nutritionalInfo, ['fat_per_serving', 'fat'], 0.0);
    final sodium = _extractNutritionValue(nutritionalInfo, ['sodium_mg', 'sodium'], 0.0);
    final fiber = _extractNutritionValue(nutritionalInfo, ['fiber_per_serving', 'fiber'], 0.0);
    final sugar = _extractNutritionValue(nutritionalInfo, ['sugar_per_serving', 'sugar'], 0.0);
    final fluids = _extractNutritionValue(nutritionalInfo, ['fluids', 'fluids_per_serving'], 0.0);

    // Extract structured serving data from database
    final servingAmount = (json['serving_amount'] as num?)?.toDouble() ?? 1.0;
    final servingUnit = json['serving_unit'] as String? ?? 'serving';
    final servingUnitPlural = json['serving_unit_plural'] as String?;
    final servingQualifier = json['serving_qualifier'] as String?;
    
    // Create legacy serving size for compatibility
    final servingSize = servingQualifier != null && servingQualifier.isNotEmpty 
        ? '$servingAmount $servingUnit, $servingQualifier'
        : '$servingAmount $servingUnit';

    // Extract categories from the food_categories join
    final categories = _extractCategoriesFromJoin(json);

    // Get carbs for tag generation (prefer explicit field over legacy)
    final effectiveCarbs = (json['carbs_per_serving'] as num?)?.toDouble() ?? carbs;
    final effectiveProtein = (json['protein_per_serving'] as num?)?.toDouble() ?? protein;
    final effectiveFat = (json['fat_per_serving'] as num?)?.toDouble() ?? fat;

    // Debug logging
    final imageAddress = json['image_address'] as String?;
    
    return FoodItem(
      id: _generateIdFromName(json['name'] as String),
      name: json['name'] as String,
      imageAddress: imageAddress,
      description: json['description'] as String?,
      instructions: json['instructions'] as String?,
      categories: categories,
      servingSize: servingSize,
      servingAmount: servingAmount,
      servingUnit: servingUnit,
      servingUnitPlural: servingUnitPlural,
      servingQualifier: servingQualifier,
      beforeRunSuitable: json['before_run_suitable'] == true,
      duringRunSuitable: json['during_run_suitable'] == true,
      runPortable: json['run_portable'] == true,
      requiresPreparation: json['requires_preparation'] == true,
      aidStationAvailable: json['aid_station_available'] == true,
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
      nutrition: NutritionInfo(
        calories: calories,
        carbs: carbs,
        protein: protein,
        fat: fat,
        sodium: sodium,
        fiber: fiber,
        sugar: sugar,
        fluids: fluids,
      ),
      tags: _generateTagsFromNutrition(effectiveCarbs, effectiveProtein, effectiveFat),
      displayName: json['display_name'] as String?,
      displayNamePlural: json['display_name_plural'] as String?,
      displayOverride: json['display_override'] as String?,
      toExcludeFromSolver: json['to_exclude_from_solver'] == true,
    );
  }

  /// Map local Drift food entry to FoodItem
  FoodItem _mapLocalFoodToFoodItem(FoodEntry entry) {
    // Parse nutritional_info JSON if available
    final nutritionalInfo = entry.nutritionalInfo as Map<String, dynamic>? ?? {};

    final carbs = (entry.carbsPerServing ?? nutritionalInfo['carbs'])?.toDouble();
    final protein = (entry.proteinPerServing ?? nutritionalInfo['protein'])?.toDouble();
    final fat = (entry.fatPerServing ?? nutritionalInfo['fat'])?.toDouble();
    final calories = entry.caloriesPerServing ?? nutritionalInfo['calories'] as int?;
    final sodium = (entry.sodiumMg ?? nutritionalInfo['sodium'])?.toDouble();
    final fluids = (entry.fluidMlPerServing ?? nutritionalInfo['fluids'])?.toDouble();

    return FoodItem(
      id: entry.id,
      name: entry.name,
      imageAddress: entry.imageAddress,
      description: entry.description ?? '',
      instructions: entry.instructions,
      servingAmount: entry.servingAmount,
      servingUnit: entry.servingUnit ?? 'serving',
      servingUnitPlural: entry.servingUnitPlural,
      servingQualifier: entry.servingQualifier,
      beforeRunSuitable: entry.beforeRunSuitable,
      duringRunSuitable: entry.duringRunSuitable,
      runPortable: entry.runPortable,
      requiresPreparation: entry.requiresPreparation,
      aidStationAvailable: entry.aidStationAvailable,
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
      tags: _generateTagsFromNutrition(carbs, protein, fat),
      displayName: entry.displayName,
      displayNamePlural: entry.displayNamePlural,
      displayOverride: entry.displayOverride,
      categories: [], // Categories would need to be fetched separately if needed
      toExcludeFromSolver: entry.toExcludeFromSolver,
    );
  }

  /// Extract categories from the food_categories join
  List<FoodCategory> _extractCategoriesFromJoin(Map<String, dynamic> json) {
    final foodCategories = json['food_categories'] as List<dynamic>?;
    if (foodCategories != null && foodCategories.isNotEmpty) {
      return foodCategories
          .map((fc) => _getCategoryFromId(fc['category_id'] as int))
          .toList();
    }
    
    // No categories found - return empty list
    return [];
  }

  /// Map category ID to FoodCategory enum
  FoodCategory _getCategoryFromId(int categoryId) {
    switch (categoryId) {
      case 1:
        return FoodCategory.beforeRun;
      case 2:
        return FoodCategory.duringRun;
      case 3:
        return FoodCategory.afterRun;
      default:
        return FoodCategory.beforeRun;
    }
  }

  /// Get category ID from FoodCategory enum
  int _getCategoryId(FoodCategory category) {
    switch (category) {
      case FoodCategory.beforeRun:
        return 1;
      case FoodCategory.duringRun:
        return 2;
      case FoodCategory.afterRun:
        return 3;
    }
  }

  /// Extract nutrition value with fallback keys
  double _extractNutritionValue(Map<String, dynamic> nutrition, List<String> keys, double? defaultValue) {
    for (final key in keys) {
      final value = nutrition[key];
      if (value != null) {
        if (value is num) return value.toDouble();
        if (value is String) {
          final parsed = double.tryParse(value);
          if (parsed != null) return parsed;
        }
      }
    }
    return defaultValue ?? 0.0;
  }

  /// Generate ID from food name (for compatibility with existing code)
  String _generateIdFromName(String name) {
    return name.toLowerCase()
        .replaceAll(' ', '_')
        .replaceAll(RegExp(r'[^a-z0-9_]'), '');
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

  /// Sync foods from Supabase response to local database
  /// This ensures that food IDs returned by edge functions can be resolved locally
  Future<void> _syncFoodsToLocalDatabase(List<dynamic> supabaseFoodsData) async {
    try {
      // Clear existing foods to avoid duplicates
      await _database.delete(_database.foodsTable).go();

      // Convert Supabase data to FoodsTableCompanion objects for insertion
      final foodsToInsert = supabaseFoodsData.map((json) {
        return FoodsTableCompanion.insert(
          id: json['id'] as String,
          name: json['name'] as String,
          imageAddress: Value(json['image_address'] as String?),
          description: Value(json['description'] as String?),
          instructions: Value(json['instructions'] as String?),
          servingAmount: Value((json['serving_amount'] as num?)?.toDouble()),
          servingUnit: Value(json['serving_unit'] as String?),
          servingUnitPlural: Value(json['serving_unit_plural'] as String?),
          servingQualifier: Value(json['serving_qualifier'] as String?),
          beforeRunSuitable: Value(json['before_run_suitable'] == true),
          duringRunSuitable: Value(json['during_run_suitable'] == true),
          runPortable: Value(json['run_portable'] == true),
          requiresPreparation: Value(json['requires_preparation'] == true),
          aidStationAvailable: Value(json['aid_station_available'] == true),
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
          servingSize: Value(json['serving_size'] as String?),
          brandId: Value(json['brand_id'] as String?),
          showInPreferences: Value(json['show_in_preferences'] == true),
          preferencePriority: Value(json['preference_priority'] as int? ?? 999),
          displayName: Value(json['display_name'] as String?),
          displayNamePlural: Value(json['display_name_plural'] as String?),
          displayOverride: Value(json['display_override'] as String?),
          toExcludeFromSolver: Value(json['to_exclude_from_solver'] == true),
          isElectrolyte: Value(json['is_electrolyte'] == true),
          createdAt: Value(DateTime.tryParse(json['created_at'] as String? ?? '') ?? DateTime.now()),
        );
      }).toList();

      // Batch insert all foods
      await _database.batch((batch) {
        for (final food in foodsToInsert) {
          batch.insert(_database.foodsTable, food);
        }
      });

      AppLogger.instance.debug('Successfully synced ${foodsToInsert.length} foods to local database');

    } catch (e) {
      AppLogger.instance.error('Error syncing foods to local database',
        context: 'FoodRepository',
        error: e,
      );
      // Don't rethrow - app should continue even if sync fails
    }
  }

}

/// Riverpod provider for FoodRepository
final foodRepositoryProvider = Provider<FoodRepository>((ref) {
  final database = ref.watch(appDatabaseProvider);
  return FoodRepository(Supabase.instance.client, database);
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

/// Provider for foods for preferences screen (curated 12 foods)
final preferenceFoodsProvider = FutureProvider<List<FoodItem>>((ref) async {
  final repository = ref.read(foodRepositoryProvider);
  return await repository.getFoodsForPreferences();
});