import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:uuid/uuid.dart';
import '../../nutrition_plan/domain/food.dart';
import '../../nutrition_plan/domain/food_item.dart';
import '../../nutrition_plan/data/food_repository.dart';
import '../domain/api_food_product.dart';

part 'food_mapping_service.g.dart';

/// Service for mapping API food products to the app's Food domain model
/// Uses FoodRepository to check for existing foods and get proper metadata
class FoodMappingService {
  FoodMappingService(this._foodRepository);

  final FoodRepository _foodRepository;

  /// Convert an ApiFoodProduct from barcode scanning to the app's Food model
  /// Checks database for existing food data and uses proper categories
  Future<Food> mapToFood(ApiFoodProduct apiProduct, {double? assumedServingGrams}) async {
    // First check if we already have this food by barcode
    final barcode = apiProduct.barcode;
    if (barcode.isNotEmpty) {
      final existingFood = await _foodRepository.getFoodByBarcode(barcode);
      if (existingFood != null) {
        // We already have this food with proper display names and categories
        return _convertFoodItemToFood(existingFood, apiProduct);
      }
    }

    // Check if we have it by name in the database
    final existingByName = await _foodRepository.getFoodByName(apiProduct.productName);

    // Use API's serving size if available, otherwise use default
    final servingGrams = apiProduct.servingGrams ?? assumedServingGrams ?? 100.0;

    // Calculate nutritional values for the serving
    final nutritionalValues = apiProduct.calculateForServing(servingGrams);

    return Food(
      id: const Uuid().v4(), // Generate proper UUID for database
      name: apiProduct.displayName,
      imageAddress: apiProduct.imageUrl,
      description: 'Scanned from barcode ${apiProduct.barcode}',
      instructions: null,

      // Serving information - use database values if available
      servingAmount: 1.0, // Always 1.0 in simplified approach
      displayName: existingByName?.displayName ?? apiProduct.displayName,
      displayNamePlural: existingByName?.displayNamePlural ?? '${apiProduct.displayName}s',
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

      // Product type - use from existing food or default to the "import" enum code
      productTypeId: existingByName?.productTypeId ?? 'import',

      // Suitability based on database categories if we found the food
      beforeRunSuitable: await _getBeforeRunSuitability(existingByName),
      duringRunSuitable: await _getDuringRunSuitability(existingByName),
      runPortable: false, // Not in our schema - always false
      requiresPreparation: false, // Most packaged foods don't require preparation
      aidStationAvailable: false, // Conservative default

      // Use existing serving limits if available
      maxServingsBefore: existingByName?.maxServingsBefore ?? 2,
      maxServingsDuring: existingByName?.maxServingsDuring ?? 1,
    );
  }

  /// Get before run suitability from database categories
  Future<bool> _getBeforeRunSuitability(FoodItem? existingFood) async {
    if (existingFood == null) return false;

    final categories = await _foodRepository.getFoodCategories(existingFood.id);
    return categories.contains(1); // category_id = 1 for before_run
  }

  /// Get during run suitability from database categories
  Future<bool> _getDuringRunSuitability(FoodItem? existingFood) async {
    if (existingFood == null) return false;

    final categories = await _foodRepository.getFoodCategories(existingFood.id);
    return categories.contains(2); // category_id = 2 for during_run
  }

  /// Convert FoodItem from repository to Food domain model
  /// Merges existing database data with fresh nutritional data from API
  Food _convertFoodItemToFood(FoodItem existingFood, ApiFoodProduct apiProduct) {
    // Use fresh nutritional data from API if available
    final servingGrams = apiProduct.servingGrams ?? 100.0;
    final nutritionalValues = apiProduct.calculateForServing(servingGrams);

    return Food(
      id: const Uuid().v4(),
      name: existingFood.name,
      imageAddress: existingFood.imageAddress,
      description: 'Updated from barcode ${apiProduct.barcode}',
      instructions: null,

      // Use database display names
      displayName: existingFood.displayName ?? apiProduct.displayName,
      displayNamePlural: existingFood.displayNamePlural ?? '${apiProduct.displayName}s',

      // Serving information
      servingAmount: 1.0,
      servingUnit: 'servings',
      servingUnitPlural: 'servings',
      servingQualifier: null,
      servingSize: apiProduct.servingSize ?? '${servingGrams.toStringAsFixed(0)}g',

      // Use fresh nutritional data from API
      carbsPerServing: nutritionalValues.carbohydrates,
      sodiumMg: nutritionalValues.sodiumMg,
      fluidMlPerServing: _extractFluidMlForBeverage(apiProduct),
      caloriesPerServing: nutritionalValues.calories,
      proteinPerServing: nutritionalValues.protein,
      fatPerServing: nutritionalValues.fat,
      caffeineMg: existingFood.caffeineMg,
      potassiumMg: existingFood.potassiumMg,

      // Use existing product type and suitability from database
      productTypeId: existingFood.productTypeId ?? 'import',
      beforeRunSuitable: existingFood.beforeRunSuitable,
      duringRunSuitable: existingFood.duringRunSuitable,
      runPortable: false, // Not in our schema
      requiresPreparation: existingFood.requiresPreparation,
      aidStationAvailable: existingFood.aidStationAvailable,

      // Use existing serving limits
      maxServingsBefore: existingFood.maxServingsBefore ?? 2,
      maxServingsDuring: existingFood.maxServingsDuring ?? 1,
    );
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

    // Primary strategy: Use serving_quantity + serving_quantity_unit
    if (apiProduct.servingQuantity != null &&
        apiProduct.servingQuantityUnit?.toLowerCase() == 'ml') {
      return apiProduct.servingQuantity!;
    }

    // Fallback strategy: Use product_quantity + product_quantity_unit
    if (apiProduct.productQuantity != null &&
        apiProduct.productQuantityUnit?.toLowerCase() == 'ml') {
      return apiProduct.productQuantity!;
    }

    return null;
  }

}

@riverpod
FoodMappingService foodMappingService(Ref ref) {
  final foodRepository = ref.watch(foodRepositoryProvider);
  return FoodMappingService(foodRepository);
}
