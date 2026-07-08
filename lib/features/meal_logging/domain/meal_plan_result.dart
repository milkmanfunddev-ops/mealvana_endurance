import 'meal_analysis_result.dart'
    show MealAnalysisConfidence, MealAnalysisItem, MealAnalysisTotals;
import 'meal_slot.dart';

/// One meal parsed from an imported meal-plan document.
///
/// Reuses [MealAnalysisItem]/[MealAnalysisTotals] so parsed macros map onto the
/// same wire shape the photo/describe flows use. Shape mirrors `PlanMealSchema`
/// in `supabase/functions/_shared/meal_plan/schema.ts`.
class ParsedPlanMeal {
  const ParsedPlanMeal({
    required this.name,
    this.dayLabel,
    required this.suggestedSlot,
    required this.confidence,
    required this.items,
    required this.totals,
    this.notes,
  });

  final String name;

  /// The day this meal appeared under in the plan, if the document was
  /// day-organized (e.g. "Day 1", "Monday"). Free-form; used only for grouping.
  final String? dayLabel;

  final MealSlot suggestedSlot;
  final MealAnalysisConfidence confidence;
  final List<MealAnalysisItem> items;
  final MealAnalysisTotals totals;
  final String? notes;

  factory ParsedPlanMeal.fromJson(Map<String, dynamic> json) {
    final slot = MealSlot.fromWireValue(json['suggested_slot'] as String?) ??
        MealSlot.snack;
    final items = (json['items'] as List<dynamic>)
        .cast<Map<String, dynamic>>()
        .map(MealAnalysisItem.fromJson)
        .toList();
    return ParsedPlanMeal(
      name: json['name'] as String,
      dayLabel: json['day_label'] as String?,
      suggestedSlot: slot,
      confidence: MealAnalysisConfidence.fromString(
        json['confidence'] as String? ?? 'medium',
      ),
      items: items,
      totals: MealAnalysisTotals.fromJson(
        json['totals'] as Map<String, dynamic>,
      ),
      notes: json['notes'] as String?,
    );
  }
}

/// The structured result returned by the `parse-meal-plan` edge function.
///
/// Shape mirrors `MealPlanSchema` in
/// `supabase/functions/_shared/meal_plan/schema.ts`.
class MealPlanResult {
  const MealPlanResult({
    this.planTitle,
    required this.meals,
    this.notes,
  });

  final String? planTitle;
  final List<ParsedPlanMeal> meals;
  final String? notes;

  factory MealPlanResult.fromJson(Map<String, dynamic> json) {
    final meals = (json['meals'] as List<dynamic>)
        .cast<Map<String, dynamic>>()
        .map(ParsedPlanMeal.fromJson)
        .toList();
    return MealPlanResult(
      planTitle: json['plan_title'] as String?,
      meals: meals,
      notes: json['notes'] as String?,
    );
  }
}
