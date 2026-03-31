// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'food_operations_service.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Service for food-related operations on nutrition plans.
///
/// Handles:
/// - Creating FoodItemData from food objects
/// - Quantity normalization and rounding
/// - Quantity label building
/// - Liquid/electrolyte food detection

@ProviderFor(foodOperationsService)
const foodOperationsServiceProvider = FoodOperationsServiceProvider._();

/// Service for food-related operations on nutrition plans.
///
/// Handles:
/// - Creating FoodItemData from food objects
/// - Quantity normalization and rounding
/// - Quantity label building
/// - Liquid/electrolyte food detection

final class FoodOperationsServiceProvider
    extends
        $FunctionalProvider<
          FoodOperationsService,
          FoodOperationsService,
          FoodOperationsService
        >
    with $Provider<FoodOperationsService> {
  /// Service for food-related operations on nutrition plans.
  ///
  /// Handles:
  /// - Creating FoodItemData from food objects
  /// - Quantity normalization and rounding
  /// - Quantity label building
  /// - Liquid/electrolyte food detection
  const FoodOperationsServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'foodOperationsServiceProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$foodOperationsServiceHash();

  @$internal
  @override
  $ProviderElement<FoodOperationsService> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  FoodOperationsService create(Ref ref) {
    return foodOperationsService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(FoodOperationsService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<FoodOperationsService>(value),
    );
  }
}

String _$foodOperationsServiceHash() =>
    r'c196093690a83d942ecc207fb79498e526188c30';
