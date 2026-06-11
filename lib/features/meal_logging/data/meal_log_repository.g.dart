// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'meal_log_repository.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(mealLogRepository)
const mealLogRepositoryProvider = MealLogRepositoryProvider._();

final class MealLogRepositoryProvider
    extends
        $FunctionalProvider<
          MealLogRepository,
          MealLogRepository,
          MealLogRepository
        >
    with $Provider<MealLogRepository> {
  const MealLogRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'mealLogRepositoryProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$mealLogRepositoryHash();

  @$internal
  @override
  $ProviderElement<MealLogRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  MealLogRepository create(Ref ref) {
    return mealLogRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(MealLogRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<MealLogRepository>(value),
    );
  }
}

String _$mealLogRepositoryHash() => r'2e23f467d6d7e00cc18ed7e78f25edef650b5ea1';
