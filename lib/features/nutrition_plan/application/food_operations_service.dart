import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:uuid/uuid.dart';
import '../domain/food_item_data.dart';
import '../../../shared/utils/food_display_utils.dart' as food_utils;

part 'food_operations_service.g.dart';

/// Service for food-related operations on nutrition plans.
///
/// Handles:
/// - Creating FoodItemData from food objects
/// - Quantity normalization and rounding
/// - Quantity label building
/// - Liquid/electrolyte food detection
@riverpod
FoodOperationsService foodOperationsService(Ref ref) {
  return FoodOperationsService();
}

class FoodOperationsService {
  /// Create a FoodItemData from a food object with optional custom amount
  FoodItemData createFoodItemData(dynamic food, {double? customAmount}) {
    final multiplier = customAmount ?? food.servingAmount ?? 1.0;

    // Derive timing category from product type for proper by-hour placement
    final String productType = (food.productTypeId as String?) ?? 'real_food';
    final isLiquid = _isLikelyLiquidFood(food, productType);
    final isElectrolyte = _isLikelyElectrolyteFood(food, productType);
    final timingCategory = TimingCategory.fromFoodProperties(
      isLiquid: isLiquid,
      productType: productType,
      isElectrolyte: isElectrolyte,
      carbsPerServing: (food.carbsPerServing as num?)?.toDouble() ?? 0,
    );
    final isDrink =
        timingCategory == TimingCategory.sipThroughout ||
        timingCategory == TimingCategory.fuelDrink;

    return normalizeFoodQuantity(
      FoodItemData(
        id: const Uuid().v4(),
        name: food.name,
        quantity: food.generateQuantityDisplay(customAmount: customAmount),
        imageAddress: food.imageAddress,
        description: food.description,
        instructions: food.instructions,
        displayName: food.displayName,
        displayNamePlural: food.displayNamePlural,
        isIndivisible: isElectrolyte || productType == 'supplement',
        isDrink: isDrink,
        timingCategory: timingCategory,
        nutritionalInfo: NutritionalInfo(
          calories: ((food.caloriesPerServing ?? 0) * multiplier).toInt(),
          carbs: ((food.carbsPerServing ?? 0) * multiplier).toInt(),
          protein: ((food.proteinPerServing ?? 0) * multiplier).toInt(),
          fat: ((food.fatPerServing ?? 0) * multiplier).toInt(),
          sodium: ((food.sodiumMg ?? 0) * multiplier).toInt(),
          fluids: ((food.fluidMlPerServing ?? 0) * multiplier),
        ),
      ),
    );
  }

  /// Normalize food quantity to friendly increments (halves, thirds, or whole numbers)
  FoodItemData normalizeFoodQuantity(FoodItemData food) {
    final currentQuantity = food_utils.parseLeadingQuantity(food.quantity);
    if (currentQuantity == null) return food;

    final normalizedQuantity = roundFriendlyQuantity(
      currentQuantity,
      isIndivisible: food.isIndivisible,
    );
    if ((normalizedQuantity - currentQuantity).abs() < 0.01) return food;

    final newLabel = buildQuantityLabel(food, normalizedQuantity);
    final scaleFactor = currentQuantity > 0
        ? normalizedQuantity / currentQuantity
        : 1.0;
    final info = food.nutritionalInfo;

    return FoodItemData(
      id: food.id,
      name: food.name,
      quantity: newLabel,
      imageAddress: food.imageAddress,
      description: food.description,
      timing: food.timing,
      nutritionalInfo: info != null
          ? NutritionalInfo(
              calories: info.calories != null
                  ? (info.calories! * scaleFactor).round()
                  : null,
              carbs: info.carbs != null
                  ? (info.carbs! * scaleFactor).round()
                  : null,
              protein: info.protein != null
                  ? (info.protein! * scaleFactor).round()
                  : null,
              fat: info.fat != null ? (info.fat! * scaleFactor).round() : null,
              sodium: info.sodium != null
                  ? (info.sodium! * scaleFactor).round()
                  : null,
              fluids: info.fluids != null ? info.fluids! * scaleFactor : null,
            )
          : null,
      instructions: food.instructions,
      displayName: food.displayName,
      displayNamePlural: food.displayNamePlural,
      displayOverride: food.displayOverride,
      servingSize: food.servingSize,
      isDrink: food.isDrink,
      isIndivisible: food.isIndivisible,
      templateId: food.templateId,
      origin: food.origin,
      scaleMultiplier: food.scaleMultiplier,
      timingCategory: food.timingCategory,
    );
  }

  /// Round quantity to friendly increments based on divisibility.
  ///
  /// For indivisible items (electrolytes, supplements), rounds to whole numbers.
  /// For divisible items, rounds to halves or thirds, whichever is closer.
  double roundFriendlyQuantity(double value, {required bool isIndivisible}) {
    if (value <= 0) return isIndivisible ? 1.0 : 0.5;
    if (isIndivisible) return value.round().toDouble();

    final half = (value * 2).round() / 2;
    final third = (value * 3).round() / 3;
    final halfDiff = (value - half).abs();
    final thirdDiff = (value - third).abs();
    final rounded = thirdDiff + 0.08 < halfDiff ? third : half;
    return (rounded * 100).round() / 100;
  }

  /// Build a user-friendly quantity label for display.
  ///
  /// Examples:
  /// - "2 Bananas"
  /// - "1.5 cups Oatmeal"
  /// - "1 packet Tailwind"
  String buildQuantityLabel(FoodItemData item, double quantity) {
    final qtyStr = food_utils.formatQuantity(quantity);

    // Prefer the existing quantity tail if it already contains unit info
    // (e.g. "2 cups Oatmeal" → tail = "cups Oatmeal").
    final existingTailMatch = RegExp(
      r'^[\d.]+\s*(.*)$',
    ).firstMatch(item.quantity.trim());
    final existingTail = existingTailMatch?.group(1)?.trim();

    // If the existing tail has multiple words (unit + name), preserve it
    // since enrichment already built the proper "unit foodName" string.
    if (existingTail != null &&
        existingTail.isNotEmpty &&
        existingTail.contains(' ')) {
      return '$qtyStr ${food_utils.stripParenthetical(existingTail)}'.trim();
    }

    String label;
    if (quantity != 1 && item.displayNamePlural?.isNotEmpty == true) {
      label = food_utils.stripParenthetical(item.displayNamePlural!);
    } else if (item.displayName?.isNotEmpty == true) {
      label = food_utils.stripParenthetical(item.displayName!);
    } else if (existingTail != null && existingTail.isNotEmpty) {
      label = food_utils.stripParenthetical(existingTail);
    } else {
      label = food_utils.stripParenthetical(item.name);
    }

    if (quantity != 1 &&
        item.displayNamePlural?.isEmpty != false &&
        !label.contains(' ') &&
        !label.contains('+') &&
        !label.toLowerCase().endsWith('s')) {
      label = '${label}s';
    }

    return '$qtyStr $label'.trim();
  }

  /// Check if a food is likely a liquid based on product type and metadata.
  bool _isLikelyLiquidFood(dynamic food, String productType) {
    final normalizedType = productType.toLowerCase();
    if (normalizedType == 'sports_drink' || normalizedType == 'beverage') {
      return true;
    }

    final fluidMl = (food.fluidMlPerServing as num?)?.toDouble() ?? 0;
    if (fluidMl > 0) return true;

    final searchable = [
      food.name,
      food.displayName,
      food.description,
    ].whereType<String>().join(' ').toLowerCase();
    return searchable.contains('drink') ||
        searchable.contains('water') ||
        searchable.contains('juice') ||
        searchable.contains('smoothie') ||
        searchable.contains('shake');
  }

  /// Check if a food is likely an electrolyte supplement.
  bool _isLikelyElectrolyteFood(dynamic food, String productType) {
    if (productType.toLowerCase() == 'supplement') return true;
    final searchable = [
      food.name,
      food.displayName,
      food.description,
    ].whereType<String>().join(' ').toLowerCase();
    return searchable.contains('electrolyte') ||
        searchable.contains('liquid iv') ||
        searchable.contains('salt') ||
        searchable.contains('sodium') ||
        searchable.contains('pickle juice');
  }
}
