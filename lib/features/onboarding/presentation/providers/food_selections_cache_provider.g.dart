// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'food_selections_cache_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Cache for food selections during onboarding
///
/// This provider maintains the state of food selections while the user
/// navigates back and forth through the onboarding flow. The cache is
/// cleared when onboarding is completed or reset.

@ProviderFor(FoodSelectionsCache)
const foodSelectionsCacheProvider = FoodSelectionsCacheProvider._();

/// Cache for food selections during onboarding
///
/// This provider maintains the state of food selections while the user
/// navigates back and forth through the onboarding flow. The cache is
/// cleared when onboarding is completed or reset.
final class FoodSelectionsCacheProvider
    extends $NotifierProvider<FoodSelectionsCache, Set<String>> {
  /// Cache for food selections during onboarding
  ///
  /// This provider maintains the state of food selections while the user
  /// navigates back and forth through the onboarding flow. The cache is
  /// cleared when onboarding is completed or reset.
  const FoodSelectionsCacheProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'foodSelectionsCacheProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$foodSelectionsCacheHash();

  @$internal
  @override
  FoodSelectionsCache create() => FoodSelectionsCache();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(Set<String> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<Set<String>>(value),
    );
  }
}

String _$foodSelectionsCacheHash() =>
    r'c11c929d67aebfeaf2b1015babbf6716d9c4b1f8';

/// Cache for food selections during onboarding
///
/// This provider maintains the state of food selections while the user
/// navigates back and forth through the onboarding flow. The cache is
/// cleared when onboarding is completed or reset.

abstract class _$FoodSelectionsCache extends $Notifier<Set<String>> {
  Set<String> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build();
    final ref = this.ref as $Ref<Set<String>, Set<String>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<Set<String>, Set<String>>,
              Set<String>,
              Object?,
              Object?
            >;
    element.handleValue(ref, created);
  }
}
