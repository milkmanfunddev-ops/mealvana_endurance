// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'credits_repository.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(creditsRepository)
const creditsRepositoryProvider = CreditsRepositoryProvider._();

final class CreditsRepositoryProvider
    extends
        $FunctionalProvider<
          CreditsRepository,
          CreditsRepository,
          CreditsRepository
        >
    with $Provider<CreditsRepository> {
  const CreditsRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'creditsRepositoryProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$creditsRepositoryHash();

  @$internal
  @override
  $ProviderElement<CreditsRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  CreditsRepository create(Ref ref) {
    return creditsRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(CreditsRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<CreditsRepository>(value),
    );
  }
}

String _$creditsRepositoryHash() => r'16d2523c7a17abb8b06b82383e8d716a0c4bff25';
