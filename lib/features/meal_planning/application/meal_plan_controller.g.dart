// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'meal_plan_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The athlete's plan period (mp-269) from the `week_start` / `period_days`
/// settings rows in Drift. Re-emits only when either changes, so
/// [MealPlanController] rebinds to the new week exactly then.

@ProviderFor(planPeriod)
const planPeriodProvider = PlanPeriodProvider._();

/// The athlete's plan period (mp-269) from the `week_start` / `period_days`
/// settings rows in Drift. Re-emits only when either changes, so
/// [MealPlanController] rebinds to the new week exactly then.

final class PlanPeriodProvider
    extends
        $FunctionalProvider<
          AsyncValue<PlanPeriod>,
          PlanPeriod,
          Stream<PlanPeriod>
        >
    with $FutureModifier<PlanPeriod>, $StreamProvider<PlanPeriod> {
  /// The athlete's plan period (mp-269) from the `week_start` / `period_days`
  /// settings rows in Drift. Re-emits only when either changes, so
  /// [MealPlanController] rebinds to the new week exactly then.
  const PlanPeriodProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'planPeriodProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$planPeriodHash();

  @$internal
  @override
  $StreamProviderElement<PlanPeriod> $createElement($ProviderPointer pointer) =>
      $StreamProviderElement(pointer);

  @override
  Stream<PlanPeriod> create(Ref ref) {
    return planPeriod(ref);
  }
}

String _$planPeriodHash() => r'b007a97bf91866f78dff740a5f4c23c85b60464e';

/// The active plan for the current week — what the Plan tab, the Shopping
/// tab, the chat's plan bar and the day planner all read.
///
/// - Watches Drift (`MealPlanRepository.watchActivePlan`) so every local or
///   server-applied change re-emits, and kicks `ensureSynced('meal_plans')`
///   in the background on first build (never blocks on the network).
/// - **Local-first** edits (05 §3): [setServings], [removeMeal],
///   [setSession], [addComment], [toggleShopping], [setDaySlot],
///   [clearDaySlot] write Drift and schedule a best-effort upload.
/// - **Remote-ack** edits: [pickMeals], [swapMeal], [confirmPlan],
///   [newPlan], [logFromPlan], [planDay] call `vana-action`, fold the
///   returned `batch` into Drift with [applyServerPlan], and throw
///   [NeedsConnectionException] when offline before sending anything.
///
/// Session-scoped (`keepAlive`) so the chat can fold `batch` parts into it
/// even while no screen is watching.

@ProviderFor(MealPlanController)
const mealPlanControllerProvider = MealPlanControllerProvider._();

/// The active plan for the current week — what the Plan tab, the Shopping
/// tab, the chat's plan bar and the day planner all read.
///
/// - Watches Drift (`MealPlanRepository.watchActivePlan`) so every local or
///   server-applied change re-emits, and kicks `ensureSynced('meal_plans')`
///   in the background on first build (never blocks on the network).
/// - **Local-first** edits (05 §3): [setServings], [removeMeal],
///   [setSession], [addComment], [toggleShopping], [setDaySlot],
///   [clearDaySlot] write Drift and schedule a best-effort upload.
/// - **Remote-ack** edits: [pickMeals], [swapMeal], [confirmPlan],
///   [newPlan], [logFromPlan], [planDay] call `vana-action`, fold the
///   returned `batch` into Drift with [applyServerPlan], and throw
///   [NeedsConnectionException] when offline before sending anything.
///
/// Session-scoped (`keepAlive`) so the chat can fold `batch` parts into it
/// even while no screen is watching.
final class MealPlanControllerProvider
    extends $AsyncNotifierProvider<MealPlanController, MealPlan?> {
  /// The active plan for the current week — what the Plan tab, the Shopping
  /// tab, the chat's plan bar and the day planner all read.
  ///
  /// - Watches Drift (`MealPlanRepository.watchActivePlan`) so every local or
  ///   server-applied change re-emits, and kicks `ensureSynced('meal_plans')`
  ///   in the background on first build (never blocks on the network).
  /// - **Local-first** edits (05 §3): [setServings], [removeMeal],
  ///   [setSession], [addComment], [toggleShopping], [setDaySlot],
  ///   [clearDaySlot] write Drift and schedule a best-effort upload.
  /// - **Remote-ack** edits: [pickMeals], [swapMeal], [confirmPlan],
  ///   [newPlan], [logFromPlan], [planDay] call `vana-action`, fold the
  ///   returned `batch` into Drift with [applyServerPlan], and throw
  ///   [NeedsConnectionException] when offline before sending anything.
  ///
  /// Session-scoped (`keepAlive`) so the chat can fold `batch` parts into it
  /// even while no screen is watching.
  const MealPlanControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'mealPlanControllerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$mealPlanControllerHash();

  @$internal
  @override
  MealPlanController create() => MealPlanController();
}

String _$mealPlanControllerHash() =>
    r'a0e9e31547ac6890d7dd7da8858bcf022b05c90d';

/// The active plan for the current week — what the Plan tab, the Shopping
/// tab, the chat's plan bar and the day planner all read.
///
/// - Watches Drift (`MealPlanRepository.watchActivePlan`) so every local or
///   server-applied change re-emits, and kicks `ensureSynced('meal_plans')`
///   in the background on first build (never blocks on the network).
/// - **Local-first** edits (05 §3): [setServings], [removeMeal],
///   [setSession], [addComment], [toggleShopping], [setDaySlot],
///   [clearDaySlot] write Drift and schedule a best-effort upload.
/// - **Remote-ack** edits: [pickMeals], [swapMeal], [confirmPlan],
///   [newPlan], [logFromPlan], [planDay] call `vana-action`, fold the
///   returned `batch` into Drift with [applyServerPlan], and throw
///   [NeedsConnectionException] when offline before sending anything.
///
/// Session-scoped (`keepAlive`) so the chat can fold `batch` parts into it
/// even while no screen is watching.

abstract class _$MealPlanController extends $AsyncNotifier<MealPlan?> {
  FutureOr<MealPlan?> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build();
    final ref = this.ref as $Ref<AsyncValue<MealPlan?>, MealPlan?>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<MealPlan?>, MealPlan?>,
              AsyncValue<MealPlan?>,
              Object?,
              Object?
            >;
    element.handleValue(ref, created);
  }
}
