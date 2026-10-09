// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'product_detail_service.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(productDetailService)
const productDetailServiceProvider = ProductDetailServiceProvider._();

final class ProductDetailServiceProvider
    extends
        $FunctionalProvider<
          ProductDetailService,
          ProductDetailService,
          ProductDetailService
        >
    with $Provider<ProductDetailService> {
  const ProductDetailServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'productDetailServiceProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$productDetailServiceHash();

  @$internal
  @override
  $ProviderElement<ProductDetailService> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  ProductDetailService create(Ref ref) {
    return productDetailService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ProductDetailService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ProductDetailService>(value),
    );
  }
}

String _$productDetailServiceHash() =>
    r'4a2504add700631ba16ddc71094d09c3bb899ed8';
