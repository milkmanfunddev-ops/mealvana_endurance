import 'package:flutter/foundation.dart';

import 'before_sub_phase.dart';
import 'formula_phase.dart';

/// A single editable component of a Before-phase formula.
///
/// Carries the structured data the controller already has on hand (food
/// identity + per-serving macros + servings count) so the PR 4 "Make this
/// mine" edit state can recompute the formula's macros live as the user
/// adjusts quantities — without a second query. In read mode the detail
/// screen still renders [BeforeFormulaView.componentDisplayStrings]; these
/// structured components only drive the edit state.
@immutable
class BeforeComponent {
  const BeforeComponent({
    required this.foodKey,
    required this.displayName,
    required this.displayNamePlural,
    required this.servingUnit,
    required this.quantity,
    required this.carbsPerServing,
    required this.proteinPerServing,
    required this.fatPerServing,
    required this.sodiumMgPerServing,
    required this.fluidMlPerServing,
  });

  /// Machine identifier from `component_food_names` (e.g. `medjool_dates`).
  /// Stable across quantity edits; used as the row key.
  final String foodKey;

  /// Human display name from `template_foods`; null when no matching row
  /// exists (the UI falls back to a humanised [foodKey]).
  final String? displayName;
  final String? displayNamePlural;

  /// Serving unit label (e.g. `cup`, `tbsp`); null for count-based foods.
  final String? servingUnit;

  /// Number of servings of this component in the formula. The only field the
  /// edit-state stepper mutates.
  final double quantity;

  // Per-single-serving macros, straight from `template_foods`. Zero when no
  // matching row exists.
  final double carbsPerServing;
  final double proteinPerServing;
  final double fatPerServing;
  final double sodiumMgPerServing;
  final double fluidMlPerServing;

  BeforeComponent copyWith({double? quantity}) => BeforeComponent(
        foodKey: foodKey,
        displayName: displayName,
        displayNamePlural: displayNamePlural,
        servingUnit: servingUnit,
        quantity: quantity ?? this.quantity,
        carbsPerServing: carbsPerServing,
        proteinPerServing: proteinPerServing,
        fatPerServing: fatPerServing,
        sodiumMgPerServing: sodiumMgPerServing,
        fluidMlPerServing: fluidMlPerServing,
      );
}

/// Immutable view model for a Before-phase formula card. Derived from
/// `templates` rows where `phase = 'before'`.
@immutable
class BeforeFormulaView {
  const BeforeFormulaView({
    required this.id,
    required this.name,
    required this.subPhase,
    required this.digestionSpeed,
    required this.templateType,
    required this.componentDisplayStrings,
    required this.components,
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

  /// `pre_workout_templates.template_type` — one of `food`, `drink`,
  /// `electrolyte`. PR 2 pin toggle is V1-scoped to food templates only;
  /// drink/electrolyte cards hide the pin affordance entirely.
  final String templateType;

  /// Whether this template is eligible for pinning under the V1 policy.
  /// Currently equivalent to `templateType == 'food'`; widens in later PRs.
  bool get isPinnable => templateType == 'food';

  /// Per-component display strings already including quantity + unit + name,
  /// e.g. `["1 Banana", "1 cup Blueberries", "1 cup Milk"]`. Built by the
  /// controller by joining `pre_workout_templates.component_quantities`
  /// with `template_foods.serving_unit` / `display_name(_plural)` via
  /// [FoodItemData.buildDisplayQuantity]. Rendered as-is in the list card
  /// subtitle and the detail "Components" section.
  final List<String> componentDisplayStrings;

  /// Structured per-component data (food identity + per-serving macros +
  /// servings count) used exclusively by the PR 4 edit state to recompute
  /// macros live. Parallel to [componentDisplayStrings] (same order, same
  /// length). Read mode does not touch this.
  final List<BeforeComponent> components;
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

/// Immutable view model for an After-phase formula card. Derived from
/// `post_workout_templates` rows (v2 Notion-imported, mirrored to Drift in
/// PR 3 substep 2). Used by the library list, the after-tab chip filter,
/// and the read-only after detail screen.
///
/// Standard portion only — there is no scaling target for recovery in V1
/// (see PLAN.md PR 3 "Locked scope"). Quantity stepper is intentionally
/// omitted on the detail screen.
@immutable
class AfterFormulaView {
  const AfterFormulaView({
    required this.id,
    required this.templateNumber,
    required this.name,
    required this.formula,
    required this.activityTypes,
    required this.componentFoodNames,
    required this.componentDisplayStrings,
    required this.carbSources,
    required this.allergens,
    required this.excludedDiets,
    required this.selectionPriority,
    required this.totalCarbsG,
    required this.totalProteinG,
    required this.totalFatG,
    required this.totalSodiumMg,
    required this.totalFluidMl,
    required this.totalCalories,
    this.portions,
    this.travelFriendliness,
    this.flavorProfile,
    this.prepEffort,
    this.proteinAnchor,
    this.targetCarbProteinRatio,
    this.notes,
  });

  final String id;
  final int templateNumber;
  final String name;

  /// Compact formula string, e.g. `2 cups chocolate milk`.
  final String formula;

  final List<String> activityTypes;
  final List<String> componentFoodNames;

  /// Per-component display strings already including quantity + unit + name,
  /// e.g. `["1 cup Cottage Cheese", "1 cup Applesauce"]`. Built by the
  /// controller by joining `post_workout_templates.default_servings` with
  /// `template_foods.serving_unit` / `display_name(_plural)`. Rendered as
  /// individual rows in the detail screen's Components section (mirrors
  /// the Before detail layout).
  final List<String> componentDisplayStrings;

  final List<String> carbSources;
  final List<String> allergens;
  final List<String> excludedDiets;

  /// Aggregated macros for the canonical single portion — sum of each
  /// component's per-serving macros from `template_foods` multiplied by its
  /// `default_servings` count. Zero when no matching `template_foods` row is
  /// found.
  final double totalCarbsG;
  final double totalProteinG;
  final double totalFatG;
  final double totalSodiumMg;
  final double totalFluidMl;
  final int totalCalories;

  /// Tie-breaker for the after-phase solver's non-pin fallthrough. Higher
  /// values win when multiple templates pass filters.
  final int selectionPriority;

  /// Human-readable portion description (e.g. `2 cups`). Surfaces in the
  /// detail screen's Components / Portions section.
  final String? portions;

  /// Primary PR 3 filter axis: `'in_bag'` | `'cooler_friendly'` | `'home_only'`.
  /// Persisted as a raw string here; the typed enum lives with the filter
  /// state in substep 5 (`TravelFriendliness`).
  final String? travelFriendliness;

  /// Sensory dimension: `'sweet_creamy'` | `'sweet_crunchy'` | `'savory_salty'`
  /// | `'warm_comforting'` | `'mixed'`. Used for V2 re-rolls.
  final String? flavorProfile;

  /// Prep effort: `'grab_and_go'` | `'assemble'` | `'cook'`.
  final String? prepEffort;

  /// Primary protein category (Notion taxonomy). Surfaced as a chip on the
  /// after card.
  final String? proteinAnchor;

  /// Human-readable carb:protein ratio (e.g. `~3:1`).
  final String? targetCarbProteinRatio;

  final String? notes;

  /// Whether this template is eligible for pinning. All post templates are
  /// pinnable in V1 (no `template_type` segmentation like Before).
  bool get isPinnable => true;

  FormulaPhase get phase => FormulaPhase.after;
}
