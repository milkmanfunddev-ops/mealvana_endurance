// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'shopping_tick_store.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(shoppingTickStore)
const shoppingTickStoreProvider = ShoppingTickStoreProvider._();

final class ShoppingTickStoreProvider
    extends
        $FunctionalProvider<
          ShoppingTickStore,
          ShoppingTickStore,
          ShoppingTickStore
        >
    with $Provider<ShoppingTickStore> {
  const ShoppingTickStoreProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'shoppingTickStoreProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$shoppingTickStoreHash();

  @$internal
  @override
  $ProviderElement<ShoppingTickStore> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  ShoppingTickStore create(Ref ref) {
    return shoppingTickStore(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ShoppingTickStore value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ShoppingTickStore>(value),
    );
  }
}

String _$shoppingTickStoreHash() => r'1a7376c385dc7d50cfe7bd631ad88292a6df0d17';
