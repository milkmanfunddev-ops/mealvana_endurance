import 'package:flutter/foundation.dart';

import 'before_sub_phase.dart';
import 'formula_phase.dart';

/// Immutable view model for a Before-phase formula card. Derived from
/// `templates` rows where `phase = 'before'`.
@immutable
class BeforeFormulaView {
  const BeforeFormulaView({
    required this.id,
    required this.name,
    required this.subPhase,
    required this.digestionSpeed,
    required this.componentDisplayStrings,
    required this.allergens,
    required this.excludedDiets,
    required this.totalCarbsG,
    required this.totalProteinG,
    required this.totalFatG,
    required this.totalSodiumMg,
    required this.totalFluidMl,
    required this.totalCalories,
    required this.timingWindow,
    this.notes,
  });

  final String id;
  final String name;
  final BeforeSubPhase? subPhase;
  final String digestionSpeed;

  /// Per-component display strings already including quantity + unit + name,
  /// e.g. `["1 Banana", "1 cup Blueberries", "1 cup Milk"]`. Built by the
  /// controller by joining `pre_workout_templates.component_quantities`
  /// with `template_foods.serving_unit` / `display_name(_plural)` via
  /// [FoodItemData.buildDisplayQuantity]. Rendered as-is in the list card
  /// subtitle and the detail "Components" section.
  final List<String> componentDisplayStrings;
  final List<String> allergens;
  final List<String> excludedDiets;
  final double totalCarbsG;
  final double totalProteinG;
  final double totalFatG;
  final double totalSodiumMg;
  final double totalFluidMl;
  final int totalCalories;

  /// Display label like `< 30 min`, `1-2 hours` — used in detail header.
  final String timingWindow;

  /// Optional template-level notes.
  final String? notes;

  FormulaPhase get phase => FormulaPhase.before;
}

/// Immutable view model for a During-phase formula card. Derived from
/// `during_workout_templates` rows.
@immutable
class DuringFormulaView {
  const DuringFormulaView({
    required this.id,
    required this.templateNumber,
    required this.name,
    required this.formula,
    required this.foodForm,
    required this.activityTypes,
    required this.durationBrackets,
    required this.gutTrainingLevels,
    required this.componentFoodNames,
    required this.allergens,
    required this.excludedDiets,
    this.componentCarbRatios,
    this.primaryToSecondaryRatio,
    this.notes,
  });

  final String id;
  final int templateNumber;
  final String name;

  /// Compact formula string e.g. `Gel + Water + Sports Drink`.
  final String formula;
  final String foodForm;
  final List<String> activityTypes;
  final List<String> durationBrackets;
  final List<String> gutTrainingLevels;
  final List<String> componentFoodNames;
  final List<String> allergens;
  final List<String> excludedDiets;
  final Map<String, double>? componentCarbRatios;
  final String? primaryToSecondaryRatio;
  final String? notes;

  FormulaPhase get phase => FormulaPhase.during;
}
