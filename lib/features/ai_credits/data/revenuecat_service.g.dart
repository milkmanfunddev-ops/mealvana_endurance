// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'revenuecat_service.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(revenueCatService)
const revenueCatServiceProvider = RevenueCatServiceProvider._();

final class RevenueCatServiceProvider
    extends
        $FunctionalProvider<
          RevenueCatService,
          RevenueCatService,
          RevenueCatService
        >
    with $Provider<RevenueCatService> {
  const RevenueCatServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'revenueCatServiceProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$revenueCatServiceHash();

  @$internal
  @override
  $ProviderElement<RevenueCatService> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  RevenueCatService create(Ref ref) {
    return revenueCatService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(RevenueCatService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<RevenueCatService>(value),
    );
  }
}

String _$revenueCatServiceHash() => r'7df35a1333c3087c9c45ac3b4b6ae247151ba07e';
