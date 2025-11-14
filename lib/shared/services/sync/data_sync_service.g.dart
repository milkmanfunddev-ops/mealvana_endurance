// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'data_sync_service.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(dataSyncService)
const dataSyncServiceProvider = DataSyncServiceProvider._();

final class DataSyncServiceProvider
    extends
        $FunctionalProvider<DataSyncService, DataSyncService, DataSyncService>
    with $Provider<DataSyncService> {
  const DataSyncServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'dataSyncServiceProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$dataSyncServiceHash();

  @$internal
  @override
  $ProviderElement<DataSyncService> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  DataSyncService create(Ref ref) {
    return dataSyncService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(DataSyncService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<DataSyncService>(value),
    );
  }
}

String _$dataSyncServiceHash() => r'232acff77e4e8ab89b242de8010cd8efdc34e1ca';
