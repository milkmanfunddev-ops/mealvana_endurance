import 'api_food_product.dart';

/// Represents the result of a barcode lookup operation
/// Can be successful with product data, not found, or error
sealed class BarcodeResult {
  final String barcode;

  const BarcodeResult({required this.barcode});

  /// Successful lookup with product data
  const factory BarcodeResult.success({
    required String barcode,
    required ApiFoodProduct product,
  }) = BarcodeResultSuccess;

  /// Product not found in any database
  const factory BarcodeResult.notFound({
    required String barcode,
    required String message,
  }) = BarcodeResultNotFound;

  /// Error occurred during lookup
  const factory BarcodeResult.error({
    required String barcode,
    required String message,
  }) = BarcodeResultError;

  /// Check if the result is successful
  bool get isSuccess => this is BarcodeResultSuccess;

  /// Check if the result is not found
  bool get isNotFound => this is BarcodeResultNotFound;

  /// Check if the result is an error
  bool get isError => this is BarcodeResultError;

  /// Get the product if successful, null otherwise
  ApiFoodProduct? get product {
    if (this is BarcodeResultSuccess) {
      return (this as BarcodeResultSuccess).product;
    }
    return null;
  }

  /// Get the error/not found message
  String? get message {
    switch (this) {
      case BarcodeResultNotFound(:final message):
        return message;
      case BarcodeResultError(:final message):
        return message;
      case BarcodeResultSuccess():
        return null;
    }
  }
}

/// Successful barcode lookup result
final class BarcodeResultSuccess extends BarcodeResult {
  final ApiFoodProduct product;

  const BarcodeResultSuccess({
    required super.barcode,
    required this.product,
  });
}

/// Product not found result
final class BarcodeResultNotFound extends BarcodeResult {
  final String message;

  const BarcodeResultNotFound({
    required super.barcode,
    required this.message,
  });
}

/// Error during lookup result
final class BarcodeResultError extends BarcodeResult {
  final String message;

  const BarcodeResultError({
    required super.barcode,
    required this.message,
  });
}