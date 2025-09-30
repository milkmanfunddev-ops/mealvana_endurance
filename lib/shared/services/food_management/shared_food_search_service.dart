import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../features/nutrition_plan/domain/food.dart';
import '../../../features/barcode_scanning/application/open_food_facts_search_service.dart';
import '../../../features/barcode_scanning/application/product_detail_service.dart';
import '../../../features/barcode_scanning/application/food_mapping_service.dart';
import '../logging_service.dart';
import 'user_food_crud_service.dart';

/// Provider for SharedFoodSearchService
final sharedFoodSearchServiceProvider = Provider<SharedFoodSearchService>((ref) {
  final openFoodFactsService = ref.read(openFoodFactsSearchServiceProvider);
  final productDetailService = ref.read(productDetailServiceProvider);
  final foodMappingService = ref.read(foodMappingServiceProvider);
  final userFoodService = ref.read(userFoodCrudServiceProvider);
  return SharedFoodSearchService(
    openFoodFactsService,
    productDetailService,
    foodMappingService,
    userFoodService,
  );
});

/// Shared service for Open Food Facts search functionality
/// Used by both food preferences and swap/add food screens
class SharedFoodSearchService {
  SharedFoodSearchService(
    this._openFoodFactsService,
    this._productDetailService,
    this._foodMappingService,
    this._userFoodService,
  );

  final OpenFoodFactsSearchService _openFoodFactsService;
  final ProductDetailService _productDetailService;
  final FoodMappingService _foodMappingService;
  final UserFoodCrudService _userFoodService;

  /// Search Open Food Facts for products
  Future<List<FoodSearchResult>> searchProducts(String query) async {
    try {
      AppLogger.instance.debug('Searching Open Food Facts',
        context: 'SharedFoodSearchService',
        data: {'query': query},
      );

      final results = await _openFoodFactsService.searchProducts(query);

      AppLogger.instance.debug('Search completed',
        context: 'SharedFoodSearchService',
        data: {'query': query, 'resultCount': results.length},
      );

      return results;
    } on SearchException catch (e) {
      AppLogger.instance.error('Search failed with SearchException',
        context: 'SharedFoodSearchService',
        data: {'query': query},
        error: e,
      );
      rethrow;
    } catch (e) {
      AppLogger.instance.error('Search failed with unexpected error',
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
        AppLogger.instance.warning('Invalid search result ID',
          context: 'SharedFoodSearchService',
          data: {'result': result.toString()},
        );
        return null;
      }

      AppLogger.instance.debug('Adding search result to user foods',
        context: 'SharedFoodSearchService',
        data: {'productId': result.id, 'deviceId': deviceId},
      );

      // Get product details from Open Food Facts
      final apiProduct = await _productDetailService.getProductDetails(
        openFoodFactsId: result.id,
      );

      if (apiProduct == null) {
        AppLogger.instance.warning('Failed to get product details',
          context: 'SharedFoodSearchService',
          data: {'productId': result.id},
        );
        return null;
      }

      // Map API product to Food
      final food = _foodMappingService.mapToFood(apiProduct);

      // Convert categories from strings to category IDs (simplified - using empty list for now)
      final categoryIds = <int>[];

      // Save to user foods
      await _userFoodService.saveUserFood(food, categoryIds);

      AppLogger.instance.debug('Successfully added search result to user foods',
        context: 'SharedFoodSearchService',
        data: {'foodId': food.id, 'name': food.name},
      );

      return food;
    } catch (e) {
      AppLogger.instance.error('Error adding search result to user foods',
        context: 'SharedFoodSearchService',
        data: {'productId': result.id, 'deviceId': deviceId},
        error: e,
      );
      return null;
    }
  }

}