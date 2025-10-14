// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'open_food_facts_search_service.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(openFoodFactsSearchService)
const openFoodFactsSearchServiceProvider =
    OpenFoodFactsSearchServiceProvider._();

final class OpenFoodFactsSearchServiceProvider
    extends
        $FunctionalProvider<
          OpenFoodFactsSearchService,
          OpenFoodFactsSearchService,
          OpenFoodFactsSearchService
        >
    with $Provider<OpenFoodFactsSearchService> {
  const OpenFoodFactsSearchServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'openFoodFactsSearchServiceProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$openFoodFactsSearchServiceHash();

  @$internal
  @override
  $ProviderElement<OpenFoodFactsSearchService> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  OpenFoodFactsSearchService create(Ref ref) {
    return openFoodFactsSearchService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(OpenFoodFactsSearchService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<OpenFoodFactsSearchService>(value),
    );
  }
}

String _$openFoodFactsSearchServiceHash() =>
    r'79d619e03cbd9ca7b59a3c3cedb98c0238335ae0';
