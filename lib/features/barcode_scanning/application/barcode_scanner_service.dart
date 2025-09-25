import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../nutrition_plan/domain/food.dart';
import '../domain/barcode_result.dart';
import 'supabase_barcode_service.dart';
import 'food_mapping_service.dart';
import '../../../shared/database/app_database.dart';
import '../../../shared/database/database_provider.dart';

part 'barcode_scanner_service.g.dart';

/// Main service for barcode scanning operations
/// Orchestrates the lookup and mapping to Food domain models
class BarcodeScannerService {
  final SupabaseBarcodeService _barcodeService;
  final FoodMappingService _mappingService;
  final AppDatabase _database;

  BarcodeScannerService({
    required SupabaseBarcodeService barcodeService,
    required FoodMappingService mappingService,
    required AppDatabase database,
  })  : _barcodeService = barcodeService,
        _mappingService = mappingService,
        _database = database;

  /// Scan a barcode and return a Food model if successful
  /// Returns null if the product is not found or there's an error
  Future<BarcodeScanResult> scanBarcode(String barcode) async {
    print('BarcodeScannerService.scanBarcode called with: $barcode');

    // Validate barcode format
    if (!_barcodeService.isValidBarcodeFormat(barcode)) {
      print('Invalid barcode format: $barcode');
      return BarcodeScanResult.invalidFormat(
        barcode: barcode,
        message: 'Invalid barcode format. Please try scanning again.',
      );
    }

    // Clean the barcode
    final cleanBarcode = _barcodeService.cleanBarcode(barcode);
    print('Cleaned barcode: $cleanBarcode');

    // Lookup the barcode
    print('About to call _barcodeService.lookupBarcode');
    final result = await _barcodeService.lookupBarcode(cleanBarcode);
    print('lookupBarcode returned: $result');

    if (result == null) {
      return BarcodeScanResult.error(
        barcode: cleanBarcode,
        message: 'Unable to connect to nutrition database.',
      );
    }

    // Handle different result types
    switch (result) {
      case BarcodeResultSuccess():
        // Map to Food domain model
        final food = _mappingService.mapToFood(result.product);

        // Cache the food to the database so it becomes searchable
        await cacheScannedFood(food);

        return BarcodeScanResult.success(
          barcode: cleanBarcode,
          food: food,
          apiProduct: result.product,
        );

      case BarcodeResultNotFound():
        return BarcodeScanResult.notFound(
          barcode: cleanBarcode,
          message: result.message ?? 'Product not found in nutrition databases.',
        );

      case BarcodeResultError():
        return BarcodeScanResult.error(
          barcode: cleanBarcode,
          message: result.message ?? 'An error occurred during lookup.',
        );
    }
  }

  /// Validate barcode format
  bool isValidBarcodeFormat(String barcode) {
    return _barcodeService.isValidBarcodeFormat(barcode);
  }

  /// Cache a scanned food to the local database so it becomes searchable
  Future<void> cacheScannedFood(Food food) async {
    try {
      print('Caching scanned food to database: ${food.name}');

      // Convert Food domain model to database format
      final foodData = _convertFoodToDatabaseFormat(food);

      // Cache to database
      await _database.cacheFoods([foodData]);

      print('Successfully cached food: ${food.id}');
    } catch (e) {
      print('Error caching scanned food: $e');
      // Don't throw - caching failure shouldn't break the scanning flow
    }
  }

  /// Convert Food domain model to database format
  Map<String, dynamic> _convertFoodToDatabaseFormat(Food food) {
    return {
      'id': food.id,
      'name': food.name,
      'display_name': food.name,
      'display_name_plural': food.name,
      'display_override': null,
      'image_address': food.imageAddress,
      'description': food.description,
      'instructions': food.instructions,
      'serving_amount': 1.0, // Simplified approach always uses 1.0
      // Deprecated fields removed: serving_unit, serving_unit_plural, serving_qualifier, serving_size
      'before_run_suitable': food.beforeRunSuitable,
      'during_run_suitable': food.duringRunSuitable,
      'after_run_suitable': true, // Default for scanned foods
      'run_portable': food.runPortable,
      'requires_preparation': food.requiresPreparation,
      'aid_station_available': food.aidStationAvailable,
      'is_electrolyte': false, // Most scanned foods aren't electrolytes
      'to_exclude_from_solver': false,
      'max_servings_before': food.maxServingsBefore,
      'max_servings_during': food.maxServingsDuring,
      'max_servings_after': 3, // Default for scanned foods
      'sodium_mg': food.sodiumMg,
      'caffeine_mg': food.caffeineMg,
      'potassium_mg': food.potassiumMg,
      'fat_per_serving': food.fatPerServing,
      'carbs_per_serving': food.carbsPerServing,
      'protein_per_serving': food.proteinPerServing,
      'calories_per_serving': food.caloriesPerServing,
      'fluid_ml_per_serving': food.fluidMlPerServing,
      'product_type': 'scanned', // Mark as scanned product
      'purchase_url': null,
      'affiliate_source': null,
      'tags': ['scanned', 'barcode'], // Add tags for filtering
      'created_at': DateTime.now().toIso8601String(),
      'updated_at': DateTime.now().toIso8601String(),
    };
  }
}

/// Result of a barcode scan operation including Food mapping
sealed class BarcodeScanResult {
  final String barcode;

  const BarcodeScanResult({required this.barcode});

  /// Successful scan with mapped Food model
  const factory BarcodeScanResult.success({
    required String barcode,
    required Food food,
    required dynamic apiProduct, // ApiFoodProduct
  }) = BarcodeScanResultSuccess;

  /// Product not found in databases
  const factory BarcodeScanResult.notFound({
    required String barcode,
    required String message,
  }) = BarcodeScanResultNotFound;

  /// Error during scanning
  const factory BarcodeScanResult.error({
    required String barcode,
    required String message,
  }) = BarcodeScanResultError;

  /// Invalid barcode format
  const factory BarcodeScanResult.invalidFormat({
    required String barcode,
    required String message,
  }) = BarcodeScanResultInvalidFormat;

  /// Check if the result is successful
  bool get isSuccess => this is BarcodeScanResultSuccess;

  /// Check if the result is not found
  bool get isNotFound => this is BarcodeScanResultNotFound;

  /// Check if the result is an error
  bool get isError => this is BarcodeScanResultError;

  /// Check if the barcode format is invalid
  bool get isInvalidFormat => this is BarcodeScanResultInvalidFormat;

  /// Get the food if successful, null otherwise
  Food? get food {
    if (this is BarcodeScanResultSuccess) {
      return (this as BarcodeScanResultSuccess).food;
    }
    return null;
  }

  /// Get the error/not found message
  String? get message {
    switch (this) {
      case BarcodeScanResultNotFound(:final message):
        return message;
      case BarcodeScanResultError(:final message):
        return message;
      case BarcodeScanResultInvalidFormat(:final message):
        return message;
      case BarcodeScanResultSuccess():
        return null;
    }
  }
}

/// Successful barcode scan result
final class BarcodeScanResultSuccess extends BarcodeScanResult {
  final Food food;
  final dynamic apiProduct; // ApiFoodProduct

  const BarcodeScanResultSuccess({
    required super.barcode,
    required this.food,
    required this.apiProduct,
  });
}

/// Product not found result
final class BarcodeScanResultNotFound extends BarcodeScanResult {
  final String message;

  const BarcodeScanResultNotFound({
    required super.barcode,
    required this.message,
  });
}

/// Error during scan result
final class BarcodeScanResultError extends BarcodeScanResult {
  final String message;

  const BarcodeScanResultError({
    required super.barcode,
    required this.message,
  });
}

/// Invalid barcode format result
final class BarcodeScanResultInvalidFormat extends BarcodeScanResult {
  final String message;

  const BarcodeScanResultInvalidFormat({
    required super.barcode,
    required this.message,
  });
}

@riverpod
BarcodeScannerService barcodeScannerService(Ref ref) {
  return BarcodeScannerService(
    barcodeService: ref.watch(supabaseBarcodeServiceProvider),
    mappingService: ref.watch(foodMappingServiceProvider),
    database: ref.read(databaseProvider).requireValue,
  );
}