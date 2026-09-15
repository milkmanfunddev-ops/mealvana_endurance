// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'dev_tools_switch_store.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(devToolsSwitchStore)
const devToolsSwitchStoreProvider = DevToolsSwitchStoreProvider._();

final class DevToolsSwitchStoreProvider
    extends
        $FunctionalProvider<
          DevToolsSwitchStore,
          DevToolsSwitchStore,
          DevToolsSwitchStore
        >
    with $Provider<DevToolsSwitchStore> {
  const DevToolsSwitchStoreProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'devToolsSwitchStoreProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$devToolsSwitchStoreHash();

  @$internal
  @override
  $ProviderElement<DevToolsSwitchStore> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  DevToolsSwitchStore create(Ref ref) {
    return devToolsSwitchStore(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(DevToolsSwitchStore value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<DevToolsSwitchStore>(value),
    );
  }
}

String _$devToolsSwitchStoreHash() =>
    r'0bb09fadc95f69c6f91bf5958ab459487df5168a';
