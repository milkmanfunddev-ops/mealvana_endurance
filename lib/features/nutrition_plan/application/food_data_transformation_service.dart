import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/food_item_data.dart';
import '../data/food_repository.dart';
import '../../../shared/services/app_external_deps.dart';
import '../../../shared/services/logging_service.dart';

/// Service for transforming edge function responses into FoodItemData objects
/// Handles database lookups and display name generation
class FoodDataTransformationService {
  FoodDataTransformationService(this.ref);
  final Ref ref;

  FoodRepository get _foodRepository => ref.read(foodRepositoryProvider);
  AppLogger get _logger => ref.read(appExternalDepsProvider).logger;

  /// Transform edge function item response to FoodItemData
  /// Takes raw response with food_id and quantity, looks up details from database
  Future<FoodItemData> transformEdgeFunctionItem(
    Map<String, dynamic> item,
  ) async {
    final foodId = item['food_id'] as String;
    final quantity = item['quantity'] as num;

    _logger.debug('Transforming edge function item',
      data: {
        'food_id': foodId,
        'quantity': quantity,
      },
    );

    // Look up food details from database (checks both foods and user_foods tables)
    final foodDetails = await _foodRepository.getFoodById(foodId);

    if (foodDetails == null) {
      _logger.error('Food not found in local database',
        context: 'FOOD_TRANSFORMATION',
        data: {
          'food_id': foodId,
          'quantity': quantity,
          'item_keys': item.keys.toList(),
          'has_food_name': item.containsKey('food_name'),
          'food_name_value': item['food_name'],
        },
      );

      // Use the food_name from edge function as fallback (should always be present)
      final foodName = item['food_name'] as String? ?? item['display_name'] as String? ?? 'Unknown Food';
      final description = item['description'] as String? ?? '';

      // Special handling for salt packets which are essential
      if (foodName.toLowerCase().contains('salt')) {
        final packets = quantity == quantity.toInt()
            ? quantity.toInt().toString()
            : quantity.toStringAsFixed(1);
        final packetLabel = quantity == 1 ? 'salt packet' : 'salt packets';

        return FoodItemData(
          id: foodId,
          name: 'Salt',
          quantity: '$packets $packetLabel',
          description: description.isNotEmpty ? description : 'Electrolyte supplement',
          nutritionalInfo: NutritionalInfo(
            calories: 0,
            carbs: 0,
            protein: 0,
            fat: 0,
            sodium: item['sodium_mg'] != null ? (item['sodium_mg'] as num).round() : (quantity * 200).round(),
            fluids: 0.0,
          ),
        );
      }

      // Return fallback data if food not found
      return FoodItemData(
        id: foodId,
        name: foodName,
        quantity: _formatQuantity(quantity, '', foodName),
        description: description.isNotEmpty ? description : 'Food details not available',
        nutritionalInfo: NutritionalInfo(
          calories: item['calories'] as int?,
          carbs: item['carbs_grams'] != null ? (item['carbs_grams'] as num).round() : null,
          protein: item['protein_grams'] != null ? (item['protein_grams'] as num).round() : null,
          fat: item['fat_grams'] != null ? (item['fat_grams'] as num).round() : null,
          sodium: item['sodium_mg'] != null ? (item['sodium_mg'] as num).round() : null,
          fluids: item['fluids_ml'] != null ? (item['fluids_ml'] as num).toDouble() : null,
        ),
      );
    }

    // Generate display name using database fields
    final displayName = _generateDisplayName(quantity, foodDetails);

    _logger.debug('Generated display name',
      data: {
        'food_id': foodId,
        'quantity': quantity,
        'display_name': displayName,
        'display_override': foodDetails.displayOverride,
      },
    );

    // Log raw database values first
    _logger.debug('Raw database values for transformation',
      data: {
        'food_id': foodId,
        'food_name': foodDetails.name,
        'effectiveCaloriesPerServing': foodDetails.effectiveCaloriesPerServing,
        'effectiveCarbsPerServing': foodDetails.effectiveCarbsPerServing,
        'effectiveProteinPerServing': foodDetails.effectiveProteinPerServing,
        'effectiveFatPerServing': foodDetails.effectiveFatPerServing,
        'effectiveSodiumMg': foodDetails.effectiveSodiumMg,
        'fluidMlPerServing': foodDetails.fluidMlPerServing,
        'quantity': quantity,
      },
    );

    // Calculate nutritional values based on quantity and food details from database
    final calculatedCalories = foodDetails.effectiveCaloriesPerServing * quantity;
    final calculatedCarbs = foodDetails.effectiveCarbsPerServing * quantity;
    final calculatedProtein = foodDetails.effectiveProteinPerServing * quantity;
    final calculatedFat = foodDetails.effectiveFatPerServing * quantity;
    final calculatedSodium = foodDetails.effectiveSodiumMg * quantity;
    final calculatedFluids = (foodDetails.fluidMlPerServing ?? 0.0) * quantity;

    _logger.debug('Calculated nutritional values',
      data: {
        'food_id': foodId,
        'quantity': quantity,
        'calories': calculatedCalories.round(),
        'carbs': calculatedCarbs.round(),
        'protein': calculatedProtein.round(),
        'fat': calculatedFat.round(),
        'sodium': calculatedSodium.round(),
        'fluids': calculatedFluids.round(),
      },
    );

    return FoodItemData(
      id: foodId,
      name: foodDetails.displayOverride ?? foodDetails.name,
      quantity: displayName,
      imageAddress: foodDetails.imageAddress,
      description: foodDetails.description,
      timing: item['timing'] as String?,
      instructions: foodDetails.instructions,
      displayName: foodDetails.displayName,
      displayNamePlural: foodDetails.displayNamePlural,
      nutritionalInfo: NutritionalInfo(
        calories: calculatedCalories.round(),
        carbs: calculatedCarbs.round(),
        protein: calculatedProtein.round(),
        fat: calculatedFat.round(),
        sodium: calculatedSodium.round(),
        fluids: calculatedFluids,
      ),
    );
  }

  /// Generate proper display name using quantity and food details
  String _generateDisplayName(num quantity, dynamic foodDetails) {
    // Check if there's a display override (for special cases like water+electrolytes)
    if (foodDetails.displayOverride != null && foodDetails.displayOverride!.isNotEmpty) {
      return _formatQuantity(quantity, '', foodDetails.displayOverride!);
    }

    // Use singular vs plural display names from database
    final isPlural = quantity != 1;
    var displayName = isPlural && foodDetails.displayNamePlural?.isNotEmpty == true
        ? foodDetails.displayNamePlural!
        : (foodDetails.displayName?.isNotEmpty == true ? foodDetails.displayName : foodDetails.name);

    final unit = foodDetails.servingUnit ?? '';

    // Check if the displayName is just a unit (like 'g', 'ml', 'oz', etc.)
    // This can happen with user foods where displayName wasn't properly set
    if (_isJustUnit(displayName)) {
      // Use the actual food name instead
      displayName = foodDetails.name;
    }

    return _formatQuantity(quantity, unit, displayName);
  }

  /// Check if a string is just a unit of measurement
  bool _isJustUnit(String str) {
    if (str.isEmpty) return false;

    // Common units that might be mistakenly used as display names
    final units = ['g', 'mg', 'kg', 'ml', 'l', 'oz', 'lb', 'lbs',
                   'tsp', 'tbsp', 'cup', 'cups', 'fl oz', 'packet', 'packets',
                   'serving', 'servings', 'piece', 'pieces'];

    final strLower = str.toLowerCase().trim();
    return units.contains(strLower);
  }

  /// Format quantity with proper number formatting
  String _formatQuantity(num quantity, String unit, String displayName) {
    final quantityStr = quantity == quantity.toInt()
        ? quantity.toInt().toString()
        : quantity.toStringAsFixed(1);

    // If unit is empty, just use quantity + display name
    if (unit.isEmpty) {
      return '$quantityStr $displayName';
    }

    // Check for redundancy using exact word matching to avoid false positives
    // (e.g., "g" should not match "gel" in "Maurten Gel")
    final unitLower = unit.toLowerCase().trim();
    final displayLower = displayName.toLowerCase().trim();

    // Split into words and check for exact word overlap
    final unitWords = unitLower.split(RegExp(r'\s+'));
    final displayWords = displayLower.split(RegExp(r'\s+'));

    // Check if any complete word in unit matches any complete word in display name
    final hasWordOverlap = unitWords.any((unitWord) =>
      displayWords.any((displayWord) => unitWord == displayWord && unitWord.length > 1)
    );

    if (hasWordOverlap) {
      // Unit already contains food name or vice versa
      return '$quantityStr $unit';
    } else {
      // Unit and food name are different, include both
      return '$quantityStr $unit $displayName';
    }
  }
}

/// Provider for FoodDataTransformationService
final foodDataTransformationServiceProvider = Provider<FoodDataTransformationService>((ref) {
  return FoodDataTransformationService(ref);
});
