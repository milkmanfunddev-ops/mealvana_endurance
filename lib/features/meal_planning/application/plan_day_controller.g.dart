// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'plan_day_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The day-planner grid for one [date] (`YYYY-MM-DD`): the four slots of
/// `meal_plans.days[date]` on the active plan.
///
/// Slot writes are local-first through [MealPlanController] when a plan
/// exists locally; [planDay] is remote-ack (the server picks by context and
/// creates the week's plan when there is none).

@ProviderFor(PlanDayController)
const planDayControllerProvider = PlanDayControllerFamily._();

/// The day-planner grid for one [date] (`YYYY-MM-DD`): the four slots of
/// `meal_plans.days[date]` on the active plan.
///
/// Slot writes are local-first through [MealPlanController] when a plan
/// exists locally; [planDay] is remote-ack (the server picks by context and
/// creates the week's plan when there is none).
final class PlanDayControllerProvider
    extends $AsyncNotifierProvider<PlanDayController, DayPlan> {
  /// The day-planner grid for one [date] (`YYYY-MM-DD`): the four slots of
  /// `meal_plans.days[date]` on the active plan.
  ///
  /// Slot writes are local-first through [MealPlanController] when a plan
  /// exists locally; [planDay] is remote-ack (the server picks by context and
  /// creates the week's plan when there is none).
  const PlanDayControllerProvider._({
    required PlanDayControllerFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'planDayControllerProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$planDayControllerHash();

  @override
  String toString() {
    return r'planDayControllerProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  PlanDayController create() => PlanDayController();

  @override
  bool operator ==(Object other) {
    return other is PlanDayControllerProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$planDayControllerHash() => r'2944d30bb09a2a8fda199895f80a325d84494599';

/// The day-planner grid for one [date] (`YYYY-MM-DD`): the four slots of
/// `meal_plans.days[date]` on the active plan.
///
/// Slot writes are local-first through [MealPlanController] when a plan
/// exists locally; [planDay] is remote-ack (the server picks by context and
/// creates the week's plan when there is none).

final class PlanDayControllerFamily extends $Family
    with
        $ClassFamilyOverride<
          PlanDayController,
          AsyncValue<DayPlan>,
          DayPlan,
          FutureOr<DayPlan>,
          String
        > {
  const PlanDayControllerFamily._()
    : super(
        retry: null,
        name: r'planDayControllerProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// The day-planner grid for one [date] (`YYYY-MM-DD`): the four slots of
  /// `meal_plans.days[date]` on the active plan.
  ///
  /// Slot writes are local-first through [MealPlanController] when a plan
  /// exists locally; [planDay] is remote-ack (the server picks by context and
  /// creates the week's plan when there is none).

  PlanDayControllerProvider call(String date) =>
      PlanDayControllerProvider._(argument: date, from: this);

  @override
  String toString() => r'planDayControllerProvider';
}

/// The day-planner grid for one [date] (`YYYY-MM-DD`): the four slots of
/// `meal_plans.days[date]` on the active plan.
///
/// Slot writes are local-first through [MealPlanController] when a plan
/// exists locally; [planDay] is remote-ack (the server picks by context and
/// creates the week's plan when there is none).

abstract class _$PlanDayController extends $AsyncNotifier<DayPlan> {
  late final _$args = ref.$arg as String;
  String get date => _$args;

  FutureOr<DayPlan> build(String date);
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build(_$args);
    final ref = this.ref as $Ref<AsyncValue<DayPlan>, DayPlan>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<DayPlan>, DayPlan>,
              AsyncValue<DayPlan>,
              Object?,
              Object?
            >;
    element.handleValue(ref, created);
  }
}
