import 'dart:async';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../../shared/services/app_external_deps.dart';
import '../../../shared/services/logging_service.dart';
import '../domain/barcode_result.dart';
import 'product_detail_service.dart';

part 'supabase_barcode_service.g.dart';

/// Service for communicating with the unified lookup-product Edge Function
/// Handles API integration with Open Food Facts via the ProductDetailService
class SupabaseBarcodeService {
  final ProductDetailService _productDetailService;
  final AppLogger _logger;

  SupabaseBarcodeService({
    required ProductDetailService productDetailService,
    required AppLogger logger,
  }) : _productDetailService = productDetailService,
       _logger = logger;

  /// Look up a barcode using the unified ProductDetailService
  /// Returns null if the product is not found or if there's an error
  Future<BarcodeResult?> lookupBarcode(String barcode) async {
    try {
      // Use the unified ProductDetailService
      final apiProduct = await _productDetailService.getProductDetails(
        barcode: barcode,
      );

      if (apiProduct != null) {
        return BarcodeResult.success(barcode: barcode, product: apiProduct);
      } else {
        return BarcodeResult.notFound(
          barcode: barcode,
          message: 'Product not found in nutrition databases',
        );
      }
    } on ProductDetailException catch (e) {
      _logger.error('ProductDetailService error: ${e.message}');

      return BarcodeResult.error(barcode: barcode, message: e.message);
    } catch (e, stackTrace) {
      _logger.error(
        'Barcode lookup error for $barcode: $e',
        error: e,
        stackTrace: stackTrace,
      );

      return BarcodeResult.error(
        barcode: barcode,
        message: 'An unexpected error occurred. Please try again.',
      );
    }
  }

  /// Validate barcode format
  bool isValidBarcodeFormat(String barcode) {
    final cleanBarcode = barcode.replaceAll(
      RegExp(r'\D'),
      '',
    ); // Remove non-digits
    return [8, 12, 13].contains(cleanBarcode.length);
  }

  /// Clean barcode by removing non-digit characters
  String cleanBarcode(String barcode) {
    return barcode.replaceAll(RegExp(r'\D'), '');
  }
}

@riverpod
SupabaseBarcodeService supabaseBarcodeService(Ref ref) {
  final logger = ref.read(appExternalDepsProvider).logger;
  return SupabaseBarcodeService(
    productDetailService: ref.read(productDetailServiceProvider),
    logger: logger,
  );
}
