// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'meal_catalog_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Meals tab: rails (Recents / My Foods / Assemblies / Recipes) plus a
/// debounced (350 ms) search with meal-type × kind filters.
///
/// Local rails (Recents from Drift logs + plan meals, My Foods from saved
/// meals) load first so the tab renders offline; the online rails and the
/// server-resolved Recents replace them when reachable. Search is online
/// only (`meal_library` is not mirrored).

@ProviderFor(MealCatalogController)
const mealCatalogControllerProvider = MealCatalogControllerProvider._();

/// Meals tab: rails (Recents / My Foods / Assemblies / Recipes) plus a
/// debounced (350 ms) search with meal-type × kind filters.
///
/// Local rails (Recents from Drift logs + plan meals, My Foods from saved
/// meals) load first so the tab renders offline; the online rails and the
/// server-resolved Recents replace them when reachable. Search is online
/// only (`meal_library` is not mirrored).
final class MealCatalogControllerProvider
    extends $AsyncNotifierProvider<MealCatalogController, MealCatalogState> {
  /// Meals tab: rails (Recents / My Foods / Assemblies / Recipes) plus a
  /// debounced (350 ms) search with meal-type × kind filters.
  ///
  /// Local rails (Recents from Drift logs + plan meals, My Foods from saved
  /// meals) load first so the tab renders offline; the online rails and the
  /// server-resolved Recents replace them when reachable. Search is online
  /// only (`meal_library` is not mirrored).
  const MealCatalogControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'mealCatalogControllerProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$mealCatalogControllerHash();

  @$internal
  @override
  MealCatalogController create() => MealCatalogController();
}

String _$mealCatalogControllerHash() =>
    r'f004c89c59032b55cc97d3189d7a4d4fc4f6702c';

/// Meals tab: rails (Recents / My Foods / Assemblies / Recipes) plus a
/// debounced (350 ms) search with meal-type × kind filters.
///
/// Local rails (Recents from Drift logs + plan meals, My Foods from saved
/// meals) load first so the tab renders offline; the online rails and the
/// server-resolved Recents replace them when reachable. Search is online
/// only (`meal_library` is not mirrored).

abstract class _$MealCatalogController
    extends $AsyncNotifier<MealCatalogState> {
  FutureOr<MealCatalogState> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build();
    final ref =
        this.ref as $Ref<AsyncValue<MealCatalogState>, MealCatalogState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<MealCatalogState>, MealCatalogState>,
              AsyncValue<MealCatalogState>,
              Object?,
              Object?
            >;
    element.handleValue(ref, created);
  }
}
