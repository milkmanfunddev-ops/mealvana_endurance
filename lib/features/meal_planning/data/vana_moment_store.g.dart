// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'vana_moment_store.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(vanaMomentStore)
const vanaMomentStoreProvider = VanaMomentStoreProvider._();

final class VanaMomentStoreProvider
    extends
        $FunctionalProvider<VanaMomentStore, VanaMomentStore, VanaMomentStore>
    with $Provider<VanaMomentStore> {
  const VanaMomentStoreProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'vanaMomentStoreProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$vanaMomentStoreHash();

  @$internal
  @override
  $ProviderElement<VanaMomentStore> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  VanaMomentStore create(Ref ref) {
    return vanaMomentStore(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(VanaMomentStore value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<VanaMomentStore>(value),
    );
  }
}

String _$vanaMomentStoreHash() => r'e293d0c2f2981e29d1117e6bdc2539b8208c9b43';
