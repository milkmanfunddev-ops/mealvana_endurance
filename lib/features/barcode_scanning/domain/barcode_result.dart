import 'api_food_product.dart';

/// Represents the result of a barcode lookup operation
/// Can be successful with product data, not found, or error
sealed class BarcodeResult {
  final String barcode;

  const BarcodeResult({required this.barcode});

  /// Override in subclasses that carry a product
  ApiFoodProduct? get product => null;

  /// Override in subclasses that carry human-readable messages
  String? get message => null;

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

}

/// Successful barcode lookup result
final class BarcodeResultSuccess extends BarcodeResult {
  final ApiFoodProduct _product;

  const BarcodeResultSuccess({
    required super.barcode,
    required ApiFoodProduct product,
  }) : _product = product;

  @override
  ApiFoodProduct get product => _product;
}

/// Product not found result
final class BarcodeResultNotFound extends BarcodeResult {
  final String _message;

  const BarcodeResultNotFound({
    required super.barcode,
    required String message,
  }) : _message = message;

  @override
  String get message => _message;
}

/// Error during lookup result
final class BarcodeResultError extends BarcodeResult {
  final String _message;

  const BarcodeResultError({
    required super.barcode,
    required String message,
  }) : _message = message;

  @override
  String get message => _message;
}
