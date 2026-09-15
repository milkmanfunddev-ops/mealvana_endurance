// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'meal_review_repository.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(mealReviewRepository)
const mealReviewRepositoryProvider = MealReviewRepositoryProvider._();

final class MealReviewRepositoryProvider
    extends
        $FunctionalProvider<
          MealReviewRepository,
          MealReviewRepository,
          MealReviewRepository
        >
    with $Provider<MealReviewRepository> {
  const MealReviewRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'mealReviewRepositoryProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$mealReviewRepositoryHash();

  @$internal
  @override
  $ProviderElement<MealReviewRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  MealReviewRepository create(Ref ref) {
    return mealReviewRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(MealReviewRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<MealReviewRepository>(value),
    );
  }
}

String _$mealReviewRepositoryHash() =>
    r'c3b0a8518f802f06c956c52524421b94526f1fb7';
