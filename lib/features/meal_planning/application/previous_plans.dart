import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../shared/services/connectivity_checker.dart';
import '../data/vana_action_client.dart';
import '../data/vana_exceptions.dart';
import '../domain/meal_plan.dart';
import '../domain/meal_plan_status.dart';
import '../domain/meal_plan_summary.dart';
import '../domain/ui_action.dart';
import 'meal_plan_controller.dart';

part 'previous_plans.g.dart';

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
@riverpod
Future<List<MealPlanSummary>> previousPlans(Ref ref) async {
  final currentId = ref.read(mealPlanControllerProvider).value?.id;
  final result = await ref
      .read(vanaActionClientProvider)
      .run(const ListPlansAction());
  return [
    for (final plan in result.plans)
      if (plan.id != currentId && plan.mealCount > 0) plan,
  ];
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
@riverpod
class EarlierPlan extends _$EarlierPlan {
  VanaActionClient get _actions => ref.read(vanaActionClientProvider);
  MealPlanController get _tab => ref.read(mealPlanControllerProvider.notifier);

  @override
  Future<MealPlan?> build(String id) async {
    final result = await _actions.run(GetPlanAction(id: id));
    return result.plan;
  }

  /// A meal's servings on this plan (`set_servings`, keyed by the row).
  Future<void> setServings(String planMealId, int servings) =>
      _edit(SetServingsAction(planMealId: planMealId, servings: servings));

  /// Take a meal out of this plan (`remove_meal`).
  Future<void> removeMeal(String planMealId) =>
      _edit(RemoveMealAction(planMealId: planMealId));

  /// The athlete's own name for this plan; an empty [name] clears it.
  Future<void> rename(String name) =>
      _edit(RenamePlanAction(id: id, name: name));

  /// Delete this plan (`delete_plan {id}`). The plan is gone afterwards, so
  /// the state is `null`; a plan Drift may hold is re-synced off the tab.
  Future<void> delete() async {
    final wasLocal = _mayBeLocal(state.value);
    await _send(DeletePlanAction(id: id));
    state = const AsyncData(null);
    if (wasLocal) await _tab.refresh();
    _listChanged();
  }

  /// The Previous plans sheet stays open under this plan's view (ticket
  /// 97), so what it lists is re-read after a write that changes a row:
  /// a name, a meal count, a plan gone, a confirm that moves one plan onto
  /// the Plan tab and another into history.
  void _listChanged() {
    if (ref.mounted) ref.invalidate(previousPlansProvider);
  }

  /// Copy this plan into this week as a new draft (`use_plan_again`). The
  /// draft goes to Drift so the Plan tab knows it; this plan is unchanged.
  /// Returns the draft, which the caller opens to confirm.
  Future<MealPlan?> useAgain() async {
    final result = await _send(UsePlanAgainAction(id: id));
    final copy = result.plan;
    if (copy != null) await _tab.applyServerPlan(copy);
    return copy;
  }

  /// Confirm this plan when it is a draft: it becomes this week's plan and
  /// the one it replaces stays in the list (mp-674, mp-675). The confirm is
  /// [MealPlanController]'s, the same as the Plan tab's Confirm.
  Future<void> confirm() async {
    final confirmed = await _tab.confirmPlan(planId: id);
    if (confirmed != null) state = AsyncData(confirmed);
    _listChanged();
  }

  bool _mayBeLocal(MealPlan? plan) =>
      plan != null && plan.status != MealPlanStatus.archived;

  Future<void> _edit(UiAction action) async {
    final result = await _send(action);
    final plan = result.plan;
    if (plan == null) return;
    if (_mayBeLocal(plan)) await _tab.applyServerPlan(plan);
    if (ref.mounted) state = AsyncData(plan);
    _listChanged();
  }

  /// Refuse offline, run [action], and on failure put the plan back and
  /// rethrow: the screen keeps the plan and says what went wrong.
  Future<VanaActionResult> _send(UiAction action) async {
    final online = await ref.read(connectivityCheckerProvider).isOnline();
    if (!online) throw NeedsConnectionException(action.type);
    final previous = state;
    final outcome = await AsyncValue.guard(() => _actions.run(action));
    if (outcome.hasError) {
      if (ref.mounted) state = previous;
      Error.throwWithStackTrace(
        outcome.error!,
        outcome.stackTrace ?? StackTrace.current,
      );
    }
    return outcome.requireValue;
  }
}
