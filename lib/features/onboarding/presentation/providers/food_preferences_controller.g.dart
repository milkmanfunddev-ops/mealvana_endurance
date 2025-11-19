// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'food_preferences_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Controller for food preferences screen - follows Andrea Bizzotto's AsyncNotifier pattern

@ProviderFor(FoodPreferencesController)
const foodPreferencesControllerProvider = FoodPreferencesControllerProvider._();

/// Controller for food preferences screen - follows Andrea Bizzotto's AsyncNotifier pattern
final class FoodPreferencesControllerProvider
    extends
        $AsyncNotifierProvider<
          FoodPreferencesController,
          FoodPreferencesState
        > {
  /// Controller for food preferences screen - follows Andrea Bizzotto's AsyncNotifier pattern
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
    r'968324bd8f3f6c0254690cb1baaff586530784e9';

/// Controller for food preferences screen - follows Andrea Bizzotto's AsyncNotifier pattern

abstract class _$FoodPreferencesController
    extends $AsyncNotifier<FoodPreferencesState> {
  FutureOr<FoodPreferencesState> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build();
    final ref =
        this.ref
            as $Ref<AsyncValue<FoodPreferencesState>, FoodPreferencesState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<
                AsyncValue<FoodPreferencesState>,
                FoodPreferencesState
              >,
              AsyncValue<FoodPreferencesState>,
              Object?,
              Object?
            >;
    element.handleValue(ref, created);
  }
}
