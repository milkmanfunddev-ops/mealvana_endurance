/// Builds the BEFORE card's view data from the plan and the engine's targets.
///
/// SSOT: `docs/ssot/spec/design/surfaces/pre-workout-before-card.md` v1 —
/// this is the surface's arithmetic: B-1 (delivered = Σ rows), B-2
/// (membership from the frozen `timeBeforeWorkoutMin`, never a clock), B-5
/// (every figure traces to an engine field; oz is a display unit over ml).
/// Component internals: `components/{fuel-stat,feeding-card,hydration-check}.md`.
///
/// What the card reads (handoff §5.8 / §5.9 rule 3):
///
/// * fluid target / band → hydration v6 `fluidMl` / `fluidLowMl` / `fluidHighMl`
///   (`PreRunMacros.fluidsMl` — `null` on the gate path renders "No fluid
///   target for this session", never "0 oz")
/// * carbs target / band → carbs v2 `carbsG` / `carbsLowG` / `carbsHighG`
/// * sodium → the SUM of the food rows, never the legacy map's `sodium_mg`
/// * per-tier fluid → `fluidTiers[]`; per-tier carb aim → `carbTiers[]` (only
///   for the FC-1 naming threshold — never rendered, FC-2)
library;

import '../domain/food_item_data.dart';
import '../domain/macro_targets.dart';
import '../domain/plan_section.dart';
import '../domain/pre_workout_before_card_model.dart';
import '../domain/pre_workout_display_units.dart';
import '../domain/pre_workout_feeding_labels.dart';
import '../domain/pre_workout_hydration_check.dart';
import '../../../shared/utils/food_display_utils.dart' as food_utils;

abstract final class PreWorkoutBeforeCardAssembler {
  /// Default stepper ceiling for a food row (the row's own cap when the
  /// catalog carries none).
  static const double defaultRowCap = 8.0;

  static PreWorkoutBeforeCardData assemble({
    required PreRunMacros? preRun,
    required List<BeforeSubPhase> subPhases,
    required double timeBeforeWorkoutMin,
    required double? bodyWeightKg,
    required PreWorkoutHydrationCheckRecord? hydrationCheck,
    String categoryPrefix = 'before_run',
  }) {
    final byType = <String, BeforeSubPhase>{
      for (final sp in subPhases) sp.subPhaseType: sp,
    };

    // --- B-2: membership from the engine's tiers (themselves a function of
    // the frozen lead time). A sub-phase that carries foods but no tier is
    // still shown — never hide the athlete's food.
    final tiers = <PreWorkoutFeedingTier>{};
    for (final t in preRun?.carbTiers ?? const <PreRunCarbTier>[]) {
      final parsed = PreWorkoutFeedingTier.parse(t.tier);
      if (parsed != null) tiers.add(parsed);
    }
    for (final t in preRun?.fluidTiers ?? const <PreRunFluidTier>[]) {
      final parsed = PreWorkoutFeedingTier.parse(t.tier);
      if (parsed != null) tiers.add(parsed);
    }
    for (final sp in subPhases) {
      final parsed = PreWorkoutFeedingTier.parse(sp.subPhaseType);
      if (parsed != null && sp.foodItems.isNotEmpty) tiers.add(parsed);
    }
    if (tiers.isEmpty && preRun == null) {
      for (final sp in subPhases) {
        final parsed = PreWorkoutFeedingTier.parse(sp.subPhaseType);
        if (parsed != null) tiers.add(parsed);
      }
    }
    final ordered = PreWorkoutFeedingTier.values
        .where(tiers.contains)
        .toList(growable: false);

    final isFasted = preRun?.isCarbRecommendationAbsent ?? false;
    final isGated = preRun?.isHydrationGated ?? true;

    // --- B-1: delivered = Σ over every feeding card's rows.
    double carbsG = 0, fluidMl = 0, sodiumMg = 0;
    final feedings = <FeedingCardData>[];
    for (var i = 0; i < ordered.length; i++) {
      final tier = ordered[i];
      final sp = byType[tier.subPhaseType];
      final rows = <FeedingFoodRow>[];
      double cardCarbs = 0;
      for (final food in sp?.foodItems ?? const <FoodItemData>[]) {
        final row = _row(food, '$categoryPrefix:${tier.subPhaseType}');
        rows.add(row);
        cardCarbs += row.carbsG;
        carbsG += row.carbsG;
        fluidMl += row.fluidMl;
        sodiumMg += row.sodiumMg;
      }

      final snackAim = preRun?.carbTiers
          ?.where((t) => PreWorkoutFeedingTier.parse(t.tier) == tier)
          .map((t) => t.carbsG)
          .firstOrNull;
      final tierFluid = preRun?.fluidTiers
          ?.where((t) => PreWorkoutFeedingTier.parse(t.tier) == tier)
          .map((t) => t.fluidMl)
          .firstOrNull;

      feedings.add(
        FeedingCardData(
          tier: tier,
          category: '$categoryPrefix:${tier.subPhaseType}',
          title: preWorkoutFeedingTitle(
            tier,
            snackCarbAimG: tier == PreWorkoutFeedingTier.snack
                ? snackAim
                : null,
            bodyWeightKg: bodyWeightKg,
          ),
          windowLabel: preWorkoutWindowLabel(
            tier,
            timeBeforeMin: timeBeforeWorkoutMin,
            isFirstFeeding: i == 0,
          ),
          rows: rows,
          carbsDelivered: isFasted ? null : wholeUnits(cardCarbs),
          fluidOz: (!isGated && tierFluid != null && tierFluid > 0)
              ? flOzTarget(tierFluid)
              : null,
          hostsHydrationCheck:
              tier == PreWorkoutFeedingTier.snack &&
              _checkExists(
                timeBeforeWorkoutMin: timeBeforeWorkoutMin,
                isGated: isGated,
              ),
        ),
      );
    }

    // --- fuel-stats (traceability: B-5 / fuel-stat table).
    final carbs = FuelStatData(
      quantity: FuelQuantity.carbs,
      mode: isFasted ? FuelStatMode.none : FuelStatMode.targeted,
      delivered: wholeUnits(carbsG),
      target: preRun == null ? null : wholeUnits(preRun.carbsG),
      bandLow: preRun?.carbsLowG == null
          ? null
          : wholeUnits(preRun!.carbsLowG!),
      bandHigh: preRun?.carbsHighG == null
          ? null
          : wholeUnits(preRun!.carbsHighG!),
    );
    final fluidTarget = preRun?.fluidsMl;
    final fluids = FuelStatData(
      quantity: FuelQuantity.fluids,
      mode: (preRun != null && isGated)
          ? FuelStatMode.noTarget
          : FuelStatMode.targeted,
      delivered: flOzDelivered(fluidMl),
      target: fluidTarget == null ? null : flOzTarget(fluidTarget),
      bandLow: preRun?.fluidsLowMl == null
          ? null
          : flOzFloor(preRun!.fluidsLowMl!),
      bandHigh: preRun?.fluidsHighMl == null
          ? null
          : flOzCeil(preRun!.fluidsHighMl!),
    );
    final sodium = FuelStatData(
      quantity: FuelQuantity.sodium,
      mode: FuelStatMode.targeted,
      delivered: wholeUnits(sodiumMg),
    );

    HydrationCheckViewState? check;
    if (_checkExists(
          timeBeforeWorkoutMin: timeBeforeWorkoutMin,
          isGated: isGated,
        ) &&
        fluidTarget != null) {
      check = HydrationCheckViewState(
        answer: hydrationCheck?.answer ?? HydrationCheckAnswer.none,
        targetOz: flOzTarget(fluidTarget),
        alreadyCovered: hydrationCheck?.alreadyCovered ?? false,
      );
    }

    return PreWorkoutBeforeCardData(
      carbs: carbs,
      fluids: fluids,
      sodium: sodium,
      feedings: feedings,
      hydrationCheck: check,
    );
  }

  /// hydration-check "When it exists at all": present only when
  /// `timeBeforeWorkoutMin >= T_REF`; suppressed on a gated plan (P1 — a
  /// target that is not stated cannot be raised). No clock (PW-021).
  static bool _checkExists({
    required double timeBeforeWorkoutMin,
    required bool isGated,
  }) => timeBeforeWorkoutMin >= kTierMealMin && !isGated;

  static FeedingFoodRow _row(FoodItemData food, String category) {
    final info = food.nutritionalInfo;
    final qty = food_utils.parseLeadingQuantity(food.quantity) ?? 1.0;
    return FeedingFoodRow(
      id: food.id,
      category: category,
      name: food.displayName ?? food.name,
      quantity: qty,
      step: food.isIndivisible ? 1.0 : 0.5,
      cap: defaultRowCap,
      carbsG: (info?.carbs ?? 0).toDouble(),
      fluidMl: info?.fluids ?? 0,
      sodiumMg: (info?.sodium ?? 0).toDouble(),
      icon: _iconFor(food),
      note: food.origin == kHydrationCheckRowOrigin
          ? HydrationCheckCopy.addedRowNote
          : null,
    );
  }

  static FeedingRowIcon _iconFor(FoodItemData food) {
    final fluids = food.nutritionalInfo?.fluids ?? 0;
    if (food.isDrink || fluids > 0) return FeedingRowIcon.drop;
    final name = food.name.toLowerCase();
    if (name.contains('chew') || name.contains('gel')) {
      return FeedingRowIcon.chew;
    }
    if (name.contains('bar')) return FeedingRowIcon.bar;
    return FeedingRowIcon.bowl;
  }
}
