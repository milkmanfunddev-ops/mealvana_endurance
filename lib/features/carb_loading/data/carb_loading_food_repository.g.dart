// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'carb_loading_food_repository.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(carbLoadingFoodRepository)
const carbLoadingFoodRepositoryProvider = CarbLoadingFoodRepositoryProvider._();

final class CarbLoadingFoodRepositoryProvider
    extends
        $FunctionalProvider<
          CarbLoadingFoodRepository,
          CarbLoadingFoodRepository,
          CarbLoadingFoodRepository
        >
    with $Provider<CarbLoadingFoodRepository> {
  const CarbLoadingFoodRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'carbLoadingFoodRepositoryProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$carbLoadingFoodRepositoryHash();

  @$internal
  @override
  $ProviderElement<CarbLoadingFoodRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  CarbLoadingFoodRepository create(Ref ref) {
    return carbLoadingFoodRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(CarbLoadingFoodRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<CarbLoadingFoodRepository>(value),
    );
  }
}

String _$carbLoadingFoodRepositoryHash() =>
    r'4ea4e3c16eb71660f2bbf49ea5905d6d1fa2ecd9';
