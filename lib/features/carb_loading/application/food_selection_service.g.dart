// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'food_selection_service.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(foodSelectionService)
const foodSelectionServiceProvider = FoodSelectionServiceProvider._();

final class FoodSelectionServiceProvider
    extends
        $FunctionalProvider<
          FoodSelectionService,
          FoodSelectionService,
          FoodSelectionService
        >
    with $Provider<FoodSelectionService> {
  const FoodSelectionServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'foodSelectionServiceProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$foodSelectionServiceHash();

  @$internal
  @override
  $ProviderElement<FoodSelectionService> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  FoodSelectionService create(Ref ref) {
    return foodSelectionService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(FoodSelectionService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<FoodSelectionService>(value),
    );
  }
}

String _$foodSelectionServiceHash() =>
    r'c03f57211e8baec1957b72f469783bd9d5906d26';
