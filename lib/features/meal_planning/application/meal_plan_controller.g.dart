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

/// The plan a Vana conversation owns, read from Drift, so a screen opened
/// from the chat ("Browse meals") knows which meals are already in it —
/// at once and offline. Every remote-ack write folds the returned plan
/// into Drift, so a pick re-emits here.
///
/// On first build the server's copy is folded in too (fire-and-forget,
/// like `ensureSynced`): the chat reads its draft through `get_plan`
/// without writing it locally, so a conversation reopened on a fresh
/// install may have no local row yet (testing-wave 18-003). `get_plan`
/// with a conversation and no plan creates nothing.

@ProviderFor(conversationDraft)
const conversationDraftProvider = ConversationDraftFamily._();

/// The plan a Vana conversation owns, read from Drift, so a screen opened
/// from the chat ("Browse meals") knows which meals are already in it —
/// at once and offline. Every remote-ack write folds the returned plan
/// into Drift, so a pick re-emits here.
///
/// On first build the server's copy is folded in too (fire-and-forget,
/// like `ensureSynced`): the chat reads its draft through `get_plan`
/// without writing it locally, so a conversation reopened on a fresh
/// install may have no local row yet (testing-wave 18-003). `get_plan`
/// with a conversation and no plan creates nothing.

final class ConversationDraftProvider
    extends
        $FunctionalProvider<AsyncValue<MealPlan?>, MealPlan?, Stream<MealPlan?>>
    with $FutureModifier<MealPlan?>, $StreamProvider<MealPlan?> {
  /// The plan a Vana conversation owns, read from Drift, so a screen opened
  /// from the chat ("Browse meals") knows which meals are already in it —
  /// at once and offline. Every remote-ack write folds the returned plan
  /// into Drift, so a pick re-emits here.
  ///
  /// On first build the server's copy is folded in too (fire-and-forget,
  /// like `ensureSynced`): the chat reads its draft through `get_plan`
  /// without writing it locally, so a conversation reopened on a fresh
  /// install may have no local row yet (testing-wave 18-003). `get_plan`
  /// with a conversation and no plan creates nothing.
  const ConversationDraftProvider._({
    required ConversationDraftFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'conversationDraftProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$conversationDraftHash();

  @override
  String toString() {
    return r'conversationDraftProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $StreamProviderElement<MealPlan?> $createElement($ProviderPointer pointer) =>
      $StreamProviderElement(pointer);

  @override
  Stream<MealPlan?> create(Ref ref) {
    final argument = this.argument as String;
    return conversationDraft(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is ConversationDraftProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$conversationDraftHash() => r'229723b1ce2f33df047223442bb64d56efa0098b';

/// The plan a Vana conversation owns, read from Drift, so a screen opened
/// from the chat ("Browse meals") knows which meals are already in it —
/// at once and offline. Every remote-ack write folds the returned plan
/// into Drift, so a pick re-emits here.
///
/// On first build the server's copy is folded in too (fire-and-forget,
/// like `ensureSynced`): the chat reads its draft through `get_plan`
/// without writing it locally, so a conversation reopened on a fresh
/// install may have no local row yet (testing-wave 18-003). `get_plan`
/// with a conversation and no plan creates nothing.

final class ConversationDraftFamily extends $Family
    with $FunctionalFamilyOverride<Stream<MealPlan?>, String> {
  const ConversationDraftFamily._()
    : super(
        retry: null,
        name: r'conversationDraftProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// The plan a Vana conversation owns, read from Drift, so a screen opened
  /// from the chat ("Browse meals") knows which meals are already in it —
  /// at once and offline. Every remote-ack write folds the returned plan
  /// into Drift, so a pick re-emits here.
  ///
  /// On first build the server's copy is folded in too (fire-and-forget,
  /// like `ensureSynced`): the chat reads its draft through `get_plan`
  /// without writing it locally, so a conversation reopened on a fresh
  /// install may have no local row yet (testing-wave 18-003). `get_plan`
  /// with a conversation and no plan creates nothing.

  ConversationDraftProvider call(String conversationId) =>
      ConversationDraftProvider._(argument: conversationId, from: this);

  @override
  String toString() => r'conversationDraftProvider';
}

/// The active plan for the current week — what the Plan tab, the Shopping
/// tab, the chat's plan bar and the day planner all read.
///
/// - Watches Drift (`MealPlanRepository.watchActivePlan`) so every local or
///   server-applied change re-emits, and kicks `ensureSynced('meal_plans')`
///   on first build. A local plan answers at once with the sync behind it;
///   with nothing local and the network up, the first read waits for the
///   sync (bounded by [firstReadBound]) so the Plan tab shows loading, never
///   "No plan yet", over a plan confirmed elsewhere (testing-wave 19-004).
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
///   on first build. A local plan answers at once with the sync behind it;
///   with nothing local and the network up, the first read waits for the
///   sync (bounded by [firstReadBound]) so the Plan tab shows loading, never
///   "No plan yet", over a plan confirmed elsewhere (testing-wave 19-004).
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
  ///   on first build. A local plan answers at once with the sync behind it;
  ///   with nothing local and the network up, the first read waits for the
  ///   sync (bounded by [firstReadBound]) so the Plan tab shows loading, never
  ///   "No plan yet", over a plan confirmed elsewhere (testing-wave 19-004).
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
    r'94a9567a70c93a5eb613624443a7e12985e0e028';

/// The active plan for the current week — what the Plan tab, the Shopping
/// tab, the chat's plan bar and the day planner all read.
///
/// - Watches Drift (`MealPlanRepository.watchActivePlan`) so every local or
///   server-applied change re-emits, and kicks `ensureSynced('meal_plans')`
///   on first build. A local plan answers at once with the sync behind it;
///   with nothing local and the network up, the first read waits for the
///   sync (bounded by [firstReadBound]) so the Plan tab shows loading, never
///   "No plan yet", over a plan confirmed elsewhere (testing-wave 19-004).
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
