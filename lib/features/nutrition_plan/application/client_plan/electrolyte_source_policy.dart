/// During-phase electrolyte source selection — RULED food-recommendation §4
/// (Xuan, 2026-09-03), the F-22/46/47 twin port.
///
/// This is the Dart twin of `pickBestElectrolyte` in
/// `supabase/functions/_shared/nutrition/during-utils.ts` — one algorithm,
/// both engines (§8 twin contract; a fix landing in one twin is a defect
/// until ported):
///   1. Symmetric target-seeking: sodium score is |target − delivered| /
///      target — overshoot above the TARGET costs the same as undershoot.
///      The hard sodiumUpper filter still applies.
///   2. The serving cap is the catalog row's max_servings_during,
///      gut-adjusted via [gutAdjustedMaxServings] (identical rule both
///      engines; the old Dart form let high gut exceed the row cap).
///   3. Carryable-first (§4.3): when the best carryable pick's
///      distance-to-target is within [kCarryableFitTolerance] × target of the
///      best pick overall, the carryable one wins. Supersedes the retired
///      capsulePenalty steer.
///   4. Baseline ("add nothing") uses the SAME formula as the candidate
///      score, including the 1.5× carb-overshoot weight.
///   5. Floor rescue keeps the 2026-07-29 server form: only a start below the
///      band floor accepts a score-worsening pick that clears it (the old
///      Dart gate accepted one from an already-in-range state — the F-46
///      floor-rescue gap).
library;

import 'dart:math';

import '../../domain/solver_food.dart';
import '../../domain/solver_types.dart';

/// §4.3 carryable-first tolerance: fits are comparable when their sodium
/// distances-to-target differ by ≤ this fraction of the target.
const double kCarryableFitTolerance = 0.10;

/// §4.3 carryable form: capsule/tablet/gel/chew outrank liquid/mix volume.
bool isCarryableForm(SolverFood food) {
  return (food.productType == 'supplement' && !food.isLiquid) ||
      food.productType == 'gel' ||
      food.productType == 'chew';
}

/// §4.2 one-cap rule: the catalog row's max_servings_during is THE cap,
/// gut-adjusted identically on both engines — low gut halves it (floor 1);
/// high gut never exceeds the row's value.
double gutAdjustedMaxServings(int maxServings, String? gutLevel) {
  final mult = gutLevel == 'low' ? 0.5 : 1.0;
  return min(maxServings.toDouble(), max(1.0, maxServings * mult));
}

/// Feasible serving candidates for a food — the Dart twin of
/// `getServingCandidates` (during-utils.ts): indivisible foods use whole
/// servings from ceil(min); divisible foods use 0.5 increments from the
/// rounded min (floor 0.5). The catalog row's min_servings_during is honoured
/// (the F-47 gap: Dart used to hardcode the 0.5 start).
List<double> servingCandidates(SolverFood food, {double? maxOverride}) {
  final maxS = maxOverride ?? max(food.minServings, food.maxServings.toDouble());
  final start = food.isIndivisible
      ? max(1.0, food.minServings.ceilToDouble())
      : max(0.5, (food.minServings * 2).roundToDouble() / 2);
  final step = food.isIndivisible ? 1.0 : 0.5;
  final out = <double>[];
  for (var s = start; s <= maxS + 1e-6; s += step) {
    out.add(food.isIndivisible ? s.roundToDouble() : (s * 2).roundToDouble() / 2);
  }
  return out;
}

/// RULED food-recommendation §4.5 (Xuan, 2026-09-03): the sodium backfill
/// essential prefers an electrolyte capsule/tablet; a salt packet is the LAST
/// resort. Within a class, higher sodium density (mg per ml carried) still
/// wins. TS twin: `pin-backfill.ts#sortSodiumBackfillCandidates`.
List<SolverFood> sortSodiumBackfillCandidates(List<SolverFood> pool) {
  bool isSaltPacket(SolverFood f) =>
      f.name.toLowerCase().contains('salt') ||
      (f.displayName ?? '').toLowerCase().contains('salt');
  double density(SolverFood f) => f.sodiumMg / max(1.0, f.fluidMl);
  final out = [...pool];
  out.sort((a, b) {
    final saltRank =
        (isSaltPacket(a) ? 1 : 0).compareTo(isSaltPacket(b) ? 1 : 0);
    if (saltRank != 0) return saltRank;
    return density(b).compareTo(density(a));
  });
  return out;
}

/// Bounds for one electrolyte fill — mirrors `ElectrolyteBounds` (TS).
class ElectrolyteSourceBounds {
  const ElectrolyteSourceBounds({
    required this.sodiumTarget,
    required this.sodiumLower,
    required this.sodiumUpper,
    required this.fluidTarget,
    required this.fluidUpper,
    required this.carbTarget,
    required this.carbUpper,
    this.gutLevel,
  });

  final double sodiumTarget;
  final double sodiumLower;
  final double sodiumUpper;
  final double fluidTarget;
  final double fluidUpper;
  final double carbTarget;
  final double carbUpper;
  final String? gutLevel;
}

/// One chosen source — mirrors `ElectrolytePickResult` (TS).
class ElectrolyteSourcePick {
  const ElectrolyteSourcePick({
    required this.food,
    required this.servings,
    required this.score,
    required this.sodiumAfter,
    required this.fluidAfter,
    required this.carbsAfter,
  });

  final SolverFood food;
  final double servings;
  final double score;
  final double sodiumAfter;
  final double fluidAfter;
  final double carbsAfter;
}

/// The ruled picker. Returns null when no candidate improves on "add
/// nothing" (and no floor rescue applies).
ElectrolyteSourcePick? pickBestElectrolyteSource(
  List<SolverFood> pool,
  double currentSodium,
  double currentFluid,
  double currentCarbs,
  ElectrolyteSourceBounds bounds,
) {
  final sodiumTarget = bounds.sodiumTarget;

  double sodiumScore(double sodium) =>
      sodiumTarget > 0 ? (sodiumTarget - sodium).abs() / sodiumTarget : 0.0;
  double fluidScore(double fluid) =>
      (bounds.fluidTarget > 0 && fluid > bounds.fluidUpper)
          ? ((fluid - bounds.fluidUpper) / bounds.fluidTarget) * 3
          : 0.0;
  double carbScore(double carbs) =>
      (bounds.carbTarget > 0 && carbs > bounds.carbUpper)
          ? ((carbs - bounds.carbUpper) / bounds.carbTarget) * 1.5
          : 0.0;

  final baselineScore = sodiumScore(currentSodium) +
      fluidScore(currentFluid) +
      carbScore(currentCarbs);

  ElectrolyteSourcePick? best;
  ElectrolyteSourcePick? bestCarryable;
  var bestIsCarryable = false;

  for (final elec in pool) {
    if (elec.sodiumMg <= 0) continue;

    final carryable = isCarryableForm(elec);
    final effectiveMax =
        gutAdjustedMaxServings(elec.maxServings, bounds.gutLevel);
    final candidates = servingCandidates(elec)
        .where((s) => s <= effectiveMax + 1e-6);

    for (final servings in candidates) {
      final sodium = currentSodium + elec.sodiumMg * servings;
      final fluid = currentFluid + elec.fluidMl * servings;
      final carbs = currentCarbs + elec.carbsG * servings;
      if (sodium > bounds.sodiumUpper + 1e-6) continue;
      if (fluid > bounds.fluidUpper + 1e-6) continue;
      if (carbs > bounds.carbUpper + 1e-6) continue;

      final preferenceBonus =
          elec.preferenceScore >= kPrefScoreLiked ? -0.02 : 0.0;
      final score = sodiumScore(sodium) +
          fluidScore(fluid) +
          carbScore(carbs) +
          preferenceBonus;

      final pick = ElectrolyteSourcePick(
        food: elec,
        servings: servings,
        score: score,
        sodiumAfter: sodium,
        fluidAfter: fluid,
        carbsAfter: carbs,
      );
      bool beats(ElectrolyteSourcePick? incumbent) {
        if (incumbent == null) return true;
        if (score < incumbent.score - 1e-9) return true;
        if ((score - incumbent.score).abs() >= 1e-9) return false;
        final dist = (sodiumTarget - sodium).abs();
        final incDist = (sodiumTarget - incumbent.sodiumAfter).abs();
        if (dist < incDist - 1e-9) return true;
        if ((dist - incDist).abs() >= 1e-9) return false;
        return servings < incumbent.servings;
      }

      if (beats(best)) {
        best = pick;
        bestIsCarryable = carryable;
      }
      if (carryable && beats(bestCarryable)) bestCarryable = pick;
    }
  }

  if (best == null) return null;

  // §4.3 carryable-first on comparable fits (sodium distance, mg).
  var chosen = best;
  if (!bestIsCarryable && bestCarryable != null && sodiumTarget > 0) {
    final distBest = (sodiumTarget - best.sodiumAfter).abs();
    final distCarry = (sodiumTarget - bestCarryable.sodiumAfter).abs();
    if (distCarry - distBest <=
        kCarryableFitTolerance * sodiumTarget + 1e-9) {
      chosen = bestCarryable;
    }
  }

  if (currentSodium < bounds.sodiumLower - 1e-6 &&
      chosen.sodiumAfter >= bounds.sodiumLower) {
    return chosen;
  }
  return chosen.score < baselineScore ? chosen : null;
}
