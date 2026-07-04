// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'nutrition_product_search_service.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(nutritionProductSearchService)
const nutritionProductSearchServiceProvider =
    NutritionProductSearchServiceProvider._();

final class NutritionProductSearchServiceProvider
    extends
        $FunctionalProvider<
          NutritionProductSearchService,
          NutritionProductSearchService,
          NutritionProductSearchService
        >
    with $Provider<NutritionProductSearchService> {
  const NutritionProductSearchServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'nutritionProductSearchServiceProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$nutritionProductSearchServiceHash();

  @$internal
  @override
  $ProviderElement<NutritionProductSearchService> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  NutritionProductSearchService create(Ref ref) {
    return nutritionProductSearchService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(NutritionProductSearchService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<NutritionProductSearchService>(
        value,
      ),
    );
  }
}

String _$nutritionProductSearchServiceHash() =>
    r'2bbba6f51170054b5634aec53e29191188319130';
