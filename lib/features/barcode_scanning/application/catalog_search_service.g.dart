// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'catalog_search_service.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(catalogSearchService)
const catalogSearchServiceProvider = CatalogSearchServiceProvider._();

final class CatalogSearchServiceProvider
    extends
        $FunctionalProvider<
          CatalogSearchService,
          CatalogSearchService,
          CatalogSearchService
        >
    with $Provider<CatalogSearchService> {
  const CatalogSearchServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'catalogSearchServiceProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$catalogSearchServiceHash();

  @$internal
  @override
  $ProviderElement<CatalogSearchService> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  CatalogSearchService create(Ref ref) {
    return catalogSearchService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(CatalogSearchService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<CatalogSearchService>(value),
    );
  }
}

String _$catalogSearchServiceHash() =>
    r'a0b4c932e7a724d33fda6775cbbca66808ed2181';
