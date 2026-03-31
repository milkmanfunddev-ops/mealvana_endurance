// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'recipe_repository.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(recipeRepository)
const recipeRepositoryProvider = RecipeRepositoryProvider._();

final class RecipeRepositoryProvider
    extends
        $FunctionalProvider<
          RecipeRepository,
          RecipeRepository,
          RecipeRepository
        >
    with $Provider<RecipeRepository> {
  const RecipeRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'recipeRepositoryProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$recipeRepositoryHash();

  @$internal
  @override
  $ProviderElement<RecipeRepository> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  RecipeRepository create(Ref ref) {
    return recipeRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(RecipeRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<RecipeRepository>(value),
    );
  }
}

String _$recipeRepositoryHash() => r'2400543009bb2a2a0493a3719a9183d76e01aaf7';
