import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:uuid/uuid.dart';
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
      id: const Uuid().v4(), // Generate proper UUID for database
      name: apiProduct.displayName,
      imageAddress: apiProduct.imageUrl,
      description: 'Scanned from barcode ${apiProduct.barcode}',
      instructions: null,

      // Serving information - simplified approach
      servingAmount: 1.0, // Always 1.0 in simplified approach
      displayName: _generateDisplayName(apiProduct, servingGrams),
      displayNamePlural: _generateDisplayNamePlural(apiProduct, servingGrams),
      // Legacy fields for compatibility
      servingUnit: 'servings',
      servingUnitPlural: 'servings',
      servingQualifier: null,
      servingSize: apiProduct.servingSize ?? '${servingGrams.toStringAsFixed(servingGrams == servingGrams.toInt() ? 0 : 1)}g',

      // Nutritional information (per serving)
      carbsPerServing: nutritionalValues.carbohydrates,
      sodiumMg: nutritionalValues.sodiumMg,
      fluidMlPerServing: _extractFluidMlForBeverage(apiProduct),
      caloriesPerServing: nutritionalValues.calories,
      proteinPerServing: nutritionalValues.protein,
      fatPerServing: nutritionalValues.fat,

      // Additional nutrients (not available from APIs)
      caffeineMg: null,
      potassiumMg: null,

      // Product type for imported/scanned foods
      productTypeId: 'cdd6a8f1-750c-4c78-93f7-ab706285ac7b', // "imported" product type

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

  /// Extract fluid content (ml) for beverages using roadmap strategy
  /// Primary: serving_quantity + serving_quantity_unit
  /// Fallback: product_quantity + product_quantity_unit
  /// Detection: Check categories field for "beverage" (case-insensitive)
  double? _extractFluidMlForBeverage(ApiFoodProduct apiProduct) {
    // Check if this is a beverage based on categories
    if (apiProduct.categories?.toLowerCase().contains('beverage') != true) {
      return null; // Not a beverage
    }

    print('🍹 DEBUG - Beverage detected: ${apiProduct.productName}');
    print('  Categories: ${apiProduct.categories}');

    // Primary strategy: Use serving_quantity + serving_quantity_unit
    if (apiProduct.servingQuantity != null &&
        apiProduct.servingQuantityUnit?.toLowerCase() == 'ml') {
      final fluidMl = apiProduct.servingQuantity!;
      print('  Fluid from serving_quantity: ${fluidMl}ml');
      return fluidMl;
    }

    // Fallback strategy: Use product_quantity + product_quantity_unit
    if (apiProduct.productQuantity != null &&
        apiProduct.productQuantityUnit?.toLowerCase() == 'ml') {
      final fluidMl = apiProduct.productQuantity!;
      print('  Fluid from product_quantity (fallback): ${fluidMl}ml');
      return fluidMl;
    }

    print('  No valid ml quantity found for beverage');
    return null;
  }

  /// Generate user-friendly display name
  String _generateDisplayName(ApiFoodProduct apiProduct, double servingGrams) {
    final productName = apiProduct.productName.trim();
    final brandName = apiProduct.brandName?.trim() ?? '';

    // Try to identify product type and reorder for better readability
    final productNameLower = productName.toLowerCase();

    // For gels: "Brand + Product" (e.g., "Maurten Gel 160")
    if (productNameLower.contains('gel')) {
      if (brandName.isNotEmpty && !productName.toLowerCase().startsWith(brandName.toLowerCase())) {
        return '$brandName $productName';
      }
      return productName;
    }

    // For bars: "Brand + Product" (e.g., "PowerBar Energy")
    if (productNameLower.contains('bar')) {
      if (brandName.isNotEmpty && !productName.toLowerCase().startsWith(brandName.toLowerCase())) {
        return '$brandName $productName';
      }
      return productName;
    }

    // For drinks/beverages: "Brand + Product" without serving size
    if (productNameLower.contains('drink') ||
        productNameLower.contains('beverage') ||
        productNameLower.contains('sports')) {
      if (brandName.isNotEmpty && !productName.toLowerCase().startsWith(brandName.toLowerCase())) {
        return '$brandName $productName';
      }
      return productName;
    }

    // For other products: Use product name as-is, add brand if not included
    if (brandName.isNotEmpty && !productName.toLowerCase().contains(brandName.toLowerCase())) {
      return '$brandName $productName';
    }

    return productName;
  }

  /// Generate user-friendly plural display name
  String _generateDisplayNamePlural(ApiFoodProduct apiProduct, double servingGrams) {
    final displayName = _generateDisplayName(apiProduct, servingGrams);
    final displayNameLower = displayName.toLowerCase();

    // Smart pluralization for common product types
    if (displayNameLower.contains('gel') && !displayNameLower.contains('gels')) {
      return displayName.replaceFirst(RegExp(r'\bgel\b', caseSensitive: false), 'Gels');
    }

    if (displayNameLower.contains('bar') && !displayNameLower.contains('bars')) {
      return displayName.replaceFirst(RegExp(r'\bbar\b', caseSensitive: false), 'Bars');
    }

    if (displayNameLower.contains('drink') && !displayNameLower.contains('drinks')) {
      return displayName.replaceFirst(RegExp(r'\bdrink\b', caseSensitive: false), 'Drinks');
    }

    if (displayNameLower.contains('chew') && !displayNameLower.contains('chews')) {
      return displayName.replaceFirst(RegExp(r'\bchew\b', caseSensitive: false), 'Chews');
    }

    // For products that don't match common patterns, just add 's' if doesn't end with 's'
    if (!displayName.toLowerCase().endsWith('s')) {
      return '${displayName}s';
    }

    return displayName;
  }
}

@riverpod
FoodMappingService foodMappingService(FoodMappingServiceRef ref) {
  return FoodMappingService();
}