// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'pending_signup_store.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(pendingSignupStore)
const pendingSignupStoreProvider = PendingSignupStoreProvider._();

final class PendingSignupStoreProvider
    extends
        $FunctionalProvider<
          PendingSignupStore,
          PendingSignupStore,
          PendingSignupStore
        >
    with $Provider<PendingSignupStore> {
  const PendingSignupStoreProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'pendingSignupStoreProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$pendingSignupStoreHash();

  @$internal
  @override
  $ProviderElement<PendingSignupStore> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  PendingSignupStore create(Ref ref) {
    return pendingSignupStore(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(PendingSignupStore value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<PendingSignupStore>(value),
    );
  }
}

String _$pendingSignupStoreHash() =>
    r'24f545ff4109047e0088981e87df09fcbca64bc9';
