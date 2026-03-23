import 'dart:convert';

import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../shared/services/supabase/supabase_client_provider.dart';
import '../../../shared/services/logging_service.dart';
import '../../../shared/services/app_external_deps.dart';

part 'catalog_search_service.g.dart';

/// A single result from the product catalog search
class CatalogSearchResult {
  final String id;
  final String title;
  final String? variantTitle;
  final String? brand;
  final String? productType;
  final String? barcode;
  final String? imageUrl;
  final String? productUrl;
  final int? priceCents;
  final String? currencyCode;

  // Nutrition (per serving)
  final int? caloriesPerServing;
  final double? carbsG;
  final double? proteinG;
  final double? fatG;
  final int? sodiumMg;
  final String? servingSize;
  final double? servingGrams;
  final int? caffeineMg;
  final String? nutritionSource;
  final double? nutritionConfidence;

  // Classification fields
  final String? productTypeId;
  final List<String>? categories;
  final bool isElectrolyte;
  final bool isLiquid;
  final List<String>? allergens;
  final List<String>? excludedDiets;

  const CatalogSearchResult({
    required this.id,
    required this.title,
    this.variantTitle,
    this.brand,
    this.productType,
    this.barcode,
    this.imageUrl,
    this.productUrl,
    this.priceCents,
    this.currencyCode,
    this.caloriesPerServing,
    this.carbsG,
    this.proteinG,
    this.fatG,
    this.sodiumMg,
    this.servingSize,
    this.servingGrams,
    this.caffeineMg,
    this.nutritionSource,
    this.nutritionConfidence,
    this.productTypeId,
    this.categories,
    this.isElectrolyte = false,
    this.isLiquid = false,
    this.allergens,
    this.excludedDiets,
  });

  factory CatalogSearchResult.fromJson(Map<String, dynamic> json) {
    return CatalogSearchResult(
      id: json['id'] as String,
      title: json['title'] as String? ?? 'Unknown',
      variantTitle: json['variant_title'] as String?,
      brand: json['brand'] as String?,
      productType: json['product_type'] as String?,
      barcode: json['barcode'] as String?,
      imageUrl: json['image_url'] as String?,
      productUrl: json['product_url'] as String?,
      priceCents: json['price_cents'] as int?,
      currencyCode: json['currency_code'] as String?,
      caloriesPerServing: json['calories_per_serving'] as int?,
      carbsG: (json['carbs_g'] as num?)?.toDouble(),
      proteinG: (json['protein_g'] as num?)?.toDouble(),
      fatG: (json['fat_g'] as num?)?.toDouble(),
      sodiumMg: json['sodium_mg'] as int?,
      servingSize: json['serving_size'] as String?,
      servingGrams: (json['serving_grams'] as num?)?.toDouble(),
      caffeineMg: json['caffeine_mg'] as int?,
      nutritionSource: json['nutrition_source'] as String?,
      nutritionConfidence: (json['nutrition_confidence'] as num?)?.toDouble(),
      productTypeId: json['product_type_id'] as String?,
      categories: (json['categories'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList(),
      isElectrolyte: json['is_electrolyte'] as bool? ?? false,
      isLiquid: json['is_liquid'] as bool? ?? false,
      allergens: (json['allergens'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList(),
      excludedDiets: (json['excluded_diets'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList(),
    );
  }

  /// Whether this result has nutrition data
  bool get hasNutrition =>
      caloriesPerServing != null || carbsG != null;

  /// Display name combining title and variant
  String get displayName {
    if (variantTitle != null && variantTitle!.isNotEmpty) {
      return '$title — $variantTitle';
    }
    return title;
  }

  /// Formatted price string (e.g., "$3.49")
  String? get formattedPrice {
    if (priceCents == null) return null;
    final dollars = priceCents! / 100.0;
    return '\$${dollars.toStringAsFixed(2)}';
  }

  @override
  String toString() =>
      'CatalogSearchResult{id: $id, title: $title, brand: $brand, hasNutrition: $hasNutrition}';
}

/// Service for searching the product catalog via the search-catalog edge function
class CatalogSearchService {
  CatalogSearchService(this._supabase, this._logger);

  final SupabaseClient _supabase;
  final AppLogger _logger;

  /// Search the product catalog. Returns empty list on failure (silent fallback).
  Future<List<CatalogSearchResult>> searchCatalog(
    String query, {
    int limit = 20,
    String? productType,
  }) async {
    if (query.trim().isEmpty) return [];

    try {
      final response = await _supabase.functions.invoke(
        'search-catalog',
        body: {
          'query': query.trim(),
          'limit': limit,
          if (productType != null) 'product_type': productType,
        },
      );

      if (response.status >= 200 && response.status < 300) {
        final data = response.data is String
            ? jsonDecode(response.data) as Map<String, dynamic>
            : response.data as Map<String, dynamic>;

        if (data['success'] == true && data['results'] is List) {
          return (data['results'] as List)
              .whereType<Map<String, dynamic>>()
              .map(CatalogSearchResult.fromJson)
              .toList();
        }
      }

      _logger.warning(
        'Catalog search returned non-success',
        context: 'CatalogSearchService',
        data: {'status': response.status, 'query': query},
      );
      return [];
    } catch (e) {
      // Fail silently — catalog search is not critical
      _logger.warning(
        'Catalog search failed, returning empty results',
        context: 'CatalogSearchService',
        data: {'query': query, 'error': e.toString()},
      );
      return [];
    }
  }
}

@riverpod
CatalogSearchService catalogSearchService(Ref ref) {
  final supabase = ref.read(supabaseClientProvider);
  final logger = ref.read(appExternalDepsProvider).logger;
  return CatalogSearchService(supabase, logger);
}
