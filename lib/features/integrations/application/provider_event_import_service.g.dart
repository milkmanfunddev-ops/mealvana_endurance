// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'provider_event_import_service.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(providerEventImportService)
const providerEventImportServiceProvider =
    ProviderEventImportServiceProvider._();

final class ProviderEventImportServiceProvider
    extends
        $FunctionalProvider<
          ProviderEventImportService,
          ProviderEventImportService,
          ProviderEventImportService
        >
    with $Provider<ProviderEventImportService> {
  const ProviderEventImportServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'providerEventImportServiceProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$providerEventImportServiceHash();

  @$internal
  @override
  $ProviderElement<ProviderEventImportService> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  ProviderEventImportService create(Ref ref) {
    return providerEventImportService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ProviderEventImportService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ProviderEventImportService>(value),
    );
  }
}

String _$providerEventImportServiceHash() =>
    r'6bed4b8aca5869f4191a96cfdfd2a47f1b959fe2';
