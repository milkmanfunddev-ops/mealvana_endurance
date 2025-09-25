import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../domain/api_food_product.dart';

part 'product_detail_service.g.dart';

/// Unified service for getting product details from barcode or Open Food Facts ID
/// Replaces the previous barcode-specific lookup with a more flexible approach
class ProductDetailService {
  final SupabaseClient _supabase;

  ProductDetailService(this._supabase);

  /// Get product details using either barcode or Open Food Facts ID
  /// Returns null if product not found or if there's an error
  Future<ApiFoodProduct?> getProductDetails({
    String? barcode,
    String? openFoodFactsId,
  }) async {
    if (barcode == null && openFoodFactsId == null) {
      throw ArgumentError('Either barcode or openFoodFactsId must be provided');
    }

    print('🔄 ProductDetailService - Looking up product with:');
    if (barcode != null) print('  Barcode: $barcode');
    if (openFoodFactsId != null) print('  Open Food Facts ID: $openFoodFactsId');

    print('🚀 ProductDetailService - CALLING EDGE FUNCTION: lookup-product');
    print('📦 ProductDetailService - Request body: ${{
      if (barcode != null) 'barcode': barcode,
      if (openFoodFactsId != null) 'open_food_facts_id': openFoodFactsId,
    }}');

    try {
      final response = await _supabase.functions.invoke(
        'lookup-product',
        body: {
          if (barcode != null) 'barcode': barcode,
          if (openFoodFactsId != null) 'open_food_facts_id': openFoodFactsId,
        },
      );

      print('📡 ProductDetailService - Edge function response status: ${response.status}');
      print('📄 ProductDetailService - Edge function response data: ${response.data}');

      if (response.status != 200) {
        print('❌ ProductDetailService - API error: ${response.status}');
        final errorData = response.data;
        if (errorData != null && errorData['message'] != null) {
          throw ProductDetailException(errorData['message'] as String);
        }
        throw ProductDetailException('Failed to lookup product details');
      }

      final data = response.data;
      if (data == null || !data['success']) {
        final errorMessage = data?['message'] ?? 'Product not found';
        print('❌ ProductDetailService - Product not found: $errorMessage');
        throw ProductDetailException(errorMessage);
      }

      final productData = data['product'];
      if (productData == null) {
        throw ProductDetailException('No product data returned');
      }

      print('✅ ProductDetailService - Product found via ${data['source']}');

      // Convert to ApiFoodProduct using the existing factory method
      return ApiFoodProduct.fromEdgeFunctionResponse(
        Map<String, dynamic>.from(productData)
      );

    } on ProductDetailException {
      rethrow; // Re-throw our custom exceptions
    } catch (e) {
      print('❌ ProductDetailService - Unexpected error: $e');
      throw ProductDetailException('Unable to connect to product lookup service');
    }
  }

  /// Convenience method for barcode-only lookups (backward compatibility)
  Future<ApiFoodProduct?> getProductByBarcode(String barcode) async {
    return getProductDetails(barcode: barcode);
  }

  /// Convenience method for Open Food Facts ID lookups
  Future<ApiFoodProduct?> getProductByOpenFoodFactsId(String id) async {
    return getProductDetails(openFoodFactsId: id);
  }
}

/// Custom exception for product detail lookup errors
class ProductDetailException implements Exception {
  final String message;

  ProductDetailException(this.message);

  @override
  String toString() => 'ProductDetailException: $message';
}

@riverpod
ProductDetailService productDetailService(Ref ref) {
  return ProductDetailService(Supabase.instance.client);
}