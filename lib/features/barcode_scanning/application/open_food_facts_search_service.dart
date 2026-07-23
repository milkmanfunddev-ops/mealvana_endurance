import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:mealvana_endurance/core/utils/debug_logger.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'open_food_facts_search_service.g.dart';

/// Service for searching Open Food Facts database
/// Uses the legacy CGI Search API due to V2 API data quality issues
class OpenFoodFactsSearchService {
  static const String _baseUrl =
      'https://world.openfoodfacts.org/cgi/search.pl';
  static const String _userAgent =
      'MealvanaEndurance/1.0 (support@mealvana.com)';

  /// Search for food products by name/brand
  /// Returns basic product information for selection
  Future<List<FoodSearchResult>> searchProducts(String query) async {
    if (query.trim().isEmpty) {
      return [];
    }

    DebugLogger.debug(
      '🔍 OpenFoodFactsSearchService - Searching for: "$query"',
    );

    try {
      final uri = Uri.parse(_baseUrl).replace(
        queryParameters: {
          'search_terms': query.trim(),
          'search_simple': '1', // Simple search mode
          'action': 'process', // Process the search
          'json': '1', // Return JSON format
          'page_size': '10', // Limit to 10 results
        },
      );

      final response = await http.get(
        uri,
        headers: {'User-Agent': _userAgent, 'Content-Type': 'application/json'},
      );

      if (response.statusCode == 429) {
        DebugLogger.warning(
          '⚠️ OpenFoodFactsSearchService - Rate limit exceeded',
        );
        throw SearchException(
          'Search rate limit exceeded. Please wait a moment before searching again.',
        );
      }

      if (response.statusCode != 200) {
        DebugLogger.error(
          '❌ OpenFoodFactsSearchService - HTTP error',
          error: response.statusCode,
        );
        throw SearchException('Search service temporarily unavailable');
      }

      final data = json.decode(response.body) as Map<String, dynamic>;

      if (data['products'] == null) {
        DebugLogger.warning(
          '❌ OpenFoodFactsSearchService - No products field in response',
        );
        return [];
      }

      final products = data['products'] as List<dynamic>;
      DebugLogger.info(
        '✅ OpenFoodFactsSearchService - Found ${products.length} results',
      );

      final results = products
          .whereType<Map<String, dynamic>>()
          .map(FoodSearchResult.fromOpenFoodFacts)
          .where(
            (result) => result.name.isNotEmpty,
          ) // Filter out products with no name
          .toList();

      // Debug: Print first few results to help diagnose
      DebugLogger.debug('🔍 OpenFoodFactsSearchService - Sample results:');
      for (int i = 0; i < results.length && i < 3; i++) {
        final result = results[i];
        DebugLogger.debug(
          '  ${i + 1}. ID: ${result.id}, Name: ${result.name}, Brand: ${result.brand}',
        );
      }

      return results;
    } catch (e) {
      if (e is SearchException) {
        rethrow;
      }
      DebugLogger.error(
        '❌ OpenFoodFactsSearchService - Unexpected error',
        error: e,
      );
      throw SearchException(
        'Unable to search for products. Please check your internet connection.',
      );
    }
  }
}

/// Represents a search result from Open Food Facts
class FoodSearchResult {
  final String id; // This will be the barcode/code
  final String name;
  final String? brand;
  final String? imageUrl;
  final String? categories;

  FoodSearchResult({
    required this.id,
    required this.name,
    this.brand,
    this.imageUrl,
    this.categories,
  });

  factory FoodSearchResult.fromOpenFoodFacts(Map<String, dynamic> data) {
    return FoodSearchResult(
      id: data['code']?.toString() ?? '',
      name: data['product_name']?.toString() ?? '',
      brand: data['brands']?.toString(),
      imageUrl:
          data['image_front_url']?.toString() ?? data['image_url']?.toString(),
      categories: data['categories']?.toString(),
    );
  }

  /// Get display name combining brand and product name
  String get displayName {
    if (brand != null && brand!.isNotEmpty) {
      return '$brand $name';
    }
    return name;
  }

  /// Check if this result has a valid ID for lookup
  bool get hasValidId => id.isNotEmpty;

  @override
  String toString() {
    return 'FoodSearchResult{id: $id, name: $name, brand: $brand}';
  }
}

/// Custom exception for search errors
class SearchException implements Exception {
  final String message;

  SearchException(this.message);

  @override
  String toString() => 'SearchException: $message';
}

@riverpod
OpenFoodFactsSearchService openFoodFactsSearchService(Ref ref) {
  return OpenFoodFactsSearchService();
}
