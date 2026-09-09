// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'kroger_repository.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(krogerRepository)
const krogerRepositoryProvider = KrogerRepositoryProvider._();

final class KrogerRepositoryProvider
    extends
        $FunctionalProvider<
          KrogerRepository,
          KrogerRepository,
          KrogerRepository
        >
    with $Provider<KrogerRepository> {
  const KrogerRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'krogerRepositoryProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$krogerRepositoryHash();

  @$internal
  @override
  $ProviderElement<KrogerRepository> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  KrogerRepository create(Ref ref) {
    return krogerRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(KrogerRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<KrogerRepository>(value),
    );
  }
}

String _$krogerRepositoryHash() => r'a8ac3cc78c89a3abf5f98dd3affd04b042ac3859';
