/// The hydration check's write path: answer → recompute → target + water row;
/// Change answer → exact revert.
///
/// SSOT: `docs/ssot/spec/design/components/hydration-check.md` v1 (state
/// table, H-2..H-5) and `surfaces/pre-workout-before-card.md` B-3, over
/// `spec/fueling/pre-workout-hydration.md` v6 *The urine check* (+PW-021).
///
/// Decision record (deferred-ledger **P2**, handoff §5.4 I10 — written before
/// coding):
///
/// * The recompute is **client-only**, through the same engine seam the
///   offline plan path uses (`MacroRepositoryImpl.preWorkoutHydrationFor` →
///   `OfflineMacroCalculator.calculatePreWorkoutHydration`). The engine is the
///   authority per its file header; no `generate-macros-v4` request field is
///   added this iteration.
/// * `timeBeforeWorkoutMin` is the plan's frozen lead time (the activity's
///   `time_before_minutes`), never the clock (hydration v6 *Inputs*).
/// * Only `fluidMl` (and the per-tier split) moves; the band is byte-identical
///   across answers (inv. 8b) — asserted here, not trusted.
/// * The water row is the *means*, added only when delivered fluid is below
///   the new target ("already covered" is the stateless-consumer rule). It is
///   tagged `origin: hydration_check` and its id is recorded, so Change
///   answer removes it even after the athlete edited its quantity (P3).
/// * Persistence: the answer + baseline + row id live in
///   `nutrition_plan_data.preWorkoutHydrationCheck`, the moved target in
///   `nutrition_plan_data.detailedMacroTargets.preRun`, the row in the SNACK
///   sub-phase's `foodItems` — one JSON, one atomic write (the controller's
///   `_saveNutritionPlanToActivity`).
library;

import '../data/macro_repository.dart';
import '../data/offline_macro_calculator.dart';
import '../domain/food_item_data.dart';
import '../domain/macro_targets.dart';
import '../domain/nutrition_plan.dart';
import '../domain/plan_section.dart';
import '../domain/pre_workout_before_card_model.dart';
import '../domain/pre_workout_feeding_labels.dart';
import '../domain/pre_workout_hydration_check.dart';

/// The plan + targets after an answer (or a revert).
class HydrationCheckWrite {
  const HydrationCheckWrite({required this.plan, required this.targets});

  final NutritionPlan plan;
  final MacroTargets targets;
}

/// One US cup of water — the 8 oz entry the DARK branch adds.
const double kHydrationCheckWaterRowMl = 236.588;

abstract final class PreWorkoutHydrationCheckService {
  /// Apply [answer] (H-2). Returns the plan/targets unchanged when the check
  /// does not exist for this plan (sub-2 h or gated — P1) or an answer is
  /// already recorded (call [revert] first).
  static HydrationCheckWrite answer({
    required NutritionPlan plan,
    required MacroTargets targets,
    required HydrationCheckAnswer answer,
    required double bodyWeightKg,
    required double workoutDurationMin,
    required double timeBeforeWorkoutMin,
    required double? tempC,
    required String Function() newFoodId,
    String categoryPrefix = 'before_run',
  }) {
    if (answer == HydrationCheckAnswer.none) {
      return HydrationCheckWrite(plan: plan, targets: targets);
    }
    if (plan.preWorkoutHydrationCheck != null) {
      return HydrationCheckWrite(plan: plan, targets: targets);
    }
    final pre = targets.preRun;
    if (timeBeforeWorkoutMin < kTierMealMin || pre.isHydrationGated) {
      return HydrationCheckWrite(plan: plan, targets: targets);
    }

    final result = MacroRepositoryImpl.preWorkoutHydrationFor(
      bodyWeightKg: bodyWeightKg,
      workoutDurationMin: workoutDurationMin,
      timeBeforeWorkoutMin: timeBeforeWorkoutMin,
      tempC: tempC,
      hydrationCheck: answer.toEngineCheck(),
    );
    if (result.gateTriggered || result.fluidMl == null) {
      // The engine gated a plan the stored targets did not — inputs drifted.
      // Do not write a half-state.
      return HydrationCheckWrite(plan: plan, targets: targets);
    }

    // inv. 8b: the band never moves on any answer. The stored band stays;
    // only the target and the tier split are taken from the recompute.
    assert(
      pre.fluidsLowMl == null ||
          (pre.fluidsLowMl! - (result.fluidLowMl ?? -1)).abs() < 1e-3,
      'hydration v6 inv. 8b: fluidLowMl moved on a hydration answer',
    );
    assert(
      pre.fluidsHighMl == null ||
          (pre.fluidsHighMl! - (result.fluidHighMl ?? -1)).abs() < 1e-3,
      'hydration v6 inv. 8b: fluidHighMl moved on a hydration answer',
    );

    final newTargetMl = result.fluidMl!;
    final updatedPre = pre.copyWith(
      fluidsMl: newTargetMl,
      fluidTiers: result.tiers
          .map((t) => PreRunFluidTier(tier: t.tier, fluidMl: t.fluidMl))
          .toList(),
      hydrationCheckUsed: result.hydrationCheckUsed,
    );

    // The water row: only on the dark branch, only when not already covered.
    String? addedId;
    var sections = plan.sections;
    if (answer.raisesTarget) {
      final delivered = _deliveredFluidMl(plan);
      if (delivered < newTargetMl) {
        addedId = newFoodId();
        sections = _mapSnack(
          plan.sections,
          (snack) => snack.copyWith(
            foodItems: [...snack.foodItems, _waterRow(addedId!)],
          ),
        );
      }
    }

    final record = PreWorkoutHydrationCheckRecord(
      answer: answer,
      baselineFluidMl: pre.fluidsMl,
      baselineFluidTiers: pre.fluidTiers,
      baselineHydrationCheckUsed: pre.hydrationCheckUsed,
      addedWaterFoodId: addedId,
    );

    return HydrationCheckWrite(
      plan: plan.copyWith(
        sections: sections,
        preWorkoutHydrationCheck: record,
        updatedAt: DateTime.now(),
      ),
      targets: targets.copyWith(preRun: updatedPre),
    );
  }

  /// Change answer (H-3/H-4): answer → NONE, the target returns to its
  /// pre-answer value, the tagged water row is removed (even if edited — P3).
  /// Nothing else changes.
  static HydrationCheckWrite revert({
    required NutritionPlan plan,
    required MacroTargets targets,
  }) {
    final record = plan.preWorkoutHydrationCheck;
    if (record == null) {
      return HydrationCheckWrite(plan: plan, targets: targets);
    }

    final pre = targets.preRun;
    final restoredPre = PreRunMacros(
      carbsG: pre.carbsG,
      proteinG: pre.proteinG,
      fatCapG: pre.fatCapG,
      fluidsMl: record.baselineFluidMl,
      sodiumMg: pre.sodiumMg,
      carbsLowG: pre.carbsLowG,
      carbsHighG: pre.carbsHighG,
      proteinLowG: pre.proteinLowG,
      proteinHighG: pre.proteinHighG,
      fluidsLowMl: pre.fluidsLowMl,
      fluidsHighMl: pre.fluidsHighMl,
      hydrationRegime: pre.hydrationRegime,
      fluidTargetBasis: pre.fluidTargetBasis,
      carbTargetBasis: pre.carbTargetBasis,
      fluidTiers: record.baselineFluidTiers,
      carbTiers: pre.carbTiers,
      hydrationCheckUsed: record.baselineHydrationCheckUsed,
    );

    final addedId = record.addedWaterFoodId;
    final sections = plan.sections
        .map((section) {
          if (!section.hasSubPhases) return section;
          return section.copyWith(
            subPhases: section.subPhases!
                .map(
                  (sp) => sp.copyWith(
                    foodItems: sp.foodItems
                        .where(
                          (f) =>
                              f.id != addedId &&
                              f.origin != kHydrationCheckRowOrigin,
                        )
                        .toList(),
                  ),
                )
                .toList(),
          );
        })
        .toList(growable: false);

    return HydrationCheckWrite(
      plan: plan.copyWith(
        sections: sections,
        clearPreWorkoutHydrationCheck: true,
        updatedAt: DateTime.now(),
      ),
      targets: targets.copyWith(preRun: restoredPre),
    );
  }

  /// Σ fluid (ml) over every BEFORE sub-phase's rows — the surface's delivered
  /// figure (B-1) in engine units.
  static double _deliveredFluidMl(NutritionPlan plan) {
    var total = 0.0;
    for (final section in plan.sections) {
      if (!_isBefore(section)) continue;
      final items = section.hasSubPhases
          ? section.subPhases!.expand((sp) => sp.foodItems)
          : section.foodItems;
      for (final f in items) {
        total += f.nutritionalInfo?.fluids ?? 0;
      }
    }
    return total;
  }

  static bool _isBefore(PlanSection s) =>
      s.id.toLowerCase().contains('before') ||
      s.title.toLowerCase().contains('before');

  static List<PlanSection> _mapSnack(
    List<PlanSection> sections,
    BeforeSubPhase Function(BeforeSubPhase) transform,
  ) {
    return sections
        .map((section) {
          if (!_isBefore(section) || !section.hasSubPhases) return section;
          final subPhases = section.subPhases!;
          final hasSnack = subPhases.any(
            (sp) =>
                PreWorkoutFeedingTier.parse(sp.subPhaseType) ==
                PreWorkoutFeedingTier.snack,
          );
          final updated = hasSnack
              ? subPhases
                    .map(
                      (sp) =>
                          PreWorkoutFeedingTier.parse(sp.subPhaseType) ==
                              PreWorkoutFeedingTier.snack
                          ? transform(sp)
                          : sp,
                    )
                    .toList()
              // FC-6: the check lives in the SNACK card; a ≥ 2 h plan always
              // has one, but a plan whose explosion omitted it gets the
              // sub-phase created so the row has a home.
              : [
                  ...subPhases,
                  transform(
                    const BeforeSubPhase(subPhaseType: 'snack', foodItems: []),
                  ),
                ];
          return section.copyWith(subPhases: updated);
        })
        .toList(growable: false);
  }

  static FoodItemData _waterRow(String id) => FoodItemData(
    id: id,
    name: HydrationCheckCopy.addedRowName,
    quantity: '1 cup Water',
    displayName: 'Water',
    displayNamePlural: 'cups Water',
    servingSize: '1 cup',
    isDrink: true,
    origin: kHydrationCheckRowOrigin,
    nutritionalInfo: const NutritionalInfo(
      calories: 0,
      carbs: 0,
      protein: 0,
      fat: 0,
      sodium: 0,
      fluids: kHydrationCheckWaterRowMl,
    ),
  );
}

/// Re-exported so the controller can name the engine enum without importing
/// the calculator directly.
typedef EngineHydrationCheck = HydrationCheck;
