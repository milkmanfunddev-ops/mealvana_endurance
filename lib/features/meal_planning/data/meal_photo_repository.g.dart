// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'meal_photo_repository.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(mealPhotoRepository)
const mealPhotoRepositoryProvider = MealPhotoRepositoryProvider._();

final class MealPhotoRepositoryProvider
    extends
        $FunctionalProvider<
          MealPhotoRepository,
          MealPhotoRepository,
          MealPhotoRepository
        >
    with $Provider<MealPhotoRepository> {
  const MealPhotoRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'mealPhotoRepositoryProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$mealPhotoRepositoryHash();

  @$internal
  @override
  $ProviderElement<MealPhotoRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  MealPhotoRepository create(Ref ref) {
    return mealPhotoRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(MealPhotoRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<MealPhotoRepository>(value),
    );
  }
}

String _$mealPhotoRepositoryHash() =>
    r'fa50e11fefb74d9e7d692e611722831ded9731e2';
