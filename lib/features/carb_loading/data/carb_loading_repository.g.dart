// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'carb_loading_repository.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(carbLoadingRepository)
const carbLoadingRepositoryProvider = CarbLoadingRepositoryProvider._();

final class CarbLoadingRepositoryProvider
    extends
        $FunctionalProvider<
          CarbLoadingRepository,
          CarbLoadingRepository,
          CarbLoadingRepository
        >
    with $Provider<CarbLoadingRepository> {
  const CarbLoadingRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'carbLoadingRepositoryProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$carbLoadingRepositoryHash();

  @$internal
  @override
  $ProviderElement<CarbLoadingRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  CarbLoadingRepository create(Ref ref) {
    return carbLoadingRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(CarbLoadingRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<CarbLoadingRepository>(value),
    );
  }
}

String _$carbLoadingRepositoryHash() =>
    r'6b37c51ed0beb37cbd9b90c538992b11cbbdf9d7';
