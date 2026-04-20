import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../features/nutrition_plan/domain/food.dart';
import '../../../features/barcode_scanning/application/open_food_facts_search_service.dart';
import '../../../features/barcode_scanning/application/catalog_search_service.dart';
import '../../../features/barcode_scanning/application/product_detail_service.dart';
import '../../../features/barcode_scanning/application/food_mapping_service.dart';
import '../app_external_deps.dart';
import '../logging_service.dart';
import 'user_food_crud_service.dart';

/// Provider for SharedFoodSearchService
final sharedFoodSearchServiceProvider = Provider<SharedFoodSearchService>((ref) {
  final openFoodFactsService = ref.read(openFoodFactsSearchServiceProvider);
  final catalogSearchService = ref.read(catalogSearchServiceProvider);
  final productDetailService = ref.read(productDetailServiceProvider);
  final foodMappingService = ref.read(foodMappingServiceProvider);
  final userFoodService = ref.read(userFoodCrudServiceProvider);
  final logger = ref.read(appExternalDepsProvider).logger;
  return SharedFoodSearchService(
    openFoodFactsService,
    catalogSearchService,
    productDetailService,
    foodMappingService,
    userFoodService,
    logger,
  );
});

/// Shared service for food search functionality (catalog + Open Food Facts)
/// Used by both food preferences and swap/add food screens
class SharedFoodSearchService {
  SharedFoodSearchService(
    this._openFoodFactsService,
    this._catalogSearchService,
    this._productDetailService,
    this._foodMappingService,
    this._userFoodService,
    this._logger,
  );

  final OpenFoodFactsSearchService _openFoodFactsService;
  final CatalogSearchService _catalogSearchService;
  final ProductDetailService _productDetailService;
  final FoodMappingService _foodMappingService;
  final UserFoodCrudService _userFoodService;
  final AppLogger _logger;

  /// Search Open Food Facts for products
  Future<List<FoodSearchResult>> searchProducts(String query) async {
    try {      final results = await _openFoodFactsService.searchProducts(query);      return results;
    } on SearchException catch (e) {
      _logger.error('Search failed with SearchException',
        context: 'SharedFoodSearchService',
        data: {'query': query},
        error: e,
      );
      rethrow;
    } catch (e) {
      _logger.error('Search failed with unexpected error',
        context: 'SharedFoodSearchService',
        data: {'query': query},
        error: e,
      );
      throw SearchException('Search failed. Please try again.');
    }
  }

  /// Handle adding a search result to user foods
  /// Returns the created Food object if successful, null if failed
  Future<Food?> addSearchResultToUserFoods(
    FoodSearchResult result,
    String deviceId, {
    List<String>? categories,
  }) async {
    try {
      if (!result.hasValidId) {
        _logger.warning('Invalid search result ID',
          context: 'SharedFoodSearchService',
          data: {'result': result.toString()},
        );
        return null;
      }      // Get product details from Open Food Facts
      final apiProduct = await _productDetailService.getProductDetails(
        openFoodFactsId: result.id,
      );

      if (apiProduct == null) {
        _logger.warning('Failed to get product details',
          context: 'SharedFoodSearchService',
          data: {'productId': result.id},
        );
        return null;
      }

      // Map API product to Food
      final food = await _foodMappingService.mapToFood(apiProduct);

      // Assign all categories to user-imported foods so they're available in all contexts
      // Categories: 1=before_run, 2=during_run, 3=after_run
      final categoryIds = [1, 2, 3];

      // Save to user foods
      await _userFoodService.saveUserFood(food, categoryIds);      return food;
    } catch (e) {
      _logger.error('Error adding search result to user foods',
        context: 'SharedFoodSearchService',
        data: {'productId': result.id, 'deviceId': deviceId},
        error: e,
      );
      return null;
    }
  }

  /// Search the product catalog (The Feed)
  /// Returns empty list on failure (silent fallback).
  Future<List<CatalogSearchResult>> searchCatalog(String query) async {
    return _catalogSearchService.searchCatalog(query);
  }

  /// Map a Feed product type string to the app's product_type enum value.
  /// Feed uses categories like "Gels", "Bars", "Hydration", etc.
  static String _mapCatalogProductType(String? feedType) {
    if (feedType == null) return 'import';
    switch (feedType.toLowerCase()) {
      case 'gels':
        return 'gel';
      case 'bars':
      case 'energy bars':
        return 'bar';
      case 'hydration':
      case 'electrolytes':
      case 'drink mix':
      case 'drink mixes':
        return 'drink_mix';
      case 'chews':
      case 'chews & gummies':
        return 'chew';
      case 'waffles':
        return 'waffle';
      case 'protein':
      case 'recovery':
      case 'protein bars':
        return 'protein_recovery';
      case 'snacks':
        return 'solid_carb_snacks';
      case 'meal replacement':
        return 'real_food';
      default:
        return 'import';
    }
  }

  /// Add a catalog search result to user foods (auto-import with nutrition).
  /// Returns the created Food object if successful, null if failed.
  Future<Food?> addCatalogResultToUserFoods(
    CatalogSearchResult result,
    String userId,
  ) async {
    try {
      final foodId = const Uuid().v4();

      final food = Food(
        id: foodId,
        name: result.displayName,
        displayName: result.displayName,
        displayNamePlural: '${result.displayName}s',
        imageAddress: result.imageUrl,
        servingSize: result.servingSize,
        servingAmount: 1.0,
        servingUnit: 'serving',
        caloriesPerServing: result.caloriesPerServing,
        carbsPerServing: result.carbsG,
        proteinPerServing: result.proteinG,
        fatPerServing: result.fatG,
        sodiumMg: result.sodiumMg,
        caffeineMg: result.caffeineMg,
        productTypeId: result.productTypeId ?? _mapCatalogProductType(result.productType),
        categories: result.categories?.isNotEmpty == true
            ? result.categories!
            : const ['before_run', 'during_run', 'after_run'],
      );

      // Save to user foods with all categories
      final categoryIds = [1, 2, 3];
      await _userFoodService.saveUserFood(food, categoryIds);

      _logger.info(
        'Catalog result imported to user foods',
        context: 'SharedFoodSearchService',
        data: {
          'catalogId': result.id,
          'foodId': foodId,
          'name': result.displayName,
          'hasNutrition': result.hasNutrition,
        },
      );

      return food;
    } catch (e) {
      _logger.error(
        'Error adding catalog result to user foods',
        context: 'SharedFoodSearchService',
        data: {'catalogId': result.id, 'userId': userId},
        error: e,
      );
      return null;
    }
  }
}
