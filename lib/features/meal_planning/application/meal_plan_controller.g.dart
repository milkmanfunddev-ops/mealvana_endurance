// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'meal_plan_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
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
    r'3e062c4740e692065eaf2684d033a8482d2eff20';

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
