// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'nutrition_plan_repository.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Riverpod provider for NutritionPlanRepository

@ProviderFor(nutritionPlanRepository)
const nutritionPlanRepositoryProvider = NutritionPlanRepositoryProvider._();

/// Riverpod provider for NutritionPlanRepository

final class NutritionPlanRepositoryProvider
    extends
        $FunctionalProvider<
          AsyncValue<NutritionPlanRepository>,
          NutritionPlanRepository,
          FutureOr<NutritionPlanRepository>
        >
    with
        $FutureModifier<NutritionPlanRepository>,
        $FutureProvider<NutritionPlanRepository> {
  /// Riverpod provider for NutritionPlanRepository
  const NutritionPlanRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'nutritionPlanRepositoryProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$nutritionPlanRepositoryHash();

  @$internal
  @override
  $FutureProviderElement<NutritionPlanRepository> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<NutritionPlanRepository> create(Ref ref) {
    return nutritionPlanRepository(ref);
  }
}

String _$nutritionPlanRepositoryHash() =>
    r'966be2994923b5b88e98387c8d5698a117b7e2b7';
