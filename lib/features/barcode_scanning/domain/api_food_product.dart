/// Represents a food product returned from API lookup
/// This is the domain model for data returned from the Edge Function
class ApiFoodProduct {
  final String barcode;
  final String productName;
  final String? brandName;
  final String? imageUrl;
  final String? servingSize;

  // Nutritional information per 100g
  final double? caloriesPer100g;
  final double? carbohydratesPer100g;
  final double? proteinPer100g;
  final double? fatPer100g;
  final double? sodiumMgPer100g;

  // Per-serving nutrition (when available from API)
  final double? caloriesPerServing;
  final double? carbohydratesPerServing;
  final double? proteinPerServing;
  final double? fatPerServing;
  final double? sodiumMgPerServing;
  final double? servingGrams;

  // Data format indicator
  final String? nutritionDataPer; // "serving" or "100g"

  // Beverage detection fields (for fluid extraction)
  final String? categories; // Product categories from Open Food Facts
  final double? servingQuantity; // serving_quantity from API
  final String? servingQuantityUnit; // serving_quantity_unit from API
  final double? productQuantity; // product_quantity from API (fallback)
  final String? productQuantityUnit; // product_quantity_unit from API (fallback)

  // Source tracking
  final String apiSource; // "open_food_facts", "usda", "manual"
  final double confidenceScore;

  const ApiFoodProduct({
    required this.barcode,
    required this.productName,
    this.brandName,
    this.imageUrl,
    this.servingSize,
    this.caloriesPer100g,
    this.carbohydratesPer100g,
    this.proteinPer100g,
    this.fatPer100g,
    this.sodiumMgPer100g,
    this.caloriesPerServing,
    this.carbohydratesPerServing,
    this.proteinPerServing,
    this.fatPerServing,
    this.sodiumMgPerServing,
    this.servingGrams,
    this.nutritionDataPer,
    this.categories,
    this.servingQuantity,
    this.servingQuantityUnit,
    this.productQuantity,
    this.productQuantityUnit,
    required this.apiSource,
    required this.confidenceScore,
  });

  /// Create from Edge Function response
  factory ApiFoodProduct.fromEdgeFunctionResponse(Map<String, dynamic> data) {
    return ApiFoodProduct(
      barcode: data['barcode'] as String,
      productName: data['product_name'] as String? ?? 'Unknown Product',
      brandName: data['brand_name'] as String?,
      imageUrl: data['image_url'] as String?,
      servingSize: data['serving_size'] as String?,
      caloriesPer100g: _parseDouble(data['calories_per_100g']),
      carbohydratesPer100g: _parseDouble(data['carbohydrates_per_100g']),
      proteinPer100g: _parseDouble(data['protein_per_100g']),
      fatPer100g: _parseDouble(data['fat_per_100g']),
      sodiumMgPer100g: _parseDouble(data['sodium_mg_per_100g']),
      caloriesPerServing: _parseDouble(data['calories_per_serving']),
      carbohydratesPerServing: _parseDouble(data['carbohydrates_per_serving']),
      proteinPerServing: _parseDouble(data['protein_per_serving']),
      fatPerServing: _parseDouble(data['fat_per_serving']),
      sodiumMgPerServing: _parseDouble(data['sodium_mg_per_serving']),
      servingGrams: _parseDouble(data['serving_grams']),
      nutritionDataPer: data['nutrition_data_per'] as String?,
      categories: data['categories'] as String?,
      servingQuantity: _parseDouble(data['serving_quantity']),
      servingQuantityUnit: data['serving_quantity_unit'] as String?,
      productQuantity: _parseDouble(data['product_quantity']),
      productQuantityUnit: data['product_quantity_unit'] as String?,
      apiSource: data['api_source'] as String? ?? 'unknown',
      confidenceScore: _parseDouble(data['confidence_score']) ?? 0.0,
    );
  }

  /// Helper method to safely parse double values
  static double? _parseDouble(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  /// Calculate nutritional values for a specific serving size in grams
  /// Prioritizes per-serving values when available
  NutritionalValues calculateForServing(double servingGrams) {
    print('🧮 DEBUG - calculateForServing:');
    print('  Requested serving: ${servingGrams}g');
    print('  API serving grams: ${this.servingGrams}g');
    print('  Nutrition data per: ${nutritionDataPer ?? "100g (default)"}');

    // If we have per-serving data, prefer it
    if (caloriesPerServing != null) {
      print('  Using direct per-serving values from API');
      print('    Calories: ${caloriesPerServing}');
      print('    Carbs: ${carbohydratesPerServing}');
      print('    Protein: ${proteinPerServing}');
      print('    Fat: ${fatPerServing}');

      // If the serving size matches exactly or we don't have serving_grams, use values directly
      if (this.servingGrams == null || (servingGrams - this.servingGrams!).abs() < 5.0) {
        return NutritionalValues(
          calories: caloriesPerServing?.round(),
          carbohydrates: carbohydratesPerServing,
          protein: proteinPerServing,
          fat: fatPerServing,
          sodiumMg: sodiumMgPerServing?.round(),
        );
      }

      // If serving sizes don't match, scale the per-serving values
      if (this.servingGrams != null && this.servingGrams! > 0) {
        final scaleFactor = servingGrams / this.servingGrams!;
        print('  Scaling per-serving values by factor: $scaleFactor');

        return NutritionalValues(
          calories: caloriesPerServing != null ? (caloriesPerServing! * scaleFactor).round() : null,
          carbohydrates: carbohydratesPerServing != null ? carbohydratesPerServing! * scaleFactor : null,
          protein: proteinPerServing != null ? proteinPerServing! * scaleFactor : null,
          fat: fatPerServing != null ? fatPerServing! * scaleFactor : null,
          sodiumMg: sodiumMgPerServing != null ? (sodiumMgPerServing! * scaleFactor).round() : null,
        );
      }
    }

    // Fallback to per-100g calculation
    final factor = servingGrams / 100.0;
    print('  Using per-100g calculation with factor: $factor');
    print('  Calculation: ${caloriesPer100g} * $factor = ${caloriesPer100g != null ? (caloriesPer100g! * factor) : null}');

    return NutritionalValues(
      calories: caloriesPer100g != null ? (caloriesPer100g! * factor).round() : null,
      carbohydrates: carbohydratesPer100g != null ? carbohydratesPer100g! * factor : null,
      protein: proteinPer100g != null ? proteinPer100g! * factor : null,
      fat: fatPer100g != null ? fatPer100g! * factor : null,
      sodiumMg: sodiumMgPer100g != null ? (sodiumMgPer100g! * factor).round() : null,
    );
  }

  /// Get a display name combining brand and product name
  String get displayName {
    if (brandName != null && brandName!.isNotEmpty) {
      return '$brandName $productName';
    }
    return productName;
  }

  /// Check if this product has sufficient nutritional data for endurance sports
  bool get hasSufficientNutritionalData {
    return caloriesPer100g != null && carbohydratesPer100g != null;
  }

  @override
  String toString() {
    return 'ApiFoodProduct{barcode: $barcode, productName: $productName, brandName: $brandName, apiSource: $apiSource}';
  }
}

/// Nutritional values for a specific serving
class NutritionalValues {
  final int? calories;
  final double? carbohydrates; // grams
  final double? protein; // grams
  final double? fat; // grams
  final int? sodiumMg; // milligrams

  const NutritionalValues({
    this.calories,
    this.carbohydrates,
    this.protein,
    this.fat,
    this.sodiumMg,
  });

  @override
  String toString() {
    return 'NutritionalValues{calories: $calories, carbs: ${carbohydrates}g, protein: ${protein}g, fat: ${fat}g, sodium: ${sodiumMg}mg}';
  }
}