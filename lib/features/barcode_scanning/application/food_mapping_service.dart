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
  Future<Food> mapToFood(
    ApiFoodProduct apiProduct, {
    double? assumedServingGrams,
  }) async {
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
    final existingByName = await _foodRepository.getFoodByName(
      apiProduct.productName,
    );

    final basis = _servingBasis(
      apiProduct,
      assumedServingGrams: assumedServingGrams,
    );
    final nutritionalValues = basis.values;

    return Food(
      id: const Uuid().v4(), // Generate proper UUID for database
      name: apiProduct.displayName,
      imageAddress: apiProduct.imageUrl,
      description: 'Scanned from barcode ${apiProduct.barcode}',
      instructions: null,

      // Serving information - use database values if available
      servingAmount: 1.0, // Always 1.0 in simplified approach
      displayName: existingByName?.displayName ?? apiProduct.displayName,
      displayNamePlural:
          existingByName?.displayNamePlural ?? '${apiProduct.displayName}s',
      // Legacy fields for compatibility
      servingUnit: 'servings',
      servingUnitPlural: 'servings',
      servingQualifier: null,
      servingSize: basis.label,

      // Nutritional information (per serving)
      carbsPerServing: nutritionalValues.carbohydrates,
      sodiumMg: nutritionalValues.sodiumMg,
      fluidMlPerServing: apiProduct.fluidMlPerServing,
      caloriesPerServing: nutritionalValues.calories,
      proteinPerServing: nutritionalValues.protein,
      fatPerServing: nutritionalValues.fat,

      // Additional nutrients (not available from APIs)
      caffeineMg: null,
      potassiumMg: null,

      // Product type - use from existing food, then OFF-detected type, then 'import'
      productTypeId:
          existingByName?.productTypeId ??
          apiProduct.suggestedProductType ??
          'import',

      // Suitability based on database categories if we found the food
      beforeRunSuitable: await _getBeforeRunSuitability(existingByName),
      duringRunSuitable: await _getDuringRunSuitability(existingByName),
      runPortable: false, // Not in our schema - always false
      requiresPreparation:
          false, // Most packaged foods don't require preparation
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
    // getFoodCategories returns category strings ("before_run"/"during_run"/
    // "after_run"), not ids — comparing against ints always returned false and
    // silently disabled before-run suitability for every known food.
    return categories.contains('before_run');
  }

  /// Get during run suitability from database categories
  Future<bool> _getDuringRunSuitability(FoodItem? existingFood) async {
    if (existingFood == null) return false;

    final categories = await _foodRepository.getFoodCategories(existingFood.id);
    // See _getBeforeRunSuitability: categories are strings, not ids.
    return categories.contains('during_run');
  }

  /// Convert FoodItem from repository to Food domain model
  /// Merges existing database data with fresh nutritional data from API
  Food _convertFoodItemToFood(
    FoodItem existingFood,
    ApiFoodProduct apiProduct,
  ) {
    // Use fresh nutritional data from API if available
    final basis = _servingBasis(apiProduct);
    final nutritionalValues = basis.values;

    return Food(
      id: const Uuid().v4(),
      name: existingFood.name,
      imageAddress: existingFood.imageAddress,
      description: 'Updated from barcode ${apiProduct.barcode}',
      instructions: null,

      // Use database display names
      displayName: existingFood.displayName ?? apiProduct.displayName,
      displayNamePlural:
          existingFood.displayNamePlural ?? '${apiProduct.displayName}s',

      // Serving information
      servingAmount: 1.0,
      servingUnit: 'servings',
      servingUnitPlural: 'servings',
      servingQualifier: null,
      servingSize: basis.label,

      // Use fresh nutritional data from API
      carbsPerServing: nutritionalValues.carbohydrates,
      sodiumMg: nutritionalValues.sodiumMg,
      fluidMlPerServing: apiProduct.fluidMlPerServing,
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
}

/// Grams in a label serving text: "15 g", "1 portion (37 g)", "250ml".
final RegExp _servingGramsPattern = RegExp(
  r'(\d+(?:[.,]\d+)?)\s*(g|ml)\b',
  caseSensitive: false,
);

/// The serving a mapped [Food] counts as "1 serving", and its values.
///
/// Testing-wave 68-011: a product cached with per-100 g values and no
/// `serving_grams` (Nutella, 3017620422003) was shown as "1 serving" with the
/// per-100 g numbers (539 kcal), because the old fallback was 100 g and the
/// label was the product's own serving text ("15 g"). Values and label now
/// always describe the same amount:
/// a. grams known (declared `serving_grams`, a gram/ml `serving_quantity`,
///    grams in the serving text, or [assumedServingGrams]): values for those
///    grams; label the serving text when it names them, else "N g" (N the grams);
/// b. no grams but per-serving values: those values, label the serving text;
/// c. neither: per-100 g values, label "100 g".
_ServingBasis _servingBasis(
  ApiFoodProduct product, {
  double? assumedServingGrams,
}) {
  final textGrams = _gramsInServingText(product.servingSize);
  final quantityUnit = product.servingQuantityUnit?.trim().toLowerCase();
  final quantityIsMass =
      quantityUnit == null || quantityUnit == 'g' || quantityUnit == 'ml';

  double? grams;
  if (product.servingGrams != null && product.servingGrams! > 0) {
    grams = product.servingGrams;
  } else if (product.servingQuantity != null &&
      product.servingQuantity! > 0 &&
      quantityIsMass) {
    grams = product.servingQuantity;
  } else if (textGrams != null) {
    grams = textGrams;
  } else if (assumedServingGrams != null && assumedServingGrams > 0) {
    grams = assumedServingGrams;
  }

  if (grams != null) {
    final textNamesGrams = textGrams != null && (textGrams - grams).abs() < 0.5;
    return _ServingBasis(
      values: product.calculateForServing(grams),
      label: textNamesGrams ? product.servingSize! : _gramsLabel(grams),
    );
  }

  if (product.caloriesPerServing != null) {
    return _ServingBasis(
      values: NutritionalValues(
        calories: product.caloriesPerServing?.round(),
        carbohydrates: product.carbohydratesPerServing,
        protein: product.proteinPerServing,
        fat: product.fatPerServing,
        sodiumMg: product.sodiumMgPerServing?.round(),
      ),
      label: product.servingSize,
    );
  }

  return _ServingBasis(
    values: product.calculateForServing(100.0),
    label: '100 g',
  );
}

double? _gramsInServingText(String? servingSize) {
  if (servingSize == null) return null;
  final match = _servingGramsPattern.firstMatch(servingSize);
  if (match == null) return null;
  final grams = double.tryParse(match.group(1)!.replaceAll(',', '.'));
  return (grams != null && grams > 0) ? grams : null;
}

String _gramsLabel(double grams) =>
    '${grams == grams.roundToDouble() ? grams.toStringAsFixed(0) : grams.toStringAsFixed(1)} g';

class _ServingBasis {
  const _ServingBasis({required this.values, required this.label});

  final NutritionalValues values;

  /// What "1 serving" is, for [Food.servingSize]. Null only when the source
  /// declared per-serving values without saying what the serving is.
  final String? label;
}

@riverpod
FoodMappingService foodMappingService(Ref ref) {
  final foodRepository = ref.watch(foodRepositoryProvider);
  return FoodMappingService(foodRepository);
}
