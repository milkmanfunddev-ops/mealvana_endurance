import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../data/vana_exceptions.dart';
import '../domain/day_plan.dart';
import '../domain/meal_type.dart';
import '../domain/vana_part.dart';
import 'meal_plan_controller.dart';

part 'plan_day_controller.g.dart';

/// The day-planner grid for one [date] (`YYYY-MM-DD`): the four slots of
/// `meal_plans.days[date]` on the active plan.
///
/// Slot writes are local-first through [MealPlanController] when a plan
/// exists locally; [planDay] is remote-ack (the server picks by context and
/// creates the week's plan when there is none).
@riverpod
class PlanDayController extends _$PlanDayController {
  MealPlanController get _plan => ref.read(mealPlanControllerProvider.notifier);

  @override
  FutureOr<DayPlan> build(String date) async {
    final plan = await ref.watch(mealPlanControllerProvider.future);
    return plan?.dayFor(date) ?? DayPlan.empty;
  }

  /// Point [slot] at [ref] (local-first). Throws [NeedsConnectionException]
  /// when there is no local plan to write into — callers fall back to
  /// [planDay] or show the "needs a connection" warning.
  Future<void> setSlot(MealType slot, DaySlotRef ref) async {
    final current = state.value ?? DayPlan.empty;
    state = AsyncData(current.withSlot(slot, ref));
    state = await AsyncValue.guard(() async {
      await _plan.setDaySlot(date, slot, ref);
      return current.withSlot(slot, ref);
    });
  }

  Future<void> clearSlot(MealType slot) async {
    final current = state.value ?? DayPlan.empty;
    state = await AsyncValue.guard(() async {
      await _plan.clearDaySlot(date, slot);
      return current.withSlot(slot, null);
    });
  }

  /// `plan_day` — fill the empty slots server-side. Remote-ack; throws
  /// [NeedsConnectionException] offline. Returns the `day` part.
  Future<VanaDayPart?> planDay() async {
    final previous = state;
    state = const AsyncLoading();
    VanaDayPart? part;
    state = await AsyncValue.guard(() async {
      part = await _plan.planDay(date: date);
      return part?.slots ?? previous.value ?? DayPlan.empty;
    });
    if (state.hasError) {
      Error.throwWithStackTrace(state.error!, state.stackTrace!);
    }
    return part;
  }
}
