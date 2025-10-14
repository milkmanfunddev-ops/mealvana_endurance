// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'barcode_scanner_service.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(barcodeScannerService)
const barcodeScannerServiceProvider = BarcodeScannerServiceProvider._();

final class BarcodeScannerServiceProvider
    extends
        $FunctionalProvider<
          BarcodeScannerService,
          BarcodeScannerService,
          BarcodeScannerService
        >
    with $Provider<BarcodeScannerService> {
  const BarcodeScannerServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'barcodeScannerServiceProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$barcodeScannerServiceHash();

  @$internal
  @override
  $ProviderElement<BarcodeScannerService> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  BarcodeScannerService create(Ref ref) {
    return barcodeScannerService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(BarcodeScannerService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<BarcodeScannerService>(value),
    );
  }
}

String _$barcodeScannerServiceHash() =>
    r'c93694e0c2e3a10bd805aafe36b6ad8e094f0cea';
