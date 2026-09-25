import 'meal_plan_status.dart';
import 'wire_record.dart';

/// One row of `list_plans` — what `listPlans` in `plan.ts` emits: the plan's
/// id, its name, week, status, cooking mode and how many meals it holds.
/// Deleted plans and drafts never confirmed never come through (mp-677).
class MealPlanSummary {
  const MealPlanSummary({
    required this.id,
    required this.weekStart,
    required this.status,
    this.name,
    this.batchCooking = true,
    this.mealCount = 0,
  });

  final String id;

  /// `YYYY-MM-DD`, the first day of the plan's period.
  final String weekStart;
  final MealPlanStatus status;

  /// The athlete's own name for the plan; `null` shows it by its week.
  final String? name;
  final bool batchCooking;
  final int mealCount;

  factory MealPlanSummary.fromJson(Map<String, dynamic> json) =>
      MealPlanSummary(
        id: requireString(json, 'id'),
        weekStart: requireString(json, 'weekStart'),
        status: MealPlanStatus.requireWire(readString(json, 'status')),
        name: readString(json, 'name'),
        batchCooking: readBool(json, 'batchCooking') ?? true,
        mealCount: readInt(json, 'mealCount') ?? 0,
      );
}
