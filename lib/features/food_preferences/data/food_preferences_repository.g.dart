// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'food_preferences_repository.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Repository provider following Andrea's pattern

@ProviderFor(foodPreferencesRepository)
const foodPreferencesRepositoryProvider = FoodPreferencesRepositoryProvider._();

/// Repository provider following Andrea's pattern

final class FoodPreferencesRepositoryProvider
    extends
        $FunctionalProvider<
          AsyncValue<FoodPreferencesRepository>,
          FoodPreferencesRepository,
          FutureOr<FoodPreferencesRepository>
        >
    with
        $FutureModifier<FoodPreferencesRepository>,
        $FutureProvider<FoodPreferencesRepository> {
  /// Repository provider following Andrea's pattern
  const FoodPreferencesRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'foodPreferencesRepositoryProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$foodPreferencesRepositoryHash();

  @$internal
  @override
  $FutureProviderElement<FoodPreferencesRepository> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<FoodPreferencesRepository> create(Ref ref) {
    return foodPreferencesRepository(ref);
  }
}

String _$foodPreferencesRepositoryHash() =>
    r'fba8676db91984b559a9e4f4954b5cd37df4c71c';
