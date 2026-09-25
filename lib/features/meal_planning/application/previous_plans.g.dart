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
/// only the Plan tab knows which plan it shows, so that one is dropped here;
/// the empty-plan check stays as a guard against an older server.
///
/// Read-only and server-only: [MealPlanController] owns the current plan and
/// nothing else, so history stays out of it. Auto-disposed, and the sheet
/// is its only listener, so every open of the sheet reads the list afresh;
/// the current plan's id is read once at that moment rather than watched,
/// which would re-hit the server on every edit to this week's plan.

@ProviderFor(previousPlans)
const previousPlansProvider = PreviousPlansProvider._();

/// The athlete's earlier plans, newest first — everything `list_plans`
/// answers except the plan on the Plan tab. The server already leaves
/// deleted and empty plans out (`listPlans` in `plan.ts`, ticket 49), and
/// only the Plan tab knows which plan it shows, so that one is dropped here;
/// the empty-plan check stays as a guard against an older server.
///
/// Read-only and server-only: [MealPlanController] owns the current plan and
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
  /// only the Plan tab knows which plan it shows, so that one is dropped here;
  /// the empty-plan check stays as a guard against an older server.
  ///
  /// Read-only and server-only: [MealPlanController] owns the current plan and
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

/// One plan by id, straight from the server (`get_plan {id}`), for the
/// read-only view of an earlier plan. `null` when the server no longer has
/// it — deleted since the list was read.

@ProviderFor(planById)
const planByIdProvider = PlanByIdFamily._();

/// One plan by id, straight from the server (`get_plan {id}`), for the
/// read-only view of an earlier plan. `null` when the server no longer has
/// it — deleted since the list was read.

final class PlanByIdProvider
    extends
        $FunctionalProvider<
          AsyncValue<MealPlan?>,
          MealPlan?,
          FutureOr<MealPlan?>
        >
    with $FutureModifier<MealPlan?>, $FutureProvider<MealPlan?> {
  /// One plan by id, straight from the server (`get_plan {id}`), for the
  /// read-only view of an earlier plan. `null` when the server no longer has
  /// it — deleted since the list was read.
  const PlanByIdProvider._({
    required PlanByIdFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'planByIdProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$planByIdHash();

  @override
  String toString() {
    return r'planByIdProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<MealPlan?> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<MealPlan?> create(Ref ref) {
    final argument = this.argument as String;
    return planById(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is PlanByIdProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$planByIdHash() => r'413b287df57f27c259fdd945ec5111fd1e546329';

/// One plan by id, straight from the server (`get_plan {id}`), for the
/// read-only view of an earlier plan. `null` when the server no longer has
/// it — deleted since the list was read.

final class PlanByIdFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<MealPlan?>, String> {
  const PlanByIdFamily._()
    : super(
        retry: null,
        name: r'planByIdProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// One plan by id, straight from the server (`get_plan {id}`), for the
  /// read-only view of an earlier plan. `null` when the server no longer has
  /// it — deleted since the list was read.

  PlanByIdProvider call(String id) =>
      PlanByIdProvider._(argument: id, from: this);

  @override
  String toString() => r'planByIdProvider';
}
