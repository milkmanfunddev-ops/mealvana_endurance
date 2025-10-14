// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'recipe_service.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(recipeService)
const recipeServiceProvider = RecipeServiceProvider._();

final class RecipeServiceProvider
    extends $FunctionalProvider<RecipeService, RecipeService, RecipeService>
    with $Provider<RecipeService> {
  const RecipeServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'recipeServiceProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$recipeServiceHash();

  @$internal
  @override
  $ProviderElement<RecipeService> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  RecipeService create(Ref ref) {
    return recipeService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(RecipeService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<RecipeService>(value),
    );
  }
}

String _$recipeServiceHash() => r'b5232f738676431855f31cc7813d814ed8812336';
