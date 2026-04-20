// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'carb_loading_service.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(carbLoadingService)
const carbLoadingServiceProvider = CarbLoadingServiceProvider._();

final class CarbLoadingServiceProvider
    extends
        $FunctionalProvider<
          CarbLoadingService,
          CarbLoadingService,
          CarbLoadingService
        >
    with $Provider<CarbLoadingService> {
  const CarbLoadingServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'carbLoadingServiceProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$carbLoadingServiceHash();

  @$internal
  @override
  $ProviderElement<CarbLoadingService> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  CarbLoadingService create(Ref ref) {
    return carbLoadingService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(CarbLoadingService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<CarbLoadingService>(value),
    );
  }
}

String _$carbLoadingServiceHash() =>
    r'0f60f31f6b7d9eba3cf7c58b05791413ec647606';
