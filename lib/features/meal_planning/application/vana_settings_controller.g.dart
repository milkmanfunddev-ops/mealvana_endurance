// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'vana_settings_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Settings are `user_memories` rows: local-first through
/// [UserMemoryRepository], plus — when online — the `set_setting` action so
/// the server flips `meal_plans.batch_cooking` in the same beat (its `batch`
/// part is folded into [MealPlanController]). Memory deletes are
/// local-first tombstones.

@ProviderFor(VanaSettingsController)
const vanaSettingsControllerProvider = VanaSettingsControllerProvider._();

/// Settings are `user_memories` rows: local-first through
/// [UserMemoryRepository], plus — when online — the `set_setting` action so
/// the server flips `meal_plans.batch_cooking` in the same beat (its `batch`
/// part is folded into [MealPlanController]). Memory deletes are
/// local-first tombstones.
final class VanaSettingsControllerProvider
    extends $AsyncNotifierProvider<VanaSettingsController, VanaSettingsState> {
  /// Settings are `user_memories` rows: local-first through
  /// [UserMemoryRepository], plus — when online — the `set_setting` action so
  /// the server flips `meal_plans.batch_cooking` in the same beat (its `batch`
  /// part is folded into [MealPlanController]). Memory deletes are
  /// local-first tombstones.
  const VanaSettingsControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'vanaSettingsControllerProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$vanaSettingsControllerHash();

  @$internal
  @override
  VanaSettingsController create() => VanaSettingsController();
}

String _$vanaSettingsControllerHash() =>
    r'4b0ba134883da363beece41f6299242b28cb9b01';

/// Settings are `user_memories` rows: local-first through
/// [UserMemoryRepository], plus — when online — the `set_setting` action so
/// the server flips `meal_plans.batch_cooking` in the same beat (its `batch`
/// part is folded into [MealPlanController]). Memory deletes are
/// local-first tombstones.

abstract class _$VanaSettingsController
    extends $AsyncNotifier<VanaSettingsState> {
  FutureOr<VanaSettingsState> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build();
    final ref =
        this.ref as $Ref<AsyncValue<VanaSettingsState>, VanaSettingsState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<VanaSettingsState>, VanaSettingsState>,
              AsyncValue<VanaSettingsState>,
              Object?,
              Object?
            >;
    element.handleValue(ref, created);
  }
}
