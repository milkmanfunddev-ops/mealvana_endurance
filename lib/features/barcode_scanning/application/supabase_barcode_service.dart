import 'dart:async';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../../shared/services/report/report.dart';
import '../domain/barcode_result.dart';
import 'product_detail_service.dart';

part 'supabase_barcode_service.g.dart';

/// Service for communicating with the unified lookup-product Edge Function
/// Handles API integration with Open Food Facts via the ProductDetailService
class SupabaseBarcodeService {
  final ProductDetailService _productDetailService;
  final Report _report;

  SupabaseBarcodeService({
    required ProductDetailService productDetailService,
    required Report report,
  }) : _productDetailService = productDetailService,
       _report = report;

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
    } on ProductNotFoundException {
      // Counted as expected by ProductDetailService (ticket 79); the screen
      // shows its own not-found words, so the message is debug only.
      return BarcodeResult.notFound(barcode: barcode, message: '');
    } on ProductLookupUnavailableException catch (e) {
      // Already reported (weather or fault) by ProductDetailService.
      return BarcodeResult.error(barcode: barcode, message: e.message);
    } on ProductDetailException catch (e, stackTrace) {
      // ProductDetailService throws these without reporting (a 200 with no
      // product); this is their one report.
      _report.degraded(
        e,
        stackTrace: stackTrace,
        area: 'barcode_scanning',
        message: 'Product detail lookup failed',
        extra: {'barcode': barcode},
      );

      return BarcodeResult.error(barcode: barcode, message: e.message);
    } catch (e, stackTrace) {
      _report.fault(
        e,
        stackTrace: stackTrace,
        area: 'barcode_scanning',
        message: 'Barcode lookup error for $barcode: $e',
      );

      return BarcodeResult.error(
        barcode: barcode,
        message: 'An unexpected error occurred. Please try again.',
      );
    }
  }

  /// Validate barcode format: EAN-8, UPC-A, EAN-13 or GTIN-14 (a typed
  /// barcode may carry the 14-digit packaging form, testing-wave 28-004).
  bool isValidBarcodeFormat(String barcode) {
    final cleanBarcode = barcode.replaceAll(
      RegExp(r'\D'),
      '',
    ); // Remove non-digits
    return const [8, 12, 13, 14].contains(cleanBarcode.length);
  }

  /// Clean barcode by removing non-digit characters
  String cleanBarcode(String barcode) {
    return barcode.replaceAll(RegExp(r'\D'), '');
  }
}

@riverpod
SupabaseBarcodeService supabaseBarcodeService(Ref ref) {
  return SupabaseBarcodeService(
    productDetailService: ref.read(productDetailServiceProvider),
    report: ref.read(reportProvider),
  );
}
