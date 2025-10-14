// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'carb_loading_user_food_repository.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(carbLoadingUserFoodRepository)
const carbLoadingUserFoodRepositoryProvider =
    CarbLoadingUserFoodRepositoryProvider._();

final class CarbLoadingUserFoodRepositoryProvider
    extends
        $FunctionalProvider<
          CarbLoadingUserFoodRepository,
          CarbLoadingUserFoodRepository,
          CarbLoadingUserFoodRepository
        >
    with $Provider<CarbLoadingUserFoodRepository> {
  const CarbLoadingUserFoodRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'carbLoadingUserFoodRepositoryProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$carbLoadingUserFoodRepositoryHash();

  @$internal
  @override
  $ProviderElement<CarbLoadingUserFoodRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  CarbLoadingUserFoodRepository create(Ref ref) {
    return carbLoadingUserFoodRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(CarbLoadingUserFoodRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<CarbLoadingUserFoodRepository>(
        value,
      ),
    );
  }
}

String _$carbLoadingUserFoodRepositoryHash() =>
    r'3a3a2176755cfc5adff08d232bf9d63e8b8bd794';
