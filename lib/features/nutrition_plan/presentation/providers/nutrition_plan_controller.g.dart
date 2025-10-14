// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'nutrition_plan_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Controller for managing nutrition plan generation and display with save state

@ProviderFor(NutritionPlanController)
const nutritionPlanControllerProvider = NutritionPlanControllerProvider._();

/// Controller for managing nutrition plan generation and display with save state
final class NutritionPlanControllerProvider
    extends
        $AsyncNotifierProvider<NutritionPlanController, NutritionPlanState> {
  /// Controller for managing nutrition plan generation and display with save state
  const NutritionPlanControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'nutritionPlanControllerProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$nutritionPlanControllerHash();

  @$internal
  @override
  NutritionPlanController create() => NutritionPlanController();
}

String _$nutritionPlanControllerHash() =>
    r'aba1e10ed23af13bca603ccb55d9e042ad3a0feb';

/// Controller for managing nutrition plan generation and display with save state

abstract class _$NutritionPlanController
    extends $AsyncNotifier<NutritionPlanState> {
  FutureOr<NutritionPlanState> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build();
    final ref =
        this.ref as $Ref<AsyncValue<NutritionPlanState>, NutritionPlanState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<NutritionPlanState>, NutritionPlanState>,
              AsyncValue<NutritionPlanState>,
              Object?,
              Object?
            >;
    element.handleValue(ref, created);
  }
}

/// Provider for current nutrition plan

@ProviderFor(currentNutritionPlan)
const currentNutritionPlanProvider = CurrentNutritionPlanProvider._();

/// Provider for current nutrition plan

final class CurrentNutritionPlanProvider
    extends $FunctionalProvider<NutritionPlan?, NutritionPlan?, NutritionPlan?>
    with $Provider<NutritionPlan?> {
  /// Provider for current nutrition plan
  const CurrentNutritionPlanProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'currentNutritionPlanProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$currentNutritionPlanHash();

  @$internal
  @override
  $ProviderElement<NutritionPlan?> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  NutritionPlan? create(Ref ref) {
    return currentNutritionPlan(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(NutritionPlan? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<NutritionPlan?>(value),
    );
  }
}

String _$currentNutritionPlanHash() =>
    r'63fa7a4c1ef30e673c8f51eb3b60a64478f22208';

/// Provider for nutrition recommendations

@ProviderFor(nutritionRecommendations)
const nutritionRecommendationsProvider = NutritionRecommendationsProvider._();

/// Provider for nutrition recommendations

final class NutritionRecommendationsProvider
    extends $FunctionalProvider<List<String>, List<String>, List<String>>
    with $Provider<List<String>> {
  /// Provider for nutrition recommendations
  const NutritionRecommendationsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'nutritionRecommendationsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$nutritionRecommendationsHash();

  @$internal
  @override
  $ProviderElement<List<String>> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  List<String> create(Ref ref) {
    return nutritionRecommendations(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(List<String> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<List<String>>(value),
    );
  }
}

String _$nutritionRecommendationsHash() =>
    r'e58a1f981623d025052d89429f72f9483df1cf4e';
