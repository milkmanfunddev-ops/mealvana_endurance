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
const mealCatalogControllerProvider = MealCatalogControllerFamily._();

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
  const MealCatalogControllerProvider._({
    required MealCatalogControllerFamily super.from,
    required CatalogSurface super.argument,
  }) : super(
         retry: null,
         name: r'mealCatalogControllerProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$mealCatalogControllerHash();

  @override
  String toString() {
    return r'mealCatalogControllerProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  MealCatalogController create() => MealCatalogController();

  @override
  bool operator ==(Object other) {
    return other is MealCatalogControllerProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$mealCatalogControllerHash() =>
    r'705908b6988c8bb659f6c5585a09b5818ba3d124';

/// Meals tab: rails (Recents / My Foods / Assemblies / Recipes) plus a
/// debounced (350 ms) search with meal-type × kind filters.
///
/// Local rails (Recents from Drift logs + plan meals, My Foods from saved
/// meals) load first so the tab renders offline; the online rails and the
/// server-resolved Recents replace them when reachable. Search is online
/// only (`meal_library` is not mirrored).

final class MealCatalogControllerFamily extends $Family
    with
        $ClassFamilyOverride<
          MealCatalogController,
          AsyncValue<MealCatalogState>,
          MealCatalogState,
          FutureOr<MealCatalogState>,
          CatalogSurface
        > {
  const MealCatalogControllerFamily._()
    : super(
        retry: null,
        name: r'mealCatalogControllerProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Meals tab: rails (Recents / My Foods / Assemblies / Recipes) plus a
  /// debounced (350 ms) search with meal-type × kind filters.
  ///
  /// Local rails (Recents from Drift logs + plan meals, My Foods from saved
  /// meals) load first so the tab renders offline; the online rails and the
  /// server-resolved Recents replace them when reachable. Search is online
  /// only (`meal_library` is not mirrored).

  MealCatalogControllerProvider call(CatalogSurface surface) =>
      MealCatalogControllerProvider._(argument: surface, from: this);

  @override
  String toString() => r'mealCatalogControllerProvider';
}

/// Meals tab: rails (Recents / My Foods / Assemblies / Recipes) plus a
/// debounced (350 ms) search with meal-type × kind filters.
///
/// Local rails (Recents from Drift logs + plan meals, My Foods from saved
/// meals) load first so the tab renders offline; the online rails and the
/// server-resolved Recents replace them when reachable. Search is online
/// only (`meal_library` is not mirrored).

abstract class _$MealCatalogController
    extends $AsyncNotifier<MealCatalogState> {
  late final _$args = ref.$arg as CatalogSurface;
  CatalogSurface get surface => _$args;

  FutureOr<MealCatalogState> build(CatalogSurface surface);
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build(_$args);
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
