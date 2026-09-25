// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'previous_plans.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The athlete's earlier plans, newest first — everything `list_plans`
/// answers except the plan on the Plan tab. The server already leaves
/// deleted and empty plans out (`listPlans` in `plan.ts`, ticket 49), and
/// drafts that were never confirmed (mp-677, ticket 73), and
/// only the Plan tab knows which plan it shows, so that one is dropped here;
/// the empty-plan check stays as a guard against an older server.
///
/// Server-only: [MealPlanController] owns the current plan and
/// nothing else, so history stays out of it. Auto-disposed, and the sheet
/// is its only listener, so every open of the sheet reads the list afresh;
/// the current plan's id is read once at that moment rather than watched,
/// which would re-hit the server on every edit to this week's plan.

@ProviderFor(previousPlans)
const previousPlansProvider = PreviousPlansProvider._();

/// The athlete's earlier plans, newest first — everything `list_plans`
/// answers except the plan on the Plan tab. The server already leaves
/// deleted and empty plans out (`listPlans` in `plan.ts`, ticket 49), and
/// drafts that were never confirmed (mp-677, ticket 73), and
/// only the Plan tab knows which plan it shows, so that one is dropped here;
/// the empty-plan check stays as a guard against an older server.
///
/// Server-only: [MealPlanController] owns the current plan and
/// nothing else, so history stays out of it. Auto-disposed, and the sheet
/// is its only listener, so every open of the sheet reads the list afresh;
/// the current plan's id is read once at that moment rather than watched,
/// which would re-hit the server on every edit to this week's plan.

final class PreviousPlansProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<MealPlanSummary>>,
          List<MealPlanSummary>,
          FutureOr<List<MealPlanSummary>>
        >
    with
        $FutureModifier<List<MealPlanSummary>>,
        $FutureProvider<List<MealPlanSummary>> {
  /// The athlete's earlier plans, newest first — everything `list_plans`
  /// answers except the plan on the Plan tab. The server already leaves
  /// deleted and empty plans out (`listPlans` in `plan.ts`, ticket 49), and
  /// drafts that were never confirmed (mp-677, ticket 73), and
  /// only the Plan tab knows which plan it shows, so that one is dropped here;
  /// the empty-plan check stays as a guard against an older server.
  ///
  /// Server-only: [MealPlanController] owns the current plan and
  /// nothing else, so history stays out of it. Auto-disposed, and the sheet
  /// is its only listener, so every open of the sheet reads the list afresh;
  /// the current plan's id is read once at that moment rather than watched,
  /// which would re-hit the server on every edit to this week's plan.
  const PreviousPlansProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'previousPlansProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$previousPlansHash();

  @$internal
  @override
  $FutureProviderElement<List<MealPlanSummary>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<MealPlanSummary>> create(Ref ref) {
    return previousPlans(ref);
  }
}

String _$previousPlansHash() => r'5406d0bda04fdae19953df2f2a2eb5007122121d';

/// One earlier plan by id (`/food/plans/:id`), straight from the server
/// (`get_plan {id}`); `null` when the server no longer has it. Plans are a
/// list (mp-675): the athlete edits an earlier plan's meals and servings,
/// renames it, deletes it, or uses it again as this week's new draft.
///
/// History is server-only, like the list: every write here is remote-ack
/// through `vana-action` and refuses offline before sending anything
/// ([NeedsConnectionException]). A failed write keeps the plan on screen
/// and rethrows so the screen can say so. A plan that is not archived may
/// also be in Drift (the draft a Use again made, a past week's confirmed
/// plan), so its answer is folded in through [MealPlanController] and the
/// Plan tab never shows a stale copy.

@ProviderFor(EarlierPlan)
const earlierPlanProvider = EarlierPlanFamily._();

/// One earlier plan by id (`/food/plans/:id`), straight from the server
/// (`get_plan {id}`); `null` when the server no longer has it. Plans are a
/// list (mp-675): the athlete edits an earlier plan's meals and servings,
/// renames it, deletes it, or uses it again as this week's new draft.
///
/// History is server-only, like the list: every write here is remote-ack
/// through `vana-action` and refuses offline before sending anything
/// ([NeedsConnectionException]). A failed write keeps the plan on screen
/// and rethrows so the screen can say so. A plan that is not archived may
/// also be in Drift (the draft a Use again made, a past week's confirmed
/// plan), so its answer is folded in through [MealPlanController] and the
/// Plan tab never shows a stale copy.
final class EarlierPlanProvider
    extends $AsyncNotifierProvider<EarlierPlan, MealPlan?> {
  /// One earlier plan by id (`/food/plans/:id`), straight from the server
  /// (`get_plan {id}`); `null` when the server no longer has it. Plans are a
  /// list (mp-675): the athlete edits an earlier plan's meals and servings,
  /// renames it, deletes it, or uses it again as this week's new draft.
  ///
  /// History is server-only, like the list: every write here is remote-ack
  /// through `vana-action` and refuses offline before sending anything
  /// ([NeedsConnectionException]). A failed write keeps the plan on screen
  /// and rethrows so the screen can say so. A plan that is not archived may
  /// also be in Drift (the draft a Use again made, a past week's confirmed
  /// plan), so its answer is folded in through [MealPlanController] and the
  /// Plan tab never shows a stale copy.
  const EarlierPlanProvider._({
    required EarlierPlanFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'earlierPlanProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$earlierPlanHash();

  @override
  String toString() {
    return r'earlierPlanProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  EarlierPlan create() => EarlierPlan();

  @override
  bool operator ==(Object other) {
    return other is EarlierPlanProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$earlierPlanHash() => r'a737ca4947ff3f08aeb93224fc1895691019a8b1';

/// One earlier plan by id (`/food/plans/:id`), straight from the server
/// (`get_plan {id}`); `null` when the server no longer has it. Plans are a
/// list (mp-675): the athlete edits an earlier plan's meals and servings,
/// renames it, deletes it, or uses it again as this week's new draft.
///
/// History is server-only, like the list: every write here is remote-ack
/// through `vana-action` and refuses offline before sending anything
/// ([NeedsConnectionException]). A failed write keeps the plan on screen
/// and rethrows so the screen can say so. A plan that is not archived may
/// also be in Drift (the draft a Use again made, a past week's confirmed
/// plan), so its answer is folded in through [MealPlanController] and the
/// Plan tab never shows a stale copy.

final class EarlierPlanFamily extends $Family
    with
        $ClassFamilyOverride<
          EarlierPlan,
          AsyncValue<MealPlan?>,
          MealPlan?,
          FutureOr<MealPlan?>,
          String
        > {
  const EarlierPlanFamily._()
    : super(
        retry: null,
        name: r'earlierPlanProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// One earlier plan by id (`/food/plans/:id`), straight from the server
  /// (`get_plan {id}`); `null` when the server no longer has it. Plans are a
  /// list (mp-675): the athlete edits an earlier plan's meals and servings,
  /// renames it, deletes it, or uses it again as this week's new draft.
  ///
  /// History is server-only, like the list: every write here is remote-ack
  /// through `vana-action` and refuses offline before sending anything
  /// ([NeedsConnectionException]). A failed write keeps the plan on screen
  /// and rethrows so the screen can say so. A plan that is not archived may
  /// also be in Drift (the draft a Use again made, a past week's confirmed
  /// plan), so its answer is folded in through [MealPlanController] and the
  /// Plan tab never shows a stale copy.

  EarlierPlanProvider call(String id) =>
      EarlierPlanProvider._(argument: id, from: this);

  @override
  String toString() => r'earlierPlanProvider';
}

/// One earlier plan by id (`/food/plans/:id`), straight from the server
/// (`get_plan {id}`); `null` when the server no longer has it. Plans are a
/// list (mp-675): the athlete edits an earlier plan's meals and servings,
/// renames it, deletes it, or uses it again as this week's new draft.
///
/// History is server-only, like the list: every write here is remote-ack
/// through `vana-action` and refuses offline before sending anything
/// ([NeedsConnectionException]). A failed write keeps the plan on screen
/// and rethrows so the screen can say so. A plan that is not archived may
/// also be in Drift (the draft a Use again made, a past week's confirmed
/// plan), so its answer is folded in through [MealPlanController] and the
/// Plan tab never shows a stale copy.

abstract class _$EarlierPlan extends $AsyncNotifier<MealPlan?> {
  late final _$args = ref.$arg as String;
  String get id => _$args;

  FutureOr<MealPlan?> build(String id);
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build(_$args);
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
