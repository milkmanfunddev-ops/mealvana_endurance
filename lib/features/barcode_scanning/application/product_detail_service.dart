import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../shared/services/app_external_deps.dart';
import '../../../shared/services/report/report.dart';
import '../domain/api_food_product.dart';

part 'product_detail_service.g.dart';

/// Unified service for getting product details from barcode or Open Food Facts ID
/// Replaces the previous barcode-specific lookup with a more flexible approach
class ProductDetailService {
  final SupabaseClient _supabase;
  final Report _report;

  ProductDetailService(this._supabase, {required Report report})
    : _report = report;

  /// Get product details using either barcode or Open Food Facts ID
  /// Returns null if product not found or if there's an error
  Future<ApiFoodProduct?> getProductDetails({
    String? barcode,
    String? openFoodFactsId,
  }) async {
    if (barcode == null && openFoodFactsId == null) {
      throw ArgumentError('Either barcode or openFoodFactsId must be provided');
    }

    _report.debug(
      '🔄 ProductDetailService - Looking up product',
      area: 'barcode_scanning',
      data: {
        if (barcode != null) 'barcode': barcode,
        if (openFoodFactsId != null) 'open_food_facts_id': openFoodFactsId,
      },
    );

    _report.debug(
      '🚀 ProductDetailService - CALLING EDGE FUNCTION: lookup-product',
      area: 'barcode_scanning',
    );
    final requestBody = {
      if (barcode != null) 'barcode': barcode,
      if (openFoodFactsId != null) 'open_food_facts_id': openFoodFactsId,
    };
    _report.debug(
      '📦 ProductDetailService - Request body: $requestBody',
      area: 'barcode_scanning',
    );

    try {
      final response = await _supabase.functions.invoke(
        'lookup-product',
        body: requestBody,
      );

      _report.debug(
        '📡 ProductDetailService - Edge function response status: ${response.status}',
        area: 'barcode_scanning',
      );
      _report.debug(
        '📄 ProductDetailService - Edge function response data: ${response.data}',
        area: 'barcode_scanning',
      );

      if (response.status != 200) {
        _report.fault(
          LoggedFault(
            '❌ ProductDetailService - API error: status ${response.status}',
            context: 'barcode_scanning',
          ),
          area: 'barcode_scanning',
          extra: {'status': response.status},
        );
        final errorData = response.data;
        if (errorData != null && errorData['message'] != null) {
          throw ProductDetailException(errorData['message'] as String);
        }
        throw ProductDetailException('Failed to lookup product details');
      }

      final data = response.data;
      if (data == null || !data['success']) {
        final errorMessage = data?['message'] ?? 'Product not found';
        _report.degraded(
          LoggedFault(
            '❌ ProductDetailService - Product not found: $errorMessage',
            context: 'barcode_scanning',
          ),
          area: 'barcode_scanning',
        );
        throw ProductDetailException(errorMessage);
      }

      final productData = data['product'];
      if (productData == null) {
        throw ProductDetailException('No product data returned');
      }

      _report.info(
        '✅ ProductDetailService - Product found via ${data['source']}',
        area: 'barcode_scanning',
      );

      // Convert to ApiFoodProduct using the existing factory method
      return ApiFoodProduct.fromEdgeFunctionResponse(
        Map<String, dynamic>.from(productData),
      );
    } on ProductDetailException {
      rethrow; // Re-throw our custom exceptions
    } catch (e, stackTrace) {
      _report.fault(
        e,
        stackTrace: stackTrace,
        area: 'barcode_scanning',
        message: '❌ ProductDetailService - Unexpected error',
      );
      throw ProductDetailException(
        'Unable to connect to product lookup service',
      );
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
  final supabase = ref.read(appExternalDepsProvider).supabaseClient;
  return ProductDetailService(supabase, report: ref.read(reportProvider));
}
