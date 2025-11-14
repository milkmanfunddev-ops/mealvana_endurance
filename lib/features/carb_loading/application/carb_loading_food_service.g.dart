// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'carb_loading_food_service.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(carbLoadingFoodService)
const carbLoadingFoodServiceProvider = CarbLoadingFoodServiceProvider._();

final class CarbLoadingFoodServiceProvider
    extends
        $FunctionalProvider<
          CarbLoadingFoodService,
          CarbLoadingFoodService,
          CarbLoadingFoodService
        >
    with $Provider<CarbLoadingFoodService> {
  const CarbLoadingFoodServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'carbLoadingFoodServiceProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$carbLoadingFoodServiceHash();

  @$internal
  @override
  $ProviderElement<CarbLoadingFoodService> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  CarbLoadingFoodService create(Ref ref) {
    return carbLoadingFoodService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(CarbLoadingFoodService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<CarbLoadingFoodService>(value),
    );
  }
}

String _$carbLoadingFoodServiceHash() =>
    r'ca325312704e8dbfd56b0f8b1489f6e25279d856';
