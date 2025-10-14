// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'meal_type_repository.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(mealTypeRepository)
const mealTypeRepositoryProvider = MealTypeRepositoryProvider._();

final class MealTypeRepositoryProvider
    extends
        $FunctionalProvider<
          MealTypeRepository,
          MealTypeRepository,
          MealTypeRepository
        >
    with $Provider<MealTypeRepository> {
  const MealTypeRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'mealTypeRepositoryProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$mealTypeRepositoryHash();

  @$internal
  @override
  $ProviderElement<MealTypeRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  MealTypeRepository create(Ref ref) {
    return mealTypeRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(MealTypeRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<MealTypeRepository>(value),
    );
  }
}

String _$mealTypeRepositoryHash() =>
    r'2c849e18d16eb41ed5145af6abfbc501ee483cf2';
