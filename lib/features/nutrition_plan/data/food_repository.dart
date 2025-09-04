import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../domain/food_item.dart';
import '../../../shared/services/logging_service.dart';

/// Repository for accessing food data from Supabase
/// Replaces the hardcoded FoodDatabase with dynamic data
class FoodRepository {
  FoodRepository(this._supabase);
  
  final SupabaseClient _supabase;

  /// Get all generic foods from Supabase (brand_id IS NULL)
  /// Use this for "Recommended Alternatives" - generic foods only
  Future<List<FoodItem>> getAllFoods() async {
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
            created_at,
            food_categories (
              category_id
            )
          ''')
          .isFilter('brand_id', null)  // Only get generic foods (no brand)
          .order('name', ascending: true);
      
      final List<dynamic> data = response as List<dynamic>;
      return data.map((json) => _mapSupabaseFoodToFoodItem(json)).toList();
    } catch (e) {
      AppLogger.instance.error('Error fetching generic foods from Supabase',
        context: 'FoodRepository',
        error: e,
      );
      // Fallback to empty list - app should still work without foods
      return [];
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

  /// Get ALL foods from Supabase including both generic and branded
  /// Use this for search functionality to include branded foods
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
            created_at,
            food_categories (
              category_id
            )
          ''')
          // NO brand_id filter - include both generic (null) and branded (not null)
          .order('name', ascending: true);
      
      final List<dynamic> data = response as List<dynamic>;
      return data.map((json) => _mapSupabaseFoodToFoodItem(json)).toList();
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
    AppLogger.instance.debug('Creating FoodItem from Supabase data',
      context: 'FoodRepository',
      data: {
        'foodName': json['name'],
        'imageAddress': imageAddress,
        'brandId': json['brand_id'],
      },
    );
    
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

}

/// Riverpod provider for FoodRepository
final foodRepositoryProvider = Provider<FoodRepository>((ref) {
  return FoodRepository(Supabase.instance.client);
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