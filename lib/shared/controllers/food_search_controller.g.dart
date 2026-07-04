// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'food_search_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Shared food search controller keyed by screen name.
///
/// Each screen gets its own instance via the [key] parameter
/// (e.g. "swap_food" or "food_preferences").

@ProviderFor(FoodSearchController)
const foodSearchControllerProvider = FoodSearchControllerFamily._();

/// Shared food search controller keyed by screen name.
///
/// Each screen gets its own instance via the [key] parameter
/// (e.g. "swap_food" or "food_preferences").
final class FoodSearchControllerProvider
    extends $NotifierProvider<FoodSearchController, FoodSearchState> {
  /// Shared food search controller keyed by screen name.
  ///
  /// Each screen gets its own instance via the [key] parameter
  /// (e.g. "swap_food" or "food_preferences").
  const FoodSearchControllerProvider._({
    required FoodSearchControllerFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'foodSearchControllerProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$foodSearchControllerHash();

  @override
  String toString() {
    return r'foodSearchControllerProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  FoodSearchController create() => FoodSearchController();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(FoodSearchState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<FoodSearchState>(value),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is FoodSearchControllerProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$foodSearchControllerHash() =>
    r'148833d996a5b6f20cb66bacbb293dc9ee4c7d20';

/// Shared food search controller keyed by screen name.
///
/// Each screen gets its own instance via the [key] parameter
/// (e.g. "swap_food" or "food_preferences").

final class FoodSearchControllerFamily extends $Family
    with
        $ClassFamilyOverride<
          FoodSearchController,
          FoodSearchState,
          FoodSearchState,
          FoodSearchState,
          String
        > {
  const FoodSearchControllerFamily._()
    : super(
        retry: null,
        name: r'foodSearchControllerProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Shared food search controller keyed by screen name.
  ///
  /// Each screen gets its own instance via the [key] parameter
  /// (e.g. "swap_food" or "food_preferences").

  FoodSearchControllerProvider call(String key) =>
      FoodSearchControllerProvider._(argument: key, from: this);

  @override
  String toString() => r'foodSearchControllerProvider';
}

/// Shared food search controller keyed by screen name.
///
/// Each screen gets its own instance via the [key] parameter
/// (e.g. "swap_food" or "food_preferences").

abstract class _$FoodSearchController extends $Notifier<FoodSearchState> {
  late final _$args = ref.$arg as String;
  String get key => _$args;

  FoodSearchState build(String key);
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build(_$args);
    final ref = this.ref as $Ref<FoodSearchState, FoodSearchState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<FoodSearchState, FoodSearchState>,
              FoodSearchState,
              Object?,
              Object?
            >;
    element.handleValue(ref, created);
  }
}
