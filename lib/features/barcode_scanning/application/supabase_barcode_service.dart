import 'dart:async';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../shared/services/logging_service.dart';
import '../domain/barcode_result.dart';
import '../domain/api_food_product.dart';

part 'supabase_barcode_service.g.dart';

/// Service for communicating with the Supabase barcode-lookup Edge Function
/// Handles API integration with Open Food Facts and USDA fallback
class SupabaseBarcodeService {
  final SupabaseClient _supabase;
  final LoggingService _logger;

  SupabaseBarcodeService({
    required SupabaseClient supabase,
    required LoggingService logger,
  })  : _supabase = supabase,
        _logger = logger;

  /// Look up a barcode using the Edge Function
  /// Returns null if the product is not found or if there's an error
  Future<BarcodeResult?> lookupBarcode(String barcode) async {
    try {
      _logger.info('Starting barcode lookup for: $barcode');

      // Log the request details
      _logger.info('Calling Edge Function: barcode-lookup with body: {"barcode": "$barcode"}');

      // Call the Edge Function
      final response = await _supabase.functions.invoke(
        'barcode-lookup',
        body: {'barcode': barcode},
      );

      // Log the raw response
      _logger.info('Edge Function response status: ${response.status}');
      _logger.info('Edge Function response data: ${response.data}');

      // Handle different response scenarios
      if (response.status == 200) {
        final data = response.data as Map<String, dynamic>;

        if (data['success'] == true && data['data'] != null) {
          // Successful lookup
          final productData = data['data'] as Map<String, dynamic>;
          final apiProduct = ApiFoodProduct.fromEdgeFunctionResponse(productData);

          _logger.info('Successfully found product: ${apiProduct.productName}');

          return BarcodeResult.success(
            barcode: barcode,
            product: apiProduct,
          );
        } else {
          // Product not found but API call was successful
          _logger.info('Product not found for barcode: $barcode');

          return BarcodeResult.notFound(
            barcode: barcode,
            message: data['message'] as String? ?? 'Product not found in nutrition databases',
          );
        }
      } else if (response.status == 404) {
        // Product not found
        final data = response.data as Map<String, dynamic>?;

        return BarcodeResult.notFound(
          barcode: barcode,
          message: data?['message'] as String? ?? 'Product not found',
        );
      } else {
        // API error
        _logger.error('Edge Function error: ${response.status}');

        return BarcodeResult.error(
          barcode: barcode,
          message: 'Unable to connect to nutrition database. Please try again.',
        );
      }
    } on TimeoutException {
      _logger.error('Barcode lookup timeout for: $barcode');

      return BarcodeResult.error(
        barcode: barcode,
        message: 'Request timed out. Please check your connection and try again.',
      );
    } catch (e, stackTrace) {
      _logger.error('Barcode lookup error for $barcode: $e', error: e, stackTrace: stackTrace);

      return BarcodeResult.error(
        barcode: barcode,
        message: 'An unexpected error occurred. Please try again.',
      );
    }
  }

  /// Validate barcode format
  bool isValidBarcodeFormat(String barcode) {
    final cleanBarcode = barcode.replaceAll(RegExp(r'\D'), ''); // Remove non-digits
    return [8, 12, 13].contains(cleanBarcode.length);
  }

  /// Clean barcode by removing non-digit characters
  String cleanBarcode(String barcode) {
    return barcode.replaceAll(RegExp(r'\D'), '');
  }
}

@riverpod
SupabaseBarcodeService supabaseBarcodeService(SupabaseBarcodeServiceRef ref) {
  return SupabaseBarcodeService(
    supabase: Supabase.instance.client,
    logger: LoggingService(),
  );
}