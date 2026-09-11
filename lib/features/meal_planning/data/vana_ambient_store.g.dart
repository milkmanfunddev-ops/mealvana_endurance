// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'vana_ambient_store.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(vanaAmbientStore)
const vanaAmbientStoreProvider = VanaAmbientStoreProvider._();

final class VanaAmbientStoreProvider
    extends
        $FunctionalProvider<
          VanaAmbientStore,
          VanaAmbientStore,
          VanaAmbientStore
        >
    with $Provider<VanaAmbientStore> {
  const VanaAmbientStoreProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'vanaAmbientStoreProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$vanaAmbientStoreHash();

  @$internal
  @override
  $ProviderElement<VanaAmbientStore> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  VanaAmbientStore create(Ref ref) {
    return vanaAmbientStore(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(VanaAmbientStore value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<VanaAmbientStore>(value),
    );
  }
}

String _$vanaAmbientStoreHash() => r'069ec97240920b7ecb06c94df8beab032900c595';
