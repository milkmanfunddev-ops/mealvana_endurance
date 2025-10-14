// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'food_import_service.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(foodImportService)
const foodImportServiceProvider = FoodImportServiceProvider._();

final class FoodImportServiceProvider
    extends
        $FunctionalProvider<
          FoodImportService,
          FoodImportService,
          FoodImportService
        >
    with $Provider<FoodImportService> {
  const FoodImportServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'foodImportServiceProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$foodImportServiceHash();

  @$internal
  @override
  $ProviderElement<FoodImportService> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  FoodImportService create(Ref ref) {
    return foodImportService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(FoodImportService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<FoodImportService>(value),
    );
  }
}

String _$foodImportServiceHash() => r'08f3f8e4c934dff51813903211b74d24f306c574';
