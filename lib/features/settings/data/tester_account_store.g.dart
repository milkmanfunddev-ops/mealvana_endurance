// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'tester_account_store.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(testerAccountStore)
const testerAccountStoreProvider = TesterAccountStoreProvider._();

final class TesterAccountStoreProvider
    extends
        $FunctionalProvider<
          TesterAccountStore,
          TesterAccountStore,
          TesterAccountStore
        >
    with $Provider<TesterAccountStore> {
  const TesterAccountStoreProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'testerAccountStoreProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$testerAccountStoreHash();

  @$internal
  @override
  $ProviderElement<TesterAccountStore> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  TesterAccountStore create(Ref ref) {
    return testerAccountStore(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(TesterAccountStore value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<TesterAccountStore>(value),
    );
  }
}

String _$testerAccountStoreHash() =>
    r'11429656a4130f40a05db5940dcfdea615a08fd4';
