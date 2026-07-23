import 'dart:convert';

import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../app_external_deps.dart';
import '../logging_service.dart';
import '../supabase/supabase_client_provider.dart';

part 'nutrition_product_search_service.g.dart';

/// A single result from the `nutrition_products` master (USDA FoodData
/// Central + Open Food Facts, cached via the barcode-lookup write-through
/// cache — see `supabase/functions/lookup-product`). Reached via the
/// `search-nutrition-products` edge function's trigram text search.
///
/// [barcode] doubles as the lookup key for the detail-resolution cascade
/// (`lookup-product`'s barcode param), so tapping a result and resolving it
/// goes through the same catalog → cache → USDA/OFF cascade as a barcode
/// scan — no separate resolution path to maintain.
class NutritionProductSearchResult {
  const NutritionProductSearchResult({
    required this.barcode,
    required this.productName,
    this.brandName,
    this.imageUrl,
    this.servingSize,
    this.servingGrams,
    this.caloriesPer100g,
    this.carbsPer100g,
    this.proteinPer100g,
    this.fatPer100g,
    this.sodiumMgPer100g,
    this.caloriesPerServing,
    this.carbsPerServing,
    this.proteinPerServing,
    this.fatPerServing,
    this.sodiumMgPerServing,
    this.categories,
    this.suggestedProductType,
    this.nutritionDataPer,
    this.source,
    this.confidenceScore,
  });

  final String barcode;
  final String productName;
  final String? brandName;
  final String? imageUrl;
  final String? servingSize;
  final double? servingGrams;

  final num? caloriesPer100g;
  final double? carbsPer100g;
  final double? proteinPer100g;
  final double? fatPer100g;
  final num? sodiumMgPer100g;

  final num? caloriesPerServing;
  final double? carbsPerServing;
  final double? proteinPerServing;
  final double? fatPerServing;
  final num? sodiumMgPerServing;

  /// Free-text category string (e.g. from OFF) — not the app's product_type.
  final String? categories;

  /// Best-effort app `product_type` code (e.g. 'gel', 'bar', 'real_food').
  /// Used for the endurance-fuel vs general-food display split.
  final String? suggestedProductType;

  /// 'serving' or '100g' — which nutrition columns are populated.
  final String? nutritionDataPer;

  /// 'usda_fdc' | 'open_food_facts' | 'catalog_thefeed' | ...
  final String? source;
  final double? confidenceScore;

  factory NutritionProductSearchResult.fromJson(Map<String, dynamic> json) {
    return NutritionProductSearchResult(
      barcode: json['barcode']?.toString() ?? '',
      productName: json['product_name']?.toString() ?? 'Unknown Product',
      brandName: json['brand_name'] as String?,
      imageUrl: json['image_url'] as String?,
      servingSize: json['serving_size'] as String?,
      servingGrams: (json['serving_grams'] as num?)?.toDouble(),
      caloriesPer100g: json['calories_per_100g'] as num?,
      carbsPer100g: (json['carbohydrates_per_100g'] as num?)?.toDouble(),
      proteinPer100g: (json['protein_per_100g'] as num?)?.toDouble(),
      fatPer100g: (json['fat_per_100g'] as num?)?.toDouble(),
      sodiumMgPer100g: json['sodium_mg_per_100g'] as num?,
      caloriesPerServing: json['calories_per_serving'] as num?,
      carbsPerServing: (json['carbohydrates_per_serving'] as num?)?.toDouble(),
      proteinPerServing: (json['protein_per_serving'] as num?)?.toDouble(),
      fatPerServing: (json['fat_per_serving'] as num?)?.toDouble(),
      sodiumMgPerServing: json['sodium_mg_per_serving'] as num?,
      categories: json['categories'] as String?,
      suggestedProductType: json['suggested_product_type'] as String?,
      nutritionDataPer: json['nutrition_data_per'] as String?,
      source: json['source'] as String?,
      confidenceScore: (json['confidence_score'] as num?)?.toDouble(),
    );
  }

  /// Display name combining brand and product name (duck-typed to match
  /// [FoodSearchResult.displayName] so both can share rendering code).
  String get displayName {
    if (brandName != null && brandName!.isNotEmpty) {
      return '$brandName $productName';
    }
    return productName;
  }

  /// Whether this result has a usable barcode for detail resolution.
  bool get hasValidId => barcode.isNotEmpty;

  /// Duck-typed alias for [barcode] so callers written against the generic
  /// OpenFoodFacts result shape (`result.id`) work unchanged.
  String get id => barcode;

  bool get hasNutrition =>
      caloriesPerServing != null ||
      carbsPerServing != null ||
      caloriesPer100g != null ||
      carbsPer100g != null;

  @override
  String toString() =>
      'NutritionProductSearchResult{barcode: $barcode, name: $productName, source: $source}';
}

/// Client for the `search-nutrition-products` edge function — trigram text
/// search over the `nutrition_products` master (USDA + cached Open Food
/// Facts hits). Server-side, so it works on Flutter web without the CORS
/// issues the direct-to-OpenFoodFacts CGI call has.
class NutritionProductSearchService {
  NutritionProductSearchService(this._supabase, this._logger);

  final SupabaseClient _supabase;
  final AppLogger _logger;

  /// Search nutrition_products by name/brand. Returns empty list on failure
  /// (silent fallback) — this is a supplementary source, not critical path.
  Future<List<NutritionProductSearchResult>> search(
    String query, {
    int limit = 20,
  }) async {
    if (query.trim().isEmpty) return [];

    try {
      final response = await _supabase.functions.invoke(
        'search-nutrition-products',
        body: {'query': query.trim(), 'limit': limit},
      );

      if (response.status >= 200 && response.status < 300) {
        final data = response.data is String
            ? jsonDecode(response.data as String) as Map<String, dynamic>
            : response.data as Map<String, dynamic>;

        if (data['success'] == true && data['results'] is List) {
          return (data['results'] as List)
              .whereType<Map<String, dynamic>>()
              .map(NutritionProductSearchResult.fromJson)
              .toList();
        }
      }

      _logger.warning(
        'Nutrition product search returned non-success',
        context: 'NutritionProductSearchService',
        data: {'status': response.status, 'query': query},
      );
      return [];
    } catch (e) {
      // Fail silently — this is a supplementary source layered on top of
      // catalog + local results.
      _logger.warning(
        'Nutrition product search failed, returning empty results',
        context: 'NutritionProductSearchService',
        data: {'query': query, 'error': e.toString()},
      );
      return [];
    }
  }
}

@riverpod
NutritionProductSearchService nutritionProductSearchService(Ref ref) {
  final supabase = ref.read(supabaseClientProvider);
  final logger = ref.read(appExternalDepsProvider).logger;
  return NutritionProductSearchService(supabase, logger);
}
