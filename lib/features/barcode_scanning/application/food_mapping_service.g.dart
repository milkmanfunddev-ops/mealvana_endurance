// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'food_mapping_service.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(foodMappingService)
const foodMappingServiceProvider = FoodMappingServiceProvider._();

final class FoodMappingServiceProvider
    extends
        $FunctionalProvider<
          FoodMappingService,
          FoodMappingService,
          FoodMappingService
        >
    with $Provider<FoodMappingService> {
  const FoodMappingServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'foodMappingServiceProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$foodMappingServiceHash();

  @$internal
  @override
  $ProviderElement<FoodMappingService> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  FoodMappingService create(Ref ref) {
    return foodMappingService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(FoodMappingService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<FoodMappingService>(value),
    );
  }
}

String _$foodMappingServiceHash() =>
    r'3c929e4024023919c59ffe8774f0aa26319422b3';
