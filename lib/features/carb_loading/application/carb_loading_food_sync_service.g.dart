// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'carb_loading_food_sync_service.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(carbLoadingFoodSyncService)
const carbLoadingFoodSyncServiceProvider =
    CarbLoadingFoodSyncServiceProvider._();

final class CarbLoadingFoodSyncServiceProvider
    extends
        $FunctionalProvider<
          CarbLoadingFoodSyncService,
          CarbLoadingFoodSyncService,
          CarbLoadingFoodSyncService
        >
    with $Provider<CarbLoadingFoodSyncService> {
  const CarbLoadingFoodSyncServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'carbLoadingFoodSyncServiceProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$carbLoadingFoodSyncServiceHash();

  @$internal
  @override
  $ProviderElement<CarbLoadingFoodSyncService> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  CarbLoadingFoodSyncService create(Ref ref) {
    return carbLoadingFoodSyncService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(CarbLoadingFoodSyncService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<CarbLoadingFoodSyncService>(value),
    );
  }
}

String _$carbLoadingFoodSyncServiceHash() =>
    r'b4ac817187d63a96170e14a1549841d8e779bc1f';
