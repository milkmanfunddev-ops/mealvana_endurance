import 'dart:convert';

import '../../../shared/database/app_database.dart';
import 'food_item_data.dart';
import 'solver_types.dart';

/// Unified food model that normalizes both [TemplateFoodEntry] and [UserFood]
/// into a single type for the client-side greedy solver.
class SolverFood {
  const SolverFood({
    required this.id,
    required this.name,
    this.displayName,
    this.displayNamePlural,
    this.imageAddress,
    this.description,
    this.servingSize,
    this.servingUnit,
    required this.carbsG,
    required this.proteinG,
    required this.fatG,
    required this.sodiumMg,
    required this.fluidMl,
    required this.calories,
    required this.maxServings,
    required this.preferenceScore,
    this.isElectrolyte = false,
    this.isLiquid = false,
    this.isEssential = false,
    this.isUserFood = false,
    this.isIndivisible = false,
    this.productType,
    this.categories = const [],
  });

  final String id;
  final String name;
  final String? displayName;
  final String? displayNamePlural;
  final String? imageAddress;
  final String? description;
  final String? servingSize;
  final String? servingUnit;

  // Per-serving nutrition
  final double carbsG;
  final double proteinG;
  final double fatG;
  final double sodiumMg;
  final double fluidMl;
  final int calories;

  // Solver metadata
  final int maxServings;
  final int preferenceScore;
  final bool isElectrolyte;
  final bool isLiquid;
  final bool isEssential;
  final bool isUserFood;
  final bool isIndivisible;
  final String? productType;
  final List<String> categories;

  /// Create from a Drift [TemplateFoodEntry].
  ///
  /// [phase] determines which maxServings column to use.
  /// [preferenceScore] is pre-computed from the food preferences map.
  factory SolverFood.fromTemplateFoodEntry(
    TemplateFoodEntry e, {
    required String phase,
    required int preferenceScore,
  }) {
    final maxServ = switch (phase) {
      'before' => e.maxServingsBefore,
      'during' => e.maxServingsDuring,
      'after' => e.maxServingsAfter,
      _ => e.maxServingsBefore,
    };

    return SolverFood(
      id: e.id,
      name: e.name,
      displayName: e.displayName,
      displayNamePlural: e.displayNamePlural,
      imageAddress: e.imageAddress,
      description: e.description,
      servingSize: e.servingSize,
      servingUnit: e.servingUnit,
      carbsG: e.carbsG,
      proteinG: e.proteinG,
      fatG: e.fatG,
      sodiumMg: e.sodiumMg,
      fluidMl: e.fluidMl ?? 0,
      calories: e.calories,
      maxServings: maxServ,
      preferenceScore: e.isEssential ? kPrefScoreEssential : preferenceScore,
      isElectrolyte: e.isElectrolyte,
      isLiquid: e.isLiquid,
      isEssential: e.isEssential,
      isIndivisible: _isIndivisibleProduct(e.productType),
      productType: e.productType,
      categories: _parseJsonList(e.categories),
    );
  }

  /// Create from a Drift [UserFood].
  factory SolverFood.fromUserFood(
    UserFood f, {
    required int preferenceScore,
  }) {
    return SolverFood(
      id: f.id,
      name: f.name,
      displayName: f.displayName,
      displayNamePlural: f.displayNamePlural,
      imageAddress: f.imageAddress,
      description: f.description,
      servingSize: f.servingSize,
      servingUnit: f.servingUnit,
      carbsG: f.carbsPerServing ?? 0,
      proteinG: f.proteinPerServing ?? 0,
      fatG: f.fatPerServing ?? 0,
      sodiumMg: (f.sodiumMg ?? 0).toDouble(),
      fluidMl: f.fluidMlPerServing ?? 0,
      calories: f.caloriesPerServing ?? 0,
      maxServings: 4,
      preferenceScore: preferenceScore,
      isElectrolyte: f.isElectrolyte,
      isLiquid: f.productTypeId == 'sports_drink' || f.productTypeId == 'beverage',
      isUserFood: true,
      isIndivisible: _isIndivisibleProduct(f.productTypeId),
      productType: f.productTypeId,
      categories: _parseJsonList(f.categories),
    );
  }

  /// Convert a solver selection into a [FoodItemData] for the UI.
  FoodItemData toFoodItemData(double quantity) {
    final rawQty = formatQuantity(quantity);
    final quantityStr = FoodItemData.buildDisplayQuantity(
      rawQty: rawQty,
      servingUnit: servingUnit,
      displayName: displayName ?? name,
      displayNamePlural: displayNamePlural,
    );

    final timingCat = TimingCategory.fromFoodProperties(
      isLiquid: isLiquid,
      productType: productType ?? 'real_food',
      isElectrolyte: isElectrolyte,
      carbsPerServing: carbsG,
    );

    return FoodItemData(
      id: id,
      name: displayName ?? name,
      quantity: quantityStr,
      imageAddress: imageAddress,
      description: description,
      nutritionalInfo: NutritionalInfo(
        calories: (calories * quantity).round(),
        carbs: (carbsG * quantity).round(),
        protein: (proteinG * quantity).round(),
        fat: (fatG * quantity).round(),
        sodium: (sodiumMg * quantity).round(),
        fluids: fluidMl * quantity,
      ),
      displayName: displayName,
      displayNamePlural: displayNamePlural,
      servingSize: servingSize,
      isDrink: isLiquid,
      isIndivisible: isIndivisible,
      timingCategory: timingCat,
    );
  }

  /// Format quantity for display: indivisible → whole, else nearest 0.5
  static String formatQuantity(double qty) {
    if ((qty - qty.roundToDouble()).abs() < 0.01) {
      return qty.round().toString();
    }
    // Round to nearest 0.5
    final rounded = (qty * 2).round() / 2;
    if (rounded == rounded.roundToDouble()) {
      return rounded.round().toString();
    }
    return rounded.toStringAsFixed(1);
  }

  /// Whether a product type is indivisible (sealed packets, tablets, etc.)
  static bool _isIndivisibleProduct(String? productType) {
    return productType == 'gel' ||
        productType == 'chew' ||
        productType == 'supplement' ||
        productType == 'bar';
  }

  /// Parse a JSON array string into a list of strings.
  static List<String> _parseJsonList(String? jsonStr) {
    if (jsonStr == null || jsonStr.isEmpty) return [];
    try {
      final decoded = jsonDecode(jsonStr);
      if (decoded is List) {
        return decoded.cast<String>();
      }
    } catch (_) {}
    return [];
  }
}
