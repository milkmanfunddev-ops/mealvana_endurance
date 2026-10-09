// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'food_preferences_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Settings > Food Likes & Dislikes: loads the athlete's levels (synced from
/// the server on demand) and saves them through [FoodPreferencesRepository],
/// which uploads (ticket 58).
///
/// State: slider levels by preference key ([foodPreferenceKey]: the catalog
/// `template_foods.name`, or a user food's name).

@ProviderFor(FoodPreferencesController)
const foodPreferencesControllerProvider = FoodPreferencesControllerProvider._();

/// Settings > Food Likes & Dislikes: loads the athlete's levels (synced from
/// the server on demand) and saves them through [FoodPreferencesRepository],
/// which uploads (ticket 58).
///
/// State: slider levels by preference key ([foodPreferenceKey]: the catalog
/// `template_foods.name`, or a user food's name).
final class FoodPreferencesControllerProvider
    extends
        $AsyncNotifierProvider<FoodPreferencesController, Map<String, int>> {
  /// Settings > Food Likes & Dislikes: loads the athlete's levels (synced from
  /// the server on demand) and saves them through [FoodPreferencesRepository],
  /// which uploads (ticket 58).
  ///
  /// State: slider levels by preference key ([foodPreferenceKey]: the catalog
  /// `template_foods.name`, or a user food's name).
  const FoodPreferencesControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'foodPreferencesControllerProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$foodPreferencesControllerHash();

  @$internal
  @override
  FoodPreferencesController create() => FoodPreferencesController();
}

String _$foodPreferencesControllerHash() =>
    r'83c4eef0cc78a057a7107a493b6f0c0d0cf50be8';

/// Settings > Food Likes & Dislikes: loads the athlete's levels (synced from
/// the server on demand) and saves them through [FoodPreferencesRepository],
/// which uploads (ticket 58).
///
/// State: slider levels by preference key ([foodPreferenceKey]: the catalog
/// `template_foods.name`, or a user food's name).

abstract class _$FoodPreferencesController
    extends $AsyncNotifier<Map<String, int>> {
  FutureOr<Map<String, int>> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build();
    final ref =
        this.ref as $Ref<AsyncValue<Map<String, int>>, Map<String, int>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<Map<String, int>>, Map<String, int>>,
              AsyncValue<Map<String, int>>,
              Object?,
              Object?
            >;
    element.handleValue(ref, created);
  }
}
