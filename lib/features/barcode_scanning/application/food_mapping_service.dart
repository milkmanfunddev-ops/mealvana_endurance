import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../nutrition_plan/domain/food.dart';
import '../domain/api_food_product.dart';

part 'food_mapping_service.g.dart';

/// Service for mapping API food products to the app's Food domain model
class FoodMappingService {

  /// Convert an ApiFoodProduct from barcode scanning to the app's Food model
  /// Uses per-serving data when available
  Food mapToFood(ApiFoodProduct apiProduct, {double? assumedServingGrams}) {
    // Prefer the API's serving size if available, otherwise estimate
    final servingGrams = apiProduct.servingGrams ?? assumedServingGrams ?? _estimateServingSize(apiProduct);

    print('🔍 DEBUG - Food Mapping for ${apiProduct.productName}:');
    print('  API serving size string: "${apiProduct.servingSize}"');
    print('  API serving grams: ${apiProduct.servingGrams}g');
    print('  Using serving grams: ${servingGrams}g');

    // Log what data we have
    if (apiProduct.caloriesPerServing != null) {
      print('  Raw API values (per serving):');
      print('    Calories: ${apiProduct.caloriesPerServing}');
      print('    Carbs: ${apiProduct.carbohydratesPerServing}');
      print('    Protein: ${apiProduct.proteinPerServing}');
      print('    Fat: ${apiProduct.fatPerServing}');
    } else {
      print('  Raw API values (per 100g):');
      print('    Calories: ${apiProduct.caloriesPer100g}');
      print('    Carbs: ${apiProduct.carbohydratesPer100g}');
      print('    Protein: ${apiProduct.proteinPer100g}');
      print('    Fat: ${apiProduct.fatPer100g}');
    }

    // Calculate nutritional values for the serving
    final nutritionalValues = apiProduct.calculateForServing(servingGrams);

    print('  Calculated values (per ${servingGrams}g serving):');
    print('    Calories: ${nutritionalValues.calories}');
    print('    Carbs: ${nutritionalValues.carbohydrates}');
    print('    Protein: ${nutritionalValues.protein}');
    print('    Fat: ${nutritionalValues.fat}');

    return Food(
      id: 'barcode_${apiProduct.barcode}',
      name: apiProduct.displayName,
      imageAddress: apiProduct.imageUrl,
      description: 'Scanned from barcode ${apiProduct.barcode}',
      instructions: null,

      // Serving information - simplified approach
      servingAmount: 1.0, // Always 1.0 in simplified approach
      displayName: '${servingGrams.toStringAsFixed(servingGrams == servingGrams.toInt() ? 0 : 1)}g ${apiProduct.productName}',
      displayNamePlural: '${servingGrams.toStringAsFixed(servingGrams == servingGrams.toInt() ? 0 : 1)}g ${apiProduct.productName}',
      // Legacy fields for compatibility
      servingUnit: 'g',
      servingUnitPlural: 'g',
      servingQualifier: null,
      servingSize: apiProduct.servingSize ?? '${servingGrams.toStringAsFixed(servingGrams == servingGrams.toInt() ? 0 : 1)}g',

      // Nutritional information (per serving)
      carbsPerServing: nutritionalValues.carbohydrates,
      sodiumMg: nutritionalValues.sodiumMg,
      fluidMlPerServing: null, // Most scanned products don't provide fluid content
      caloriesPerServing: nutritionalValues.calories,
      proteinPerServing: nutritionalValues.protein,
      fatPerServing: nutritionalValues.fat,

      // Additional nutrients (not available from APIs)
      caffeineMg: null,
      potassiumMg: null,

      // Conservative endurance suitability defaults
      // Users can manually adjust these after adding the food
      beforeRunSuitable: _isLikelyBeforeRunSuitable(apiProduct, nutritionalValues),
      duringRunSuitable: _isLikelyDuringRunSuitable(apiProduct, nutritionalValues),
      runPortable: _isLikelyRunPortable(apiProduct),
      requiresPreparation: false, // Most packaged foods don't require preparation
      aidStationAvailable: false, // Conservative default

      // Conservative serving limits
      maxServingsBefore: 2,
      maxServingsDuring: 1,
    );
  }

  /// Estimate serving size based on product type and available information
  double _estimateServingSize(ApiFoodProduct apiProduct) {
    // Try to extract serving size from product data
    if (apiProduct.servingSize != null) {
      final gramMatch = RegExp(r'(\d+)\s*g', caseSensitive: false)
          .firstMatch(apiProduct.servingSize!);
      if (gramMatch != null) {
        return double.tryParse(gramMatch.group(1)!) ?? 100.0;
      }
    }

    // Use heuristics based on product name/brand for common sports nutrition products
    final productNameLower = apiProduct.productName.toLowerCase();
    final brandLower = apiProduct.brandName?.toLowerCase() ?? '';

    // Energy gels - typically 32-45g
    if (productNameLower.contains('gel') ||
        brandLower.contains('gu') ||
        brandLower.contains('maurten')) {
      return 35.0;
    }

    // Energy bars - typically 40-80g
    if (productNameLower.contains('bar') ||
        productNameLower.contains('energy')) {
      return 60.0;
    }

    // Sports drinks - assume per 100ml serving
    if (productNameLower.contains('drink') ||
        productNameLower.contains('beverage') ||
        productNameLower.contains('sports')) {
      return 100.0;
    }

    // Energy chews - typically 50-60g package
    if (productNameLower.contains('chew') ||
        productNameLower.contains('gummy')) {
      return 50.0;
    }

    // Default to 100g for most products
    return 100.0;
  }

  /// Determine if a product is likely suitable before runs
  bool _isLikelyBeforeRunSuitable(ApiFoodProduct apiProduct, NutritionalValues nutrition) {
    // High carb, low fat foods are generally good before runs
    if (nutrition.carbohydrates != null && nutrition.fat != null) {
      final carbPercent = (nutrition.carbohydrates! * 4) / (nutrition.calories ?? 1) * 100;
      final fatPercent = (nutrition.fat! * 9) / (nutrition.calories ?? 1) * 100;

      return carbPercent > 60 && fatPercent < 20;
    }

    // If no nutritional data, be conservative
    return false;
  }

  /// Determine if a product is likely suitable during runs
  bool _isLikelyDuringRunSuitable(ApiFoodProduct apiProduct, NutritionalValues nutrition) {
    final productNameLower = apiProduct.productName.toLowerCase();

    // Sports nutrition products are likely suitable
    if (productNameLower.contains('gel') ||
        productNameLower.contains('sports') ||
        productNameLower.contains('energy') ||
        productNameLower.contains('electrolyte')) {
      return true;
    }

    // High carb, low fat, easily digestible
    if (nutrition.carbohydrates != null && nutrition.fat != null) {
      final carbPercent = (nutrition.carbohydrates! * 4) / (nutrition.calories ?? 1) * 100;
      final fatPercent = (nutrition.fat! * 9) / (nutrition.calories ?? 1) * 100;

      return carbPercent > 70 && fatPercent < 10;
    }

    // Conservative default
    return false;
  }

  /// Determine if a product is likely portable for runs
  bool _isLikelyRunPortable(ApiFoodProduct apiProduct) {
    final productNameLower = apiProduct.productName.toLowerCase();

    // Common portable formats
    return productNameLower.contains('gel') ||
           productNameLower.contains('bar') ||
           productNameLower.contains('chew') ||
           productNameLower.contains('tablet') ||
           productNameLower.contains('gummy');
  }
}

@riverpod
FoodMappingService foodMappingService(FoodMappingServiceRef ref) {
  return FoodMappingService();
}