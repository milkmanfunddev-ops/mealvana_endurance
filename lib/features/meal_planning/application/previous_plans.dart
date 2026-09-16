import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../data/vana_action_client.dart';
import '../domain/meal_plan.dart';
import '../domain/meal_plan_summary.dart';
import '../domain/ui_action.dart';
import 'meal_plan_controller.dart';

part 'previous_plans.g.dart';

/// The athlete's earlier plans, newest first — everything `list_plans`
/// answers except the plan on the Plan tab and plans with nothing in them.
/// The server already leaves deleted plans out (`is_deleted = false` in
/// `plan.ts`), so nothing is filtered for that here.
///
/// Read-only and server-only: [MealPlanController] owns the current plan and
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

/// One plan by id, straight from the server (`get_plan {id}`), for the
/// read-only view of an earlier plan. `null` when the server no longer has
/// it — deleted since the list was read.
@riverpod
Future<MealPlan?> planById(Ref ref, String id) async {
  final result = await ref
      .read(vanaActionClientProvider)
      .run(GetPlanAction(id: id));
  return result.plan;
}
