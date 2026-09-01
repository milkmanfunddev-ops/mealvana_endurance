// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'cooking_session_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Cooking mode (`/food/cook/:id`): the phase machine, step navigation,
/// per-step timers parsed by [CookingStepTimers], the ingredients drawer
/// and the wake-lock intent. No platform calls here — the screen owns
/// `wakelock_plus`, notifications and vibration.
///
/// Timers tick once a second while any is running (one `Timer.periodic`,
/// cancelled on dispose). Countdown is per-tick so it is deterministic under
/// `fakeAsync`; a backgrounded app resumes from where it paused.

@ProviderFor(CookingSessionController)
const cookingSessionControllerProvider = CookingSessionControllerFamily._();

/// Cooking mode (`/food/cook/:id`): the phase machine, step navigation,
/// per-step timers parsed by [CookingStepTimers], the ingredients drawer
/// and the wake-lock intent. No platform calls here — the screen owns
/// `wakelock_plus`, notifications and vibration.
///
/// Timers tick once a second while any is running (one `Timer.periodic`,
/// cancelled on dispose). Countdown is per-tick so it is deterministic under
/// `fakeAsync`; a backgrounded app resumes from where it paused.
final class CookingSessionControllerProvider
    extends
        $AsyncNotifierProvider<CookingSessionController, CookingSessionState> {
  /// Cooking mode (`/food/cook/:id`): the phase machine, step navigation,
  /// per-step timers parsed by [CookingStepTimers], the ingredients drawer
  /// and the wake-lock intent. No platform calls here — the screen owns
  /// `wakelock_plus`, notifications and vibration.
  ///
  /// Timers tick once a second while any is running (one `Timer.periodic`,
  /// cancelled on dispose). Countdown is per-tick so it is deterministic under
  /// `fakeAsync`; a backgrounded app resumes from where it paused.
  const CookingSessionControllerProvider._({
    required CookingSessionControllerFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'cookingSessionControllerProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$cookingSessionControllerHash();

  @override
  String toString() {
    return r'cookingSessionControllerProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  CookingSessionController create() => CookingSessionController();

  @override
  bool operator ==(Object other) {
    return other is CookingSessionControllerProvider &&
        other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$cookingSessionControllerHash() =>
    r'ef84431bd2bc4f91c28b164351ced265e6818a33';

/// Cooking mode (`/food/cook/:id`): the phase machine, step navigation,
/// per-step timers parsed by [CookingStepTimers], the ingredients drawer
/// and the wake-lock intent. No platform calls here — the screen owns
/// `wakelock_plus`, notifications and vibration.
///
/// Timers tick once a second while any is running (one `Timer.periodic`,
/// cancelled on dispose). Countdown is per-tick so it is deterministic under
/// `fakeAsync`; a backgrounded app resumes from where it paused.

final class CookingSessionControllerFamily extends $Family
    with
        $ClassFamilyOverride<
          CookingSessionController,
          AsyncValue<CookingSessionState>,
          CookingSessionState,
          FutureOr<CookingSessionState>,
          String
        > {
  const CookingSessionControllerFamily._()
    : super(
        retry: null,
        name: r'cookingSessionControllerProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Cooking mode (`/food/cook/:id`): the phase machine, step navigation,
  /// per-step timers parsed by [CookingStepTimers], the ingredients drawer
  /// and the wake-lock intent. No platform calls here — the screen owns
  /// `wakelock_plus`, notifications and vibration.
  ///
  /// Timers tick once a second while any is running (one `Timer.periodic`,
  /// cancelled on dispose). Countdown is per-tick so it is deterministic under
  /// `fakeAsync`; a backgrounded app resumes from where it paused.

  CookingSessionControllerProvider call(String mealId) =>
      CookingSessionControllerProvider._(argument: mealId, from: this);

  @override
  String toString() => r'cookingSessionControllerProvider';
}

/// Cooking mode (`/food/cook/:id`): the phase machine, step navigation,
/// per-step timers parsed by [CookingStepTimers], the ingredients drawer
/// and the wake-lock intent. No platform calls here — the screen owns
/// `wakelock_plus`, notifications and vibration.
///
/// Timers tick once a second while any is running (one `Timer.periodic`,
/// cancelled on dispose). Countdown is per-tick so it is deterministic under
/// `fakeAsync`; a backgrounded app resumes from where it paused.

abstract class _$CookingSessionController
    extends $AsyncNotifier<CookingSessionState> {
  late final _$args = ref.$arg as String;
  String get mealId => _$args;

  FutureOr<CookingSessionState> build(String mealId);
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build(_$args);
    final ref =
        this.ref as $Ref<AsyncValue<CookingSessionState>, CookingSessionState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<CookingSessionState>, CookingSessionState>,
              AsyncValue<CookingSessionState>,
              Object?,
              Object?
            >;
    element.handleValue(ref, created);
  }
}
