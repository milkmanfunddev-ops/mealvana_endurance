import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../shared/services/analytics/analytics_tracker.dart';
import '../../../shared/services/app_external_deps.dart';
import '../../../shared/services/report/report.dart';
import '../domain/api_food_product.dart';

part 'product_detail_service.g.dart';

/// Unified service for getting product details from barcode or Open Food Facts ID
/// Replaces the previous barcode-specific lookup with a more flexible approach
class ProductDetailService {
  final SupabaseClient _supabase;
  final Report _report;

  /// Where a not-found or offline lookup's `expected_failure` count goes
  /// (ticket 79). Null (a test, or no tracker): a Sentry counter instead.
  final AnalyticsTracker? _analytics;

  ProductDetailService(
    this._supabase, {
    required Report report,
    AnalyticsTracker? analytics,
  }) : _report = report,
       _analytics = analytics;

  /// One lookup attempt's bound. Successful lookups answer in under 1 s
  /// (run 68); without a bound the wait was the OS's ~30 s connect timeout
  /// (68-018). Two attempts at most, so the worst case is about 20 s.
  @visibleForTesting
  static const lookupTimeout = Duration(seconds: 10);

  @visibleForTesting
  static const area = 'barcode_scanning';

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
      final response = await _invokeLookup(requestBody);

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
        // Reported once by the caller that catches ProductDetailException.
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
    } on FunctionException catch (e, stackTrace) {
      // lookup-product's 404 is "no such product": an expected outcome, the
      // athlete gets the not-found dialog (ticket 79, 68-007). Keyed on the
      // body's `success: false` so a gateway 404 still faults.
      if (isNotFoundAnswer(e)) {
        await _report.noteExpected(
          'lookup-product: not found',
          area: area,
          reason: 'barcode_not_found',
          analytics: _analytics,
          data: {'status': 404},
        );
        final details = e.details;
        final message = details is Map ? details['message'] : null;
        throw ProductNotFoundException(
          message is String ? message : 'Product not found',
        );
      }
      // Any other HTTP answer is final (no retry) and a fault, as before.
      _report.fault(
        e,
        stackTrace: stackTrace,
        area: area,
        message: '❌ ProductDetailService - Unexpected error',
        extra: {'status': e.status},
      );
      throw ProductDetailException(
        'Unable to connect to product lookup service',
      );
    } on _LookupUnreachable catch (u) {
      // Both attempts failed on transport. Offline and timeout are weather (a
      // breadcrumb and one count); anything else faults (ticket 79, 68-018).
      await _report.faultUnlessWeather(
        u.error,
        stackTrace: u.stackTrace,
        area: area,
        message: 'lookup-product unreachable after one retry',
        analytics: _analytics,
      );
      throw ProductLookupUnavailableException(
        'Unable to connect to product lookup service',
      );
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

  /// Whether [e] is lookup-product's not-found answer: 404 with
  /// `success: false` in the body (`lookup-product/index.ts`).
  @visibleForTesting
  static bool isNotFoundAnswer(FunctionException e) {
    final details = e.details;
    return e.status == 404 && details is Map && details['success'] == false;
  }

  /// One bounded attempt, and one more on a transport failure (no answer:
  /// timeout, socket, client). An HTTP answer ([FunctionException]) is never
  /// retried. lookup-product is a read; a repeat that did reach the server
  /// re-runs an idempotent cache upsert and bumps a hit counter (ticket 79's
  /// write list).
  Future<FunctionResponse> _invokeLookup(Map<String, dynamic> body) async {
    try {
      return await _invokeOnce(body);
    } catch (e) {
      if (!_isTransportFailure(e)) rethrow;
      _report.breadcrumb(
        'lookup-product attempt 1 failed; retrying once',
        category: area,
        data: {'error': e.runtimeType.toString()},
      );
    }
    try {
      return await _invokeOnce(body);
    } catch (e, st) {
      if (!_isTransportFailure(e)) rethrow;
      throw _LookupUnreachable(e, st);
    }
  }

  Future<FunctionResponse> _invokeOnce(Map<String, dynamic> body) => _supabase
      .functions
      .invoke('lookup-product', body: body)
      .timeout(lookupTimeout);

  static bool _isTransportFailure(Object e) =>
      e is TimeoutException ||
      e is SocketException ||
      e is http.ClientException;

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

/// lookup-product answered 404: no product for this code. Already counted as
/// an expected outcome by [ProductDetailService]; callers do not report it.
class ProductNotFoundException extends ProductDetailException {
  ProductNotFoundException(super.message);

  @override
  String toString() => 'ProductNotFoundException: $message';
}

/// lookup-product could not be reached after one retry. Already reported by
/// [ProductDetailService] (weather or fault); callers do not report it again.
class ProductLookupUnavailableException extends ProductDetailException {
  ProductLookupUnavailableException(super.message);

  @override
  String toString() => 'ProductLookupUnavailableException: $message';
}

/// Both lookup attempts failed on transport; carries the last error.
class _LookupUnreachable implements Exception {
  _LookupUnreachable(this.error, this.stackTrace);

  final Object error;
  final StackTrace stackTrace;
}

@riverpod
ProductDetailService productDetailService(Ref ref) {
  final supabase = ref.read(appExternalDepsProvider).supabaseClient;
  return ProductDetailService(
    supabase,
    report: ref.read(reportProvider),
    analytics: ref.read(appExternalDepsProvider).analytics,
  );
}
