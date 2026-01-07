// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'bulk_nutrition_plan_service.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Provider for BulkNutritionPlanService

@ProviderFor(bulkNutritionPlanService)
const bulkNutritionPlanServiceProvider = BulkNutritionPlanServiceProvider._();

/// Provider for BulkNutritionPlanService

final class BulkNutritionPlanServiceProvider
    extends
        $FunctionalProvider<
          BulkNutritionPlanService,
          BulkNutritionPlanService,
          BulkNutritionPlanService
        >
    with $Provider<BulkNutritionPlanService> {
  /// Provider for BulkNutritionPlanService
  const BulkNutritionPlanServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'bulkNutritionPlanServiceProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$bulkNutritionPlanServiceHash();

  @$internal
  @override
  $ProviderElement<BulkNutritionPlanService> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  BulkNutritionPlanService create(Ref ref) {
    return bulkNutritionPlanService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(BulkNutritionPlanService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<BulkNutritionPlanService>(value),
    );
  }
}

String _$bulkNutritionPlanServiceHash() =>
    r'9c9fa1ef918e5ca280d197819725d1c55aed3b74';
