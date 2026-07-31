import 'dart:math';

import '../../domain/solver_food.dart';
import '../../domain/solver_types.dart';
import '../../domain/sport_config.dart';

/// Client-side greedy solver for all nutrition plan phases.
///
/// Intentionally simpler than the V3 edge function — this is a "good enough"
/// fallback that produces real food selections when the server is unreachable.
/// The plan is regenerated when connectivity returns.
///
/// Based on the server's `greedy-fallback.ts` algorithm, adapted for Dart.
class ClientGreedySolver {
  const ClientGreedySolver();

  /// Solve for a single phase: select foods from [foods] to approximate [targets].
  ///
  /// [phase] is one of: 'before', 'during', 'after'.
  /// [config] controls max foods and servings per food.
  List<SolverSelection> solve({
    required List<SolverFood> foods,
    required SolverTargets targets,
    required String phase,
    required SportPhaseConfig config,
  }) {
    if (foods.isEmpty) return [];

    final selections = <SolverSelection>[];
    final totals = _RunningTotals();

    // Sort: preference desc, then macro efficiency
    final sorted = List<SolverFood>.from(foods)
      ..sort((a, b) => _compareFoods(a, b, phase));

    final carbsTarget = targets.carbsG;
    final waterTarget = targets.fluidMl;

    for (final food in sorted) {
      if (selections.length >= config.maxFoods) break;

      // Skip foods that would overshoot already-met targets
      if (_wouldOvershoot(food, totals, targets, phase)) continue;

      // Calculate needed servings based on primary deficit
      var neededServings = _calcNeededServings(
        food: food,
        totals: totals,
        targets: targets,
        phase: phase,
      );

      if (neededServings <= 0) continue;

      // Cap servings to avoid overshoots
      neededServings = _capServings(
        food: food,
        neededServings: neededServings,
        totals: totals,
        targets: targets,
        phase: phase,
      );

      // Apply limits
      neededServings = min(
        neededServings.toDouble(),
        min(config.maxServingsPerFood.toDouble(), food.maxServings.toDouble()),
      );

      // Round: indivisible → whole numbers, divisible → nearest 0.5. Both
      // rounders floor at one (resp. half) a serving because you cannot take
      // 0.4 of a tablet — so bail out FIRST when a band-ceiling cap zeroed the
      // count, or that floor silently reinstates a ceiling-breaching serving.
      // Mirrors the same guard in greedy-fallback.ts (2026-07-29).
      if (neededServings <= 0) continue;
      neededServings = food.isIndivisible
          ? max(1, neededServings.roundToDouble())
          : _roundToHalf(neededServings);

      if (neededServings <= 0) continue;

      selections.add(
        SolverSelection(
          foodId: food.id,
          foodName: food.name,
          quantity: neededServings,
          carbsG: food.carbsG * neededServings,
          proteinG: food.proteinG * neededServings,
          fatG: food.fatG * neededServings,
          sodiumMg: food.sodiumMg * neededServings,
          fluidMl: food.fluidMl * neededServings,
          calories: (food.calories * neededServings).round(),
          displayName: food.displayName,
          displayNamePlural: food.displayNamePlural,
          description: food.description,
          imageAddress: food.imageAddress,
          servingSize: food.servingSize,
          servingUnit: food.servingUnit,
          isDrink: food.isLiquid,
          isIndivisible: food.isIndivisible,
          isLiquid: food.isLiquid,
          isElectrolyte: food.isElectrolyte,
          productType: food.productType,
        ),
      );

      totals.carbsG += food.carbsG * neededServings;
      totals.proteinG += food.proteinG * neededServings;
      totals.fatG += food.fatG * neededServings;
      totals.sodiumMg += food.sodiumMg * neededServings;
      totals.fluidMl += food.fluidMl * neededServings;

      // Stop only once every macro has actually REACHED its target
      // (2026-07-29) — must stay byte-for-byte equivalent to the stop
      // condition in the server's `greedy-fallback.ts`. The old fractional
      // thresholds (90% carbs / 70% protein / 70% water / 90% sodium) declared
      // success well short of target; the per-macro serving caps in
      // [_capServings] are what keep additions off the band ceiling.
      final carbsMet = carbsTarget <= 0 || totals.carbsG >= carbsTarget;
      // Protein is a stop criterion only for the after-phase fallback.
      final proteinTarget = targets.proteinG;
      final proteinMet =
          phase != 'after' ||
          proteinTarget <= 0 ||
          totals.proteinG >= proteinTarget;
      final waterMet = waterTarget <= 0 || totals.fluidMl >= waterTarget;
      final sodiumTarget = targets.sodiumMg;
      final sodiumMet = sodiumTarget <= 0 || totals.sodiumMg >= sodiumTarget;
      if (carbsMet && proteinMet && waterMet && sodiumMet) break;
    }

    return selections;
  }

  /// Sort foods by preference and macro efficiency.
  int _compareFoods(SolverFood a, SolverFood b, String phase) {
    // Primary: preference score descending
    if (a.preferenceScore != b.preferenceScore) {
      return b.preferenceScore - a.preferenceScore;
    }
    // Secondary: macro efficiency. Protein counts ONLY for the after-phase
    // fallback (2026-07-29): it approximates a curated recovery snack.
    if (phase == 'after') {
      return (b.carbsG + b.proteinG).compareTo(a.carbsG + a.proteinG);
    }
    return b.carbsG.compareTo(a.carbsG);
  }

  /// Check if adding 1 serving of [food] would excessively overshoot targets.
  bool _wouldOvershoot(
    SolverFood food,
    _RunningTotals totals,
    SolverTargets targets,
    String phase,
  ) {
    final carbsTarget = targets.carbsG;
    final sodiumTarget = targets.sodiumMg;
    final waterTarget = targets.fluidMl;

    final wouldOvershootCarbs =
        carbsTarget > 0 && totals.carbsG + food.carbsG > carbsTarget * 1.3;
    final wouldOvershootSodium =
        sodiumTarget > 0 &&
        totals.sodiumMg + food.sodiumMg > sodiumTarget * 1.3;
    final wouldOvershootWater =
        waterTarget > 0 && totals.fluidMl + food.fluidMl > waterTarget * 1.3;
    final proteinTarget = targets.proteinG;
    final wouldOvershootProtein =
        phase == 'after' &&
        proteinTarget > 0 &&
        totals.proteinG + food.proteinG > proteinTarget * 1.3;
    // After only: when protein is critically unmet, allow low-carb protein
    // foods through (e.g. a protein shake).
    final proteinCriticallyUnmet =
        phase == 'after' &&
        proteinTarget > 0 &&
        totals.proteinG < proteinTarget * 0.7;

    if (wouldOvershootCarbs &&
        totals.carbsG > carbsTarget * 0.7 &&
        !proteinCriticallyUnmet) {
      return true;
    }
    if (wouldOvershootSodium && totals.sodiumMg > sodiumTarget * 0.7) {
      return true;
    }
    if (wouldOvershootWater && totals.fluidMl > waterTarget * 0.7) {
      return true;
    }
    if (wouldOvershootProtein && totals.proteinG > proteinTarget * 0.9) {
      return true;
    }
    return false;
  }

  /// Calculate needed servings based on the primary deficit for this phase.
  double _calcNeededServings({
    required SolverFood food,
    required _RunningTotals totals,
    required SolverTargets targets,
    required String phase,
  }) {
    if (phase == 'after' && targets.proteinG > 0) {
      // After-phase fallback approximates a curated recovery snack:
      // protein first, then carbs (2026-07-29).
      final proteinDeficit = max(0.0, targets.proteinG - totals.proteinG);
      final carbsDeficit = max(0.0, targets.carbsG - totals.carbsG);
      final waterDeficit = max(0.0, targets.fluidMl - totals.fluidMl);
      final sodiumDeficit = max(0.0, targets.sodiumMg - totals.sodiumMg);
      if (proteinDeficit > 0 && food.proteinG > 0) {
        return (proteinDeficit / food.proteinG).ceilToDouble();
      } else if (carbsDeficit > 0 && food.carbsG > 0) {
        return (carbsDeficit / food.carbsG).ceilToDouble();
      } else if (waterDeficit > 0 && food.fluidMl > 0) {
        return (waterDeficit / food.fluidMl).ceilToDouble();
      } else if (sodiumDeficit > 0 && food.sodiumMg > 0) {
        return (sodiumDeficit / food.sodiumMg).ceilToDouble();
      }
      return 0;
    }
    // Before/during lead with carbs, then fall through to hydration and
    // sodium (2026-07-29, mirrors greedy-fallback.ts). Sizing on the carb
    // deficit alone meant that once carbs hit target every later food
    // resolved to 0 servings, stranding fluid and sodium wherever they landed.
    // Protein is still never a consideration outside the after phase.
    final carbsDeficit = max(0.0, targets.carbsG - totals.carbsG);
    final waterDeficit = max(0.0, targets.fluidMl - totals.fluidMl);
    final sodiumDeficit = max(0.0, targets.sodiumMg - totals.sodiumMg);
    if (carbsDeficit > 0 && food.carbsG > 0) {
      return (carbsDeficit / food.carbsG).ceilToDouble();
    } else if (waterDeficit > 0 && food.fluidMl > 0) {
      return (waterDeficit / food.fluidMl).ceilToDouble();
    } else if (sodiumDeficit > 0 && food.sodiumMg > 0) {
      return (sodiumDeficit / food.sodiumMg).ceilToDouble();
    }
    return 0;
  }

  /// Floor a raw serving cap to what the food can actually be served in.
  ///
  /// Without this the cap stays fractional (e.g. 2.75 bottles) and the
  /// downstream `roundToDouble()` rounds it back UP (to 3), breaching the very
  /// ceiling the cap existed to enforce. The server does this flooring inline
  /// in `greedy-fallback.ts` (`Math.floor` / `floorToIncrement`); Dart never
  /// did, which is how the offline solver could ship 1200ml against an 1100ml
  /// ceiling (2026-07-29).
  double _floorToGranularity(SolverFood food, double raw) {
    if (raw <= 0) return 0;
    return food.isIndivisible ? raw.floorToDouble() : (raw * 2).floor() / 2;
  }

  /// Cap servings to prevent overshooting individual macro targets.
  double _capServings({
    required SolverFood food,
    required double neededServings,
    required _RunningTotals totals,
    required SolverTargets targets,
    required String phase,
  }) {
    var capped = neededServings;

    // Cap by carbs. After only: relax the ceiling to 1.5x while protein is
    // critically unmet so protein-rich low-carb foods still fit.
    if (targets.carbsG > 0 && food.carbsG > 0) {
      final proteinCriticallyUnmet =
          phase == 'after' &&
          targets.proteinG > 0 &&
          totals.proteinG < targets.proteinG * 0.7;
      final carbMultiplier = proteinCriticallyUnmet ? 1.5 : 1.2;
      // Honor the explicit band ceiling when the caller supplied one, exactly
      // as greedy-fallback.ts does (`Math.min(carbHigh, target * mult)`).
      final carbCap = targets.carbsHighG == null
          ? targets.carbsG * carbMultiplier
          : min(targets.carbsHighG!, targets.carbsG * carbMultiplier);
      final maxCarbServings = _floorToGranularity(
        food,
        (carbCap - totals.carbsG) / food.carbsG,
      );
      if (maxCarbServings <= 0) return 0;
      capped = min(capped, maxCarbServings);
    }

    // Cap by sodium. `max(1.0, ...)` used to floor this at one serving, which
    // forced a ceiling breach whenever no serving fit — the server returns 0
    // (skip the food) instead. Prefer the in-range option and take the honest
    // shortfall over a silent overshoot (2026-07-29).
    if (targets.sodiumMg > 0 && food.sodiumMg > 0) {
      final sodiumHigh = targets.sodiumHighMg ?? targets.sodiumMg * 1.25;
      final maxSodiumServings = _floorToGranularity(
        food,
        (sodiumHigh - totals.sodiumMg) / food.sodiumMg,
      );
      if (maxSodiumServings <= 0) return 0;
      capped = min(capped, maxSodiumServings);
    }

    // Cap by water — same rationale as sodium above.
    if (targets.fluidMl > 0 && food.fluidMl > 0) {
      final fluidHigh = targets.fluidHighMl ?? targets.fluidMl * 1.2;
      final maxWaterServings = _floorToGranularity(
        food,
        (fluidHigh - totals.fluidMl) / food.fluidMl,
      );
      if (maxWaterServings <= 0) return 0;
      capped = min(capped, maxWaterServings);
    }

    // Cap by protein (after-phase fallback only)
    if (phase == 'after' && targets.proteinG > 0 && food.proteinG > 0) {
      final proteinHigh = targets.proteinG * 1.2;
      final maxProteinServings = _floorToGranularity(
        food,
        (proteinHigh - totals.proteinG) / food.proteinG,
      );
      if (maxProteinServings <= 0) return 0;
      capped = min(capped, maxProteinServings);
    }
    return capped;
  }

  /// Round to nearest 0.5 increment (matching server's roundToIncrement).
  double _roundToHalf(double value) {
    if (value <= 0) return 0;
    final rounded = (value * 2).round() / 2;
    return max(0.5, rounded);
  }
}

/// Mutable running totals tracker used during the solve loop.
class _RunningTotals {
  double carbsG = 0;
  double proteinG = 0;
  double fatG = 0;
  double sodiumMg = 0;
  double fluidMl = 0;
}
