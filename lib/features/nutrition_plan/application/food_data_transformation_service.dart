import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/food_item_data.dart';
import '../data/food_repository.dart';
import '../../../shared/services/logging_service.dart';

/// Service for transforming edge function responses into FoodItemData objects
/// Handles database lookups and display name generation
class FoodDataTransformationService {
  FoodDataTransformationService(this.ref);
  final Ref ref;

  FoodRepository get _foodRepository => ref.read(foodRepositoryProvider);

  /// Transform edge function item response to FoodItemData
  /// Takes raw response with food_id and quantity, looks up details from database
  Future<FoodItemData> transformEdgeFunctionItem(
    Map<String, dynamic> item,
  ) async {
    final foodId = item['food_id'] as String;
    final quantity = item['quantity'] as num;

    AppLogger.instance.debug('Transforming edge function item',
      data: {
        'food_id': foodId,
        'quantity': quantity,
      },
    );

    // Look up food details from database
    final foodDetails = await _foodRepository.getFoodById(foodId);

    if (foodDetails == null) {
      AppLogger.instance.error('Food not found in database',
        context: 'FOOD_TRANSFORMATION',
        data: {
          'food_id': foodId,
          'quantity': quantity,
        },
      );

      // Return fallback data if food not found
      return FoodItemData(
        id: foodId,
        name: 'Unknown Food',
        quantity: _formatQuantity(quantity, '', 'Unknown Food'),
        description: 'Food details not available',
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

    AppLogger.instance.debug('Generated display name',
      data: {
        'food_id': foodId,
        'quantity': quantity,
        'display_name': displayName,
        'display_override': foodDetails.displayOverride,
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

  /// Generate proper display name using quantity and food details
  String _generateDisplayName(num quantity, dynamic foodDetails) {
    // Check if there's a display override (for special cases like water+electrolytes)
    if (foodDetails.displayOverride != null && foodDetails.displayOverride!.isNotEmpty) {
      return _formatQuantity(quantity, '', foodDetails.displayOverride!);
    }

    // Use singular vs plural display names from database
    final isPlural = quantity != 1;
    final displayName = isPlural
        ? (foodDetails.displayNamePlural ?? foodDetails.displayName ?? foodDetails.name)
        : (foodDetails.displayName ?? foodDetails.name);

    final unit = foodDetails.servingUnit ?? '';

    return _formatQuantity(quantity, unit, displayName);
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

    // Check for redundancy to avoid duplication like "1 bagel bagel"
    final unitLower = unit.toLowerCase();
    final displayLower = displayName.toLowerCase();

    if (unitLower.contains(displayLower) || displayLower.contains(unitLower)) {
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