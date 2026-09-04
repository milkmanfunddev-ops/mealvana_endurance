import 'day_plan.dart';
import 'meal_plan_status.dart';
import 'plan_coverage.dart';
import 'plan_meal.dart';
import 'plan_rule.dart';
import 'shopping_item.dart';
import 'wire_record.dart';

/// A `meal_plans` row with its children — `MealPlan` in `contracts.ts`.
///
/// One confirmed plan per athlete-week; any number of drafts, each owned by
/// the Vana conversation building it ([conversationId]; `null` = week-level).
class MealPlan extends WireRecord {
  const MealPlan({
    required this.id,
    required this.weekStart,
    required this.status,
    this.batchCooking = false,
    this.days = const {},
    this.conversationId,
    this.brief,
    this.rules = const [],
    this.meals = const [],
    this.shopping = const [],
    this.dayNotes = const {},
    this.dayNotesStale = false,
    required this.coverage,
  });

  final String id;

  /// `YYYY-MM-DD` (Monday).
  final String weekStart;
  final MealPlanStatus status;
  final bool batchCooking;

  /// ISO date → that day's slots.
  final Map<String, DayPlan> days;
  final String? conversationId;
  final String? brief;
  final List<PlanRule> rules;
  final List<PlanMeal> meals;
  final List<ShoppingItem> shopping;

  /// ISO date → Vana's precomputed one-liner for that day.
  final Map<String, String> dayNotes;

  /// `true` while an edit has invalidated [dayNotes] and the server has not
  /// regenerated them yet (the client re-polls `get_home`; never generates).
  final bool dayNotesStale;
  final PlanCoverage coverage;

  bool get isDraft => status == MealPlanStatus.draft;
  bool get isConfirmed => status == MealPlanStatus.confirmed;

  DayPlan dayFor(String date) => days[date] ?? DayPlan.empty;

  /// Parses the wire shape. When `coverage` is absent (a locally built
  /// plan), it is computed with [PlanCoverageService].
  factory MealPlan.fromJson(Map<String, dynamic> json) {
    final meals = readRecordList(json, 'meals', PlanMeal.fromJson);
    final coverageJson = asJsonMap(json['coverage']);
    final daysJson = asJsonMap(json['days']) ?? const <String, dynamic>{};
    final days = <String, DayPlan>{};
    for (final entry in daysJson.entries) {
      final map = asJsonMap(entry.value);
      if (map != null) days[entry.key] = DayPlan.fromJson(map);
    }
    return MealPlan(
      id: requireString(json, 'id'),
      weekStart: requireString(json, 'weekStart'),
      status: MealPlanStatus.requireWire(readString(json, 'status')),
      batchCooking: readBool(json, 'batchCooking') ?? false,
      days: Map.unmodifiable(days),
      conversationId: readString(json, 'conversationId'),
      brief: readString(json, 'brief'),
      rules: readRecordList(json, 'rules', PlanRule.fromJson),
      meals: meals,
      shopping: readRecordList(json, 'shopping', ShoppingItem.fromJson),
      dayNotes: readStringMap(json, 'dayNotes'),
      dayNotesStale: readBool(json, 'dayNotesStale') ?? false,
      coverage: coverageJson == null
          ? PlanCoverageService.compute(meals)
          : PlanCoverage.fromJson(coverageJson),
    );
  }

  @override
  Map<String, dynamic> toJson() => {
    'id': id,
    'weekStart': weekStart,
    'status': status.wire,
    'batchCooking': batchCooking,
    'days': {for (final entry in days.entries) entry.key: entry.value.toJson()},
    'conversationId': conversationId,
    'brief': brief,
    'rules': rules.map((r) => r.toJson()).toList(),
    'meals': meals.map((m) => m.toJson()).toList(),
    'shopping': shopping.map((s) => s.toJson()).toList(),
    'dayNotes': dayNotes,
    'dayNotesStale': dayNotesStale,
    'coverage': coverage.toJson(),
  };

  MealPlan copyWith({
    String? id,
    String? weekStart,
    MealPlanStatus? status,
    bool? batchCooking,
    Map<String, DayPlan>? days,
    String? conversationId,
    String? brief,
    List<PlanRule>? rules,
    List<PlanMeal>? meals,
    List<ShoppingItem>? shopping,
    Map<String, String>? dayNotes,
    bool? dayNotesStale,
    PlanCoverage? coverage,

    /// Recompute [coverage] from the resulting [meals] (local-first edits).
    bool recomputeCoverage = false,
  }) {
    final nextMeals = meals ?? this.meals;
    return MealPlan(
      id: id ?? this.id,
      weekStart: weekStart ?? this.weekStart,
      status: status ?? this.status,
      batchCooking: batchCooking ?? this.batchCooking,
      days: days ?? this.days,
      conversationId: conversationId ?? this.conversationId,
      brief: brief ?? this.brief,
      rules: rules ?? this.rules,
      meals: nextMeals,
      shopping: shopping ?? this.shopping,
      dayNotes: dayNotes ?? this.dayNotes,
      dayNotesStale: dayNotesStale ?? this.dayNotesStale,
      // A local recompute keeps the server's denominator (the athlete's
      // coverage scope) — only the numerator changes client-side.
      coverage: recomputeCoverage
          ? PlanCoverageService.compute(
              nextMeals,
              lunchDinnerSlots: (coverage ?? this.coverage).lunchDinnerSlots,
            )
          : (coverage ?? this.coverage),
    );
  }
}
