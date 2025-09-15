// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'nutrition_plan_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$currentNutritionPlanHash() =>
    r'ffe55a43fe2e32e5b2271eb25a40bb17f7a2bc80';

/// Provider for current nutrition plan
///
/// Copied from [currentNutritionPlan].
@ProviderFor(currentNutritionPlan)
final currentNutritionPlanProvider =
    AutoDisposeProvider<NutritionPlan?>.internal(
  currentNutritionPlan,
  name: r'currentNutritionPlanProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$currentNutritionPlanHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef CurrentNutritionPlanRef = AutoDisposeProviderRef<NutritionPlan?>;
String _$nutritionRecommendationsHash() =>
    r'e58a1f981623d025052d89429f72f9483df1cf4e';

/// Provider for nutrition recommendations
///
/// Copied from [nutritionRecommendations].
@ProviderFor(nutritionRecommendations)
final nutritionRecommendationsProvider =
    AutoDisposeProvider<List<String>>.internal(
  nutritionRecommendations,
  name: r'nutritionRecommendationsProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$nutritionRecommendationsHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef NutritionRecommendationsRef = AutoDisposeProviderRef<List<String>>;
String _$nutritionPlanControllerHash() =>
    r'47ca45bc8b1f76a69a5e02d2dbeb76ba7d1a3508';

/// Controller for managing nutrition plan generation and display with save state
///
/// Copied from [NutritionPlanController].
@ProviderFor(NutritionPlanController)
final nutritionPlanControllerProvider = AutoDisposeAsyncNotifierProvider<
    NutritionPlanController, NutritionPlanState>.internal(
  NutritionPlanController.new,
  name: r'nutritionPlanControllerProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$nutritionPlanControllerHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$NutritionPlanController
    = AutoDisposeAsyncNotifier<NutritionPlanState>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
