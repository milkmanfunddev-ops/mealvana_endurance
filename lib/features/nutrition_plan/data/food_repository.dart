import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../domain/food_item.dart';

/// Repository for accessing food data from Supabase
/// Replaces the hardcoded FoodDatabase with dynamic data
class FoodRepository {
  FoodRepository(this._supabase);
  
  final SupabaseClient _supabase;

  /// Get all foods from Supabase
  Future<List<FoodItem>> getAllFoods() async {
    try {
      final response = await _supabase
          .from('foods')
          .select('*')
          .order('category', ascending: true);
      
      final List<dynamic> data = response as List<dynamic>;
      return data.map((json) => _mapSupabaseFoodToFoodItem(json)).toList();
    } catch (e) {
      print('Error fetching foods from Supabase: $e');
      // Fallback to empty list - app should still work without foods
      return [];
    }
  }

  /// Get foods by category
  Future<List<FoodItem>> getFoodsByCategory(FoodCategory category) async {
    try {
      final categoryName = _mapCategoryToSupabaseCategory(category);
      final response = await _supabase
          .from('foods')
          .select('*')
          .eq('category', categoryName)
          .order('name', ascending: true);
      
      final List<dynamic> data = response as List<dynamic>;
      return data.map((json) => _mapSupabaseFoodToFoodItem(json)).toList();
    } catch (e) {
      print('Error fetching foods by category from Supabase: $e');
      return [];
    }
  }

  /// Get a specific food by name (since Supabase uses text names as IDs)
  Future<FoodItem?> getFoodByName(String name) async {
    try {
      final response = await _supabase
          .from('foods')
          .select('*')
          .eq('name', name)
          .maybeSingle();
      
      if (response != null) {
        return _mapSupabaseFoodToFoodItem(response);
      }
      return null;
    } catch (e) {
      print('Error fetching food by name from Supabase: $e');
      return null;
    }
  }

  /// Search foods by name or description
  Future<List<FoodItem>> searchFoods(String query) async {
    try {
      final lowerQuery = query.toLowerCase();
      final response = await _supabase
          .from('foods')
          .select('*')
          .or('name.ilike.%$lowerQuery%,description.ilike.%$lowerQuery%')
          .order('name', ascending: true);
      
      final List<dynamic> data = response as List<dynamic>;
      return data.map((json) => _mapSupabaseFoodToFoodItem(json)).toList();
    } catch (e) {
      print('Error searching foods in Supabase: $e');
      return [];
    }
  }

  /// Get preferred foods based on user likes
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

  /// Map Supabase food data to FoodItem domain object
  FoodItem _mapSupabaseFoodToFoodItem(Map<String, dynamic> json) {
    final nutritionalInfo = json['nutritional_info'] as Map<String, dynamic>? ?? {};
    
    // Extract nutrition values with defaults
    final calories = _extractNutritionValue(nutritionalInfo, ['calories', 'calories_per_serving'], 0.0);
    final carbs = _extractNutritionValue(nutritionalInfo, ['carbs_per_serving', 'carbs'], 0.0);
    final protein = _extractNutritionValue(nutritionalInfo, ['protein_per_serving', 'protein'], 0.0);
    final fat = _extractNutritionValue(nutritionalInfo, ['fat_per_serving', 'fat'], 0.0);
    final sodium = _extractNutritionValue(nutritionalInfo, ['sodium_mg', 'sodium'], 0.0);
    final fiber = _extractNutritionValue(nutritionalInfo, ['fiber_per_serving', 'fiber'], 0.0);
    final sugar = _extractNutritionValue(nutritionalInfo, ['sugar_per_serving', 'sugar'], 0.0);
    final servingSize = nutritionalInfo['serving_size'] as String? ?? '1 serving';

    return FoodItem(
      id: _generateIdFromName(json['name'] as String),
      name: json['name'] as String,
      description: json['description'] as String? ?? '',
      category: _mapSupabaseCategoryToFoodCategory(json['category'] as String),
      servingSize: servingSize,
      servingAmount: 1.0, // Default serving amount
      servingUnit: _extractServingUnit(servingSize),
      nutrition: NutritionInfo(
        calories: calories,
        carbs: carbs,
        protein: protein,
        fat: fat,
        sodium: sodium,
        fiber: fiber,
        sugar: sugar,
        fluids: 0.0, // Default value for fluids
      ),
      tags: _generateTagsFromNutrition(carbs, protein, fat),
      additionalInfo: json['instructions'] as String?,
    );
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

  /// Extract serving unit from serving size string
  String _extractServingUnit(String servingSize) {
    final words = servingSize.toLowerCase().split(' ');
    if (words.length >= 2) {
      return words.last; // Last word is usually the unit
    }
    return 'serving';
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

  /// Map FoodCategory enum to Supabase category string
  String _mapCategoryToSupabaseCategory(FoodCategory category) {
    switch (category) {
      case FoodCategory.preRun:
        return 'before_run';
      case FoodCategory.duringRun:
        return 'during_run';
      case FoodCategory.postRun:
        return 'after_run';
    }
  }

  /// Map Supabase category string to FoodCategory enum
  FoodCategory _mapSupabaseCategoryToFoodCategory(String category) {
    switch (category) {
      case 'before_run':
        return FoodCategory.preRun;
      case 'during_run':
        return FoodCategory.duringRun;
      case 'after_run':
        return FoodCategory.postRun;
      default:
        return FoodCategory.preRun; // Default fallback
    }
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