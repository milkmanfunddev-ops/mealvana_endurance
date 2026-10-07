// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'supabase_barcode_service.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(supabaseBarcodeService)
const supabaseBarcodeServiceProvider = SupabaseBarcodeServiceProvider._();

final class SupabaseBarcodeServiceProvider
    extends
        $FunctionalProvider<
          SupabaseBarcodeService,
          SupabaseBarcodeService,
          SupabaseBarcodeService
        >
    with $Provider<SupabaseBarcodeService> {
  const SupabaseBarcodeServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'supabaseBarcodeServiceProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$supabaseBarcodeServiceHash();

  @$internal
  @override
  $ProviderElement<SupabaseBarcodeService> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  SupabaseBarcodeService create(Ref ref) {
    return supabaseBarcodeService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(SupabaseBarcodeService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<SupabaseBarcodeService>(value),
    );
  }
}

String _$supabaseBarcodeServiceHash() =>
    r'b3946a56a1cbdd91e57c8a42f08dacf7409f4d58';
