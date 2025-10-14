// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'carb_loading_day_meal_repository.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(carbLoadingDayMealRepository)
const carbLoadingDayMealRepositoryProvider =
    CarbLoadingDayMealRepositoryProvider._();

final class CarbLoadingDayMealRepositoryProvider
    extends
        $FunctionalProvider<
          CarbLoadingDayMealRepository,
          CarbLoadingDayMealRepository,
          CarbLoadingDayMealRepository
        >
    with $Provider<CarbLoadingDayMealRepository> {
  const CarbLoadingDayMealRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'carbLoadingDayMealRepositoryProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$carbLoadingDayMealRepositoryHash();

  @$internal
  @override
  $ProviderElement<CarbLoadingDayMealRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  CarbLoadingDayMealRepository create(Ref ref) {
    return carbLoadingDayMealRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(CarbLoadingDayMealRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<CarbLoadingDayMealRepository>(value),
    );
  }
}

String _$carbLoadingDayMealRepositoryHash() =>
    r'9277da22f03261da2476f688d667f9dd4f60bcb3';
